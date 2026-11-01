"""USD MaterialX (macro UsdMaterialX): after a USD import of a Blender export with "MaterialX Network" ticked, pick the
same USD file; each Principled BSDF's MaterialX network becomes an OpenPBR_Material on the objects that use it.
The code is in AlecUsdMtlxRead.py (the file) and AlecUsdMtlxBuild.py (the scene). Needs the USD for 3ds Max plugin (pxr).
"""

import importlib
import sys

from pymxs import runtime as rt

if getattr(rt, "USDImporter", None) is None:
    raise RuntimeError("USD MaterialX needs the USD for 3ds Max plugin")
# the plugin loads on first use, with its pxr modules
rt.pluginManager.loadClass(rt.USDImporter)

TOOLS = rt.AlecTools_path("tools")
if TOOLS not in sys.path:
    sys.path.append(TOOLS)
import AlecUsdMtlxRead
import AlecUsdMtlxBuild

importlib.reload(AlecUsdMtlxRead)
importlib.reload(AlecUsdMtlxBuild)
AlecUsdMtlxBuild.run()
