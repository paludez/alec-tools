-- Check for the Create popup (materials / maps / misc, at the cursor in the SME and in the viewport). Prints facts only, no PASS/FAIL:
-- 1. the real class names for VRayMtl, OpenPBR, V-Ray bitmap, Uber bitmap and the mix maps
-- 2. what the Slate view offers (interfaces, node properties), to place a node at the cursor
-- 3. the Qt windows of the SME, to tell whether the cursor is over it
-- Creates one temporary Slate view ("AlecPopupCheck") and deletes it at the end. Does not touch the scene.

fn AlecPopupCheck_classes list patterns =
(
	for c in list where (for p in patterns where matchPattern (c as string) pattern:p collect p).count > 0 collect (c as string)
)

format "--- material classes\n"
print (AlecPopupCheck_classes material.classes #("*vraymtl*", "*openpbr*", "*blend*", "*multi*"))
format "--- map classes\n"
print (AlecPopupCheck_classes textureMap.classes #("*bitmap*", "*uber*", "*mix*", "*blend*", "*composite*"))

(
format "--- Slate view\n"
if not sme.isOpen() do sme.Open()
local old = sme.GetViewByName "AlecPopupCheck"
if old != 0 do sme.DeleteView old false
local index = sme.CreateView "AlecPopupCheck"
local view = sme.GetView index
showInterfaces view
local a = view.CreateNode (VRayMtl()) [100, 200]
local b = view.CreateNode (VRayMtl()) [1000, 200]
format "node position: % %\n" a.position b.position
view.ZoomExtents()
sme.DeleteView index false

format "--- Qt windows\n"
python.Execute (
"from qtmax import GetQMaxMainWindow\nfrom PySide6 import QtWidgets\n" +
"for w in QtWidgets.QApplication.topLevelWidgets():\n" +
"    t = w.windowTitle()\n" +
"    if w.isVisible() and ('Slate' in t or 'Material' in t or 'Editor' in t):\n" +
"        print('top:', type(w).__name__, repr(t), w.objectName(), w.geometry())\n" +
"        for c in w.findChildren(QtWidgets.QWidget):\n" +
"            if c.isVisible() and c.width() > 200 and c.height() > 200:\n" +
"                print('   child:', type(c).__name__, c.objectName(), c.size())\n"
)
)
