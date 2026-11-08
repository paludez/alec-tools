-- BBox, Distribute, Mid Between and Measure Angle share one caddy pattern: it opens at once, hint when nothing is selected,
-- Reset / OK / Cancel buttons, the help icon, Enter = OK, right click = Cancel. A left click in a viewport and a running measurement need the
-- user's mouse and are not covered here.

global CP_fails = #()
global CP_value = undefined
global CP_boxes
fn CP_py code = (CP_value = undefined; python.Execute code; CP_value)

fn CP_check label ok = (format "% %\n" (if ok then "PASS" else "FAIL") label; if not ok do append CP_fails label)

python.Execute "import AlecTools_caddy\nfrom PySide6 import QtCore, QtGui, QtWidgets"
python.Execute @"
def cp_caddy():
    for c in AlecTools_caddy.GetQMaxMainWindow().findChildren(QtWidgets.QFrame, 'AlecToolsCaddy'):
        if c.isVisible():
            return c

def cp_buttons():
    c = cp_caddy()
    rt.CP_value = '|'.join(sorted(b.objectName() for b in c.findChildren(QtWidgets.QPushButton) if b.objectName() in ('ok', 'cancel', 'reset')))

def cp_help():
    rt.CP_value = len(cp_caddy().findChildren(AlecTools_caddy.HelpIcon))

def cp_click_help():
    icon = cp_caddy().findChildren(AlecTools_caddy.HelpIcon)[0]
    e = QtGui.QMouseEvent(QtCore.QEvent.MouseButtonPress, QtCore.QPointF(2, 2), QtCore.QPointF(2, 2), QtCore.Qt.LeftButton, QtCore.Qt.LeftButton, QtCore.Qt.NoModifier)
    icon.mousePressEvent(e)
    rt.CP_value = True

def cp_right_click():
    c = cp_caddy()
    e = QtGui.QMouseEvent(QtCore.QEvent.MouseButtonPress, QtCore.QPointF(2, 2), QtCore.QPointF(2, 2), QtCore.Qt.RightButton, QtCore.Qt.RightButton, QtCore.Qt.NoModifier)
    if hasattr(c, 'right_on_caddy'):
        c.right_on_caddy()
    else:
        c.mousePressEvent(e)
    rt.CP_value = True

def cp_enter():
    c = cp_caddy()
    c.keyPressEvent(QtGui.QKeyEvent(QtCore.QEvent.KeyPress, QtCore.Qt.Key_Return, QtCore.Qt.NoModifier))
    rt.CP_value = True

def cp_tags():
    rt.CP_value = len([t for t in AlecTools_caddy.GetQMaxMainWindow().findChildren(QtWidgets.QFrame, 'AlecToolsPickTag') if t.isVisible()])

def cp_hide_hint():
    AlecTools_caddy.hide_hint('Select objects first')
    rt.CP_value = True
"

fn CP_hintTest tl call =
(
	clearSelection()
	AlecTools_closeCaddy()
	execute call
	CP_check (tl + " nothing selected: no caddy") (AlecTools_caddyOpen == "")
	CP_check (tl + " nothing selected: hint shown") ((CP_py "cp_tags()") == 1)
	CP_py "cp_hide_hint()"
	CP_check (tl + " hint goes") ((CP_py "cp_tags()") == 0)
)

-- the caddy is open: buttons, help, a click on the help icon
fn CP_commonTest tl section =
(
	CP_check (tl + " caddy open") (AlecTools_caddyOpen == section)
	CP_check (tl + " buttons Reset OK Cancel") ((CP_py "cp_buttons()") == "cancel|ok|reset")
	CP_check (tl + " help icon") ((CP_py "cp_help()") == 1)
	CP_check (tl + " help icon click") ((CP_py "cp_click_help()") == true)
)

fileIn (AlecTools_path "tools/bbox.ms")
fileIn (AlecTools_path "tools/distribute.ms")
fileIn (AlecTools_path "tools/midBetween.ms")
fileIn (AlecTools_path "tools/measureAngle.ms")
fileIn (AlecTools_path "tools/measureAngleDialog.ms")

CP_hintTest "BBox" "AlecBBox_run()"
CP_hintTest "Distribute" "AlecDistribute_run()"
CP_hintTest "MidBetween" "AlecMidBetween_run()"
CP_hintTest "MeasureAngle" "AlecMeasureAngle_run()"

CP_boxes = for i = 1 to 3 collect Box name:("CP_box" + i as string) pos:[i * 40, 0, 0]

-- BBox: right click cancels, Enter keeps the cages
select CP_boxes
AlecBBox_run()
CP_commonTest "BBox" "BBox"
CP_check "BBox preview cage" ((getNodeByName "BBox") != undefined)
CP_py "cp_right_click()"
CP_check "BBox right click closes" (AlecTools_caddyOpen == "")
CP_check "BBox right click removes the preview" ((getNodeByName "BBox") == undefined)
AlecBBox_run()
CP_py "cp_enter()"
CP_check "BBox Enter closes" (AlecTools_caddyOpen == "")
CP_check "BBox Enter keeps the cage" ((getNodeByName "BBox") != undefined)
delete (getNodeByName "BBox")
if LayerManager.getLayerFromName "BBox helpers" != undefined do LayerManager.deleteLayerByName "BBox helpers"

-- Distribute
select CP_boxes
CP_boxes[3].pos = [200, 0, 0]
AlecDistribute_run()
CP_commonTest "Distribute" "Distribute"
CP_py "cp_right_click()"
CP_check "Distribute right click closes" (AlecTools_caddyOpen == "")
CP_check "Distribute right click puts the objects back" (CP_boxes[3].pos.x == 200 and CP_boxes[2].pos.x == 80)
AlecDistribute_run()
CP_py "cp_enter()"
CP_check "Distribute Enter closes" (AlecTools_caddyOpen == "")
CP_check "Distribute Enter distributes" (abs (CP_boxes[2].pos.x - 120) < 0.01)

-- Mid Between: the caddy only (the pick loop needs the mouse)
select CP_boxes
AlecMidBetween_active = AlecMidBetween_newSession (AlecMidBetween_Settings())
python.ExecuteFile (AlecTools_path "tools/midBetweenCaddy.py")
CP_commonTest "MidBetween" "MidBetween"
CP_py "cp_right_click()"
CP_check "MidBetween right click closes" (AlecTools_caddyOpen == "" and AlecMidBetween_active == undefined)
AlecMidBetween_active = AlecMidBetween_newSession (AlecMidBetween_Settings())
python.ExecuteFile (AlecTools_path "tools/midBetweenCaddy.py")
CP_py "cp_enter()"
CP_check "MidBetween Enter closes" (AlecTools_caddyOpen == "" and AlecMidBetween_active == undefined)

-- Measure Angle: the caddy only (the measurement needs the mouse)
python.ExecuteFile (AlecTools_path "tools/measureAngleCaddy.py")
CP_commonTest "MeasureAngle" "MeasureAngle"
CP_check "MeasureAngle has no Start button" ((CP_py "rt.CP_value = len([b for b in cp_caddy().findChildren(QtWidgets.QPushButton) if b.text() == 'Start'])") == 0)
CP_py "cp_right_click()"
CP_check "MeasureAngle right click closes" (AlecTools_caddyOpen == "")
python.ExecuteFile (AlecTools_path "tools/measureAngleCaddy.py")
CP_py "cp_enter()"
CP_check "MeasureAngle Enter closes" (AlecTools_caddyOpen == "")

delete CP_boxes
AlecTools_closeCaddy()
format "failures: %\n" CP_fails.count
for f in CP_fails do format "FAIL %\n" f
