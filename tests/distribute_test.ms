-- Test for tools/distribute.ms. Run in Max (needs a scene you do not mind changing):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\distribute_test.ms"
-- Creates temporary objects (ATtest_*), distributes them, compares positions with values worked out by hand, deletes everything.
-- Prints PASS/FAIL lines to the Listener. Not covered, try by hand: the caddy controls (spinners, Auto, picking the anchor, Reset), Esc closing the caddy
-- and one Ctrl+Z after OK putting all the objects back.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/distribute.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	fn near a b = (distance a b) < 0.01
	fn nearF a b = abs (a - b) < 0.01
	-- plain loops: "for ... collect" with a function parameter inside raises "Bad free thunk"
	fn xs nodes = (local v = #(); for n in nodes do append v n.pos.x; v)
	fn ys nodes = (local v = #(); for n in nodes do append v n.pos.y; v)
	fn nearAll values expected =
	(
		local ok = values.count == expected.count
		for i = 1 to values.count where ok do ok = nearF values[i] expected[i]
		ok
	)
	fn newSess nodes s anchor:undefined =
	(
		local sess = AlecDist_newSession s (AlecDist_sources nodes)
		sess.anchor = anchor
		sess
	)
	-- a box 10 x 10 x 10 (or w wide) whose pivot is at the center of its base
	fn cube nm p w:10 = box name:("ATtest_" + nm) width:w length:10 height:10 pos:p

	-- Positions along world X, by the pivot
	local a = cube "a" [0,0,0]
	local b = cube "b" [10,30,5]
	local c = cube "c" [50,-20,0]
	local abc = #(a, b, c)

	local sess = newSess abc (AlecDist_Settings())
	AlecDist_apply sess
	if not (check "positions auto: the ends stay, the middle goes halfway" (nearAll (xs abc) #(0, 25, 50) and nearF sess.step 25)) do failures += 1
	if not (check "positions: the other axes are not touched" (nearF b.pos.y 30 and nearF b.pos.z 5)) do failures += 1
	AlecDist_buildDims sess
	local dims = sess.dims
	if not (check "dims: a box per object, a dimension per step (line and two ticks)" (dims.boxes.count == 3 and dims.lines.count == 6 and dims.labels.count == 2)) do failures += 1
	if not (check "dims: the lengths of the steps, in the middle of each piece" (dims.labels[1][2] == units.formatValue 25.0 and nearF dims.labels[1][1].x 12.5 and nearF dims.labels[2][1].x 37.5)) do failures += 1
	if not (check "dims: the line runs along X, past the objects on Y, level with their bottom" (nearF dims.lines[1][1].y 41 and nearF dims.lines[1][1].z 0 and nearF dims.lines[1][2].x 25)) do failures += 1

	sess.autoFill = false
	sess.step = 20
	AlecDist_apply sess
	if not (check "positions step 20, no anchor: the lowest stays" (nearAll (xs abc) #(0, 20, 40))) do failures += 1

	sess.anchor = b
	AlecDist_apply sess
	if not (check "positions step 20, anchor in the middle: the anchor stays, the others on both sides" (nearAll (xs abc) #(-10, 10, 30))) do failures += 1
	AlecDist_restore sess

	sess = newSess abc (AlecDist_Settings alignX:true alignY:true alignZ:true) anchor:b
	AlecDist_apply sess
	if not (check "align to anchor on Y and Z by pivot; X is the distribution axis and is ignored" (nearAll (xs abc) #(-15, 10, 35) \
		and nearF a.pos.y 30 and nearF c.pos.y 30 and nearF a.pos.z 5 and nearF c.pos.z 5)) do failures += 1

	AlecDist_restore sess
	if not (check "restore: every object back where it was" (near a.pos [0,0,0] and near b.pos [10,30,5] and near c.pos [50,-20,0])) do failures += 1

	-- Gaps: widths 10, 20, 10 from 0 to 110
	local g1 = cube "g1" [5,100,0]
	local g2 = cube "g2" [40,100,0] w:20
	local g3 = cube "g3" [105,100,0]
	local g = #(g1, g2, g3)

	sess = newSess g (AlecDist_Settings gaps:true)
	AlecDist_apply sess
	if not (check "gaps auto: 35 between the boxes, the ends stay" (nearAll (xs g) #(5, 55, 105) and nearF sess.gap 35)) do failures += 1
	AlecDist_buildDims sess
	if not (check "dims: in Gaps a piece across each gap" (sess.dims.labels[2][2] == units.formatValue 35.0 and nearF sess.dims.lines[1][1].x 10 and nearF sess.dims.lines[1][2].x 45)) do failures += 1

	sess.autoFill = false
	sess.gap = 0
	sess.anchor = g3
	AlecDist_apply sess
	if not (check "gaps 0 with the anchor at the end: the others stack against it" (nearAll (xs g) #(75, 90, 105))) do failures += 1

	sess.anchor = undefined
	sess.gap = -100
	AlecDist_apply sess
	if not (check "gaps -100: clamped to minus the thinnest width (-10)" (nearF sess.gap -10 and nearAll (xs g) #(5, 10, 15))) do failures += 1
	AlecDist_buildDims sess
	if not (check "dims: a negative gap is written with its minus" (sess.dims.labels.count == 2 and sess.dims.labels[1][2] == units.formatValue -10.0)) do failures += 1
	AlecDist_restore sess

	-- references on boxes of different widths
	sess = newSess g (AlecDist_Settings reference:4)
	AlecDist_apply sess
	if not (check "reference Max: the max sides 50 apart" (nearAll (xs g) #(5, 50, 105))) do failures += 1
	sess = newSess g (AlecDist_Settings reference:2)
	AlecDist_apply sess
	if not (check "reference Center: the centers 50 apart" (nearAll (xs g) #(5, 55, 105))) do failures += 1
	sess = newSess g (AlecDist_Settings reference:1)
	AlecDist_apply sess
	if not (check "reference Min: the min sides 50 apart" (nearAll (xs g) #(5, 60, 105))) do failures += 1
	AlecDist_restore sess

	-- Local: the anchor is turned 90 degrees, so its X is the world Y
	local l1 = cube "l1" [0,200,0]
	rotate l1 (eulerAngles 0 0 90)
	local l2 = cube "l2" [0,210,0]
	local l3 = cube "l3" [0,250,0]
	local l = #(l1, l2, l3)
	sess = newSess l (AlecDist_Settings localAxes:true) anchor:l1
	AlecDist_apply sess
	if not (check "local: along the X of the anchor, which is the world Y" ((nearAll (ys l) #(200, 225, 250)) and nearAll (xs l) #(0, 0, 0))) do failures += 1
	AlecDist_restore sess
	sess = newSess l (AlecDist_Settings localAxes:true)
	AlecDist_apply sess
	if not (check "local without an anchor: the world axes, so along X nothing moves" (nearAll (ys l) #(200, 210, 250) and nearAll (xs l) #(0, 0, 0))) do failures += 1
	AlecDist_restore sess
	-- axes from an object outside the selection, turned 90 degrees: it gives the axes and does not move; it wins over the axes of the anchor
	local ext = cube "ext" [500,500,0]
	rotate ext (eulerAngles 0 0 90)
	sess.axesOf = ext
	AlecDist_apply sess
	if not (check "axes of an outside object: along its X, which is the world Y; it does not move" (nearAll (ys l) #(200, 225, 250) and near ext.pos [500,500,0])) do failures += 1
	AlecDist_restore sess
	sess.anchor = l2
	AlecDist_apply sess
	if not (check "axes of an outside object with an anchor: its axes, the anchor stays" (nearAll (ys l) #(185, 210, 235))) do failures += 1
	AlecDist_restore sess

	-- rotation blend: the anchor at 0 degrees, the last one at 90, the middle (scaled) gets 45 and keeps its scale
	local r1 = cube "r1" [0,400,0]
	local r2 = cube "r2" [50,400,0]
	r2.scale = [2,1,1]
	local r3 = cube "r3" [100,400,0]
	rotate r3 (eulerAngles 0 0 90)
	local r = #(r1, r2, r3)
	sess = newSess r (AlecDist_Settings blend:true) anchor:r1
	AlecDist_apply sess
	if not (check "blend: the middle is turned 45 degrees" (near (normalize r2.transform.row1) (normalize ([1,0,0] + normalize r3.transform.row1)))) do failures += 1
	if not (check "blend: scale and position kept, the ends unchanged" (near r2.scale [2,1,1] and near r2.pos [50,400,0] \
		and near (normalize r1.transform.row1) [1,0,0] and nearF (abs (normalize r3.transform.row1).y) 1)) do failures += 1
	AlecDist_restore sess
	if not (check "blend: restore puts the rotation back" (near (normalize r2.transform.row1) [1,0,0])) do failures += 1

	-- what moves: a closed group is one object; a child of a selected object, a target and an open group head are left out
	local m1 = cube "m1" [0,600,0]
	local m2 = cube "m2" [30,600,0]
	local grp = group #(m1, m2) name:"ATtest_grp"
	local child = cube "child" [0,700,0]
	child.parent = a
	local tg = Targetobject name:"ATtest_target"
	local src = AlecDist_sources #(grp, m1, m2, a, child, tg)
	if not (check "sources: the group head and the parent only" (src.count == 2 and findItem src grp > 0 and findItem src a > 0)) do failures += 1
	local m = AlecDist_measure grp (matrix3 1)
	if not (check "measure: a group is measured on its members" (near m[1] [-5,595,0] and near m[2] [35,605,10])) do failures += 1
	setGroupOpen grp true
	src = AlecDist_sources #(grp, m1, m2)
	if not (check "sources: an open group gives its members, not its head" (src.count == 2 and findItem src grp == 0)) do failures += 1
	setGroupOpen grp false

	-- preview: end puts the objects back, accept keeps them and ends the session
	AlecDist_active = newSess abc (AlecDist_Settings())
	AlecDist_updatePreview AlecDist_active
	AlecDist_end()
	if not (check "cancel: the objects are back, the session ends" (nearF b.pos.x 10 and AlecDist_active == undefined)) do failures += 1
	AlecDist_active = newSess abc (AlecDist_Settings())
	AlecDist_updatePreview AlecDist_active
	AlecDist_accept()
	if not (check "accept: the objects stay distributed, the session ends" (nearF b.pos.x 25 and AlecDist_active == undefined)) do failures += 1
	b.pos = [10,30,5]

	-- objects deleted while the caddy is open leave the session; fewer than 2 left and the preview stops
	local d1 = box name:"ATtest_d1" pos:[0,500,0]
	local d2 = box name:"ATtest_d2" pos:[40,500,0]
	local d3 = box name:"ATtest_d3" pos:[100,500,0]
	local dSess = newSess #(d1, d2, d3) (AlecDist_Settings()) anchor:d3
	delete d3
	if not (check "deleted: the session goes on with the others, the deleted anchor is unpicked" ((AlecDist_updatePreview dSess) and dSess.sources.count == 2 and dSess.saved.count == 2 and dSess.anchor == undefined)) do failures += 1
	delete d2
	if not (check "deleted: one object left, the preview stops" (not (AlecDist_updatePreview dSess))) do failures += 1
	delete d1

	-- run: one object opens nothing; two open the caddy with a preview; loading the file again closes it and the objects go back
	AlecTools_forgetSettings()
	select a
	AlecDist_run()
	if not (check "run: one object, no caddy" (not AlecDist_rollout.open and AlecDist_active == undefined)) do failures += 1
	select #(a, b, c)
	AlecDist_run()
	if not (check "run: the caddy opens and the objects move as a preview" (AlecDist_rollout.open and nearF b.pos.x 25 and AlecDist_active.dims.boxes.count == 3)) do failures += 1
	fileIn (AlecTools_path "tools/distribute.ms")
	if not (check "load again (macro pressed while open): the caddy closes and the objects go back" (not AlecDist_rollout.open and nearF b.pos.x 10)) do failures += 1

	clearSelection()
	delete (for o in objects where matchPattern o.name pattern:"ATtest_*" collect o)

	format "distribute_test: % failure(s)\n" failures
)
