-- Test for the value boxes of the BBox and Distribute panels (AlecTools_caddy.ValueField) and the pick tag. Run in Max after Reload Alec Tools:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\caddyValue_test.ms"
-- Creates and deletes its own boxes. Prints PASS/FAIL lines, then the number of failures and the failed ones.
-- By hand: BBox and Mid Between with nothing selected (the tag at the top of the viewport, the mouse moves freely, a click on an object goes on,
-- right click cancels), the middle drag with the
-- real mouse on a box and on its name, the right click, Enter (the first enters the value, the next one is OK).

global AlecValueTest_failed = #()

fn AlecValueTest_check label ok =
(
	format "% %\n" (if ok then "PASS" else "FAIL") label
	if not ok do append AlecValueTest_failed label
)

-- python.Execute gives #success, not the value: the results come back through a temporary global
fn AlecValueTest_python code =
(
	python.Execute ("rt.ATtest_value = " + code)
	local value = globalVars.get #ATtest_value
	globalVars.remove #ATtest_value
	value
)

fn AlecValueTest_near a b = abs (a - b) < 0.001

-- before the block below is compiled, so its names bind to the globals of these files
fileIn (AlecTools_path "tools/bbox.ms")
fileIn (AlecTools_path "tools/distribute.ms")

python.Execute "
import AlecTools_caddy
from pymxs import runtime as rt
from PySide6 import QtCore, QtWidgets
from qtmax import GetQMaxMainWindow
def value_panel():
    return [w for w in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, AlecTools_caddy.OBJECT_NAME) if w.isVisible()][0]
def value_type(field, text):
    field.setText(text)
    field.mark_edited()
    field.typed()
def value_drag(field, delta):
    field.drag_start()
    field.drag_preview([1], delta)
    field.drag_end([1], delta)
    return field.drag_text([1], delta)
def value_label_of(field):
    return [w for w in value_panel().findChildren(AlecTools_caddy.ValueLabel) if w.drag.fields is field][0]
"

(
	AlecValueTest_failed = #()
	local a = box name:"ATtest_value1" width:10 length:10 height:10
	local b = box name:"ATtest_value2" width:10 length:10 height:10 pos:[50, 0, 0]
	select #(a, b)

	-- BBox: a typed value, arithmetic, something that is no value, the ladder, the right click
	AlecTools_optionsClick = true
	macros.run "Alec Tools" "BBox"
	AlecValueTest_check "BBox: the caddy opens" (AlecTools_caddyOpen == "BBox")
	AlecValueTest_check "BBox: Offset is a value box" (AlecValueTest_python "isinstance(value_panel().offset, AlecTools_caddy.ValueField)")
	python.Execute "value_type(value_panel().offset, '4')"
	AlecValueTest_check "BBox: a typed value reaches the settings" (AlecValueTest_near AlecBBox_active.settings.offset 4)
	python.Execute "value_type(value_panel().offset, '15+28')"
	AlecValueTest_check "BBox: arithmetic is worked out" (AlecValueTest_near AlecBBox_active.settings.offset 43)
	python.Execute "value_type(value_panel().offset, 'abc')"
	AlecValueTest_check "BBox: no value: the old one stays" (AlecValueTest_near AlecBBox_active.settings.offset 43)
	AlecValueTest_check "BBox: no value: the box shows the old one" ((AlecValueTest_python "value_panel().offset.text()") == "43.00")
	AlecValueTest_check "BBox: the ladder's text is the value reached" ((AlecValueTest_python "value_drag(value_panel().offset, -3.0)") == "40.00")
	AlecValueTest_check "BBox: the ladder changes the settings" (AlecValueTest_near AlecBBox_active.settings.offset 40)
	python.Execute "value_panel().offset.right_clicked()"
	AlecValueTest_check "BBox: a right click gives the default" (AlecValueTest_near AlecBBox_active.settings.offset (AlecBBox_Settings()).offset)
	python.Execute "value_label_of(value_panel().offset).right_clicked()"
	AlecValueTest_check "BBox: a right click on the name works too" (AlecValueTest_near AlecBBox_active.settings.offset (AlecBBox_Settings()).offset)
	-- typed and not entered, then the panel closes: nothing runs after closed()
	python.Execute "value_panel().offset.setText('9')\nvalue_panel().offset.mark_edited()"
	AlecTools_closeCaddy()
	AlecValueTest_check "BBox: closing drops what was not entered" (AlecTools_caddyOpen == "")

	-- Distribute: the step cannot go under 0, a disabled value does not drag from its name
	AlecTools_optionsClick = true
	macros.run "Alec Tools" "Distribute"
	AlecValueTest_check "Distribute: the caddy opens" (AlecTools_caddyOpen == "Distribute")
	python.Execute "value_panel().mode.button(1).click()"
	python.Execute "value_type(value_panel().step, '12')"
	AlecValueTest_check "Distribute: a typed step" (AlecValueTest_near AlecDist_active.step 12)
	python.Execute "value_type(value_panel().step, '-5')"
	AlecValueTest_check "Distribute: the step stops at 0" (AlecValueTest_near AlecDist_active.step 0)
	python.Execute "value_type(value_panel().step, '12')"
	python.Execute "value_panel().step.right_clicked()"
	AlecValueTest_check "Distribute: a right click works the step out again" (AlecDist_active.autoFill and AlecValueTest_near AlecDist_active.step 50)
	AlecValueTest_check "Distribute: positions: Gap is off" (not (AlecValueTest_python "value_panel().gap.isEnabled()"))
	AlecTools_closeCaddy()

	-- Distribute with nothing selected: only a message
	clearSelection()
	AlecTools_optionsClick = true
	macros.run "Alec Tools" "Distribute"
	AlecValueTest_check "Distribute, nothing selected: no caddy and no tag" (AlecTools_caddyOpen == "")
	select #(a, b)

	-- the pick tag
	AlecTools_showPickTag "Test: click an object"
	AlecValueTest_check "pick tag: it opens" (AlecTools_caddyOpen == "Pick Tag")
	AlecValueTest_check "pick tag: it has no timer" (AlecValueTest_python "len(value_panel().findChildren(QtCore.QTimer)) == 0")
	AlecValueTest_check "pick tag: it is in the active viewport" (AlecValueTest_python "AlecTools_caddy.view_rect().contains(value_panel().geometry().topLeft())")
	AlecValueTest_check "pick tag: it takes no clicks" (AlecValueTest_python "bool(value_panel().windowFlags() & QtCore.Qt.WindowTransparentForInput)")
	AlecValueTest_check "pick tag: it takes no focus" (not (AlecValueTest_python "value_panel().isActiveWindow()"))
	AlecTools_closeCaddy()
	AlecValueTest_check "pick tag: it closes" (AlecTools_caddyOpen == "")

	delete #(a, b)

	format "caddyValue_test: % failure(s)\n" AlecValueTest_failed.count
	for f in AlecValueTest_failed do format "FAIL %\n" f
)
