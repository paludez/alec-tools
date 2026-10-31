-- Test for tools/midBetween.ms. Run in Max (needs a scene you do not mind changing):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\midBetween_test.ms"
-- Creates temporary objects, moves them to a midpoint, reads the result back, deletes them. Prints PASS/FAIL lines to the Listener.
-- Not covered, try by hand: the clicks of pickPoint and pickObject, and the caddy buttons (the run without any point is covered with a timer).

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/midBetween.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	fn near a b = (distance a b) < 0.01

	-- a box that is rotated and scaled, so world and local space differ
	fn awkwardBox nm =
	(
		local b = box name:nm length:20 width:20 height:20 lengthsegs:2 widthsegs:2 heightsegs:2
		b.transform = (scaleMatrix [2,1,1]) * (rotateZMatrix 30) * (transMatrix [100,50,20])
		b
	)

	local mid = [-40, 15, 70]
	max modify mode

	-- objects: a linked parent / child / grandchild move as one group, only the top one is moved
	local p = box name:"ATtest_parent" pos:[0,0,0]
	local c = box name:"ATtest_child" pos:[50,0,0]
	local g = box name:"ATtest_grandchild" pos:[80,0,0]
	c.parent = p
	g.parent = c
	select #(p, c, g)
	AlecMid_moveObjects [100,0,0] (AlecMid_Settings())
	if not (check "objects: the average of the pivots lands on the midpoint" (near (AlecTools_average #(p.pos, c.pos, g.pos)) [100,0,0])) do failures += 1
	if not (check "objects: a linked child is not moved twice" (near c.pos (p.pos + [50,0,0]) and near g.pos (p.pos + [80,0,0]))) do failures += 1
	select p
	AlecMid_moveObjects [0,0,0] (AlecMid_Settings bounds:true)
	if not (check "objects: the bounding box center lands on the midpoint" (near (selection.center) [0,0,0])) do failures += 1
	delete #(p, c, g)
	-- a rotated box: its node.min/max box is not tight, the tight box of its geometry is what lands on the midpoint
	local rot = Box name:"ATtest_rot" length:10 width:40 height:10 pos:[0,0,0]
	rotate rot (eulerAngles 30 40 0)
	select rot
	AlecMid_moveObjects [50,0,0] (AlecMid_Settings bounds:true)
	local rb = nodeGetBoundingBox rot (matrix3 1)
	if not (check "objects: a rotated object's tight box center lands on the midpoint" (near ((rb[1] + rb[2]) / 2) [50,0,0])) do failures += 1
	delete rot

	-- Editable Poly, vertex / edge / face level
	local ep = convertToPoly (awkwardBox "ATtest_EP")
	select ep
	subObjectLevel = 1
	polyop.setVertSelection ep #{1}
	if not (check "Editable Poly vertex: selected verts" ((AlecMid_selectedVerts ep ep) == #{1})) do failures += 1
	local untouched = ep.verts[2].pos
	AlecMid_moveVerts ep ep #{1} mid (AlecMid_Settings())
	if not (check "Editable Poly vertex: moved to the midpoint (world)" (near (AlecMid_vertsCenter ep ep #{1} false) mid)) do failures += 1
	if not (check "Editable Poly vertex: other vertices stay" (near ep.verts[2].pos untouched)) do failures += 1
	subObjectLevel = 2
	polyop.setEdgeSelection ep #{1}
	local verts = AlecMid_selectedVerts ep ep
	if not (check "Editable Poly edge: two vertices" (verts.numberSet == 2)) do failures += 1
	AlecMid_moveVerts ep ep verts mid (AlecMid_Settings())
	if not (check "Editable Poly edge: center on the midpoint (world)" (near (AlecMid_vertsCenter ep ep verts false) mid)) do failures += 1
	subObjectLevel = 4
	polyop.setFaceSelection ep #{1}
	verts = AlecMid_selectedVerts ep ep
	if not (check "Editable Poly face: four vertices" (verts.numberSet == 4)) do failures += 1
	AlecMid_moveVerts ep ep verts mid (AlecMid_Settings())
	if not (check "Editable Poly face: center on the midpoint (world)" (near (AlecMid_vertsCenter ep ep verts false) mid)) do failures += 1
	subObjectLevel = 0
	delete ep

	-- Edit Poly modifier, vertex / edge / face level (the modifier has Select / GetSelection; SetSelection does not hold)
	local em = awkwardBox "ATtest_EM"
	addModifier em (Edit_Poly())
	select em
	local m = em.modifiers[1]
	modPanel.setCurrentObject m
	subObjectLevel = 1
	max select none
	local pick = #{1}
	m.Select #Vertex pick
	if not (check "Edit Poly vertex: selected verts" ((AlecMid_selectedVerts m em) == #{1})) do failures += 1
	AlecMid_moveVerts m em #{1} mid (AlecMid_Settings())
	if not (check "Edit Poly vertex: moved to the midpoint (world)" (near (AlecMid_vertsCenter m em #{1} false) mid)) do failures += 1
	max select none
	local vertsBefore = #{5}
	m.Select #Vertex vertsBefore
	subObjectLevel = 2
	max select none
	pick = #{1}
	m.Select #Edge pick
	verts = AlecMid_selectedVerts m em
	if not (check "Edit Poly edge: two vertices" (verts.numberSet == 2)) do failures += 1
	if not (check "Edit Poly edge: the user's vertex selection is not changed" ((m.GetSelection #Vertex) == #{5})) do failures += 1
	AlecMid_moveVerts m em verts mid (AlecMid_Settings())
	if not (check "Edit Poly edge: center on the midpoint (world)" (near (AlecMid_vertsCenter m em verts false) mid)) do failures += 1
	subObjectLevel = 4
	max select none
	pick = #{1}
	m.Select #Face pick
	verts = AlecMid_selectedVerts m em
	if not (check "Edit Poly face: four vertices" (verts.numberSet == 4)) do failures += 1
	AlecMid_moveVerts m em verts mid (AlecMid_Settings())
	if not (check "Edit Poly face: center on the midpoint (world)" (near (AlecMid_vertsCenter m em verts false) mid)) do failures += 1
	if not (check "Edit Poly face: the face selection and level are kept" ((m.GetSelection #Face) == #{1} and subObjectLevel == 4)) do failures += 1
	subObjectLevel = 0
	delete em

	-- not supported at sub-object level: an Editable Mesh gives undefined
	local mesh = convertToMesh (box name:"ATtest_mesh")
	select mesh
	subObjectLevel = 1
	if not (check "Editable Mesh at sub-object level is reported unsupported" ((AlecMid_selectedVerts (modPanel.getCurrentObject()) mesh) == undefined)) do failures += 1
	subObjectLevel = 0
	delete mesh

	-- markers: a dummy at each picked point, the selection untouched, none left after removing
	local keep = box name:"ATtest_keep"
	select keep
	local m1 = AlecMid_addMarker [10,20,30]
	local m2 = AlecMid_addMarker [-5,0,5]
	if not (check "markers: a dummy sits at each picked point" (classOf m1 == Dummy and near m1.pos [10,20,30] and near m2.pos [-5,0,5])) do failures += 1
	if not (check "markers: the selection is not changed" (selection.count == 1 and selection[1] == keep)) do failures += 1
	AlecMid_removeMarkers #(m1, m2)
	if not (check "markers: removing leaves none behind" ((for o in objects where o.name == "AlecMid_marker" collect o).count == 0)) do failures += 1
	delete keep

	-- center of points: average vs bounding box differ for three points
	local pts = #([0,0,0], [0,0,0], [30,60,90])
	if not (check "center: average of the points" (near (AlecMid_center pts false) [10,20,30])) do failures += 1
	if not (check "center: bounding box of the points" (near (AlecMid_center pts true) [15,30,45])) do failures += 1

	-- axes: a switched off axis does not move
	local only = AlecMid_Settings y:false z:false
	if not (check "mask: only X survives" (near (AlecMid_mask [5,6,7] only) [5,0,0])) do failures += 1
	local lockBox = box name:"ATtest_axes" pos:[0,0,0]
	select lockBox
	AlecMid_moveObjects [10,20,30] (AlecMid_Settings z:false)
	if not (check "objects: Z switched off keeps Z" (near lockBox.pos [10,20,0])) do failures += 1
	delete lockBox

	-- caddy preview: a red frozen dummy at the landing point, nothing moves until accept
	local pv = box name:"ATtest_preview" pos:[0,0,0]
	select pv
	local sess = AlecMid_Session settings:(AlecMid_Settings()) points:#([30,40,50])
	AlecMid_active = sess
	AlecMid_updatePreview sess
	if not (check "preview: a dummy sits at the landing point, the object has not moved" (isValidNode sess.preview and near sess.preview.pos [30,40,50] and near pv.pos [0,0,0])) do failures += 1
	if not (check "preview: the dummy is red and frozen, and not drawn gray" (sess.preview.wireColor == red and sess.preview.isFrozen and not sess.preview.showFrozenInGray)) do failures += 1
	sess.settings.z = false
	AlecMid_updatePreview sess
	if not (check "preview: the dummy follows a setting (Z off)" (near sess.preview.pos [30,40,0])) do failures += 1
	sess.points = #()
	AlecMid_updatePreview sess
	if not (check "preview: no points, no dummy" (sess.preview == undefined and (for o in objects where o.name == "AlecMid_preview" collect o).count == 0)) do failures += 1
	sess.points = #([30,40,50])
	AlecMid_updatePreview sess
	AlecMid_end()
	if not (check "preview: ending removes the dummy and the session" (AlecMid_active == undefined and (for o in objects where o.name == "AlecMid_preview" collect o).count == 0 and near pv.pos [0,0,0])) do failures += 1
	AlecMid_updatePreview sess
	if not (check "preview: an ended session does not bring the dummy back (a picking that was still running)" (sess.ended and sess.preview == undefined and (for o in objects where o.name == "AlecMid_preview" collect o).count == 0)) do failures += 1
	sess = AlecMid_Session settings:(AlecMid_Settings()) points:#([30,40,50])
	AlecMid_active = sess
	AlecMid_updatePreview sess
	AlecMid_accept()
	if not (check "preview: accept moves the object and removes the dummy" (near pv.pos [30,40,50] and AlecMid_active == undefined and (for o in objects where o.name == "AlecMid_preview" collect o).count == 0)) do failures += 1
	delete pv

	local pe = convertToPoly (awkwardBox "ATtest_previewEP")
	select pe
	subObjectLevel = 1
	polyop.setVertSelection pe #{1}
	sess = AlecMid_Session settings:(AlecMid_Settings()) points:#([0,0,0]) cur:pe node:pe verts:#{1}
	AlecMid_active = sess
	AlecMid_updatePreview sess
	if not (check "preview: Editable Poly vertex, dummy at the landing point, vertex has not moved" (near sess.preview.pos [0,0,0] and not (near pe.verts[1].pos [0,0,0]))) do failures += 1
	AlecMid_accept()
	if not (check "preview: Editable Poly vertex moves on accept" (near pe.verts[1].pos [0,0,0])) do failures += 1
	subObjectLevel = 0
	delete pe

	local pm = awkwardBox "ATtest_previewEM"
	addModifier pm (Edit_Poly())
	select pm
	local mod1 = pm.modifiers[1]
	modPanel.setCurrentObject mod1
	subObjectLevel = 1
	max select none
	local one = #{1}
	mod1.Select #Vertex one
	sess = AlecMid_Session settings:(AlecMid_Settings()) points:#([0,0,0]) cur:mod1 node:pm verts:#{1}
	AlecMid_active = sess
	AlecMid_updatePreview sess
	if not (check "preview: Edit Poly vertex, dummy at the landing point, vertex has not moved" (near sess.preview.pos [0,0,0] and not (near (mod1.GetVertex 1 node:pm) [0,0,0]))) do failures += 1
	AlecMid_accept()
	if not (check "preview: Edit Poly vertex moves on accept" (near (mod1.GetVertex 1 node:pm) [0,0,0])) do failures += 1
	subObjectLevel = 0
	delete pm

	-- caddy position: remembered in the ini, always pulled back inside the work area; the user's own saved position is restored afterwards
	local screenClass = dotNetClass "System.Windows.Forms.Screen"
	local area = screenClass.PrimaryScreen.WorkingArea
	local ini = AlecTools_iniFile()
	local keepX = getINISetting ini "MidBetween" "dialogX"
	local keepY = getINISetting ini "MidBetween" "dialogY"
	local inside = true
	for c in #([area.Left, area.Top], [area.Right - 1, area.Bottom - 1], [area.Right - 1, area.Top], [area.Left, area.Bottom - 1], [area.Left + 400, area.Top + 300], [-9000, -9000], [90000, 90000]) do
	(
		local p = AlecTools_clampToScreen c 260 220
		local a = (screenClass.FromPoint (dotNetObject "System.Drawing.Point" p.x p.y)).WorkingArea
		if p.x < a.Left or p.y < a.Top or p.x + 260 > a.Right or p.y + 220 > a.Bottom do inside = false
	)
	if not (check "dialog position: clamped into a work area for corners, middle and far off-screen points" inside) do failures += 1
	AlecTools_saveDialogPos "MidBetween" [area.Left + 123, area.Top + 45]
	local back = (AlecTools_loadDialogPos "MidBetween")
	if not (check "dialog position: saved and read back" (back != undefined and back.x == area.Left + 123 and back.y == area.Top + 45)) do failures += 1
	if not (check "dialog position: a saved position inside the screen is used as it is" (near (AlecTools_dialogPos "MidBetween" 260 220) back)) do failures += 1
	AlecTools_saveDialogPos "MidBetween" [-9000, -9000]
	local pulled = AlecTools_dialogPos "MidBetween" 260 220
	if not (check "dialog position: a saved position off every screen is pulled back" (pulled.x > -9000 and pulled.y > -9000)) do failures += 1
	setINISetting ini "MidBetween" "dialogX" ""
	setINISetting ini "MidBetween" "dialogY" ""
	local first = AlecTools_dialogPos "MidBetween" 260 220
	local firstArea = (screenClass.FromPoint (dotNetObject "System.Drawing.Point" first.x first.y)).WorkingArea
	if not (check "dialog position: with nothing saved it still lands inside a work area" ((AlecTools_loadDialogPos "MidBetween") == undefined and first.x >= firstArea.Left and first.y >= firstArea.Top and first.x + 260 <= firstArea.Right and first.y + 220 <= firstArea.Bottom)) do failures += 1
	setINISetting ini "MidBetween" "dialogX" keepX
	setINISetting ini "MidBetween" "dialogY" keepY

	-- the whole run with no point given: a timer ends the picking like a right click, so no click is needed
	-- (global because the timer handler cannot see the locals of this block)
	global AT_timer = dotNetObject "System.Windows.Forms.Timer"
	AT_timer.interval = 500
	dotnet.addEventHandler AT_timer "Tick" (fn AT_onTick s e = (max select))
	local runBox = box name:"ATtest_run" pos:[7,8,9]
	select runBox
	AT_timer.start()
	AlecMid_run (AlecMid_Settings()) false
	AlecMid_run (AlecMid_Settings()) true
	AT_timer.stop()
	if not (check "run: no points ends the command, in both modes, with nothing moved or left behind" (AlecMid_active == undefined and near runBox.pos [7,8,9] and (for o in objects where o.name == "AlecMid_preview" collect o).count == 0)) do failures += 1
	if not (check "run: the caddy is closed after a run without points" (not AlecMid_rollout.open)) do failures += 1

	-- picking again clears the points and the dummy first; a picking that gives nothing leaves them cleared, and accept then moves nothing
	local again = AlecMid_Session settings:(AlecMid_Settings()) points:#([30,40,50])
	AlecMid_active = again
	AlecMid_updatePreview again
	AT_timer.start()
	AlecMid_collectPoints again
	AT_timer.stop()
	if not (check "repick: the old points and the dummy are gone" (again.points.count == 0 and again.preview == undefined and (for o in objects where o.name == "AlecMid_preview" collect o).count == 0)) do failures += 1
	AlecMid_accept()
	if not (check "repick: accept without points moves nothing" (near runBox.pos [7,8,9] and AlecMid_active == undefined)) do failures += 1
	delete runBox

	format "midBetween_test: % failure(s)\n" failures
)
