-- Transform fields test (tools/transformFields.ms): run after Reload Alec Tools. Prints PASS/FAIL, deletes its objects and
-- puts the Use Center back. Then by hand on the toolbar: type, middle drag and right click in the four rows with one and with
-- several objects, under each Use Center, Ctrl+Z after each.
(
	fileIn (AlecTools_path "tools/transformFields.ms")
	local failed = #()
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		if not ok do append failed label
	)
	fn near a b = distance a b < 0.001
	fn nearAngles a b = near [a[1], a[2], a[3]] b
	-- the same rotation, whatever angles describe it
	fn sameRotation a b = near a.row1 b.row1 and near a.row2 b.row2 and near a.row3 b.row3
	-- max undo also undoes the selection made in the same script, so the selection is put back after it
	fn undoStep =
	(
		local keep = selection as array
		max undo
		with undo off select keep
	)
	local center = getCoordCenter()

	-- made with undo off: a script run from the Listener can fold everything into one undo step, and max undo must not reach these
	local a, b
	with undo off
	(
		a = box pos:[10, 20, 30] width:10 length:10 height:10
		b = box pos:[50, 20, 30] width:10 length:10 height:10
		rotate b (angleAxis 90 [0, 0, 1])
		b.scale = [2, 2, 2]
	)

	-- position
	clearSelection()
	check "nothing selected: undefined" (AlecFields_worldPosition() == undefined and AlecFields_relative() == undefined)
	select a
	check "one object: its pivot" (nearAngles (AlecFields_worldPosition()) [10, 20, 30])
	AlecFields_setWorldPosition #(100, undefined, undefined)
	check "set world X, the other axes stay" (near a.pos [100, 20, 30])
	undoStep()
	check "undo restores" (near a.pos [10, 20, 30])
	AlecFields_setWorldPosition #(undefined, 5, undefined) add:true undoable:false
	check "add to world Y" (near a.pos [10, 25, 30])
	with undo off (a.pos = [10, 20, 30])
	select b
	AlecFields_moveLocal [10, 0, 5]
	check "local move on a rotated, scaled object goes along its axes, in scene units" (near b.pos [50, 30, 35])
	with undo off (b.pos = [50, 20, 30])
	select #(a, b)
	check "several: the center of their bounds" (nearAngles (AlecFields_worldPosition()) [32.5, 20, 40])
	AlecFields_setWorldPosition #(undefined, undefined, 45)
	check "several move as one" (near a.pos [10, 20, 35] and near b.pos [50, 20, 35])
	with undo off (b.parent = a)
	AlecFields_moveLocal [0, 0, 10] undoable:false
	check "selected child of a selected parent moves once" (near a.pos [10, 20, 45] and near b.pos [50, 20, 45])
	with undo off (b.parent = undefined)
	with undo off (a.pos = [10, 20, 30])
	with undo off (b.pos = [50, 20, 30])

	-- ladder drag: hold, change, restore
	AlecFields_hold()
	AlecFields_setWorldPosition #(7, undefined, undefined) add:true undoable:false
	AlecFields_restore()
	check "restore puts the held transforms back" (near a.pos [10, 20, 30] and near b.pos [50, 20, 30])

	-- world rotation, Pivot Point Center. Max may switch the Use Center when the selection changes, so it is set after
	select b
	setCoordCenter #local
	check "world rotation as Max shows it" (nearAngles (AlecFields_worldRotation()) [0, 0, 90])
	AlecFields_setWorldRotation #(30, 20, 10)
	check "set world rotation: Max's XYZ angles" (nearAngles (AlecFields_worldRotation()) [30, 20, 10])
	check "set world rotation keeps position and scale" (near b.pos [50, 20, 30] and near b.scale [2, 2, 2])
	undoStep()
	check "undo restores the rotation" (nearAngles (AlecFields_worldRotation()) [0, 0, 90])
	select #(a, b)
	setCoordCenter #local
	local r = AlecFields_worldRotation()
	check "several, pivot center: equal angles shown, different ones undefined" (r[1] == 0 and r[2] == 0 and r[3] == undefined)
	AlecFields_setWorldRotation #(undefined, undefined, 45)
	check "several, pivot center: each object gets the angle, about its own pivot" \
		(nearAngles (AlecFields_angles a) [0, 0, 45] and nearAngles (AlecFields_angles b) [0, 0, 45] and near a.pos [10, 20, 30] and near b.pos [50, 20, 30])
	AlecFields_setWorldRotation #(undefined, undefined, 10) add:true
	check "several, pivot center: add turns each by the same amount" (nearAngles (AlecFields_angles a) [0, 0, 55] and nearAngles (AlecFields_angles b) [0, 0, 55])
	with undo off (a.transform = transMatrix [10, 20, 30])
	with undo off (b.transform = scaleMatrix [2, 2, 2] * transMatrix [50, 20, 30])

	-- world rotation, Selection and Transform Coordinate Center: several turn as one
	setCoordCenter #selection
	check "several, selection center: relative" (AlecFields_worldRotation() == #relative)
	local c = AlecFields_boundsCenter()
	AlecFields_rotateWorld [0, 0, 180]
	check "selection center: turns as one about the center of their bounds" (near a.pos [2 * c.x - 10, 2 * c.y - 20, 30] and near b.pos [2 * c.x - 50, 2 * c.y - 20, 30])
	undoStep()
	setCoordCenter #system
	AlecFields_rotateWorld [0, 0, 90] undoable:false
	check "transform coordinate center: turns about the world origin" (near a.pos [-20, 10, 30] and near b.pos [-20, 50, 30])
	with undo off (a.transform = transMatrix [10, 20, 30])
	select a
	check "one object with the selection center: absolute angles" (not (AlecFields_worldRotation() == #relative))

	-- local rotation
	select b
	local before = b.transform
	AlecFields_rotateLocal [90, 0, 0]
	check "local rotation turns around the object's own X, about its pivot" \
		(near b.pos before.pos and sameRotation (b.transform.rotationPart as matrix3) ((rotateXMatrix 90) * (before.rotationPart as matrix3)))

	-- scale (percent) and size (scene units, along the object's own axes)
	with undo off (a.transform = transMatrix [10, 20, 30])
	with undo off (b.transform = rotateZMatrix 90 * transMatrix [50, 20, 30])
	with undo off (b.scale = [2, 2, 2])
	select b
	check "scale shows percent" (nearAngles (AlecFields_scale()) [200, 200, 200])
	check "size along its own axes, scale included (box 10 x 2)" (nearAngles (AlecFields_size()) [20, 20, 20])
	AlecFields_setScale #(undefined, 50, undefined)
	check "set scale Y, the others stay" (near b.scale [2, 0.5, 2])
	check "set scale keeps position" (near b.pos [50, 20, 30])
	undoStep()
	check "undo restores the scale" (near b.scale [2, 2, 2])
	AlecFields_setScale #(undefined, 0, undefined)
	check "a scale of 0 is refused" (near b.scale [2, 2, 2])
	AlecFields_setScale #(100, undefined, undefined) add:true undoable:false
	check "add to scale X" (near b.scale [3, 2, 2])
	with undo off (b.transform = rotateZMatrix 90 * transMatrix [50, 20, 30]; b.scale = [2, 2, 2])
	AlecFields_setSize #(40, undefined, 5)
	check "set size X and Z by scaling along the object's own axes" (nearAngles (AlecFields_size()) [40, 20, 5] and near b.scale [4, 2, 0.5])
	check "set size keeps position and rotation" (near b.pos [50, 20, 30] and sameRotation (b.transform.rotationPart as matrix3) (rotateZMatrix 90))
	undoStep()
	check "undo restores the size" (near b.scale [2, 2, 2])
	AlecFields_setSize #(5, undefined, undefined) add:true undoable:false
	check "add to size X" (nearAngles (AlecFields_size()) [25, 20, 20])
	with undo off (b.transform = rotateZMatrix 90 * transMatrix [50, 20, 30]; b.scale = [2, 2, 2])
	select #(a, b)
	local ab = AlecTools_bounds #(a, b) (matrix3 1)
	local sz = AlecFields_size()
	check "several: the size of both together, along the world axes" (nearAngles [sz[1], sz[2], sz[3]] (ab[2] - ab[1]))
	AlecFields_setSize #(100, undefined, undefined)
	local after = AlecTools_bounds #(a, b) (matrix3 1)
	check "several: set size X scales both as one" (abs ((after[2] - after[1]).x - 100) < 0.01)
	check "several: the center of the bounds stays" (distance ((after[1] + after[2]) / 2) ((ab[1] + ab[2]) / 2) < 0.01)
	clearSelection()
	check "nothing selected: scale and size undefined" (AlecFields_scale() == undefined and AlecFields_size() == undefined)

	delete #(b, a)
	setCoordCenter center
	format "transformFields_test: % failure(s)\n" failed.count
	for label in failed do format "FAIL %\n" label
)
