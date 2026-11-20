#!/usr/bin/env python3
"""Portable Godot launcher. Python standard library only; same commands on 3 OSes."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.5.1"
TOOLS = ROOT / ".tools"
GODOT_DIR = TOOLS / "godot"


def engine() -> Path:
    override = os.environ.get("GODOT_BIN")
    if override:
        resolved = shutil.which(override) or override
        if not Path(resolved).is_file():
            raise RuntimeError(f"GODOT_BIN does not exist: {resolved}")
        return Path(resolved).resolve()
    system = platform.system()
    if system == "Windows":
        binary = GODOT_DIR / f"Godot_v{VERSION}-stable_win64_console.exe"
    elif system == "Darwin":
        binary = GODOT_DIR / "Godot.app/Contents/MacOS/Godot"
    else:
        arch = "arm64" if platform.machine().lower() in ("aarch64", "arm64") else "x86_64"
        binary = GODOT_DIR / f"Godot_v{VERSION}-stable_linux.{arch}"
    if binary.is_file():
        return binary
    for command in ("godot", "godot4"):
        found = shutil.which(command)
        if found:
            return Path(found)
    raise RuntimeError("Godot is missing. Run: python tools/manage.py build (or set GODOT_BIN).")


def download() -> Path:
    try:
        return engine()
    except RuntimeError:
        if os.environ.get("GODOT_BIN"):
            raise
    GODOT_DIR.mkdir(parents=True, exist_ok=True)
    system = platform.system()
    arch = platform.machine().lower()
    suffix = {"Windows": "win64.exe", "Darwin": "macos.universal"}.get(system)
    if suffix is None:
        suffix = "linux.arm64" if arch in ("arm64", "aarch64") else "linux.x86_64"
    archive_name = f"Godot_v{VERSION}-stable_{suffix}.zip"
    base = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/"
    archive = GODOT_DIR / archive_name
    print(f"Downloading official Godot {VERSION}: {archive_name}", flush=True)
    urllib.request.urlretrieve(base + archive_name, archive)
    # Validate against the checksums supplied by the engine's own release.
    checksum_text = urllib.request.urlopen(base + "SHA512-SUMS.txt", timeout=60).read().decode()
    matches = [line.split()[0] for line in checksum_text.splitlines()
               if line.split() and line.split()[-1].lstrip("*") == archive_name]
    if len(matches) != 1 or hashlib.sha512(archive.read_bytes()).hexdigest() != matches[0]:
        raise RuntimeError("Godot archive SHA512 verification failed")
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            target = (GODOT_DIR / member.filename).resolve()
            if not target.is_relative_to(GODOT_DIR.resolve()):
                raise RuntimeError("Unsafe archive path")
        bundle.extractall(GODOT_DIR)
    binary = engine()
    if system != "Windows":
        binary.chmod(binary.stat().st_mode | 0o111)
    return binary


def environment() -> dict[str, str]:
    env = os.environ.copy()
    # Keep engine caches and user data inside this checkout, including in CI.
    for name, subdir in (("APPDATA", "userdata"), ("LOCALAPPDATA", "localdata"),
                         ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                         ("XDG_CACHE_HOME", "cache")):
        path = TOOLS / subdir
        path.mkdir(parents=True, exist_ok=True)
        env[name] = str(path)
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    return env


def command(extra: list[str]) -> list[str]:
    return [str(engine()), "--path", str(ROOT), "--log-file", str(TOOLS / f"godot-{os.getpid()}.log"), *extra]


def run(extra: list[str], timeout: int | None = None) -> int:
    return subprocess.run(command(extra), cwd=ROOT, env=environment(), timeout=timeout).returncode


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: python tools/manage.py build|play|headless|bench|soak|package|test|gui-test|capture|editor [arguments]")
        return 2
    action, args = sys.argv[1], sys.argv[2:]
    if action == "build":
        binary = download()
        # Portable editor mode avoids writing settings outside the project.
        if binary.is_relative_to(GODOT_DIR):
            (GODOT_DIR / "_sc_").touch()
        result = subprocess.run(command(["--headless", "--editor", "--quit"]), cwd=ROOT,
                                env=environment(), capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
        log = result.stdout + result.stderr
        print(log)
        return result.returncode or (1 if "SCRIPT ERROR" in log or "Parse Error" in log else 0)
    if action == "play":
        if len(args) == 2 and args[0] == "--export-leaderboard":
            return run(["--headless", "--script", "res://src/leaderboard_cli.gd", "--", args[1]])
        return run(args)
    if action in ("bench", "soak"):
        import metrics
        return metrics.run(action, args, command, ROOT, environment())
    if action == "package":
        from release import package
        return package()
    if action == "editor":
        return run(["--editor", *args])
    if action == "headless":
        return run(["--headless", "--script", "res://src/headless.gd", "--", *args])
    if action == "test":
        code = run(["--headless", "--script", "res://tests/unit.gd"], timeout=45)
        if code:
            return code
        return subprocess.run([sys.executable, str(ROOT / "tests/test_contract.py"), *args], cwd=ROOT, env=environment()).returncode
    if action == "gui-test":
        return run(["--script", "res://tests/test_gui.gd"], timeout=90)
    if action == "capture":
        directory = ROOT / "docs/proof/local"
        directory.mkdir(parents=True, exist_ok=True)
        name = "menu.png" if "--capture-menu" in args else "gameplay.png"
        return run(["--", "--capture", str(directory / name), *args], timeout=90)
    print("Unknown action:", action, file=sys.stderr)
    return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
