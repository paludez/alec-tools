-- Mid Between: the selection moves so its center lands on the middle of some picked points.
-- Every run opens the caddy (tools/midBetweenCaddy.py) and the picking starts at once; with nothing selected only the hint "Select objects first" shows.
-- Left clicks in a viewport pick: snap points (snaps forced on) or objects, whose pivots are the points (the default).
-- OK or Enter moves and closes; Cancel, a right click or Esc (in a viewport or on the caddy), or the macro's button or shortcut again, cancels and closes.
-- A change on the caddy applies at once and the picking goes on; switching between snap points and object pivots restarts the pick.
-- The picked points are yellow markers of constant screen size, drawn in the viewports (lib/overlay.ms).
-- The selection itself moves live as points are picked and options change (no undo); Enter keeps the move as one undo step, a cancel puts it back.
-- Objects: the center of the selection is the average of the pivots, or the center of its bounding box (settings.bounds).
-- Sub-objects (Editable Poly, Edit Poly): the center of the selected vertices; edges and faces count by their vertices.
-- Editable Poly and Edit Poly do not share commands: polyop.* for the first, the modifier's own methods for the second.

AlecTools_closeCaddy()

-- settings: the last choice is the next default, for this scene (lib/settings.ms)
struct AlecMidBetween_Settings
(
	bounds = false,       -- the center of what moves: bounding box instead of the average
	targetBounds = false, -- the middle of the points: bounding box of the points instead of their average
	fromObjects = true,   -- points come from the pivots of picked objects instead of snap clicks
	x = true, y = true, z = true -- axes along which the move happens
)

-- one run of the tool; verts is undefined when whole objects move. applied is how far the selection has moved from where it started,
-- overlay what the viewports draw. picking is true while a pick waits for a click, so the caddy knows there is a pick to stop;
-- restart asks the loop for a new pick (the kind of pick changed), accepted is set by Enter, ended stops the loop
struct AlecMidBetween_Session (settings, points = #(), cur, node, verts, applied = [0, 0, 0], overlay, picking = false, restart = false, accepted = false, ended = false)

global AlecMidBetween_active = undefined

-- points and axes

-- the average of the points, or the center of their bounding box
fn AlecMidBetween_center points useBounds =
(
	if useBounds then AlecTools_boundsCenter (AlecTools_pointsBounds points) else AlecTools_average points
)

-- a move with the axes that are switched off zeroed
fn AlecMidBetween_mask delta s =
(
	[if s.x then delta.x else 0, if s.y then delta.y else 0, if s.z then delta.z else 0]
)

-- objects

-- the center of the selected objects, in world space; the bounding box is tight on the geometry (selection.center is not on rotated objects)
fn AlecMidBetween_objectsCenter s =
(
	local nodes = selection as array
	if s.bounds then AlecTools_boundsCenter (AlecTools_bounds nodes (matrix3 1))
	else in coordsys world AlecTools_average (for o in nodes collect o.pos)
)

-- moves the selected objects by delta; a selected child follows its selected parent, so only the top ones are moved
fn AlecMidBetween_moveObjects delta =
(
	in coordsys world for o in AlecTools_topLevel (selection as array) do move o delta
)

-- sub-objects

-- the vertices of the current sub-object selection, undefined for an unsupported object
fn AlecMidBetween_selectedVerts cur node =
(
	local level = subObjectLevel
	if classOf cur == Editable_Poly then
	(
		if level == 1 then polyop.getVertSelection node
		else if level <= 3 then polyop.getVertsUsingEdge node (polyop.getEdgeSelection node)
		else polyop.getVertsUsingFace node (polyop.getFaceSelection node)
	)
	else if classOf cur == Edit_Poly then
	(
		-- read through the edges and faces, not ConvertSelection, which would leave the user's vertex selection changed
		if level == 1 then cur.GetSelection #Vertex
		else if level <= 3 then
		(
			local verts = #{}
			for e in cur.GetSelection #Edge do (verts[cur.GetEdgeVertex e 1 node:node] = true; verts[cur.GetEdgeVertex e 2 node:node] = true)
			verts
		)
		else
		(
			local verts = #{}
			for f in cur.GetSelection #Face do for i = 1 to cur.GetFaceDegree f node:node do verts[cur.GetFaceVertex f i node:node] = true
			verts
		)
	)
	else undefined
)

-- the Edit Poly modifier reads (GetVertex) and moves (MoveSelection) along Max's reference coordinate system, even with node:, so it
-- works in World for that time and the user's system is put back after
fn AlecMidBetween_worldVert cur node v =
(
	if classOf cur == Edit_Poly then
	(
		local system = getRefCoordSys()
		setRefCoordSys #world
		local p = cur.GetVertex v node:node
		setRefCoordSys system
		p
	)
	else polyop.getVert node v node:node
)

-- a plain loop: "for ... collect" with a function parameter inside raises "Bad free thunk" here
fn AlecMidBetween_vertsCenter cur node verts useBounds =
(
	local points = #()
	for v in verts do append points (AlecMidBetween_worldVert cur node v)
	AlecMidBetween_center points useBounds
)

-- Edit Poly keeps the move as one pending operation (GetVertex does not show it, the viewport does): each new total replaces the
-- previous one, and only the commit makes it permanent
fn AlecMidBetween_isPending sess = sess.verts != undefined and classOf sess.cur == Edit_Poly

fn AlecMidBetween_pendingMove sess total commit =
(
	local system = getRefCoordSys()
	setRefCoordSys #world
	sess.cur.Cancel()
	if total != [0, 0, 0] do
	(
		sess.cur.SetOperation #Transform
		sess.cur.MoveSelection total
		if commit do sess.cur.Commit()
	)
	setRefCoordSys system
)

-- session

-- the session for the current selection and sub-object level, or undefined (with a message) when it cannot be moved
fn AlecMidBetween_newSession s =
(
	local sess = AlecMidBetween_Session settings:s
	if selection.count > 0 and subObjectLevel != undefined and subObjectLevel != 0 do
	(
		sess.node = selection[1]
		sess.cur = modPanel.getCurrentObject()
		sess.verts = AlecMidBetween_selectedVerts sess.cur sess.node
		if sess.verts == undefined then
		(
			displayTempPrompt "Mid Between: sub-objects only work on Editable Poly or Edit Poly" 3000
			sess = undefined
		)
		else if sess.verts.isEmpty do
		(
			displayTempPrompt "Mid Between: select at least one vertex, edge or face" 3000
			sess = undefined
		)
	)
	sess
)

-- the center of what the session moves, in world space
fn AlecMidBetween_sessionCenter sess =
(
	if sess.verts == undefined then AlecMidBetween_objectsCenter sess.settings
	else AlecMidBetween_vertsCenter sess.cur sess.node sess.verts sess.settings.bounds
)

-- the selection moved by total from where it started (no undo here: Enter records the move)
fn AlecMidBetween_place sess total =
(
	if AlecMidBetween_isPending sess then AlecMidBetween_pendingMove sess total false
	else if sess.verts == undefined then AlecMidBetween_moveObjects (total - sess.applied)
	else polyop.moveVert sess.node sess.verts (total - sess.applied) node:sess.node
	sess.applied = total
)

-- where the selection has to be for the current points and settings, as a move from where it started
fn AlecMidBetween_total sess =
(
	local total = [0, 0, 0]
	if sess.points.count > 0 do
	(
		local center = AlecMidBetween_sessionCenter sess
		if not (AlecMidBetween_isPending sess) do center -= sess.applied
		total = AlecMidBetween_mask ((AlecMidBetween_center sess.points sess.settings.targetBounds) - center) sess.settings
	)
	total
)

-- preview: the selection follows the points, and the points are drawn by the viewports (no scene node, so nothing to snap to or to leave behind)

fn AlecMidBetween_draw =
(
	if AlecMidBetween_active != undefined and AlecMidBetween_active.overlay != undefined do AlecTools_drawOverlay AlecMidBetween_active.overlay
)

fn AlecMidBetween_updatePreview sess =
(
	if not sess.ended do
	(
		sess.overlay = AlecTools_Overlay()
		sess.overlay.points = sess.points
		if selection.count > 0 do with undo off AlecMidBetween_place sess (AlecMidBetween_total sess)
	)
	redrawViews()
)

-- ends the command: the preview goes, the selection goes back unless Enter kept the move, and a pick that is still waiting is
-- stopped by switching to the Select tool (the pick then returns and the loop sees ended)
fn AlecMidBetween_end =
(
	local sess = AlecMidBetween_active
	if sess != undefined do
	(
		sess.ended = true
		AlecMidBetween_active = undefined
		if not sess.accepted do with undo off AlecMidBetween_place sess [0, 0, 0]
		AlecTools_endOverlayTool()
		if sess.picking do max select
	)
)

-- Enter: the move as one undo step (put back, then done again with undo on), then the end; without points nothing moved
fn AlecMidBetween_accept =
(
	local sess = AlecMidBetween_active
	if sess != undefined do
	(
		local total = sess.applied
		if sess.points.count == 0 then displayTempPrompt "Mid Between: no point was picked, nothing moved" 3000
		else
		(
			if not (AlecMidBetween_isPending sess) do with undo off AlecMidBetween_place sess [0, 0, 0]
			undo "Mid Between" on
			(
				if AlecMidBetween_isPending sess then AlecMidBetween_pendingMove sess total true
				else AlecMidBetween_place sess total
			)
			sess.accepted = true
			displayTempPrompt "Mid Between: moved" 3000
		)
		AlecMidBetween_end()
	)
)

-- the waiting pick returns (it stays in the session's loop, which starts a new one with the current settings)
fn AlecMidBetween_pickAgain sess =
(
	if sess.picking do
	(
		sess.restart = true
		max select
	)
)

-- what the caddy (tools/midBetweenCaddy.py) calls

-- new settings: saved for this scene, the preview follows; a switch between snap points and object pivots restarts the pick
fn AlecMidBetween_change bounds targetBounds fromObjects x y z =
(
	local sess = AlecMidBetween_active
	local s = AlecMidBetween_Settings bounds:bounds targetBounds:targetBounds fromObjects:fromObjects x:x y:y z:z
	AlecTools_rememberSettings "MidBetween" s
	local switched = s.fromObjects != sess.settings.fromObjects
	sess.settings = s
	AlecMidBetween_updatePreview sess
	if switched do AlecMidBetween_pickAgain sess
)

-- the picked points are dropped; the pick starts again (its rubber band went from the last point)
fn AlecMidBetween_clear =
(
	local sess = AlecMidBetween_active
	sess.points = #()
	AlecMidBetween_updatePreview sess
	AlecMidBetween_pickAgain sess
)

-- picking

-- only objects that are not being moved can give a point
fn AlecMidBetween_notMoving node = not node.isSelected

fn AlecMidBetween_pickPivot sess =
(
	local text = "click object " + ((sess.points.count + 1) as string) + ", its pivot is the point"
	pickObject prompt:("Mid Between: " + text) filter:AlecMidBetween_notMoving select:false
)

fn AlecMidBetween_pickSnapPoint sess =
(
	local points = sess.points
	local text = "click point " + ((points.count + 1) as string) + " (snaps on)"
	if points.count == 0 then pickPoint snap:#3D prompt:("Mid Between: " + text)
	else pickPoint snap:#3D rubberBand:points[points.count] prompt:("Mid Between: " + text)
)

-- one pick, the kind the selection and the settings ask for
fn AlecMidBetween_pick sess =
(
	sess.picking = true
	local answer = if sess.settings.fromObjects then AlecMidBetween_pickPivot sess else AlecMidBetween_pickSnapPoint sess
	sess.picking = false
	answer
)

-- what a pick gave: a Point3 to add, #again (pick again), #cancel, or #ended (the caddy ended the session and stopped the pick).
-- Anything else (a right click, Esc, another Max command that ended the pick) cancels
fn AlecMidBetween_outcome sess answer =
(
	if sess.ended then #ended
	else if sess.restart then
	(
		sess.restart = false
		#again
	)
	else if isValidNode answer then answer.pos
	else if classOf answer == Point3 then answer
	else #cancel
)

-- picks until the session ends: by Enter or a cancel on the caddy (which stop the waiting pick), or a cancel here, which closes the caddy
fn AlecMidBetween_pickLoop =
(
	local sess = AlecMidBetween_active
	while not sess.ended and AlecMidBetween_active == sess do
	(
		local outcome = AlecMidBetween_outcome sess (AlecMidBetween_pick sess)
		if classOf outcome == Point3 then
		(
			append sess.points outcome
			AlecMidBetween_updatePreview sess
		)
		else if outcome == #cancel do
		(
			AlecTools_closeCaddy()
			AlecMidBetween_end()
		)
	)
)

-- run

-- the caddy opens first, then the picking runs until the session ends (the macro returns only then)
fn AlecMidBetween_run =
(
	AlecTools_closeCaddy()
	local sess = if AlecTools_hasSelection() then AlecMidBetween_newSession (AlecTools_recallSettings "MidBetween" (AlecMidBetween_Settings()))
	if sess != undefined do
	(
		AlecMidBetween_active = sess
		AlecTools_beginOverlayTool AlecMidBetween_draw undefined
		python.ExecuteFile (AlecTools_path "tools/midBetweenCaddy.py")
		AlecTools_withSnaps AlecMidBetween_pickLoop
	)
)
