-- Test for tools/measureClearance.ms. Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\measureClearance_test.ms"
-- Creates a temporary floor and ceiling, measures between them, deletes them. Prints PASS/FAIL lines to the Listener.
-- Not covered, try by hand: hovering, clicking, Ctrl and that right click clears the viewports.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/measureClearance.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)

	-- floor slab top at z 0 (20 thick), ceiling slab bottom at z 270, far from anything else in the scene
	local o = [100000, 100000, 0]
	local floorBox = box name:"ATtest_floor" length:500 width:500 height:20 pos:(o + [0, 0, -20])
	local ceilBox = box name:"ATtest_ceiling" length:500 width:500 height:20 pos:(o + [0, 0, 270])

	local up = AlecClear_measure o [0, 0, 1]
	if not (check "floor to ceiling is 270" (up[2] != undefined and abs ((distance up[1] up[2]) - 270) < 0.01)) do failures += 1

	local hit = AlecClear_firstHit (o + [0, 0, 100]) [0, 0, -1]
	if not (check "ray down hits the floor with an up normal" (hit != undefined and hit[1] == floorBox and hit[2].dir.z > 0.99)) do failures += 1

	local down = AlecClear_measureInward o [0, 0, -1] floorBox
	if not (check "inward from the floor top is the slab thickness, 20" (down[2] != undefined and abs ((distance down[1] down[2]) - 20) < 0.01)) do failures += 1

	local side = AlecClear_measure (o + [0, 0, 100]) [1, 0, 0]
	if not (check "nothing in front gives no end" (side[2] == undefined)) do failures += 1

	local ov = AlecClear_buildOverlay #(up, side)
	if not (check "overlay: 1 line, its length and a no hit" (ov.lines.count == 1 and ov.labels.count == 2 and ov.labels[2][2] == "no hit")) do failures += 1

	delete #(floorBox, ceilBox)
	format "measureClearance_test: % failure(s)\n" failures
)
