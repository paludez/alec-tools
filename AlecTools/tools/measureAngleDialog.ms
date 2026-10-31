-- Measure Angle, advanced: the dialog (Shift + click on the button) and what it starts. Needs tools/measureAngle.ms loaded.
-- Edges: hover any object, its nearest real edge (not a hidden diagonal) lights up, a click takes it; 2 edges, from any objects.
-- Faces: hover, the face lights up, a click takes it; 2 faces, the angle between the faces (not their normals) on the side of each click.
-- A third click starts a new measure. Plane: 3D, World XY / XZ / YZ, through 3 clicked points, or the plane of a clicked face;
-- with a plane, edges are projected on it and faces are cut by it, so the angle is the one seen looking straight at that plane.
-- Ctrl switches the plane on and off, as in the plain command. Right click or Esc ends.

-- where two surfaces meet (#(pos, normal) each): the line where their planes cross, and on it the foot of each clicked point;
-- each foot-to-point arm lies in its face, square to that line, so the angle between the arms is the angle between the faces,
-- the side each point was clicked on. Gives #(foot a, foot b, angle), or undefined when the planes are parallel or a point is on that line
fn AlecAngle_surfaceCorner a b =
(
	local d = cross a[2] b[2]
	local dd = dot d d
	if dd < 1e-9 then undefined
	else
	(
		local p0 = ((dot a[2] a[1]) * (cross b[2] d) + (dot b[2] b[1]) * (cross d a[2])) / dd
		local footA = p0 + d * ((dot (a[1] - p0) d) / dd)
		local footB = p0 + d * ((dot (b[1] - p0) d) / dd)
		if distance a[1] footA < 0.0001 or distance b[1] footB < 0.0001 then undefined
		else #(footA, footB, AlecAngle_between (a[1] - footA) (b[1] - footB))
	)
)

-- a face (#(pos, normal)) cut by the plane of the normal through p: the point moved onto that plane and the normal's part in it,
-- or undefined when the face is parallel to the plane
fn AlecAngle_cutFace face p normal =
(
	local n = normalize normal
	local inPlane = face[2] - n * (dot face[2] n)
	if length inPlane < 0.0001 then undefined
	else #(face[1] - n * (dot (face[1] - p) n), normalize inPlane)
)

-- the overlay of 2 faces (#(pos, normal) each), cut by the plane of the normal when there is one: an arm from each point to where
-- the faces meet, that meeting line between the two feet, and the angle written on it
fn AlecAngle_facesOverlay faces normal =
(
	local ov = AlecTools_Overlay()
	if faces.count == 2 do
	(
		local a = faces[1]
		local b = faces[2]
		if normal != undefined do
		(
			a = AlecAngle_cutFace a faces[1][1] normal
			b = AlecAngle_cutFace b faces[1][1] normal
		)
		local c = if a == undefined or b == undefined then undefined else AlecAngle_surfaceCorner a b
		if c == undefined then append ov.labels #((faces[1][1] + faces[2][1]) / 2, "parallel")
		else
		(
			append ov.lines #(a[1], c[1])
			append ov.lines #(b[1], c[2])
			if distance c[1] c[2] > 0.01 do append ov.lines #(c[1], c[2])
			append ov.labels #((c[1] + c[2]) / 2, AlecAngle_format c[3])
		)
	)
	ov
)

-- the object under the mouse with its world mesh and a ray grid on it, kept while the mouse stays on that object
global AlecAngle_pickNode = undefined
global AlecAngle_pickMesh = undefined
global AlecAngle_pickGrid = undefined

fn AlecAngle_freePick =
(
	if AlecAngle_pickGrid != undefined do AlecAngle_pickGrid.free()
	if AlecAngle_pickMesh != undefined do delete AlecAngle_pickMesh
	AlecAngle_pickNode = undefined
	AlecAngle_pickMesh = undefined
	AlecAngle_pickGrid = undefined
)

fn AlecAngle_usePick node =
(
	if node != AlecAngle_pickNode do
	(
		AlecAngle_freePick()
		AlecAngle_pickNode = node
		AlecAngle_pickMesh = snapshotAsMesh node
		AlecAngle_pickGrid = RayMeshGridIntersect()
		AlecAngle_pickGrid.Initialize 10
		AlecAngle_pickGrid.addNode node
		AlecAngle_pickGrid.buildGrid()
	)
)

-- the face under a screen point as #(hit pos, face index in AlecAngle_pickMesh), or undefined
fn AlecAngle_faceAt screenPoint =
(
	local hit = AlecTools_surfaceAt screenPoint
	if hit == undefined then undefined
	else
	(
		AlecAngle_usePick hit[1]
		local r = mapScreenToWorldRay screenPoint
		if (AlecAngle_pickGrid.intersectRay r.pos r.dir false) == 0 then undefined
		else #(hit[2].pos, AlecAngle_pickGrid.getHitFace (AlecAngle_pickGrid.getClosestHit()))
	)
)

-- the edges of a mesh face as #(a, b) each, world space; only the real ones, all 3 when the face has none
fn AlecAngle_faceEdges m face =
(
	local fv = getFace m face
	local v = #(getVert m fv.x, getVert m fv.y, getVert m fv.z)
	local edges = for i = 1 to 3 where getEdgeVis m face i collect #(v[i], v[(mod i 3) + 1])
	if edges.count == 0 then for i = 1 to 3 collect #(v[i], v[(mod i 3) + 1]) else edges
)

fn AlecAngle_segmentDistance p a b =
(
	local ab = b - a
	local t = amax 0.0 (amin 1.0 ((dot (p - a) ab) / (dot ab ab)))
	distance p (a + ab * t)
)

-- what is under a screen point for the mode (#edges or #faces): #(item, highlight lines), or undefined;
-- an edge item is #(a, b), the real edge nearest to the mouse; a face item is #(pos, normal)
fn AlecAngle_hoverAt screenPoint mode =
(
	local f = AlecAngle_faceAt screenPoint
	if f == undefined then undefined
	else
	(
		local edges = AlecAngle_faceEdges AlecAngle_pickMesh f[2]
		if mode == #faces then #(#(f[1], getFaceNormal AlecAngle_pickMesh f[2]), edges)
		else
		(
			local best = edges[1]
			for e in edges where (AlecAngle_segmentDistance f[1] e[1] e[2]) < (AlecAngle_segmentDistance f[1] best[1] best[2]) do best = e
			#(best, #(best))
		)
	)
)

-- state of the pick command: #edges or #faces, the picked items and what is under the mouse (as AlecAngle_hoverAt gives it)
global AlecAngle_mode = #edges
global AlecAngle_picked = #()
global AlecAngle_hover = undefined

fn AlecAngle_pickOverlay =
(
	local items = for i in AlecAngle_picked collect i
	if items.count < 2 and AlecAngle_hover != undefined do append items AlecAngle_hover[1]
	local normal = if AlecAngle_flat then AlecAngle_normal else undefined
	local ov = if AlecAngle_mode == #faces then AlecAngle_facesOverlay items normal
	else
	(
		local points = #()
		for e in items do join points e
		AlecAngle_linesOverlay (if normal != undefined and points.count > 0 then AlecAngle_project points normal else points)
	)
	if AlecAngle_hover != undefined do join ov.lines AlecAngle_hover[2]
	ov
)

fn AlecAngle_pickShow =
(
	AlecAngle_overlay = AlecAngle_pickOverlay()
	AlecAngle_report AlecAngle_overlay
	local what = if AlecAngle_mode == #faces then "face" else "edge"
	local n = AlecAngle_picked.count
	replacePrompt ((if n < 2 then "Measure Angle: click " + what + " " + ((n + 1) as string) + " of 2" else "Measure Angle: click = new measure") \
		+ AlecAngle_promptTail())
	redrawViews()
)

fn AlecAngle_pickToggle =
(
	AlecAngle_flat = not AlecAngle_flat
	AlecAngle_pickShow()
)

tool AlecAngle_pickTool
(
	fn track =
	(
		AlecAngle_hover = AlecAngle_hoverAt viewPoint AlecAngle_mode
		AlecAngle_pickShow()
	)

	on start do
	(
		AlecAngle_picked = #()
		AlecAngle_hover = undefined
		AlecAngle_overlay = AlecTools_Overlay()
		registerRedrawViewsCallback AlecAngle_draw
		AlecTools_watchCtrl AlecAngle_pickToggle
	)
	on freeMove do track()
	on mouseMove clickno do track()
	-- the first click comes twice, on press (1) and on release (2): the release is skipped
	on mousePoint clickno do if clickno != 2 do
	(
		local h = AlecAngle_hoverAt viewPoint AlecAngle_mode
		if h != undefined do
		(
			if AlecAngle_picked.count == 2 do AlecAngle_picked = #()
			append AlecAngle_picked h[1]
		)
		AlecAngle_hover = h
		AlecAngle_pickShow()
	)
	on stop do
	(
		AlecTools_stopWatchCtrl()
		unregisterRedrawViewsCallback AlecAngle_draw
		AlecAngle_overlay = undefined
		AlecAngle_freePick()
		redrawViews()
	)
)

-- the plane picked by AlecAngle_planeTool: #points (3 clicks with snaps) or #face (a click on a face); its normal, or undefined
global AlecAngle_planeBy = #points
global AlecAngle_planePoints = #()
global AlecAngle_planeNormal = undefined

tool AlecAngle_planeTool
(
	fn track =
	(
		local ov = AlecTools_Overlay()
		if AlecAngle_planeBy == #face then
		(
			local h = AlecAngle_hoverAt viewPoint #faces
			if h != undefined do ov.lines = h[2]
		)
		else
		(
			local points = for p in AlecAngle_planePoints collect p
			if points.count > 0 do append points worldPoint
			if points.count >= 2 do ov.lines = for i = 1 to points.count collect #(points[i], points[(mod i points.count) + 1])
		)
		AlecAngle_overlay = ov
		redrawViews()
	)

	on start do
	(
		AlecAngle_planePoints = #()
		AlecAngle_planeNormal = undefined
		AlecAngle_overlay = AlecTools_Overlay()
		registerRedrawViewsCallback AlecAngle_draw
	)
	on freeMove do track()
	on mouseMove clickno do track()
	on mousePoint clickno do if clickno != 2 do
	(
		if AlecAngle_planeBy == #face then
		(
			local h = AlecAngle_hoverAt viewPoint #faces
			if h != undefined do
			(
				AlecAngle_planeNormal = h[1][2]
				#stop
			)
		)
		else
		(
			append AlecAngle_planePoints worldPoint
			if AlecAngle_planePoints.count == 3 do
			(
				local p = AlecAngle_planePoints
				local n = cross (p[2] - p[1]) (p[3] - p[1])
				if length n > 0.0001 do AlecAngle_planeNormal = normalize n
				#stop
			)
		)
	)
	on stop do
	(
		unregisterRedrawViewsCallback AlecAngle_draw
		AlecAngle_overlay = undefined
		AlecAngle_freePick()
		redrawViews()
	)
)

-- the normal of a plane picked by #points or #face, or undefined when it was cancelled (or the 3 points are on one line)
fn AlecAngle_pickPlane method =
(
	AlecAngle_planeBy = method
	local snapWasOn = snapMode.active
	if method == #points do snapMode.active = true
	local text = if method == #points then "Measure Angle: click 3 points of the plane" else "Measure Angle: click the face of the plane"
	startTool AlecAngle_planeTool snap:#3D prompt:(text + " | right click or Esc = cancel")
	snapMode.active = snapWasOn
	AlecAngle_planeNormal
)

fn AlecAngle_runPick mode normal label flat =
(
	AlecAngle_mode = mode
	AlecAngle_normal = normal
	AlecAngle_planeName = label
	AlecAngle_flat = flat
	startTool AlecAngle_pickTool prompt:("Measure Angle: click " + (if mode == #faces then "face" else "edge") + " 1 of 2" + AlecAngle_promptTail())
)

-- true while Start runs a command from the dialog, so the Esc that ends it does not close the dialog too
global AlecAngle_measuring = false

-- the dialog's Start: what is 1 Points, 2 Edges, 3 Faces; plane is 1 3D, 2 World XY, 3 World XZ, 4 World YZ, 5 3 points, 6 Pick face
fn AlecAngle_dialogStart what plane =
(
	AlecAngle_measuring = true
	local normal = case plane of
	(
		3: [0, 1, 0]
		4: [1, 0, 0]
		5: AlecAngle_pickPlane #points
		6: AlecAngle_pickPlane #face
		default: [0, 0, 1]
	)
	if normal != undefined do
	(
		local label = #("World XY", "World XY", "World XZ", "World YZ", "3 points plane", "face plane")[plane]
		local flat = plane != 1
		case what of
		(
			1: AlecAngle_run normal:normal name:label flat:flat
			2: AlecAngle_runPick #edges normal label flat
			3: AlecAngle_runPick #faces normal label flat
		)
	)
	AlecAngle_measuring = false
)

-- the dialog, as the other Alec Tools dialogs: a tool window where the user left it (the first time the middle of Max), Esc closes it;
-- the last choices are kept in the ini

-- the macro loads this file on every Shift + click: a dialog still open from the last one closes before its rollout is defined again
if AlecAngle_dialog != undefined and AlecAngle_dialog.open do destroyDialog AlecAngle_dialog

rollout AlecAngle_dialog "Measure Angle"
(
	radiobuttons rdoWhat "Measure:" labels:#("Points", "Edges", "Faces") columns:3 align:#left
	radiobuttons rdoPlane "Plane:" labels:#("3D", "World XY", "World XZ", "World YZ", "3 points", "Pick face") columns:3 align:#left
	button btnStart "Start" width:200
	label lblResult "" align:#left width:200
	button btnClose "Close" width:200
	-- Esc does not reach a dialog on its own, so the key is polled; it also works when the viewport has the focus
	timer tmrEsc interval:100

	fn store =
	(
		setINISetting (AlecTools_iniFile()) "MeasureAngle" "what" (rdoWhat.state as string)
		setINISetting (AlecTools_iniFile()) "MeasureAngle" "plane" (rdoPlane.state as string)
	)

	on AlecAngle_dialog open do
	(
		local what = getINISetting (AlecTools_iniFile()) "MeasureAngle" "what"
		local plane = getINISetting (AlecTools_iniFile()) "MeasureAngle" "plane"
		if what != "" do rdoWhat.state = what as integer
		if plane != "" do rdoPlane.state = plane as integer
	)
	on rdoWhat changed v do store()
	on rdoPlane changed v do store()
	on btnStart pressed do AlecAngle_dialogStart rdoWhat.state rdoPlane.state
	on btnClose pressed do destroyDialog AlecAngle_dialog
	on tmrEsc tick do if keyboard.escPressed and not AlecAngle_measuring do destroyDialog AlecAngle_dialog
	on AlecAngle_dialog moved p do AlecTools_saveDialogPos "MeasureAngle" p
)

fn AlecAngle_openDialog =
(
	createDialog AlecAngle_dialog 220 170 pos:(AlecTools_dialogPos "MeasureAngle" 220 170) style:#(#style_toolwindow, #style_sysmenu)
)
