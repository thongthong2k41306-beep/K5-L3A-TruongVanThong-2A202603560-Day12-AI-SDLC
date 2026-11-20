"""Build the Windows release archive from the official, verified Godot template."""
from __future__ import annotations

import hashlib
from pathlib import Path
import shutil
import urllib.request
import zipfile

from manage import GODOT_DIR, ROOT, VERSION, run


def package() -> int:
    base = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/"
    archive_name = f"Godot_v{VERSION}-stable_export_templates.tpz"
    GODOT_DIR.mkdir(parents=True, exist_ok=True)
    template = GODOT_DIR / "windows_release_x86_64.exe"
    if not template.is_file():
        archive = GODOT_DIR / "windows-template.tpz"
        if not archive.is_file():
            urllib.request.urlretrieve(base + archive_name, archive)
        checksums = GODOT_DIR / "SHA512-SUMS.txt"
        if not checksums.is_file():
            urllib.request.urlretrieve(base + "SHA512-SUMS.txt", checksums)
        expected = next(line.split()[0] for line in checksums.read_text().splitlines()
                        if line.split() and line.split()[-1].lstrip("*") == archive_name)
        digest = hashlib.sha512()
        with archive.open("rb") as file:
            for chunk in iter(lambda: file.read(8 * 1024 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest() != expected:
            raise RuntimeError("Export template checksum mismatch")
        with zipfile.ZipFile(archive) as package:
            with package.open("templates/windows_release_x86_64.exe") as source, template.open("wb") as target:
                shutil.copyfileobj(source, target)
    output = ROOT / "build"
    output.mkdir(exist_ok=True)
    executable = output / "DaoDenLong.exe"
    code = run(["--headless", "--export-release", "Windows Desktop", str(executable)], timeout=180)
    if code:
        return code
    if not executable.is_file() or executable.stat().st_size < template.stat().st_size:
        raise RuntimeError("Godot did not produce the embedded Windows executable")
    with zipfile.ZipFile(output / "DaoDenLong-v1.0.0-Windows-x64.zip", "w", zipfile.ZIP_DEFLATED) as bundle:
        bundle.write(executable, executable.name)
        for name in ("LICENSE", "CREDITS.md"):
            bundle.write(ROOT / name, name)
        bundle.writestr("README.txt", "Extract the ZIP and launch DaoDenLong.exe.\nWindows x64 and OpenGL 3.3 required. Godot license: https://godotengine.org/license/\n")
    return 0
