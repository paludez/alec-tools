"""USD MaterialX (macro UsdMaterialX): after a USD import of a Blender export with "MaterialX Network" ticked, pick the
same USD file; each Principled BSDF's MaterialX network becomes an OpenPBR_Material on the objects that use it.
The code is in AlecUsdMtlxRead.py (the file) and AlecUsdMtlxBuild.py (the scene). Needs the USD for 3ds Max plugin (pxr).
"""

import importlib

from pymxs import runtime as rt


def main():
    if getattr(rt, "USDImporter", None) is None:
        rt.displayTempPrompt("USD MaterialX: the USD for 3ds Max plugin is not installed", 4000)
        return
    # the plugin loads on first use, with its pxr modules
    rt.pluginManager.loadClass(rt.USDImporter)
    import AlecUsdMtlxRead
    import AlecUsdMtlxBuild

    importlib.reload(AlecUsdMtlxRead)
    importlib.reload(AlecUsdMtlxBuild)
    AlecUsdMtlxBuild.run()


main()
