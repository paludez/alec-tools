-- Test for tools/bbox.ms. Run in Max (needs a scene you do not mind changing):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\bbox_test.ms"
-- Creates temporary objects (ATtest_*), builds cages around them, compares sizes and positions with values worked out by hand, deletes everything.
-- Prints PASS/FAIL lines to the Listener. Not covered, try by hand: the caddy controls (spinner, checkboxes, Reset, picking the Local axes object), Esc closing the caddy, clicking an object when nothing is selected and one Ctrl+Z after OK removing all the cages.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/bbox.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	fn near a b = (distance a b) < 0.01

	fn cageSize c = [c.width, c.length, c.height]
	-- the pivot of a Box is at the center of its base
	fn cageCenter c = c.pos + (normalize c.transform.row3) * (c.height / 2)
	fn build nodes s = AlecBBox_build (AlecBBox_Session settings:s sources:(AlecBBox_sources nodes))
	fn drop cages = for m in cages where isValidNode m do delete m
	fn sameAxes a b = near (normalize a.row1) (normalize b.row1) and near (normalize a.row2) (normalize b.row2) and near (normalize a.row3) (normalize b.row3)

	-- size of the mesh vertices in the local frame (rotation without scale), worked out the slow way
	fn vertsSize node =
	(
		local frame = node.transform.rotation as matrix3
		frame.row4 = node.transform.row4
		local inv = inverse frame
		local m = snapshotAsMesh node
		local lo = (getVert m 1) * inv
		local hi = lo
		for i = 1 to m.numVerts do
		(
			local p = (getVert m i) * inv
			lo = [amin lo.x p.x, amin lo.y p.y, amin lo.z p.z]
			hi = [amax hi.x p.x, amax hi.y p.y, amax hi.z p.z]
		)
		delete m
		hi - lo
	)

	-- what a run that stopped halfway left behind, so names and layers start clean
	delete (for o in objects where matchPattern o.name pattern:"ATtest_*" collect o)
	LayerManager.deleteLayerByName "ATtest_layer"

	local helpersExisted = LayerManager.getLayerFromName "BBox helpers" != undefined

	-- a box that is rotated and scaled, so world and local differ: 40 x 20 x 20 in its own axes, center at [100,50,30]
	local aw = box name:"ATtest_awkward" length:20 width:20 height:20
	aw.transform = (scaleMatrix [2,1,1]) * (rotateZMatrix 30) * (transMatrix [100,50,20])

	local c = (build #(aw) (AlecBBox_Settings each:true localAxes:true))
	if not (check "local: one cage, the size of the object in its axes without scale" (c.count == 1 and near (cageSize c[1]) [40,20,20])) do failures += 1
	if not (check "local: the cage is centered on the object and turned with it" (near (cageCenter c[1]) [100,50,30] and sameAxes c[1].transform aw.transform)) do failures += 1
	if not (check "local: the cage carries no scale" (near c[1].scale [1,1,1])) do failures += 1
	if not (check "local: name ends in _bbox_L" (c[1].name == "ATtest_awkward_bbox_L")) do failures += 1

	drop c
	c = build #(aw) (AlecBBox_Settings each:true localAxes:false)
	if not (check "world: the size of the rotated object along the world axes" (near (cageSize c[1]) [44.641,37.3205,20] and near (cageCenter c[1]) [100,50,30])) do failures += 1
	if not (check "world: the cage is not turned" (sameAxes c[1].transform (matrix3 1))) do failures += 1
	if not (check "world: name ends in _bbox_W" (c[1].name == "ATtest_awkward_bbox_W")) do failures += 1

	drop c
	c = build #(aw) (AlecBBox_Settings each:false localAxes:true)
	if not (check "combined, one object, Local: the axes of the object, named BBox" (near (cageSize c[1]) [40,20,20] and sameAxes c[1].transform aw.transform and matchPattern c[1].name pattern:"BBox*")) do failures += 1

	-- a modifier: the cage follows the bent mesh, not the box parameters
	local bent = box name:"ATtest_bent" width:10 length:10 height:60 heightsegs:20 pos:[0,300,0]
	addModifier bent (Bend angle:120)
	rotate bent (eulerAngles 0 30 0)
	drop c
	c = build #(bent) (AlecBBox_Settings each:true localAxes:true)
	if not (check "modifier: the cage matches the bent vertices" (near (cageSize c[1]) (vertsSize bent))) do failures += 1

	-- an instance of the awkward box, turned differently and not scaled
	local inst = instance aw
	inst.name = "ATtest_inst"
	inst.transform = (rotateXMatrix 45) * (transMatrix [0,200,0])
	drop c
	c = build #(inst) (AlecBBox_Settings each:true localAxes:true)
	if not (check "instance: its own transform, 20 x 20 x 20" (near (cageSize c[1]) [20,20,20] and sameAxes c[1].transform inst.transform)) do failures += 1

	-- two boxes: one cage around both, or one each
	local b1 = box name:"ATtest_b1" width:10 length:10 height:10
	local b2 = box name:"ATtest_b2" width:10 length:10 height:10 pos:[50,0,0]
	drop c
	c = build #(b1, b2) (AlecBBox_Settings each:false)
	if not (check "combined: one cage around both boxes" (c.count == 1 and near (cageSize c[1]) [60,10,10] and near (cageCenter c[1]) [25,0,5])) do failures += 1
	drop c
	c = build #(b1, b2) (AlecBBox_Settings each:true)
	if not (check "each: one cage per box" (c.count == 2 and near (cageSize c[1]) [10,10,10] and near (cageCenter c[2]) [50,0,5])) do failures += 1

	-- Local with an anchor: every cage takes its axes; without one, the first object (combined) or each its own (Each)
	local anc = box name:"ATtest_anchor" width:5 length:5 height:5 pos:[0,-50,0]
	rotate anc (eulerAngles 0 0 90)
	local sess = AlecBBox_Session settings:(AlecBBox_Settings each:false localAxes:true) sources:(AlecBBox_sources #(b1, b2))
	drop c
	c = AlecBBox_build sess
	if not (check "anchor: none picked, combined takes the first object" (sess.anchor == undefined and near (cageSize c[1]) [60,10,10] and sameAxes c[1].transform (matrix3 1))) do failures += 1
	sess.anchor = anc
	drop c
	c = AlecBBox_build sess
	if not (check "anchor: a picked object turns the cage, which still holds both boxes" (near (cageSize c[1]) [10,60,10] and sameAxes c[1].transform anc.transform and near (cageCenter c[1]) [25,0,5])) do failures += 1
	-- with Each: a 10 cube in the axes of the awkward box (30 degrees) is 10 cos30 + 10 sin30 wide
	sess.settings = AlecBBox_Settings each:true localAxes:true
	sess.anchor = aw
	drop c
	c = AlecBBox_build sess
	if not (check "anchor with Each: every cage in the axes of the anchor" (c.count == 2 and near (cageSize c[1]) [13.6603,13.6603,10] and sameAxes c[1].transform aw.transform and sameAxes c[2].transform aw.transform)) do failures += 1
	sess.anchor = undefined
	drop c
	c = AlecBBox_build sess
	if not (check "anchor cleared with Each: each cage back in its own axes" (near (cageSize c[1]) [10,10,10] and sameAxes c[1].transform b1.transform)) do failures += 1

	-- offset: grows or shrinks every side, never under 0.1, the center stays
	drop c
	c = build #(b1) (AlecBBox_Settings each:true offset:2.0)
	if not (check "offset +2: 4 more on every axis, same center" (near (cageSize c[1]) [14,14,14] and near (cageCenter c[1]) [0,0,5])) do failures += 1
	drop c
	c = build #(b1) (AlecBBox_Settings each:true offset:-2.0)
	if not (check "offset -2: 4 less on every axis, same center" (near (cageSize c[1]) [6,6,6] and near (cageCenter c[1]) [0,0,5])) do failures += 1
	drop c
	c = build #(b1) (AlecBBox_Settings each:true offset:-100.0)
	if not (check "offset -100: stops at 0.1, same center" (near (cageSize c[1]) [0.1,0.1,0.1] and near (cageCenter c[1]) [0,0,5])) do failures += 1

	-- copy: a tight cage plus one with the offset; with no offset there is no copy
	drop c
	c = build #(b1) (AlecBBox_Settings each:true localAxes:true offset:3.0 addCopy:true)
	if not (check "copy: tight green cage plus a cyan _p cage with the offset" (c.count == 2 and near (cageSize c[1]) [10,10,10] and near (cageSize c[2]) [16,16,16] \
		and c[1].wirecolor == green and c[2].wirecolor == (color 0 231 255) and c[2].name == c[1].name + "_p")) do failures += 1
	drop c
	c = build #(b1) (AlecBBox_Settings each:true offset:0.0 addCopy:true)
	if not (check "copy: no offset, no copy" (c.count == 1)) do failures += 1
	drop c
	c = build #(b1) (AlecBBox_Settings each:false offset:3.0 addCopy:true)
	if not (check "copy: combined names BBox and BBox_p" (c.count == 2 and c[2].name == c[1].name + "_p")) do failures += 1

	-- flat objects: a plane and a turned rectangle get the 0.1 minimum on their flat side
	local pl = Plane name:"ATtest_plane" length:10 width:20 pos:[0,-100,0]
	drop c
	c = build #(pl) (AlecBBox_Settings each:true)
	if not (check "plane: flat side becomes 0.1" (near (cageSize c[1]) [20,10,0.1] and near (cageCenter c[1]) [0,-100,0])) do failures += 1
	local rect = Rectangle name:"ATtest_rect" length:10 width:20 pos:[0,-200,0]
	rotate rect (eulerAngles 0 0 30)
	drop c
	c = build #(rect) (AlecBBox_Settings each:true localAxes:true)
	if not (check "shape: a turned rectangle, tight in its axes" (near (cageSize c[1]) [20,10,0.1] and near (cageCenter c[1]) [0,-200,0])) do failures += 1

	-- skipped: helpers and camera/light targets
	local dm = Dummy name:"ATtest_dummy"
	local pt = Point name:"ATtest_point"
	local tg = Targetobject name:"ATtest_target"
	if not (check "skip: Dummy, Point and a target give no source" ((AlecBBox_sources #(dm, pt, tg)).count == 0)) do failures += 1

	-- groups: a closed group is one source in the axes of its head; an open one gives its members
	local g1 = box name:"ATtest_g1" width:10 length:10 height:10 pos:[0,500,0]
	local g2 = box name:"ATtest_g2" width:10 length:10 height:10 pos:[30,500,0]
	local grp = group #(g1, g2) name:"ATtest_grp"
	rotate grp (eulerAngles 0 0 30)
	local src = AlecBBox_sources #(grp, g1, g2)
	if not (check "group closed: the head (selected with its members) is the only source" (src.count == 1 and src[1] == grp)) do failures += 1
	drop c
	c = build #(grp, g1, g2) (AlecBBox_Settings each:true localAxes:true)
	if not (check "group closed: one cage around the members, in the axes of the head, named after the group" (c.count == 1 and near (cageSize c[1]) [40,10,10] \
		and sameAxes c[1].transform grp.transform and c[1].name == "ATtest_grp_bbox_L")) do failures += 1
	setGroupOpen grp true
	src = AlecBBox_sources #(grp, g1, g2)
	if not (check "group open: the members are the sources, the head is not" (src.count == 2 and findItem src grp == 0)) do failures += 1
	setGroupOpen grp false
	local g3 = box name:"ATtest_g3" width:10 length:10 height:10 pos:[0,560,0]
	local outer = group #(grp, g3) name:"ATtest_outer"
	src = AlecBBox_sources #(outer, grp, g1, g2, g3)
	if not (check "group nested: only the outer head, measured on all three boxes" (src.count == 1 and src[1] == outer and (AlecTools_parts outer).count == 3)) do failures += 1

	-- layers: BBox helpers, the layer of the object with Each, the current layer when combined
	-- newLayerFromName gives undefined when the layer is already there (deleteLayerByName above leaves it when it is the current one)
	local lay = LayerManager.getLayerFromName "ATtest_layer"
	if lay == undefined do lay = LayerManager.newLayerFromName "ATtest_layer"
	lay.addNode b2
	drop c
	c = build #(b2) (AlecBBox_Settings each:true useLayer:true)
	if not (check "layer: BBox helpers" (c[1].layer.name == "BBox helpers")) do failures += 1
	drop c
	c = build #(b2) (AlecBBox_Settings each:true useLayer:false)
	if not (check "layer: off with Each, the layer of the object" (c[1].layer.name == "ATtest_layer")) do failures += 1
	drop c
	c = build #(b2) (AlecBBox_Settings each:false useLayer:false)
	if not (check "layer: off when combined, the current layer" (c[1].layer.name == LayerManager.current.name)) do failures += 1

	-- display and render: drawn as a box, not rendered, no shadows, green
	local cg = c[1]
	if not (check "cage: Display as Box, not renderable, no shadows, green" (cg.boxmode and not cg.renderable and not cg.castShadows and not cg.receiveShadows and cg.wirecolor == green)) do failures += 1

	-- names: a second cage of the same object gets a free name; the selection stays as it was
	select b1
	local first = build #(b1) (AlecBBox_Settings each:true)
	local second = build #(b1) (AlecBBox_Settings each:true)
	if not (check "names: a taken name is made unique" (first[1].name == "ATtest_b1_bbox_W" and second[1].name != first[1].name)) do failures += 1
	if not (check "selection: unchanged after making cages" (selection.count == 1 and selection[1] == b1)) do failures += 1

	drop c
	drop first
	drop second

	-- preview: rebuilt on every update, accept keeps the cages, end drops the preview
	-- (the single undo step of accept is not tested here: inside a running script the whole script is one undo step, so max undo would undo the test itself)
	AlecBBox_active = AlecBBox_Session settings:(AlecBBox_Settings each:true) sources:#(b1)
	AlecBBox_updatePreview AlecBBox_active
	local firstPreview = AlecBBox_active.cages[1]
	AlecBBox_updatePreview AlecBBox_active
	if not (check "preview: an update replaces the old cage" (not (isValidNode firstPreview) and AlecBBox_active.cages.count == 1)) do failures += 1
	local lastPreview = AlecBBox_active.cages[1]
	AlecBBox_accept()
	local kept = for o in objects where o.name == "ATtest_b1_bbox_W" collect o
	if not (check "accept: the preview is gone, one cage is kept, the session ends" (not (isValidNode lastPreview) and kept.count == 1 and AlecBBox_active == undefined)) do failures += 1
	drop kept

	AlecBBox_active = AlecBBox_Session settings:(AlecBBox_Settings each:true) sources:#(b1)
	AlecBBox_updatePreview AlecBBox_active
	local dropped = AlecBBox_active.cages[1]
	AlecBBox_end()
	if not (check "cancel: the preview is gone and the session ends" (not (isValidNode dropped) and AlecBBox_active == undefined)) do failures += 1

	-- run: nothing measurable selected waits for a pick, and giving up opens nothing (a timer ends the picking like a right click, so no click is needed;
	-- global because the timer handler cannot see the locals of this block); a run opens the caddy with a preview; running again or loading the file again closes the old one
	global AT_bboxTimer = dotNetObject "System.Windows.Forms.Timer"
	AT_bboxTimer.interval = 500
	dotnet.addEventHandler AT_bboxTimer "Tick" (fn AT_onBBoxTick s e = (max select))
	select dm
	AT_bboxTimer.start()
	AlecBBox_run()
	AT_bboxTimer.stop()
	if not (check "run: only a helper selected, the pick is given up, no caddy" (not AlecBBox_rollout.open and AlecBBox_active == undefined)) do failures += 1
	select b1
	AlecBBox_run()
	local runPreview = AlecBBox_active.cages[1]
	if not (check "run: the caddy opens with a preview" (AlecBBox_rollout.open and isValidNode runPreview)) do failures += 1
	AlecBBox_run()
	if not (check "run again: the old preview is gone, a new one is up" (not (isValidNode runPreview) and AlecBBox_rollout.open and AlecBBox_active.cages.count > 0)) do failures += 1
	runPreview = AlecBBox_active.cages[1]
	fileIn (AlecTools_path "tools/bbox.ms")
	if not (check "load again (macro pressed while open): the old caddy and its preview are gone" (not (isValidNode runPreview) and not AlecBBox_rollout.open)) do failures += 1

	-- settings are saved to the ini and read back; the user's own values are restored afterwards
	local original = AlecBBox_loadSettings()
	AlecBBox_saveSettings (AlecBBox_Settings each:true localAxes:true offset:2.5 addCopy:true useLayer:false)
	local back = AlecBBox_loadSettings()
	if not (check "settings: saved and read back" (back.each and back.localAxes and back.offset == 2.5 and back.addCopy and not back.useLayer)) do failures += 1
	AlecBBox_saveSettings original

	clearSelection()
	delete (for o in objects where matchPattern o.name pattern:"ATtest_*" collect o)
	LayerManager.deleteLayerByName "ATtest_layer"
	if not helpersExisted do LayerManager.deleteLayerByName "BBox helpers"

	format "bbox_test: % failure(s)\n" failures
)
