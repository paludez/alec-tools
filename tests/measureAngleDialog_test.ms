-- Test for tools/measureAngleDialog.ms (the geometry behind the Shift + click dialog). Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\measureAngleDialog_test.ms"
-- Checks the angle between faces, faces cut by a plane, and the real edges of a mesh face; makes a temporary box and deletes it.
-- Prints PASS/FAIL lines to the Listener. Not covered, try by hand: the dialog, hovering and clicking edges and faces,
-- picking a plane by 3 points or by a face, Ctrl and that the result shows in the dialog.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/measureAngle.ms")
fileIn (AlecTools_path "tools/measureAngleDialog.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	fn faceAngle a b = (local c = AlecAngle_surfaceCorner a b; if c == undefined then -1 else c[3])
	fn labelStarts ov text = ov.labels.count == 1 and (findString ov.labels[1][2] text) == 1

	-- faces, not normals: the normals of these pairs are 90, 45 and 30 apart
	local topFace = #([-10,0,0], [0,0,1])
	local chamfer = #([5,0,-5], normalize [1,0,1])
	if not (check "box outer edge (top and side) is 90" (abs ((faceAngle topFace #([0,0,-10], [1,0,0])) - 90) < 0.01)) do failures += 1
	if not (check "45 deg chamfer on an edge makes 135 with the top" (abs ((faceAngle topFace chamfer) - 135) < 0.01)) do failures += 1
	if not (check "floor and a 30 deg ramp make 150" (abs ((faceAngle topFace #([10,0,5.7735], [-0.5,0,0.866025])) - 150) < 0.01)) do failures += 1
	if not (check "parallel faces give undefined" (AlecAngle_surfaceCorner topFace #([0,0,20], [0,0,-1]) == undefined)) do failures += 1

	if not (check "faces overlay in 3D: 135 written" (labelStarts (AlecAngle_facesOverlay #(topFace, chamfer) undefined) "135.0 deg /")) do failures += 1
	-- cut by XZ (square to the edge, which runs along Y): still 135; cut by XY: the top is parallel to it
	if not (check "faces cut by World XZ: still 135" (labelStarts (AlecAngle_facesOverlay #(topFace, chamfer) [0,1,0]) "135.0 deg /")) do failures += 1
	if not (check "faces cut by World XY: the top face is parallel" (labelStarts (AlecAngle_facesOverlay #(topFace, chamfer) [0,0,1]) "parallel")) do failures += 1
	-- a wall turned 30 deg around Z against a wall along X: cut by XY they make 150 or 30, here the clicked sides give 150
	local wallA = #([-10,0,50], [0,-1,0])
	local wallB = #([8.66,5,50], normalize [0.5,-0.866025,0])
	local ovw = AlecAngle_facesOverlay #(wallA, wallB) [0,0,1]
	format "  two walls cut by World XY: %\n" (if ovw.labels.count > 0 then ovw.labels[1][2] else "no label")

	if not (check "segment distance: square to the middle" (abs ((AlecAngle_segmentDistance [5,3,0] [0,0,0] [10,0,0]) - 3) < 0.001)) do failures += 1
	if not (check "segment distance: past the end" (abs ((AlecAngle_segmentDistance [13,4,0] [0,0,0] [10,0,0]) - 5) < 0.001)) do failures += 1

	-- the real edges of the top face of a box: 2 of its 3 triangle edges (the third is the hidden diagonal)
	local b = box name:"ATtest_angPick" length:100 width:100 height:100 pos:[100000, 100000, 0]
	local m = snapshotAsMesh b
	local edges = AlecAngle_faceEdges m 3
	if not (check "a box face (triangle) has 2 real edges" (edges.count == 2)) do failures += 1
	if not (check "the real edges are axis-aligned, 100 long" \
		(edges.count == 2 and abs ((distance edges[1][1] edges[1][2]) - 100) < 0.01 and abs ((distance edges[2][1] edges[2][2]) - 100) < 0.01)) do failures += 1
	delete m
	delete b

	-- the pick cache keeps the last 2 objects, most recent first
	local c1 = box name:"ATtest_cache1"
	local c2 = box name:"ATtest_cache2"
	local c3 = box name:"ATtest_cache3"
	AlecAngle_usePick c1
	AlecAngle_usePick c2
	local grid1 = AlecAngle_pickCache[2][3]
	AlecAngle_usePick c1
	if not (check "cache: back to an object reuses its grid" (AlecAngle_pickCache.count == 2 and AlecAngle_pickCache[1][1] == c1 and AlecAngle_pickGrid == grid1)) do failures += 1
	AlecAngle_usePick c3
	if not (check "cache: a third object drops the oldest" (AlecAngle_pickCache.count == 2 and AlecAngle_pickCache[1][1] == c3 and AlecAngle_pickCache[2][1] == c1)) do failures += 1
	AlecAngle_freePick()
	if not (check "cache: freed" (AlecAngle_pickCache.count == 0 and AlecAngle_pickGrid == undefined)) do failures += 1
	delete #(c1, c2, c3)

	format "measureAngleDialog_test: % failure(s)\n" failures
)
