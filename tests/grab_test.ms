-- Test for tools/grab.ms and tools/grabCaddy.py (Grab, Rotate, Scale). Run in Max (needs a scene you do not mind changing):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\grab_test.ms"
-- Creates temporary objects, calls the functions the panel calls, reads the transforms back, deletes them. Prints PASS/FAIL lines.
-- Not covered, try by hand: the macros, typing in the panel, Enter, right click, Esc, Ctrl+Z after accepting, and View/Screen
-- in a real view.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/grab.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	fn near a b = (distance a b) < 0.01

	local oldSystem = getRefCoordSys()
	local oldCenter = getCoordCenter()
	local b = box name:"ATtest_grab" pos:[0, 0, 0]
	rotate b (angleaxis 30 [0, 0, 1])
	local home = b.transform

	-- move
	setRefCoordSys #world
	select b
	AlecGrab_begin #move
	AlecGrab_preview 1 -100.0
	if not (check "move, world, x-100: 100 back along X" (near b.pos [-100, 0, 0])) do failures += 1
	AlecGrab_preview 2 50.0
	if not (check "move: a new preview starts again from the start: y50" (near b.pos [0, 50, 0])) do failures += 1
	if not (check "move: the last axis is remembered" (AlecGrab_lastAxis() == 2)) do failures += 1
	AlecGrab_end()
	if not (check "move: closed without accepting, back at the start" (near b.pos [0, 0, 0])) do failures += 1

	setRefCoordSys #local
	select b
	AlecGrab_begin #move
	AlecGrab_preview 1 10.0
	local u = (AlecTools_localFrame b).row1
	if not (check "move, local, x10: along the box's own X" (near b.pos (u * 10))) do failures += 1
	AlecGrab_end()

	setRefCoordSys #world
	select b
	AlecGrab_begin #move
	AlecGrab_preview 3 20.0
	AlecGrab_accept 3 20.0
	AlecGrab_end()
	if not (check "move: accepted, the box stays moved" (near b.pos [0, 0, 20])) do failures += 1
	-- the single undo step is tried by hand with Ctrl+Z: the undo steps inside one block merge, max undo would remove the box too
	b.transform = home

	-- rotate and scale: a box off the origin, not rotated
	local r = box name:"ATtest_grabTurn" pos:[10, 0, 0]
	setRefCoordSys #world
	setCoordCenter #local
	select r
	AlecGrab_begin #rotate
	if not (check "rotate: X is the first axis" (AlecGrab_lastAxis() == 1)) do failures += 1
	AlecGrab_preview 3 90.0
	if not (check "rotate, z90 about the pivot: X turns into Y, the box stays" (near r.transform.row1 [0, 1, 0] and near r.pos [10, 0, 0])) do failures += 1
	AlecGrab_end()
	if not (check "rotate: closed without accepting, not turned" (near r.transform.row1 [1, 0, 0])) do failures += 1
	setCoordCenter #system
	select r
	AlecGrab_begin #rotate
	AlecGrab_preview 3 90.0
	if not (check "rotate, z90 about the world origin: the box goes round to Y" (near r.pos [0, 10, 0])) do failures += 1
	AlecGrab_end()

	setCoordCenter #local
	select r
	AlecGrab_begin #scale
	if not (check "scale: all three axes at first" (AlecGrab_lastAxis() == 0)) do failures += 1
	AlecGrab_preview 0 200.0
	if not (check "scale, 200 on all: twice as big" (near r.scale [2, 2, 2])) do failures += 1
	AlecGrab_preview 1 50.0
	if not (check "scale, x50: half along X only" (near r.scale [0.5, 1, 1])) do failures += 1
	AlecGrab_preview 1 0.0
	if not (check "scale, 0: the box stays as it started" (near r.scale [1, 1, 1])) do failures += 1
	AlecGrab_end()
	setCoordCenter #system
	select r
	AlecGrab_begin #scale
	AlecGrab_preview 1 200.0
	if not (check "scale, x200 about the world origin: the box moves out to 20" (near r.pos [20, 0, 0])) do failures += 1
	AlecGrab_accept 1 200.0
	AlecGrab_end()
	if not (check "scale: accepted, the box stays scaled" (near r.scale [2, 1, 1])) do failures += 1
	delete r

	-- a linked child follows its parent, only the parent is moved
	setCoordCenter #local
	local c = box name:"ATtest_grabChild" pos:[40, 0, 0]
	c.parent = b
	select #(b, c)
	AlecGrab_begin #move
	if not (check "begin: a selected child of a selected parent is not moved by itself" (AlecGrab_nodes.count == 1 and AlecGrab_nodes[1] == b)) do failures += 1
	AlecGrab_preview 2 20.0
	if not (check "the child keeps its distance to the parent" (near c.pos [40, 20, 0])) do failures += 1
	AlecGrab_end()
	delete #(b, c)

	-- python.Execute gives #success, not the value: the results come back through a temporary global
	python.Execute ("import sys, importlib\nsys.path.append(r'" + (AlecTools_path "lib") + "')\nimport AlecTools_caddy\nimportlib.reload(AlecTools_caddy)")
	python.Execute "from pymxs import runtime as rt\nrt.ATtest_values = [AlecTools_caddy.evaluate('15+28'), AlecTools_caddy.evaluate('-2,5')]"
	local values = globalVars.get #ATtest_values
	globalVars.remove #ATtest_values
	if not (check "evaluate: 15+28" (values[1] == 43.0)) do failures += 1
	if not (check "evaluate: a decimal comma" (values[2] == -2.5)) do failures += 1

	setCoordCenter oldCenter
	setRefCoordSys oldSystem
	format "grab_test: % failure(s)\n" failures
)
