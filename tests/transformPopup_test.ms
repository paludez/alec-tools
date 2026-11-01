-- Transform Popup test: run after Reload Alec Tools. Opens the popup, types into it, checks it follows the selection, closes it.
-- Prints PASS/FAIL per check and the failed ones at the end. Creates and deletes its own box.
-- Then by hand: put Alt+S on the macro (Customize > Hotkey Editor, category Alec Tools), press it with something selected: the
-- panel opens at the mouse; click a box (it selects all), 15+28 and Enter moves, Tab goes on, middle drag is the ladder, right
-- click resets, Esc does nothing, Alt+S again closes it.
global AlecPopupTest_failed = #()

fn AlecPopupTest_check label ok =
(
	format "% %\n" (if ok then "PASS" else "FAIL") label
	if not ok do append AlecPopupTest_failed label
)

python.Execute "
import AlecToolbar
import AlecTools_caddy
from PySide6 import QtWidgets
from qtmax import GetQMaxMainWindow
def popup():
    found = [w for w in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, AlecTools_caddy.OBJECT_NAME) if w.isVisible()]
    return found[0] if found else None
def row_count():
    p = popup()
    return len(p.findChildren(AlecToolbar.TransformFields)) if p else 0
def boxes(row):
    return popup().fields[row].boxes
def type_into(row, axis, text):
    box = boxes(row)[axis]
    box.setText(text)
    box.edited = True
    box.editingFinished.emit()
def shown(row, axis):
    return boxes(row)[axis].text()
"

(
	AlecPopupTest_failed = #()
	local b = box pos:[10, 20, 30] length:20 width:20 height:20
	select b

	macros.run "Alec Tools" "TransformPopup"
	AlecPopupTest_check "the popup opens" (AlecTools_caddyOpen == "Transform Popup")
	AlecPopupTest_check "it has the six rows" ((python.Execute "row_count()") == 6)
	AlecPopupTest_check "W Move shows the position" ((python.Execute "shown(0, 0)") == "10.000")

	python.Execute "type_into(0, 0, '15+28')"
	AlecPopupTest_check "typing 15+28 in W Move X moves the box" (abs (b.pos.x - 43) < 0.001)

	python.Execute "type_into(1, 2, '5')"
	AlecPopupTest_check "L Move Z moves by 5" (abs (b.pos.z - 35) < 0.001)

	python.Execute "type_into(4, 0, '200')"
	AlecPopupTest_check "Scale X 200 scales the box" (abs (b.scale.x - 2) < 0.001)
	AlecToolbar_refresh()
	AlecPopupTest_check "Size X follows the scale" ((python.Execute "shown(5, 0)") == "40.000")

	b.pos = [100, 0, 0]
	AlecToolbar_refresh()
	AlecPopupTest_check "the fields follow a change of the object" ((python.Execute "shown(0, 0)") == "100.000")

	clearSelection()
	AlecToolbar_refresh()
	AlecPopupTest_check "nothing selected: the boxes are off" (not (python.Execute "boxes(0)[0].isEnabled()"))

	macros.run "Alec Tools" "TransformPopup"
	AlecPopupTest_check "the macro run again closes it" (AlecTools_caddyOpen == "")

	delete b
	if AlecPopupTest_failed.count == 0 then format "ALL PASS\n"
	else
	(
		format "FAILED:\n"
		for f in AlecPopupTest_failed do format "  %\n" f
	)
)
