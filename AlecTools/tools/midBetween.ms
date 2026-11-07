-- Mid Between: the selection moves so its center lands on the middle of some picked points.
-- Every run opens the caddy (tools/midBetweenCaddy.py) and the picking starts at once; with nothing selected, the first click picks what moves.
-- Left clicks in a viewport pick: snap points (snaps forced on) or objects, whose pivots are the points (the default).
-- Enter moves and closes; a right click (in a viewport or on the caddy), or the macro's button or shortcut again, cancels and closes.
-- Esc does nothing: it only starts the same pick again (Esc crashed Max).
-- A change on the caddy applies at once and the picking goes on; switching between snap points and object pivots restarts the pick.
-- The preview is drawn in the viewports (lib/overlay.ms): an orange box at each picked point and, in red, the box where the center of
-- the selection lands with a line from where it is now. Nothing moves until Enter, which moves in one undo step.
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

-- one run of the tool; verts is undefined when whole objects move. landing is where the center will land (undefined without points),
-- overlays what the viewports draw. picking is true while a pick waits for a click, so the caddy knows there is a pick to stop;
-- restart asks the loop for a new pick (the kind of pick changed), ended stops the loop
struct AlecMidBetween_Session (settings, points = #(), cur, node, verts, landing, overlays = #(), picking = false, restart = false, ended = false)

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

-- moves the selected objects so their center is at mid; a selected child follows its selected parent, so only the top ones are moved
fn AlecMidBetween_moveObjects mid s =
(
	in coordsys world
	(
		local delta = AlecMidBetween_mask (mid - AlecMidBetween_objectsCenter s) s
		for o in AlecTools_topLevel (selection as array) do move o delta
	)
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

-- moves the vertices (and with them the edges and faces that were selected) so their center is at mid
fn AlecMidBetween_moveVerts cur node verts mid s =
(
	local delta = AlecMidBetween_mask (mid - AlecMidBetween_vertsCenter cur node verts s.bounds) s
	if classOf cur == Edit_Poly then
	(
		local system = getRefCoordSys()
		setRefCoordSys #world
		cur.SetOperation #Transform
		cur.MoveSelection delta
		cur.Commit()
		setRefCoordSys system
	)
	else
		polyop.moveVert node verts delta node:node
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

-- the move of the session with its current settings and points
fn AlecMidBetween_apply sess =
(
	local mid = AlecMidBetween_center sess.points sess.settings.targetBounds
	if sess.verts == undefined then AlecMidBetween_moveObjects mid sess.settings
	else AlecMidBetween_moveVerts sess.cur sess.node sess.verts mid sess.settings
)

-- preview: drawn by the viewports (no scene node, so nothing to snap to, to undo or to leave behind)

fn AlecMidBetween_draw =
(
	if AlecMidBetween_active != undefined do for ov in AlecMidBetween_active.overlays do AlecTools_drawOverlay ov
)

-- an orange box at each picked point; in red the box where the center of what moves lands and a line from where it is now
fn AlecMidBetween_updatePreview sess =
(
	if not sess.ended do
	(
		local picks = AlecTools_Overlay boxColor:orange
		for p in sess.points do AlecTools_addBox picks (p - [3, 3, 3]) (p + [3, 3, 3]) (matrix3 1)
		local landingOv = AlecTools_Overlay boxColor:red lineColor:red
		sess.landing = undefined
		if sess.points.count > 0 and selection.count > 0 do
		(
			local center = AlecMidBetween_sessionCenter sess
			local mid = AlecMidBetween_center sess.points sess.settings.targetBounds
			sess.landing = center + AlecMidBetween_mask (mid - center) sess.settings
			AlecTools_addBox landingOv (sess.landing - [5, 5, 5]) (sess.landing + [5, 5, 5]) (matrix3 1)
			append landingOv.lines #(center, sess.landing)
		)
		sess.overlays = #(picks, landingOv)
	)
	redrawViews()
)

-- ends the command: the preview goes, and a pick that is still waiting is stopped by switching to the Select tool (the pick then
-- returns and the loop sees ended)
fn AlecMidBetween_end =
(
	local sess = AlecMidBetween_active
	if sess != undefined do
	(
		sess.ended = true
		AlecMidBetween_active = undefined
		AlecTools_endOverlayTool()
		if sess.picking do max select
	)
)

-- Enter: the move as one undo step, then the end; without points nothing moves
fn AlecMidBetween_accept =
(
	local sess = AlecMidBetween_active
	if sess != undefined do
	(
		if sess.points.count == 0 then displayTempPrompt "Mid Between: no point was picked, nothing moved" 3000
		else
		(
			undo "Mid Between" on (AlecMidBetween_apply sess)
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

-- the second line of the pick tag
fn AlecMidBetween_hint = "left click = pick, Enter = move, right click = cancel"

fn AlecMidBetween_tag text = AlecTools_showPickTag ("Mid Between: " + text) hint:(AlecMidBetween_hint())

fn AlecMidBetween_pickMover =
(
	AlecMidBetween_tag "click the object to move"
	pickObject prompt:"Mid Between: click the object to move" select:true
)

-- only objects that are not being moved can give a point
fn AlecMidBetween_notMoving node = not node.isSelected

fn AlecMidBetween_pickPivot sess =
(
	local text = "click object " + ((sess.points.count + 1) as string) + ", its pivot is the point"
	AlecMidBetween_tag text
	pickObject prompt:("Mid Between: " + text) filter:AlecMidBetween_notMoving select:false
)

fn AlecMidBetween_pickSnapPoint sess =
(
	local points = sess.points
	local text = "click point " + ((points.count + 1) as string) + " (snaps on)"
	AlecMidBetween_tag text
	if points.count == 0 then pickPoint snap:#3D prompt:("Mid Between: " + text)
	else pickPoint snap:#3D rubberBand:points[points.count] prompt:("Mid Between: " + text)
)

-- one pick, the kind the selection and the settings ask for
fn AlecMidBetween_pick sess =
(
	sess.picking = true
	local answer = if selection.count == 0 then AlecMidBetween_pickMover()
		else if sess.settings.fromObjects then AlecMidBetween_pickPivot sess
		else AlecMidBetween_pickSnapPoint sess
	sess.picking = false
	answer
)

-- what a pick gave: a Point3 to add, #again (pick again), #cancel, or #ended (the caddy ended the session and stopped the pick).
-- Esc picks again, it must not close anything; pickObject gives undefined for a right click and for Esc alike, so escDown (Esc held
-- when it returned) tells them apart. The object to move, picked with select:true, is selected: #again, the points come next.
-- Anything else (a right click, another Max command that ended the pick) cancels
fn AlecMidBetween_outcome sess answer escDown =
(
	if sess.ended then #ended
	else if sess.restart then
	(
		sess.restart = false
		#again
	)
	else if isValidNode answer then (if answer.isSelected then #again else answer.pos)
	else if classOf answer == Point3 then answer
	else if answer == #escape or (answer == undefined and escDown) then #again
	else #cancel
)

-- picks until the session ends: by Enter or a cancel on the caddy (which stop the waiting pick), or a cancel here, which closes the caddy
fn AlecMidBetween_pickLoop =
(
	local sess = AlecMidBetween_active
	local caddy = python.import "AlecTools_caddy"
	while not sess.ended and AlecMidBetween_active == sess do
	(
		local answer = AlecMidBetween_pick sess
		local escDown = caddy.escape_down()
		local outcome = AlecMidBetween_outcome sess answer escDown
		if classOf outcome == Point3 then
		(
			append sess.points outcome
			AlecMidBetween_updatePreview sess
		)
		else if outcome == #cancel then
		(
			AlecTools_closeCaddy()
			AlecMidBetween_end()
		)
		else if escDown do caddy.wait_for_escape_up()
	)
)

fn AlecMidBetween_pickWithSnaps = AlecTools_withSnaps AlecMidBetween_pickLoop

-- run

-- the caddy opens first, then the picking runs until the session ends (the macro returns only then)
fn AlecMidBetween_run =
(
	AlecTools_closeCaddy()
	local sess = AlecMidBetween_newSession (AlecTools_recallSettings "MidBetween" (AlecMidBetween_Settings()))
	if sess != undefined do
	(
		AlecMidBetween_active = sess
		AlecTools_beginOverlayTool AlecMidBetween_draw undefined
		python.ExecuteFile (AlecTools_path "tools/midBetweenCaddy.py")
		AlecTools_withPickTag "Mid Between" AlecMidBetween_pickWithSnaps hint:(AlecMidBetween_hint())
	)
)
