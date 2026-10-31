-- Test for tools/measureBBox.ms. Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\measureBBox_test.ms"
-- Creates temporary objects, checks the sizes and the overlay, deletes them. Prints PASS/FAIL lines to the Listener.
-- Not covered, try by hand: hovering, clicking and that right click clears the viewports.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/measureBBox.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	fn near a b = (distance a b) < 0.01

	-- rotated, so the sizes must come from the local axes
	local b = box name:"ATtest_mbox" length:20 width:40 height:10
	b.transform = (rotateZMatrix 30) * (transMatrix [100, 50, 0])
	local ov = AlecTools_Overlay()
	local size = AlecMBox_addObject ov b
	if not (check "rotated box: sizes in its own axes" (near size [40, 20, 10])) do failures += 1
	if not (check "overlay: 1 box, 3 labels, no lines" (ov.boxes.count == 1 and ov.lines.count == 0 and ov.labels.count == 3)) do failures += 1

	local wsize = AlecMBox_addObject (AlecTools_Overlay()) b world:true
	local wx = 40 * cos 30 + 20 * sin 30
	if not (check "rotated box: world sizes are larger" (near wsize [wx, 40 * sin 30 + 20 * cos 30, 10])) do failures += 1

	-- a closed group stands for all its members
	local g1 = box name:"ATtest_g1" length:10 width:10 height:10 pos:[0, 0, 0]
	local g2 = box name:"ATtest_g2" length:10 width:10 height:10 pos:[50, 0, 0]
	local head = group #(g1, g2) name:"ATtest_group"
	if not (check "member of a closed group gives its head" (AlecTools_groupObject g1 == head)) do failures += 1
	local gsize = AlecMBox_addObject (AlecTools_Overlay()) head
	if not (check "group: size covers both members" (abs (gsize.x - 60) < 0.01)) do failures += 1

	local kept = #(b)
	AlecMBox_buildOverlay kept head
	if not (check "overlay: kept object plus hovered one" (AlecMBox_overlay.boxes.count == 2)) do failures += 1
	AlecMBox_overlay = undefined

	delete #(b, g1, g2, head)
	format "measureBBox_test: % failure(s)\n" failures
)
