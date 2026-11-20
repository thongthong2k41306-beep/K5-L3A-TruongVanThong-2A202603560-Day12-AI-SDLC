"""Verification gate for humans, agents, and CI: nonzero blocks completion."""
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
for action in ("build", "test"):
    result = subprocess.run([sys.executable, str(root / "tools/manage.py"), action], cwd=root)
    if result.returncode:
        print(f"BLOCKED: {action} failed. Do not mark the phase complete.", file=sys.stderr)
        raise SystemExit(result.returncode)
print("Verification gate passed. Review visual evidence separately.")
