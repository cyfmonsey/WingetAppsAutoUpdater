#!/usr/bin/env python3
# WingetAppsAutoUpdater.py
# Stdlib-only, no persistent installs. Finds the latest winget.exe under WindowsApps and runs upgrade.

import os
import re
import sys
import subprocess
from pathlib import Path
from typing import Optional, Tuple

MIN_WIN10_1809 = (10, 0, 17763)
MIN_SERVER_2022 = (10, 0, 20348)
MIN_WIN11 = (10, 0, 22000)

def parse_version_tuple(s: str) -> Tuple[int, int, int]:
    parts = [int(p) for p in re.findall(r"\d+", s)[:3]]
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])

def get_windows_version_tuple() -> Tuple[int, int, int]:
    # sys.getwindowsversion() is reliable and stdlib
    v = sys.getwindowsversion()
    return (v.major, v.minor, v.build)

def is_supported_windows() -> bool:
    v = get_windows_version_tuple()
    # Windows 10 1809+ OR Windows 11 OR Server 2022+
    return (
        v >= MIN_WIN10_1809 or
        v >= MIN_WIN11 or
        v >= MIN_SERVER_2022
    )

def find_latest_winget_in_windowsapps() -> Optional[Path]:
    base = Path(r"C:\Program Files\WindowsApps")
    if not base.is_dir():
        return None

    # Typical folder names look like:
    #   Microsoft.DesktopAppInstaller_1.22.3621.0_x64__8wekyb3d8bbwe
    # We’ll pick the highest version that actually contains winget.exe
    candidates = []
    pat = re.compile(r"^Microsoft\.DesktopAppInstaller_(\d+\.\d+\.\d+\.\d+)_")
    try:
        for p in base.iterdir():
            if not p.is_dir():
                continue
            m = pat.match(p.name)
            if not m:
                continue
            ver = tuple(int(x) for x in m.group(1).split("."))
            winget_path = p / "winget.exe"
            if winget_path.exists():
                candidates.append((ver, winget_path))
    except PermissionError:
        # Access to WindowsApps can be restricted; in that case we’ll fall back to PATH
        return None

    if not candidates:
        return None

    candidates.sort(reverse=True)
    return candidates[0][1]

def which(cmd: str) -> Optional[Path]:
    # Simple which for Windows
    exts = os.environ.get("PATHEXT", ".EXE;.BAT;.CMD").split(";")
    for dirpath in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(dirpath) / cmd
        if candidate.exists():
            return candidate
        for ext in exts:
            c2 = candidate.with_suffix(ext.lower())
            if c2.exists():
                return c2
    return None

def get_winget_path() -> Optional[Path]:
    # Prefer the WindowsApps copy (like the PS1), else fallback to winget on PATH
    p = find_latest_winget_in_windowsapps()
    if p:
        return p
    return which("winget.exe") or which("winget")

def run_winget_upgrade(winget: Path) -> int:
    args = [
        str(winget),
        "upgrade",
        "--all",
        "-h",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--include-unknown",
        "--force",
    ]
    print("Running:", " ".join(args))
    try:
        proc = subprocess.run(args, check=False)
        return proc.returncode
    except Exception as e:
        print(f"Error launching winget: {e}")
        return 1

def main() -> int:
    if os.name != "nt":
        print("This script is intended for Windows.")
        return 1

    if not is_supported_windows():
        print("This system does not meet the minimum requirement (Windows 10 1809+, Windows 11, or Windows Server 2022).")
        return 1

    winget = get_winget_path()
    if not winget:
        print("winget.exe not found. Make sure App Installer is installed and accessible.")
        return 1

    # Recommend elevation (won’t force it—keeps it simple and dependency-free)
    try:
        # crude admin check: writing to a protected location would fail; we just hint instead
        import ctypes  # stdlib
        if ctypes.windll.shell32.IsUserAnAdmin() == 0:
            print("Note: Running without Administrator privileges may limit upgrades. Right-click your console and 'Run as administrator' for best results.")
    except Exception:
        pass

    return run_winget_upgrade(winget)

if __name__ == "__main__":
    sys.exit(main())
