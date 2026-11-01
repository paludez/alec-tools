"""Opens the toolbar editor (Edit Toolbar macro); the code is in AlecToolbar.py."""

import importlib
import sys

from pymxs import runtime as rt

TOOLS = rt.AlecTools_path("tools")
if TOOLS not in sys.path:
    sys.path.append(TOOLS)
import AlecToolbar

importlib.reload(AlecToolbar)
AlecToolbar.open_editor()
