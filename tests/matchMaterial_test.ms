-- Test for tools/matchMaterial.ms. Run in Max (needs a scene you do not mind changing):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\matchMaterial_test.ms"
-- Creates temporary objects, checks the assignment, deletes them. Prints PASS/FAIL lines to the Listener.
-- The interactive pickObject in AlecMatchMat_execute is not covered: try it by hand.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/matchMaterial.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)

	-- created with undo off: inside a running script the whole script is one undo step, so max undo below could otherwise undo the objects too
	local mat, oldMat, source, bare, b, c
	with undo off
	(
		mat = StandardMaterial name:"ATtest_mat"
		oldMat = StandardMaterial name:"ATtest_old"
		source = box name:"ATtest_source" material:mat
		bare = box name:"ATtest_bare" wireColor:blue
		b = box name:"ATtest_B"
		c = box name:"ATtest_C" material:oldMat
	)

	-- source with a material: targets get it
	if not (check "material: assign reports success" (AlecMatchMat_assign #(b, c) source)) do failures += 1
	if not (check "material: targets get the source material" (b.material == mat and c.material == mat)) do failures += 1
	max undo
	if not (check "material: one undo restores all targets" (b.material == undefined and c.material == oldMat)) do failures += 1

	-- source without a material: nothing changes
	if not (check "no material: assign reports failure" (not (AlecMatchMat_assign #(b, c) bare))) do failures += 1
	if not (check "no material: targets are left alone" (b.material == undefined and c.material == oldMat)) do failures += 1

	delete #(source, bare, b, c)
	format "matchMaterial_test: % failure(s)\n" failures
)
