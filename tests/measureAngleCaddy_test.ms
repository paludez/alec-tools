-- Test for tools/measureAngleCaddy.py and lib/AlecTools_caddy.py. Run in Max after Reload Alec Tools:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\measureAngleCaddy_test.ms"
-- Opens the caddy twice (only one stays), checks its buttons and that a click is kept in the scene settings, closes it.
-- Prints PASS/FAIL lines to the Listener. Not covered, try by hand: Start (check button) for each choice, the yellow result while
-- measuring, Esc in the viewport closing it but not the Esc that ends a measure, dragging it, Enter.
(
	local saved = AlecTools_recallSettings "MeasureAngle" #(2, 1)
	AlecTools_rememberSettings "MeasureAngle" #(3, 4)
	python.ExecuteFile (AlecTools_path "tools/measureAngleCaddy.py")
	python.ExecuteFile (AlecTools_path "tools/measureAngleCaddy.py")
	python.Execute "
from PySide6 import QtWidgets
from qtmax import GetQMaxMainWindow
def check(label, ok):
    print(('PASS ' if ok else 'FAIL ') + label)
QtWidgets.QApplication.processEvents()
caddies = [c for c in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, 'AlecToolsCaddy') if c.isVisible()]
check('one caddy open after opening it twice', len(caddies) == 1)
c = caddies[0]
check('the saved choices are pressed (Faces, World YZ)', c.what.checkedId() == 3 and c.plane.checkedId() == 4)
check('Plane buttons in order XY XZ YZ / 3D 3P face', [b.text() for b in c.plane.buttons()] == ['World XY', 'World XZ', 'World YZ', '3D', '3P plane', 'Pick face'])
c.plane.button(1).click()
c.close()
QtWidgets.QApplication.processEvents()
"
	local after = AlecTools_recallSettings "MeasureAngle" #(2, 1)
	format "% a click is kept in the settings (3D)\n" (if after[2] == 1 then "PASS" else "FAIL")
	AlecTools_rememberSettings "MeasureAngle" saved
)
