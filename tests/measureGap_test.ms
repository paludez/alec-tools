-- Test for tools/measureGap.ms. Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\measureGap_test.ms"
-- Creates temporary boxes, checks the gaps and the overlay, deletes them. Prints PASS/FAIL lines to the Listener.
-- Not covered, try by hand: hovering, clicking, Ctrl and that right click clears the viewports.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/measureGap.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	fn near a b = (distance a b) < 0.01

	-- boxes 20 x 20 x 20, pivot at the bottom center: a spans x -10..10, z 0..20
	local a = box name:"ATtest_gapA" length:20 width:20 height:20 pos:[0, 0, 0]
	local b = box name:"ATtest_gapB" length:20 width:20 height:20 pos:[50, 0, 0]
	local c = box name:"ATtest_gapC" length:20 width:20 height:20 pos:[50, 60, 30]
	local o = box name:"ATtest_gapO" length:20 width:20 height:20 pos:[5, 5, 5]
	local w = matrix3 1

	local ab = AlecGap_closest a b w
	if not (check "apart on X: gap is 30 along X" (near (ab[2] - ab[1]) [30, 0, 0])) do failures += 1
	local ac = AlecGap_closest a c w
	if not (check "apart on X, Y, Z: legs 30, 40, 10" (near (ac[2] - ac[1]) [30, 40, 10])) do failures += 1
	local ao = AlecGap_closest a o w
	if not (check "overlapping boxes: no gap" (near ao[1] ao[2])) do failures += 1

	local ov1 = AlecGap_buildOverlay a b true
	if not (check "one axis: 2 boxes, 1 line, no legs" (ov1.boxes.count == 2 and ov1.lines.count == 1 and ov1.labels.count == 1)) do failures += 1
	local ov3 = AlecGap_buildOverlay a c true
	if not (check "three axes: 1 line + 3 legs" (ov3.lines.count == 4 and ov3.labels.count == 4)) do failures += 1
	local ovo = AlecGap_buildOverlay a o true
	if not (check "overlap is written" (ovo.lines.count == 0 and ovo.labels[1][2] == "overlap")) do failures += 1

	-- in the reference's own axes: rotated together by 45, b is only along the reference's X
	local r = rotateZMatrix 45
	a.transform = r
	b.transform = r * (transMatrix ([50, 0, 0] * r))
	local loc = AlecGap_closest a b (AlecGap_frame a false)
	if not (check "local axes: rotated pair still 30 along the reference's X" (near (loc[2] - loc[1]) [30, 0, 0])) do failures += 1

	delete #(a, b, c, o)
	format "measureGap_test: % failure(s)\n" failures
)
