-- BBox, Distribute, Mid Between and Measure Angle share one caddy pattern: it opens at once, hint when nothing is selected,
-- Reset / OK / Cancel buttons, the help icon, Enter = OK, right click = Cancel. Esc = Cancel on every caddy, the popups at the mouse,
-- Max Settings and the toolbar editor too. A left click in a viewport and a running measurement need the user's mouse and are not covered here.

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

# Esc as a key event, sent to the caddy or to a child of it (a text box when it has one), which passes it up
def cp_escape(child):
    c = cp_caddy()
    target = c
    if child:
        target = (c.findChildren(QtWidgets.QLineEdit) or c.findChildren(QtWidgets.QPushButton))[0]
        target.setFocus()
    QtWidgets.QApplication.sendEvent(target, QtGui.QKeyEvent(QtCore.QEvent.KeyPress, QtCore.Qt.Key_Escape, QtCore.Qt.NoModifier))
    rt.CP_value = True

# what the key watcher posts for an Esc on a caddy without a text box
def cp_escape_watched():
    c = cp_caddy()
    QtWidgets.QApplication.sendEvent(c, QtCore.QEvent(c.CANCEL_EVENT))
    rt.CP_value = True

def cp_layer_popup():
    popups = [w for w in AlecTools_caddy.GetQMaxMainWindow().findChildren(QtWidgets.QFrame, 'AlecToolsCaddy') if type(w).__name__ == 'MoveToLayerPopup' and w.isVisible()]
    for popup in popups:
        popup.close()
    rt.CP_value = len(popups)

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

CP_boxes = for i = 1 to 3 collect Box name:("CP_box" + i as string) pos:[i * 40, 0, 0]

-- BBox: right click cancels, Enter keeps the cages
select CP_boxes
AlecBBox_open()
CP_commonTest "BBox" "BBox"
CP_check "BBox preview cage" ((getNodeByName "BBox") != undefined)
CP_py "cp_right_click()"
CP_check "BBox right click closes" (AlecTools_caddyOpen == "")
CP_check "BBox right click removes the preview" ((getNodeByName "BBox") == undefined)
AlecBBox_open()
CP_py "cp_enter()"
CP_check "BBox Enter closes" (AlecTools_caddyOpen == "")
CP_check "BBox Enter keeps the cage" ((getNodeByName "BBox") != undefined)
delete (getNodeByName "BBox")
AlecBBox_open()
(python.import "AlecTools_caddy").accept_open()
CP_check "BBox viewport left click is OK" (AlecTools_caddyOpen == "" and (getNodeByName "BBox") != undefined)
delete (getNodeByName "BBox")
if LayerManager.getLayerFromName "BBox helpers" != undefined do LayerManager.deleteLayerByName "BBox helpers"

-- Distribute
select CP_boxes
CP_boxes[3].pos = [200, 0, 0]
AlecDistribute_open()
CP_commonTest "Distribute" "Distribute"
CP_py "cp_right_click()"
CP_check "Distribute right click closes" (AlecTools_caddyOpen == "")
CP_check "Distribute right click puts the objects back" (CP_boxes[3].pos.x == 200 and CP_boxes[2].pos.x == 80)
AlecDistribute_open()
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

-- Esc is Cancel on every caddy, sent to the caddy itself and to a child that has the focus (a real key press is a hand check)
fn CP_escTest tl section child =
(
	CP_check (tl + " caddy open") (AlecTools_caddyOpen == section)
	CP_py ("cp_escape(" + (if child then "True" else "False") + ")")
	CP_check (tl + " Esc" + (if child then " from a child" else "") + " closes") (AlecTools_caddyOpen == "")
)

select CP_boxes
AlecBBox_open()
CP_escTest "BBox" "BBox" false
CP_check "BBox Esc removes the preview" ((getNodeByName "BBox") == undefined)
AlecBBox_open()
CP_escTest "BBox" "BBox" true
CP_check "BBox Esc from a child removes the preview" ((getNodeByName "BBox") == undefined)

CP_boxes[3].pos = [300, 0, 0]
AlecDistribute_open()
CP_escTest "Distribute" "Distribute" true
CP_check "Distribute Esc puts the objects back" (CP_boxes[3].pos.x == 300 and abs (CP_boxes[2].pos.x - 120) < 0.01)
CP_boxes[3].pos = [200, 0, 0]

AlecMidBetween_active = AlecMidBetween_newSession (AlecMidBetween_Settings())
CP_check "MidBetween pick ended with Esc cancels (pickPoint)" ((AlecMidBetween_outcome AlecMidBetween_active #escape) == #cancel)
CP_check "MidBetween pick ended with Esc cancels (pickObject)" ((AlecMidBetween_outcome AlecMidBetween_active undefined) == #cancel)
python.ExecuteFile (AlecTools_path "tools/midBetweenCaddy.py")
CP_escTest "MidBetween" "MidBetween" false
CP_check "MidBetween Esc ends the session" (AlecMidBetween_active == undefined)

python.ExecuteFile (AlecTools_path "tools/measureAngleCaddy.py")
CP_escTest "MeasureAngle" "MeasureAngle" true

fileIn (AlecTools_path "tools/grab.ms")
for mode in #(#move, #rotate, #scale) do
(
	select CP_boxes
	local before = CP_boxes[1].transform
	AlecGrab_run mode
	AlecGrab_preview [50, 50, 50]
	CP_check ((AlecGrab_name()) + " preview changes the selection") (CP_boxes[1].transform != before)
	CP_escTest (AlecGrab_name()) (AlecGrab_name()) true
	CP_check ((AlecGrab_name()) + " Esc puts the selection back") (CP_boxes[1].transform == before)
)

select CP_boxes
AlecBBox_open()
CP_check "BBox key watcher runs" ((CP_py "rt.CP_value = cp_caddy().key_timer.isActive()") == true)
AlecTools_showPickTag "CP pick"
CP_check "pick tag is seen (Esc then belongs to the pick)" ((CP_py "rt.CP_value = AlecTools_caddy.pick_tag_shown()") == true)
AlecTools_hidePickTag()
CP_check "pick tag gone" ((CP_py "rt.CP_value = AlecTools_caddy.pick_tag_shown()") == false)
CP_py "cp_escape_watched()"
CP_check "BBox Esc seen by the key watcher closes" (AlecTools_caddyOpen == "" and (getNodeByName "BBox") == undefined)

fileIn (AlecTools_path "tools/moveToLayer.ms")
AlecMoveToLayer_run()
CP_check "Move to Layer opens" ((CP_py "cp_layer_popup()") == 1)

python.ExecuteFile (AlecTools_path "tools/transformPopup.py")
CP_escTest "Transform Popup" "Transform Popup" true
python.ExecuteFile (AlecTools_path "tools/createPopup.py")
CP_escTest "Create Popup" "Create Popup" true
python.ExecuteFile (AlecTools_path "tools/maxSettings.py")
CP_escTest "Max Settings" "Max Settings" true
python.ExecuteFile (AlecTools_path "tools/toolbarEditor.py")
CP_escTest "Toolbar Editor" "Toolbar Editor" true

-- the real runs, with the mouse replaced by a redraw callback that acts once a tool is running (a tool waits for a click, so the run only returns
-- when it ends). BBox / Distribute: the click tool is paused once (a pick), then a left click is OK. Measure Angle: an option changes once
-- (Faces), then the measurement ends as a right click would
global CP_step = 0
global CP_seen = 0
global CP_mode = ""

fn CP_onClickTool =
(
	if AlecTools_clickActive do
	(
		CP_step += 1
		if CP_step == 1 then AlecTools_clickPause()
		else
		(
			unregisterRedrawViewsCallback CP_onClickTool
			(python.import "AlecTools_caddy").accept_open()
			max select
		)
	)
)

fn CP_onMeasure =
(
	if AlecTools_toolDraw != undefined do
	(
		CP_seen += 1
		if CP_step == 0 and CP_seen >= 3 then
		(
			CP_step = 1
			AlecMeasureAngle_restart 3 1
		)
		else if CP_step == 1 and AlecMeasureAngle_mode == #faces do
		(
			CP_step = 2
			unregisterRedrawViewsCallback CP_onMeasure
			CP_mode = AlecMeasureAngle_mode as string
			max select
		)
	)
)

fn CP_realRun label runFn callback =
(
	CP_step = 0
	CP_seen = 0
	registerRedrawViewsCallback callback
	local err = try (runFn(); "") catch (getCurrentException())
	unregisterRedrawViewsCallback callback
	CP_check (label + " real run returns without an error " + err) (err == "")
	CP_check (label + " real run: tool restarted once, ended") (CP_step >= 2)
	CP_check (label + " real run: caddy closed") (AlecTools_caddyOpen == "")
)

select CP_boxes
CP_realRun "BBox" AlecBBox_run CP_onClickTool
CP_check "BBox real run: left click kept the cage" ((getNodeByName "BBox") != undefined)
if (getNodeByName "BBox") != undefined do delete (getNodeByName "BBox")
if LayerManager.getLayerFromName "BBox helpers" != undefined do LayerManager.deleteLayerByName "BBox helpers"

CP_boxes[3].pos = [200, 0, 0]
select CP_boxes
CP_realRun "Distribute" AlecDistribute_run CP_onClickTool
CP_check "Distribute real run: left click distributed" (abs (CP_boxes[2].pos.x - 120) < 0.01)

clearSelection()
CP_realRun "MeasureAngle" AlecMeasureAngle_run CP_onMeasure
CP_check "MeasureAngle real run: restarted in Faces mode" (CP_mode == "faces")

delete CP_boxes
AlecTools_closeCaddy()
CP_check "escapeEnable is still off" (escapeEnable == false)
format "failures: %\n" CP_fails.count
for f in CP_fails do format "FAIL %\n" f
