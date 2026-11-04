-- Test for how the panels close (lib/AlecTools_caddy.py): a click elsewhere (CLICK_AWAY), the shortcut again (KEY_TOGGLES), never Esc.
-- Run in Max after Reload Alec Tools:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\clickAway_test.ms"
-- Calls what a click and a key run; creates and deletes its own box. Prints PASS/FAIL lines, then the number of failures and the failed ones.
-- By hand, with the real clicks and keys (give the macros shortcuts first):
--   Scale, type 200, left click in a viewport: closes, the object is back as it was.
--   Scale, type 200, right click in a viewport: closes, the object stays scaled.
--   Scale, type 200, the shortcut again: closes, the object is back. A long press of the shortcut does not close it by itself.
--   With a saved scene: Mid Between from its toolbar button with nothing selected, Esc: the pick ends, no crash. Then held down.
--   Scale, Max Settings and the other panels, Esc, then held down: nothing happens.
--   Transform Popup, the shortcut again, before and after clicking into a box: closes.
--   Max Settings, the shortcut again while typing in a path: closes.
--   BBox with Shift + click, Axes of: Esc cancels the pick (Max's own), the panel stays open.
--   Transform Popup, left click in a viewport: closes. Middle drag on a box (the ladder), Tab, a click on another box: stays open.

global AlecAwayTest_failed = #()

fn AlecAwayTest_check label ok =
(
	format "% %\n" (if ok then "PASS" else "FAIL") label
	if not ok do append AlecAwayTest_failed label
)

-- python.Execute gives #success, not the value: the results come back through a temporary global
fn AlecAwayTest_python code =
(
	python.Execute ("rt.ATtest_value = " + code)
	local value = globalVars.get #ATtest_value
	globalVars.remove #ATtest_value
	value
)

python.Execute "
import AlecTools_caddy
from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow
def away_panel():
    return [w for w in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, AlecTools_caddy.OBJECT_NAME) if w.isVisible()][0]
# S (Windows key 0x53) as the panel's shortcut, then S pressed on what has the focus
AWAY_S = 0x53
def away_press(modifiers=QtCore.Qt.NoModifier, repeat=False):
    panel = away_panel()
    panel.toggle_key.keys = {AWAY_S}
    panel.toggle_key.modifiers = QtCore.Qt.NoModifier
    target = panel.focusWidget() or panel
    QtWidgets.QApplication.sendEvent(target, QtGui.QKeyEvent(QtCore.QEvent.KeyPress, QtCore.Qt.Key_S, modifiers, 0, AWAY_S, 0, 's', repeat))
def away_escape():
    panel = away_panel()
    QtWidgets.QApplication.sendEvent(panel, QtGui.QKeyEvent(QtCore.QEvent.KeyPress, QtCore.Qt.Key_Escape, QtCore.Qt.NoModifier))
"

(
	AlecAwayTest_failed = #()
	AlecAwayTest_check "the load turned the Esc interrupt off" (not escapeEnable)
	local b = box name:"ATtest_clickAway"
	select b

	for macro in #("Grab", "Rotate", "Scale", "TransformPopup", "CreatePopup") do
	(
		macros.run "Alec Tools" macro
		AlecAwayTest_check (macro + ": closes on a click elsewhere") ((AlecAwayTest_python "away_panel().CLICK_AWAY") == true)
		python.Execute "away_panel().clicked_away()"
		AlecAwayTest_check (macro + ": a click elsewhere closed it") (AlecTools_caddyOpen == "")
		AlecTools_closeCaddy()
	)

	macros.run "Alec Tools" "MaxSettings"
	AlecAwayTest_check "MaxSettings: stays open on a click elsewhere" ((AlecAwayTest_python "away_panel().CLICK_AWAY") == false)
	AlecTools_closeCaddy()

	macros.run "Alec Tools" "Scale"
	python.Execute "away_panel().lines[0].setText('200')"
	AlecAwayTest_check "Scale: the preview scales" ((distance b.scale [2, 2, 2]) < 0.01)
	python.Execute "away_panel().clicked_away()"
	AlecAwayTest_check "Scale: a left click elsewhere puts it back" ((distance b.scale [1, 1, 1]) < 0.01)

	for macro in #("Grab", "Rotate", "Scale", "TransformPopup") do
	(
		macros.run "Alec Tools" macro
		local section = AlecTools_caddyOpen
		python.Execute "away_press(repeat=True)"
		AlecAwayTest_check (macro + ": the shortcut held down does not close it") (AlecTools_caddyOpen == section)
		python.Execute "away_press(QtCore.Qt.AltModifier)"
		AlecAwayTest_check (macro + ": the same key with another modifier does not close it") (AlecTools_caddyOpen == section)
		python.Execute "away_press()"
		AlecAwayTest_check (macro + ": the shortcut again closes it") (AlecTools_caddyOpen == "")
		macros.run "Alec Tools" macro
		AlecAwayTest_check (macro + ": the macro opens it") (AlecTools_caddyOpen == section)
		macros.run "Alec Tools" macro
		AlecAwayTest_check (macro + ": the macro again closes it") (AlecTools_caddyOpen == "")
	)

	-- Esc on every panel that opens by its macro (the second list with the toolbar's right click; Mid Between waits for clicks)
	local b2 = box name:"ATtest_clickAway2" pos:[50, 0, 0]
	select #(b, b2)
	local plain = #("Grab", "Rotate", "Scale", "TransformPopup", "CreatePopup", "MaxSettings", "LightConverter")
	local options = #("BBox", "Distribute", "MeasureAngle", "UniversalConverter")
	for macro in (plain + options) do
	(
		AlecTools_optionsClick = (findItem options macro) > 0
		macros.run "Alec Tools" macro
		local section = AlecTools_caddyOpen
		python.Execute "away_escape()"
		AlecAwayTest_check (macro + ": Esc does nothing") (section != "" and AlecTools_caddyOpen == section)
		AlecTools_closeCaddy()
		AlecAwayTest_check (macro + ": Esc still interrupts no MAXScript after it closes") (not escapeEnable)
	)
	delete b2
	select b

	macros.run "Alec Tools" "MaxSettings"
	AlecAwayTest_check "MaxSettings: the shortcut again closes it" ((AlecAwayTest_python "away_panel().KEY_TOGGLES") == true)
	AlecTools_closeCaddy()

	macros.run "Alec Tools" "Scale"
	python.Execute "away_panel().lines[0].setText('200')"
	python.Execute "away_press()"
	AlecAwayTest_check "Scale: the shortcut again puts it back" ((distance b.scale [1, 1, 1]) < 0.01)

	delete b

	format "clickAway_test: % failure(s)\n" AlecAwayTest_failed.count
	for f in AlecAwayTest_failed do format "FAIL %\n" f
)
