-- Test for tools/usdMaterialX.py (AlecUsdMtlxRead.py, AlecUsdMtlxBuild.py). Run in Max after Reload Alec Tools (needs USD for 3ds Max):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\usdMaterialX_test.ms"
-- Makes three boxes with Standard materials named like the materials of a small .usda with Blender-style inline MaterialX
-- networks, which tests/usdMaterialX_test.py writes to a temp folder (with a 1-pixel texture), applies and checks: the
-- OpenPBR_Materials, maps and assignment. Then one undo here, outside the Python part, and everything is deleted.
-- Prints PASS/FAIL lines to the Listener. Not covered, try by hand: a render of the result on V-Ray GPU and Arnold GPU, the file dialog.
(
	global ATusd_boxes, ATusd_failures = 0
	-- created with undo off: inside a running script the whole script is one undo step, so max undo below could otherwise undo the boxes too
	with undo off
	(
		local multi = Multimaterial numsubs:2
		multi[1] = StandardMaterial name:"AT_mtlxA"
		multi[2] = StandardMaterial name:"AT_mtlxB"
		ATusd_boxes = #(box material:multi, box material:(StandardMaterial name:"at_mtlxa"), box material:(StandardMaterial name:"AT_mtlxD"))
	)
	python.ExecuteFile ((getFilenamePath (getThisScriptFilename())) + "usdMaterialX_test.py")
	local b = ATusd_boxes[2]
	max undo
	local ok = classOf b.material == StandardMaterial and b.material.name == "at_mtlxa" and classOf ATusd_boxes[1].material[1] == StandardMaterial
	format "% one undo gives the Standard materials back\n" (if ok then "PASS" else "FAIL")
	if not ok do ATusd_failures += 1
	delete ATusd_boxes
	format "usdMaterialX_test: % failure(s)\n" ATusd_failures
	globalVars.remove #ATusd_boxes
	globalVars.remove #ATusd_failures
)
