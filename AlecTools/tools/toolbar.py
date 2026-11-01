"""Creates the Alec Tools toolbar (AlecTools_load, at every start and reload); the code is in AlecToolbar.py."""

import importlib
import sys

from pymxs import runtime as rt

TOOLS = rt.AlecTools_path("tools")
if TOOLS not in sys.path:
    sys.path.append(TOOLS)
import AlecToolbar

importlib.reload(AlecToolbar)
AlecToolbar.create()
