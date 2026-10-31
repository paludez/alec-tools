-- Test for tools/measureAngle.ms. Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\measureAngle_test.ms"
-- Checks the angles, the meeting point of two lines, the World XY projection and the overlays. No scene objects are made.
-- Prints PASS/FAIL lines to the Listener. Not covered, try by hand: clicks, hovering, Ctrl (3D/World XY) and that right click clears the viewports.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/measureAngle.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	fn near a b = (distance a b) < 0.01

	if not (check "X and Y are 90" (abs ((AlecAngle_between [1,0,0] [0,1,0]) - 90) < 0.001)) do failures += 1
	if not (check "45 between X and XY" (abs ((AlecAngle_between [1,0,0] [1,1,0]) - 45) < 0.001)) do failures += 1
	if not (check "opposite directions are 180" (abs ((AlecAngle_between [1,0,0] [-1,0,0]) - 180) < 0.001)) do failures += 1
	format "  written as: %\n" (AlecAngle_format 30.0)

	-- two segments that do not touch, whose lines meet at [100, 0, 0]
	local c = AlecAngle_closest [0,0,0] [50,0,0] [100,20,0] [100,60,0]
	if not (check "lines meet at their crossing" (c != undefined and near c[1] [100,0,0] and near c[2] [100,0,0])) do failures += 1
	local skew = AlecAngle_closest [0,0,0] [10,0,0] [0,0,30] [0,10,30]
	if not (check "skew lines: closest points 30 apart" (skew != undefined and near skew[1] [0,0,0] and near skew[2] [0,0,30])) do failures += 1
	if not (check "parallel lines give undefined" (AlecAngle_closest [0,0,0] [10,0,0] [0,5,0] [10,5,0] == undefined)) do failures += 1

	local ov = AlecAngle_linesOverlay #([0,0,0], [50,0,0], [100,20,0], [100,60,0])
	if not (check "lines overlay: 2 segments + 2 extensions, angle at the crossing" \
		(ov.lines.count == 4 and ov.labels.count == 1 and near ov.labels[1][1] [100,0,0])) do failures += 1
	-- a 60 degree corner at [0,0,0], clicked in every order: the angle is always 60, not 120
	local A = [100,0,0]
	local C = [50,86.6025,0]
	local orders = #(#(A, [0,0,0], [0,0,0], C), #([0,0,0], A, [0,0,0], C), #(A, [0,0,0], C, [0,0,0]), #([0,0,0], A, C, [0,0,0]))
	local allSixty = true
	for p in orders do
	(
		local cc = AlecAngle_closest p[1] p[2] p[3] p[4]
		if cc == undefined or abs ((AlecAngle_cornerAngle p[1] p[2] p[3] p[4] cc) - 60) > 0.01 do allSixty = false
	)
	if not (check "corner angle is 60 in any click order" allSixty) do failures += 1
	local ovc = AlecAngle_linesOverlay orders[1]
	if not (check "corner overlay writes 60 first" (ovc.labels.count == 1 and (findString ovc.labels[1][2] "60.0 deg /") == 1)) do failures += 1

	-- lines that do not meet: no angle, the gap between them instead
	local ovk = AlecAngle_linesOverlay #([0,0,0], [10,0,0], [0,0,30], [0,10,30])
	if not (check "skew lines: no angle, the closest distance is written" \
		(ovk.labels.count == 1 and (findString ovk.labels[1][2] "deg") == undefined and (findString ovk.labels[1][2] "closest distance") != undefined)) do failures += 1
	format "  skew label: %\n" ovk.labels[1][2]

	local ov3 = AlecAngle_linesOverlay #([0,0,0], [50,0,0], [100,20,0])
	if not (check "3 points: only the first line, no angle" (ov3.lines.count == 1 and ov3.labels.count == 0)) do failures += 1

	-- World XY: the skew lines above (X at height 0, Y at height 30) meet at 90 once flattened, at the height of the first point
	local flat = AlecAngle_project #([0,0,0], [10,0,0], [0,0,30], [0,10,30]) [0,0,1]
	if not (check "XY projection keeps X and Y, takes the first point's height" (near flat[3] [0,0,0] and near flat[4] [0,10,0])) do failures += 1
	local side = AlecAngle_project #([5,0,0], [0,7,3]) [0,1,0]
	if not (check "XZ projection keeps X and Z, takes the first point's Y" (near side[2] [0,0,3])) do failures += 1
	local ovf = AlecAngle_linesOverlay flat
	if not (check "skew lines flattened meet at 90" (ovf.labels.count == 1 and (findString ovf.labels[1][2] "90.0 deg /") == 1)) do failures += 1
	-- a line sloping up 45 in XZ and one along Y: 90 in World XY, whatever the slope
	local ovs = AlecAngle_linesOverlay (AlecAngle_project #([0,0,0], [10,0,10], [0,0,0], [0,10,0]) [0,0,1])
	if not (check "a sloped line against Y is 90 in World XY" (ovs.labels.count == 1 and (findString ovs.labels[1][2] "90.0 deg /") == 1)) do failures += 1

	format "measureAngle_test: % failure(s)\n" failures
)
