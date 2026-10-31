-- Test for tools/measure.ms. Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\measure_test.ms"
-- Checks the lengths and the overlay built from points. Prints PASS/FAIL lines to the Listener.
-- Not covered, try by hand: the clicks of pickPoint, and that right click clears the viewports.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/measure.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	local pts = #([0,0,0], [30,40,0], [30,40,12])

	if not (check "total of 3-4-5 plus 12 is 62" (abs ((AlecMeasure_total pts) - 62.0) < 0.001)) do failures += 1
	if not (check "one point gives total 0" ((AlecMeasure_total #([1,2,3])) == 0.0)) do failures += 1

	local ov2 = AlecMeasure_buildOverlay #(pts[1], pts[2])
	if not (check "2 points: 1 line, 1 label, no total" (ov2.lines.count == 1 and ov2.labels.count == 1)) do failures += 1
	if not (check "2 points: label is the length" (ov2.labels[1][2] == units.formatValue 50.0)) do failures += 1

	local ov3 = AlecMeasure_buildOverlay pts
	if not (check "3 points: 2 lines, 2 labels + total" (ov3.lines.count == 2 and ov3.labels.count == 3)) do failures += 1
	if not (check "3 points: total at the last point" (ov3.labels[3][1] == pts[3] and ov3.labels[3][2] == "Total: " + units.formatValue 62.0)) do failures += 1

	-- a 300 x 400 cm rectangle: 12 m2, perimeter 1400
	local rect = #([0,0,0], [300,0,0], [300,400,0], [0,400,0])
	if not (check "area of a 300 x 400 rectangle is 120000" (abs ((AlecMeasure_area rect) - 120000.0) < 0.01)) do failures += 1
	if not (check "the same rectangle tilted keeps its area" (abs ((AlecMeasure_area (for p in rect collect p * (rotateXMatrix 40))) - 120000.0) < 0.01)) do failures += 1
	if not (check "closed perimeter is 1400" (abs ((AlecMeasure_total rect closed:true) - 1400.0) < 0.01)) do failures += 1
	format "  area written as: %\n" (AlecMeasure_formatArea 120000.0)
	local ova = AlecMeasure_buildOverlay rect area:true
	if not (check "area overlay: 4 closed lines, 4 lengths + area" (ova.lines.count == 4 and ova.labels.count == 5)) do failures += 1

	format "measure_test: % failure(s)\n" failures
)
