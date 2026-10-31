-- Test for tools/moveToLayer.ms. Run in Max (needs a scene you do not mind changing):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\moveToLayer_test.ms"
-- Creates temporary layers and objects, checks the moves, deletes them. Prints PASS/FAIL lines to the Listener.
-- The popup in moveToLayer.py is not covered: try it by hand.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/moveToLayer.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)

	for n in #("ATtest_New", "ATtest_Sub", "ATtest_Dest") do LayerManager.deleteLayerByName n
	-- created with undo off in the current layer, so max undo below can only undo the move
	local home = LayerManager.current
	local dest = AlecMoveLayer_layer "ATtest_Dest" undefined
	local a, b, g1, g2, grp
	undo off
	(
		a = box name:"ATtest_A"
		b = box name:"ATtest_B"
		g1 = box name:"ATtest_G1"
		g2 = box name:"ATtest_G2"
		grp = group #(g1, g2) name:"ATtest_Group"
	)

	-- layer: created, found again, created under a parent
	if not (check "layer: created" (dest != undefined and dest.name == "ATtest_Dest")) do failures += 1
	if not (check "layer: existing one is reused" ((AlecMoveLayer_layer "ATtest_Dest" undefined).name == "ATtest_Dest" and LayerManager.getLayerFromName "ATtest_Dest" != undefined)) do failures += 1
	local sub = AlecMoveLayer_layer "ATtest_Sub" dest
	if not (check "layer: created under parent" ((sub.getParent()).name == "ATtest_Dest")) do failures += 1

	-- move: plain nodes, one undo
	if not (check "move: reports count" ((AlecMoveLayer_move #(a, b) dest) == 2)) do failures += 1
	if not (check "move: nodes in the layer" (a.layer.name == "ATtest_Dest" and b.layer.name == "ATtest_Dest")) do failures += 1
	max undo
	if not (check "move: one undo restores both" (a.layer == home and b.layer == home)) do failures += 1

	-- move: a member of a closed group moves the whole group
	if not (check "group: member lifts to whole group" ((AlecMoveLayer_move #(g1) sub) == 3)) do failures += 1
	if not (check "group: head and members in the layer" (grp.layer.name == "ATtest_Sub" and g1.layer.name == "ATtest_Sub" and g2.layer.name == "ATtest_Sub")) do failures += 1

	-- new layer and move: one undo step; whether Max also undoes the layer itself is what the last check finds out
	local newLayer = AlecMoveLayer_moveToNew #(a) "ATtest_New" dest
	if not (check "new: layer created under parent" (newLayer.name == "ATtest_New" and (newLayer.getParent()).name == "ATtest_Dest")) do failures += 1
	if not (check "new: node in the new layer" (a.layer.name == "ATtest_New")) do failures += 1
	max undo
	if not (check "new: undo puts the node back" (a.layer == home)) do failures += 1
	if not (check "new: undo removes the new layer" (LayerManager.getLayerFromName "ATtest_New" == undefined)) do failures += 1
	LayerManager.deleteLayerByName "ATtest_New"

	delete #(a, b, g1, g2, grp)
	LayerManager.deleteLayerByName "ATtest_Sub"
	LayerManager.deleteLayerByName "ATtest_Dest"
	format "moveToLayer_test: % failure(s)\n" failures
)
