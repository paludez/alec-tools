-- Test for tools/grab.ms and tools/grabCaddy.py (Grab, Rotate, Scale). Run in Max (needs a scene you do not mind changing):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\grab_test.ms"
-- Creates temporary objects, calls the functions the panel calls, drives the panel's fields, reads the transforms back, deletes them.
-- Prints PASS/FAIL lines, then the number of failures and the failed ones.
-- Not covered, try by hand: the macros, real typing and Tab in the panel, right click, Ctrl+Z after accepting, and View/Screen
-- in a real view.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/grab.ms")

global AlecGrabTest_failed = #()

fn AlecGrabTest_check label ok =
(
	format "% %\n" (if ok then "PASS" else "FAIL") label
	if not ok do append AlecGrabTest_failed label
)

-- python.Execute gives #success, not the value: the results come back through a temporary global
fn AlecGrabTest_python code =
(
	python.Execute ("rt.ATtest_value = " + code)
	local value = globalVars.get #ATtest_value
	globalVars.remove #ATtest_value
	value
)

python.Execute ("import sys, importlib\nsys.path.append(r'" + (AlecTools_path "lib") + "')\nimport AlecTools_caddy\nimportlib.reload(AlecTools_caddy)")
python.Execute "
from pymxs import runtime as rt
from PySide6 import QtCore, QtGui, QtWidgets
from qtmax import GetQMaxMainWindow
def grab_panel():
    return [w for w in GetQMaxMainWindow().findChildren(QtWidgets.QFrame, AlecTools_caddy.OBJECT_NAME) if w.isVisible()][0]
def grab_key(key, text=''):
    p = grab_panel()
    QtWidgets.QApplication.sendEvent(p.lines[p.axis], QtGui.QKeyEvent(QtCore.QEvent.KeyPress, key, QtCore.Qt.NoModifier, text))
    return grab_panel().axis
def grab_tab():
    return grab_key(QtCore.Qt.Key_Tab)
def grab_back():
    return grab_key(QtCore.Qt.Key_Backtab)
def grab_type(axis, text):
    grab_panel().lines[axis].setText(text)
"

(
	fn near a b = (distance a b) < 0.01
	fn nearTM a b = near a.row1 b.row1 and near a.row2 b.row2 and near a.row3 b.row3 and near a.row4 b.row4

	AlecGrabTest_failed = #()
	local oldSystem = getRefCoordSys()
	local oldCenter = getCoordCenter()
	local b = box name:"ATtest_grab" pos:[0, 0, 0]
	rotate b (angleaxis 30 [0, 0, 1])
	local home = b.transform

	-- move
	setRefCoordSys #world
	select b
	AlecGrab_begin #move
	AlecGrab_preview [-100, 0, 0]
	AlecGrabTest_check "move, world, x-100: 100 back along X" (near b.pos [-100, 0, 0])
	AlecGrab_preview [0, 50, 0]
	AlecGrabTest_check "move: a new preview starts again from the start: y50" (near b.pos [0, 50, 0])
	AlecGrab_preview [10, 20, -5]
	AlecGrabTest_check "move: the three axes together" (near b.pos [10, 20, -5])
	AlecGrab_end()
	AlecGrabTest_check "move: closed without accepting, back at the start" (near b.pos [0, 0, 0])

	setRefCoordSys #local
	select b
	AlecGrab_begin #move
	AlecGrab_preview [10, 5, 0]
	local f = AlecTools_localFrame b
	AlecGrabTest_check "move, local, x10 y5: along the box's own axes" (near b.pos (f.row1 * 10 + f.row2 * 5))
	AlecGrab_end()

	setRefCoordSys #world
	select b
	AlecGrab_begin #move
	AlecGrab_preview [0, 0, 20]
	AlecGrab_accept [0, 0, 20]
	AlecGrab_end()
	AlecGrabTest_check "move: accepted, the box stays moved" (near b.pos [0, 0, 20])
	-- the single undo step is tried by hand with Ctrl+Z: the undo steps inside one block merge, max undo would remove the box too
	b.transform = home

	-- rotate and scale: a box off the origin, not rotated
	local r = box name:"ATtest_grabTurn" pos:[10, 0, 0]
	setRefCoordSys #world
	setCoordCenter #local
	select r
	AlecGrab_begin #rotate
	AlecGrab_preview [0, 0, 90]
	AlecGrabTest_check "rotate, z90 about the pivot: X turns into Y, the box stays" (near r.transform.row1 [0, 1, 0] and near r.pos [10, 0, 0])
	AlecGrab_preview [90, 0, 90]
	local both = rotateXMatrix 90 * rotateZMatrix 90
	AlecGrabTest_check "rotate, x90 z90: X first, then Z" (near r.transform.row1 both.row1 and near r.transform.row2 both.row2)
	AlecGrab_end()
	AlecGrabTest_check "rotate: closed without accepting, not turned" (near r.transform.row1 [1, 0, 0])
	setCoordCenter #system
	select r
	AlecGrab_begin #rotate
	AlecGrab_preview [0, 0, 90]
	AlecGrabTest_check "rotate, z90 about the world origin: the box goes round to Y" (near r.pos [0, 10, 0])
	AlecGrab_end()

	setCoordCenter #local
	setRefCoordSys #local
	select b
	AlecGrab_begin #rotate
	AlecGrab_preview [30, 40, 0]
	local once = b.transform
	AlecGrab_preview [30, 40, 0]
	AlecGrabTest_check "rotate, local: the same values again give the same result, the axes do not drift" (nearTM b.transform once)
	AlecGrab_end()
	setRefCoordSys #world

	select r
	AlecGrab_begin #scale
	AlecGrab_preview [200, 200, 200]
	AlecGrabTest_check "scale, 200 on all: twice as big" (near r.scale [2, 2, 2])
	AlecGrab_preview [50, 100, 100]
	AlecGrabTest_check "scale, x50: half along X only" (near r.scale [0.5, 1, 1])
	AlecGrab_preview [0, 100, 100]
	AlecGrabTest_check "scale, 0: the box stays as it started" (near r.scale [1, 1, 1])
	AlecGrab_end()
	setCoordCenter #system
	select r
	AlecGrab_begin #scale
	AlecGrab_preview [200, 100, 100]
	AlecGrabTest_check "scale, x200 about the world origin: the box moves out to 20" (near r.pos [20, 0, 0])
	AlecGrab_accept [200, 100, 100]
	AlecGrab_end()
	AlecGrabTest_check "scale: accepted, the box stays scaled" (near r.scale [2, 1, 1])
	r.transform = matrix3 [1, 0, 0] [0, 1, 0] [0, 0, 1] [10, 0, 0]

	-- the panel: Scale, the order of Tab, XYZ for the empty axes
	setCoordCenter #local
	select r
	AlecGrab_run #scale
	AlecGrabTest_check "panel, scale: opens on XYZ" ((AlecGrabTest_python "grab_panel().axis") == 0)
	AlecGrabTest_check "panel, scale: Tab goes to X" ((AlecGrabTest_python "grab_tab()") == 1)
	AlecGrabTest_check "panel, scale: Tab goes to Y" ((AlecGrabTest_python "grab_tab()") == 2)
	AlecGrabTest_check "panel, scale: Tab goes to Z" ((AlecGrabTest_python "grab_tab()") == 3)
	AlecGrabTest_check "panel, scale: Tab goes back to XYZ" ((AlecGrabTest_python "grab_tab()") == 0)
	AlecGrabTest_check "panel, scale: Shift+Tab goes to Z" ((AlecGrabTest_python "grab_back()") == 3)
	AlecGrabTest_check "panel, scale: the key Z on Z goes to XYZ" ((AlecGrabTest_python "grab_key(QtCore.Qt.Key_Z, 'z')") == 0)
	python.Execute "grab_type(0, '100+100')"
	AlecGrabTest_check "panel, scale: XYZ 100+100 scales all three" (near r.scale [2, 2, 2])
	AlecGrabTest_check "panel, scale: an empty Y shows the value of XYZ" ((AlecGrabTest_python "grab_panel().lines[2].placeholderText()") == "200")
	python.Execute "grab_type(1, '50')"
	AlecGrabTest_check "panel, scale: X 50 holds for X, XYZ for the others" (near r.scale [0.5, 2, 2])
	python.Execute "grab_type(1, '')"
	AlecGrabTest_check "panel, scale: X emptied follows XYZ again" (near r.scale [2, 2, 2])
	python.Execute "grab_type(1, '50+')"
	AlecGrabTest_check "panel, scale: an unreadable value keeps the last preview" (near r.scale [2, 2, 2])
	python.Execute "grab_panel().ok()"
	AlecGrabTest_check "panel, scale: Enter accepts" (near r.scale [2, 2, 2] and AlecTools_caddyOpen == "")
	r.transform = matrix3 [1, 0, 0] [0, 1, 0] [0, 0, 1] [10, 0, 0]

	-- the panel: Scale opens on XYZ again after another field was used
	AlecGrab_run #scale
	AlecGrabTest_python "grab_key(QtCore.Qt.Key_Y, 'y')"
	python.Execute "grab_panel().cancel()"
	AlecGrab_run #scale
	AlecGrabTest_check "panel, scale: the next one opens on XYZ again" ((AlecGrabTest_python "grab_panel().axis") == 0)
	python.Execute "grab_panel().cancel()"

	-- the panel: Grab, three fields, opens on X
	AlecGrab_run #move
	AlecGrabTest_check "panel, move: has no XYZ field" ((AlecGrabTest_python "len(grab_panel().lines)") == 3)
	AlecGrabTest_check "panel, move: opens on X" ((AlecGrabTest_python "grab_panel().axis") == 1)
	AlecGrabTest_check "panel, move: Shift+Tab from X goes round to Z" ((AlecGrabTest_python "grab_back()") == 3)
	AlecGrabTest_check "panel, move: Tab from Z goes round to X" ((AlecGrabTest_python "grab_tab()") == 1)
	python.Execute "grab_type(1, '5')"
	python.Execute "grab_type(2, '15+5')"
	python.Execute "grab_type(3, '-5')"
	AlecGrabTest_check "panel, move: the three fields apply together" (near r.pos [15, 20, -5])
	AlecGrabTest_check "panel, move: the key Y goes to Y" ((AlecGrabTest_python "grab_key(QtCore.Qt.Key_Y, 'y')") == 2)
	python.Execute "grab_panel().cancel()"
	AlecGrabTest_check "panel, move: cancel puts it back" (near r.pos [10, 0, 0] and AlecTools_caddyOpen == "")
	AlecGrab_run #move
	AlecGrabTest_check "panel, move: the next one opens on X again" ((AlecGrabTest_python "grab_panel().axis") == 1)
	python.Execute "grab_panel().cancel()"

	-- the panel: Rotate opens on X
	AlecGrab_run #rotate
	AlecGrabTest_check "panel, rotate: opens on X" ((AlecGrabTest_python "grab_panel().axis") == 1)
	AlecGrabTest_check "panel, rotate: the value is in degrees" ((AlecGrabTest_python "ord(grab_panel().suffix)") == 176)
	python.Execute "grab_panel().cancel()"
	delete r

	-- a linked child follows its parent, only the parent is moved
	setCoordCenter #local
	local c = box name:"ATtest_grabChild" pos:[40, 0, 0]
	c.parent = b
	select #(b, c)
	AlecGrab_begin #move
	AlecGrabTest_check "begin: a selected child of a selected parent is not moved by itself" (AlecGrab_nodes.count == 1 and AlecGrab_nodes[1] == b)
	AlecGrab_preview [0, 20, 0]
	AlecGrabTest_check "the child keeps its distance to the parent" (near c.pos [40, 20, 0])
	AlecGrab_end()
	delete #(b, c)

	AlecGrabTest_check "evaluate: 15+28" ((AlecGrabTest_python "AlecTools_caddy.evaluate('15+28')") == 43.0)
	AlecGrabTest_check "evaluate: a decimal comma" ((AlecGrabTest_python "AlecTools_caddy.evaluate('-2,5')") == -2.5)

	setCoordCenter oldCenter
	setRefCoordSys oldSystem
	format "grab_test: % failure(s)\n" AlecGrabTest_failed.count
	for f in AlecGrabTest_failed do format "FAIL %\n" f
)
