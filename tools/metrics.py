"""Run the Godot measurement driver and collect the native process RSS."""
from __future__ import annotations

import argparse
import ctypes
import json
import os
from pathlib import Path
import platform
import subprocess
import tempfile
import time


def rss(pid: int) -> float:
    """Read resident memory in MiB, including engine and graphics allocations resident in RAM."""
    if platform.system() == "Windows":
        from ctypes import wintypes

        class Counters(ctypes.Structure):
            _fields_ = [("cb", wintypes.DWORD), ("faults", wintypes.DWORD),
                        *[(name, ctypes.c_size_t) for name in (
                            "peak_working", "working", "peak_paged", "paged",
                            "peak_nonpaged", "nonpaged", "pagefile", "peak_pagefile")]]

        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
        handle = kernel.OpenProcess(0x0410, False, pid)
        if not handle:
            raise OSError(ctypes.get_last_error(), "OpenProcess")
        psapi = ctypes.WinDLL("psapi", use_last_error=True)
        counters = Counters()
        counters.cb = ctypes.sizeof(counters)
        try:
            psapi.GetProcessMemoryInfo.argtypes = (wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD)
            if not psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
                raise OSError(ctypes.get_last_error(), "GetProcessMemoryInfo")
            return counters.working / (1024 * 1024)
        finally:
            kernel.CloseHandle(handle)
    if platform.system() == "Linux":
        pages = int(Path(f"/proc/{pid}/statm").read_text().split()[1])
        return pages * os.sysconf("SC_PAGE_SIZE") / (1024 * 1024)
    kib = int(subprocess.check_output(["ps", "-o", "rss=", "-p", str(pid)], text=True))
    return kib / 1024


def run(mode, arguments, command, root, env):
    parser = argparse.ArgumentParser(prog=mode)
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--out", type=Path, required=True)
    if mode == "bench":
        parser.add_argument("--duration", type=float, required=True)
    else:
        parser.add_argument("--nights", type=int, required=True)
    args = parser.parse_args(arguments)
    amount = args.duration if mode == "bench" else args.nights
    if not 0 < amount <= 3600:
        parser.error("duration or nights must be between zero and 3600")
    out = args.out.resolve()
    with tempfile.TemporaryDirectory(prefix=f"{mode}-", dir=root / ".tools") as temp:
        folder = Path(temp)
        driver = ["--script", "res://src/metrics.gd"]
        if mode == "soak":
            driver.insert(0, "--headless")
        process_start = time.time()
        proc = subprocess.Popen(command([
            *driver, "--", mode, temp, str(args.seed), str(amount), str(process_start),
        ]), cwd=root, env=env)
        start = time.monotonic()
        pid = None
        peak = 0.0
        memory = {}
        try:
            while proc.poll() is None:
                if time.monotonic() - start > max(180, amount + 60):
                    raise RuntimeError(f"{mode} did not finish in time")
                if pid is None and (folder / "pid.json").is_file():
                    try:
                        pid = int(json.loads((folder / "pid.json").read_text())["pid"])
                    except json.JSONDecodeError:
                        pass
                if pid is not None:
                    if mode == "bench" and (folder / "measuring.json").is_file() and not (folder / "result.json").exists():
                        try:
                            peak = max(peak, rss(pid))
                        except (OSError, ValueError, subprocess.CalledProcessError):
                            if proc.poll() is None and not (folder / "result.json").exists():
                                raise
                    if mode == "soak":
                        for name in ("start", "end"):
                            if name not in memory and (folder / (name + ".json")).is_file():
                                memory[name] = rss(pid)
                                (folder / (name + ".ack")).touch()
                time.sleep(0.01)
        finally:
            if proc.poll() is None:
                proc.terminate()
                proc.wait()
        if proc.returncode:
            return proc.returncode
        result = json.loads((folder / "result.json").read_text())
        if mode == "bench":
            if peak <= 0:
                raise RuntimeError("Could not measure benchmark RSS")
            result["peak_mem_mb"] = round(peak, 3)
        else:
            result["mem_start_mb"] = round(memory["start"], 3)
            result["mem_end_mb"] = round(memory["end"], 3)
        out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(out)
        return 0
