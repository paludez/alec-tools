-- Test for tools/getMaterials.ms. Run in Max (needs a scene you do not mind changing):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\getMaterials_test.ms"
-- Creates temporary objects and its own SME tab (not the "Get Materials" tab), checks which nodes appear, removes everything.
-- Prints PASS/FAIL lines to the Listener.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/getMaterials.ms")

(
	local failures = 0
	local tab = "ATtest_tab"
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)

	local shared = StandardMaterial name:"ATtest_shared" diffuseMap:(Checker())
	local other = StandardMaterial name:"ATtest_other"
	local a = box name:"ATtest_A" material:shared
	local b = box name:"ATtest_B" material:shared
	local c = box name:"ATtest_C" material:other
	local d = box name:"ATtest_D"

	-- the materials of a selection, without duplicates and without objects that have none
	select #(a, b, c, d)
	local mats = AlecGetMaterials_selectionMaterials()
	if not (check "selectionMaterials: one entry per distinct material" (mats.count == 2 and findItem mats shared != 0 and findItem mats other != 0)) do failures += 1

	-- the tab gets the material nodes and the map nodes under them
	select #(a, b)
	AlecGetMaterials_execute tabName:tab
	local view = sme.GetView (sme.GetViewByName tab)
	if not (check "execute: material node and its map node are in the tab" (view.GetNumNodes() == 2 and view.GetNodeByRef shared != undefined)) do failures += 1

	-- unused slots are hidden, so the nodes are not tall
	local allHidden = true
	for i = 1 to view.GetNumNodes() do if not (view.GetNode i).hideUnusedNodeSlots do allHidden = false
	if not (check "execute: unused node slots are hidden" allHidden) do failures += 1

	-- running it again does not duplicate, a new material is added
	AlecGetMaterials_execute tabName:tab
	if not (check "execute: a second run adds no duplicates" (view.GetNumNodes() == 2)) do failures += 1
	select #(a, b, c)
	AlecGetMaterials_execute tabName:tab
	if not (check "execute: a new material is added to the same tab" (view.GetNumNodes() == 3 and view.GetNodeByRef other != undefined)) do failures += 1

	-- nothing with a material selected: no exception, tab untouched
	select d
	AlecGetMaterials_execute tabName:tab
	if not (check "execute: selection without materials changes nothing" (view.GetNumNodes() == 3)) do failures += 1

	sme.DeleteView (sme.GetViewByName tab) false
	delete #(a, b, c, d)
	format "getMaterials_test: % failure(s)\n" failures
)
