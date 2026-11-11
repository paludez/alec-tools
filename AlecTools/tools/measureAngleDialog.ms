-- Measure Angle, advanced: what the caddy (Shift + click on the button, or a toolbar right click) starts. Needs tools/measureAngle.ms loaded.
-- Edges: hover any object, its nearest real edge (not a hidden diagonal) lights up, a click takes it; 2 edges, from any objects.
-- Faces: hover, the face lights up, a click takes it; 2 faces, the angle between the faces (not their normals) on the side of each click.
-- A third click starts a new measure. Plane: 3D, World XY / XZ / YZ, through 3 clicked points, or the plane of a clicked face;
-- with a plane, edges are projected on it and faces are cut by it, so the angle is the one seen looking straight at that plane.
-- Ctrl switches the plane on and off. Right click ends and closes the caddy.

-- where two surfaces meet (#(pos, normal) each): the line where their planes cross, and on it the foot of each clicked point;
-- each foot-to-point arm lies in its face, square to that line, so the angle between the arms is the angle between the faces,
-- the side each point was clicked on. Gives #(foot a, foot b, angle), or undefined when the planes are parallel or a point is on that line
fn AlecMeasureAngle_surfaceCorner a b =
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
		else #(footA, footB, AlecMeasureAngle_between (a[1] - footA) (b[1] - footB))
	)
)

-- a face (#(pos, normal)) cut by the plane of the normal through p: the point moved onto that plane and the normal's part in it,
-- or undefined when the face is parallel to the plane
fn AlecMeasureAngle_cutFace face p normal =
(
	local n = normalize normal
	local inPlane = face[2] - n * (dot face[2] n)
	if length inPlane < 0.0001 then undefined
	else #(face[1] - n * (dot (face[1] - p) n), normalize inPlane)
)

-- the overlay of 2 faces (#(pos, normal) each), cut by the plane of the normal when there is one: an arm from each point to where
-- the faces meet, that meeting line between the two feet, and the angle written on it
fn AlecMeasureAngle_facesOverlay faces normal =
(
	local ov = AlecTools_Overlay()
	if faces.count == 2 do
	(
		local a = faces[1]
		local b = faces[2]
		if normal != undefined do
		(
			a = AlecMeasureAngle_cutFace a faces[1][1] normal
			b = AlecMeasureAngle_cutFace b faces[1][1] normal
		)
		local c = if a == undefined or b == undefined then undefined else AlecMeasureAngle_surfaceCorner a b
		if c == undefined then append ov.labels #((faces[1][1] + faces[2][1]) / 2, "parallel")
		else
		(
			append ov.lines #(a[1], c[1])
			append ov.lines #(b[1], c[2])
			if distance c[1] c[2] > 0.01 do append ov.lines #(c[1], c[2])
			append ov.labels #((c[1] + c[2]) / 2, AlecMeasureAngle_format c[3])
		)
	)
	ov
)

-- the object under the mouse with its world mesh and a ray grid on it. The last 2 objects are kept, #(node, mesh, grid) each,
-- most recent first, so moving between the 2 objects of a measure does not snapshot and grid them again
global AlecMeasureAngle_pickCache = #()
global AlecMeasureAngle_pickMesh = undefined
global AlecMeasureAngle_pickGrid = undefined

fn AlecMeasureAngle_freeEntry e =
(
	e[3].free()
	delete e[2]
)

fn AlecMeasureAngle_freePick =
(
	for e in AlecMeasureAngle_pickCache do AlecMeasureAngle_freeEntry e
	AlecMeasureAngle_pickCache = #()
	AlecMeasureAngle_pickMesh = undefined
	AlecMeasureAngle_pickGrid = undefined
)

fn AlecMeasureAngle_usePick node =
(
	local k = 0
	for i = 1 to AlecMeasureAngle_pickCache.count where AlecMeasureAngle_pickCache[i][1] == node do k = i
	local e
	if k > 0 then
	(
		e = AlecMeasureAngle_pickCache[k]
		deleteItem AlecMeasureAngle_pickCache k
	)
	else
	(
		local grid = RayMeshGridIntersect()
		grid.Initialize 10
		grid.addNode node
		grid.buildGrid()
		e = #(node, snapshotAsMesh node, grid)
		if AlecMeasureAngle_pickCache.count == 2 do
		(
			AlecMeasureAngle_freeEntry AlecMeasureAngle_pickCache[2]
			deleteItem AlecMeasureAngle_pickCache 2
		)
	)
	insertItem e AlecMeasureAngle_pickCache 1
	AlecMeasureAngle_pickMesh = e[2]
	AlecMeasureAngle_pickGrid = e[3]
)

-- the face under a screen point as #(hit pos, face index in AlecMeasureAngle_pickMesh), or undefined
fn AlecMeasureAngle_faceAt screenPoint =
(
	local hit = AlecTools_surfaceAt screenPoint
	if hit == undefined then undefined
	else
	(
		AlecMeasureAngle_usePick hit[1]
		local r = mapScreenToWorldRay screenPoint
		if (AlecMeasureAngle_pickGrid.intersectRay r.pos r.dir false) == 0 then undefined
		else #(hit[2].pos, AlecMeasureAngle_pickGrid.getHitFace (AlecMeasureAngle_pickGrid.getClosestHit()))
	)
)

-- the edges of a mesh triangle as #(a, b) each, world space; only the real ones (not hidden diagonals) when realOnly
fn AlecMeasureAngle_triangleEdges m face realOnly:false =
(
	local fv = getFace m face
	local v = #(getVert m fv.x, getVert m fv.y, getVert m fv.z)
	for i = 1 to 3 where not realOnly or getEdgeVis m face i collect #(v[i], v[(mod i 3) + 1])
)

-- the real edges (not the hidden diagonals) of the whole polygon a mesh triangle is part of, as #(a, b) each, world space;
-- the triangle's 3 edges when none is real. The nearest real edge to the mouse may lie on another triangle of that polygon
fn AlecMeasureAngle_faceEdges m face =
(
	local edges = #()
	for f in meshop.getPolysUsingFace m #{face} do join edges (AlecMeasureAngle_triangleEdges m f realOnly:true)
	if edges.count == 0 then AlecMeasureAngle_triangleEdges m face else edges
)

fn AlecMeasureAngle_segmentDistance p a b =
(
	local ab = b - a
	local t = amax 0.0 (amin 1.0 ((dot (p - a) ab) / (dot ab ab)))
	distance p (a + ab * t)
)

-- what is under a screen point for the mode (#edges or #faces): #(item, highlight lines), or undefined;
-- an edge item is #(a, b), the real edge nearest to the mouse; a face item is #(pos, normal)
fn AlecMeasureAngle_hoverAt screenPoint mode =
(
	local f = AlecMeasureAngle_faceAt screenPoint
	if f == undefined then undefined
	else
	(
		local edges = AlecMeasureAngle_faceEdges AlecMeasureAngle_pickMesh f[2]
		if mode == #faces then #(#(f[1], getFaceNormal AlecMeasureAngle_pickMesh f[2]), edges)
		else
		(
			local best = edges[1]
			for e in edges where (AlecMeasureAngle_segmentDistance f[1] e[1] e[2]) < (AlecMeasureAngle_segmentDistance f[1] best[1] best[2]) do best = e
			#(best, #(best))
		)
	)
)

-- state of the pick command: #edges or #faces, the picked items and what is under the mouse (as AlecMeasureAngle_hoverAt gives it)
global AlecMeasureAngle_mode = #edges
global AlecMeasureAngle_picked = #()
global AlecMeasureAngle_hover = undefined

fn AlecMeasureAngle_pickOverlay =
(
	local items = for i in AlecMeasureAngle_picked collect i
	if items.count < 2 and AlecMeasureAngle_hover != undefined do append items AlecMeasureAngle_hover[1]
	local normal = if AlecMeasureAngle_flat then AlecMeasureAngle_normal else undefined
	local ov = if AlecMeasureAngle_mode == #faces then AlecMeasureAngle_facesOverlay items normal
	else
	(
		local points = #()
		for e in items do join points e
		AlecMeasureAngle_linesOverlay (if normal != undefined and points.count > 0 then AlecMeasureAngle_project points normal else points)
	)
	if AlecMeasureAngle_hover != undefined do join ov.lines AlecMeasureAngle_hover[2]
	ov
)

fn AlecMeasureAngle_pickPrompt =
(
	local what = if AlecMeasureAngle_mode == #faces then "face" else "edge"
	local n = AlecMeasureAngle_picked.count
	(if n < 2 then "Measure Angle: click " + what + " " + ((n + 1) as string) + " of 2" else "Measure Angle: click = new measure") + AlecMeasureAngle_promptTail()
)

fn AlecMeasureAngle_pickShow =
(
	AlecMeasureAngle_overlay = AlecMeasureAngle_pickOverlay()
	AlecMeasureAngle_showResult()
	replacePrompt (AlecMeasureAngle_pickPrompt())
	redrawViews()
)

fn AlecMeasureAngle_pickToggle =
(
	AlecMeasureAngle_flat = not AlecMeasureAngle_flat
	AlecMeasureAngle_pickShow()
)

tool AlecMeasureAngle_pickTool
(
	fn track =
	(
		AlecTools_ctrlSeen()
		if AlecTools_hoverMoved viewPoint and not (AlecTools_overCaddy()) do
		(
			AlecMeasureAngle_hover = AlecMeasureAngle_hoverAt viewPoint AlecMeasureAngle_mode
			AlecMeasureAngle_pickShow()
		)
	)

	on start do
	(
		AlecMeasureAngle_picked = #()
		AlecMeasureAngle_hover = undefined
		AlecMeasureAngle_overlay = AlecTools_Overlay()
		AlecTools_beginOverlayTool AlecMeasureAngle_draw AlecMeasureAngle_pickToggle
	)
	on freeMove do track()
	on mouseMove clickno do track()
	-- the first click comes twice, on press (1) and on release (2): the release is skipped
	on mousePoint clickno do if clickno != 2 do
	(
		local c = AlecMeasureAngle_caddyClick()
		if c != undefined then c
		else
		(
			local h = AlecMeasureAngle_hoverAt viewPoint AlecMeasureAngle_mode
			if h != undefined do
			(
				if AlecMeasureAngle_picked.count == 2 do AlecMeasureAngle_picked = #()
				append AlecMeasureAngle_picked h[1]
			)
			AlecMeasureAngle_hover = h
			AlecMeasureAngle_pickShow()
		)
	)
	on stop do
	(
		AlecMeasureAngle_overlay = undefined
		AlecMeasureAngle_freePick()
		AlecTools_endOverlayTool()
		AlecMeasureAngle_ended()
	)
)

-- the plane picked by AlecMeasureAngle_planeTool: #points (3 clicks with snaps) or #face (a click on a face); its normal, or undefined
global AlecMeasureAngle_planeBy = #points
global AlecMeasureAngle_planePoints = #()
global AlecMeasureAngle_planeNormal = undefined

tool AlecMeasureAngle_planeTool
(
	fn track =
	(
		local ov = AlecTools_Overlay()
		if AlecMeasureAngle_planeBy == #face then
		(
			local h = AlecMeasureAngle_hoverAt viewPoint #faces
			if h != undefined do ov.lines = h[2]
		)
		else
		(
			local points = for p in AlecMeasureAngle_planePoints collect p
			if points.count > 0 do append points worldPoint
			if points.count >= 2 do ov.lines = for i = 1 to points.count collect #(points[i], points[(mod i points.count) + 1])
		)
		AlecMeasureAngle_overlay = ov
		redrawViews()
	)

	on start do
	(
		AlecMeasureAngle_planePoints = #()
		AlecMeasureAngle_planeNormal = undefined
		AlecMeasureAngle_overlay = AlecTools_Overlay()
		AlecTools_beginOverlayTool AlecMeasureAngle_draw undefined
	)
	on freeMove do track()
	on mouseMove clickno do track()
	on mousePoint clickno do if clickno != 2 do
	(
		local c = AlecMeasureAngle_caddyClick()
		if c != undefined then c
		else if AlecMeasureAngle_planeBy == #face then
		(
			local h = AlecMeasureAngle_hoverAt viewPoint #faces
			if h != undefined do
			(
				AlecMeasureAngle_planeNormal = h[1][2]
				#stop
			)
		)
		else
		(
			append AlecMeasureAngle_planePoints worldPoint
			if AlecMeasureAngle_planePoints.count == 3 do
			(
				local p = AlecMeasureAngle_planePoints
				local n = cross (p[2] - p[1]) (p[3] - p[1])
				if length n > 0.0001 do AlecMeasureAngle_planeNormal = normalize n
				#stop
			)
		)
	)
	on stop do
	(
		AlecMeasureAngle_overlay = undefined
		AlecMeasureAngle_freePick()
		AlecTools_endOverlayTool()
		AlecMeasureAngle_stopAsked = false
	)
)

fn AlecMeasureAngle_pickPlaneTool =
(
	local text = if AlecMeasureAngle_planeBy == #points then "Measure Angle: click 3 points of the plane" else "Measure Angle: click the face of the plane"
	startTool AlecMeasureAngle_planeTool snap:#3D prompt:(text + " | right click = cancel")
)

-- the normal of a plane picked by #points or #face, or undefined when it was cancelled (or the 3 points are on one line)
fn AlecMeasureAngle_pickPlane method =
(
	AlecMeasureAngle_planeBy = method
	AlecTools_withSnaps AlecMeasureAngle_pickPlaneTool on:(method == #points or snapMode.active)
	AlecMeasureAngle_planeNormal
)

fn AlecMeasureAngle_runPick mode normal label flat =
(
	AlecMeasureAngle_mode = mode
	AlecMeasureAngle_normal = normal
	AlecMeasureAngle_planeName = label
	AlecMeasureAngle_flat = flat
	AlecMeasureAngle_picked = #()
	startTool AlecMeasureAngle_pickTool prompt:(AlecMeasureAngle_pickPrompt())
)

-- stops whatever measurement is running (the caddy's options changed, or it closes) by switching to the Select command, which ends a
-- running tool from outside (stopTool did not end it); inside a tool's own click (AlecMeasureAngle_caddyClick) the tool returns #stop instead
fn AlecMeasureAngle_stop =
(
	if AlecMeasureAngle_inClick then AlecMeasureAngle_stopAsked = true
	else
	(
		AlecMeasureAngle_stopping = true
		max select
		AlecMeasureAngle_stopping = false
	)
)

-- the caddy closed: the measurement stops for good
fn AlecMeasureAngle_end =
(
	AlecMeasureAngle_wanted = undefined
	AlecMeasureAngle_stop()
)

-- the caddy starts the measurement (tools/measureAngleCaddy.py): what is 1 Points, 2 Edges, 3 Faces; plane is 1 3D, 2 World XY, 3 World XZ, 4 World YZ, 5 3 points, 6 Pick face
fn AlecMeasureAngle_dialogStart what plane =
(
	local normal = case plane of
	(
		3: [0, 1, 0]
		4: [1, 0, 0]
		5: AlecMeasureAngle_pickPlane #points
		6: AlecMeasureAngle_pickPlane #face
		default: [0, 0, 1]
	)
	if normal == undefined then AlecMeasureAngle_ended()
	else
	(
		local label = #("World XY", "World XY", "World XZ", "World YZ", "3 points plane", "face plane")[plane]
		local flat = plane != 1
		case what of
		(
			1: AlecMeasureAngle_start normal label flat
			2: AlecMeasureAngle_runPick #edges normal label flat
			3: AlecMeasureAngle_runPick #faces normal label flat
		)
	)
)

-- an option changed: the running measurement stops and the loop in AlecMeasureAngle_run starts it again, as if it had been started anew
fn AlecMeasureAngle_restart what plane =
(
	AlecMeasureAngle_wanted = #(what, plane)
	AlecMeasureAngle_stop()
)
