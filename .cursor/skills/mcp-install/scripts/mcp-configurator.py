#!/usr/bin/env python3
"""Forward to mcp-switch/scripts/mcp-configurator.py (compat shim)."""
from __future__ import annotations

import runpy
import sys
from pathlib import Path

target = Path(__file__).resolve().parent.parent.parent / "mcp-switch" / "scripts" / "mcp-configurator.py"
if not target.is_file():
    raise SystemExit(f"Switch configurator not found: {target}")

sys.argv[0] = str(target)
runpy.run_path(str(target), run_name="__main__")
