-- Mid Between: the selection (picked first if there is none) moves so its center lands on the middle of some points.
-- Click: pick the points, right click applies. Shift+Click: the same with a caddy (AlecMid_rollout); right click only ends the picking, OK applies, Cancel drops it.
-- A red dummy shows where the center of the selection will land and follows every point and setting; nothing moves until the end.
-- Points: clicked with snaps (Esc cancels) or taken from the pivots of picked objects (right click or Esc ends the picking).
-- Objects: the center of the selection is the average of the pivots, or the center of its bounding box (settings.bounds).
-- Sub-objects (Editable Poly, Edit Poly): the center of the selected vertices; edges and faces count by their vertices.
-- Editable Poly and Edit Poly do not share commands: polyop.* for the first, the modifier's own methods for the second.

-- settings: kept in AlecTools.ini, so the last choice is the next default
struct AlecMid_Settings
(
	bounds = false,       -- the center of what moves: bounding box instead of the average
	targetBounds = false, -- the middle of the points: bounding box of the points instead of their average
	fromObjects = false,  -- points come from the pivots of picked objects instead of clicks
	x = true, y = true, z = true -- axes along which the move happens
)

-- one run of the tool; verts is undefined when whole objects move, preview is the red dummy, ended stops late events of a picking that was still running
struct AlecMid_Session (settings, points = #(), cur, node, verts, preview, ended = false)

global AlecMid_active = undefined

fn AlecMid_readBool key default =
(
	local text = getINISetting (AlecTools_iniFile()) "MidBetween" key
	if text == "" then default else text == "true"
)

fn AlecMid_loadSettings =
(
	AlecMid_Settings bounds:(AlecMid_readBool "bounds" false) targetBounds:(AlecMid_readBool "targetBounds" false) \
		fromObjects:(AlecMid_readBool "fromObjects" false) x:(AlecMid_readBool "x" true) y:(AlecMid_readBool "y" true) z:(AlecMid_readBool "z" true)
)

fn AlecMid_saveSettings s =
(
	local f = AlecTools_iniFile()
	setINISetting f "MidBetween" "bounds" (s.bounds as string)
	setINISetting f "MidBetween" "targetBounds" (s.targetBounds as string)
	setINISetting f "MidBetween" "fromObjects" (s.fromObjects as string)
	setINISetting f "MidBetween" "x" (s.x as string)
	setINISetting f "MidBetween" "y" (s.y as string)
	setINISetting f "MidBetween" "z" (s.z as string)
)

-- points and axes

fn AlecMid_average points =
(
	local sum = [0, 0, 0]
	for p in points do sum += p
	sum / points.count
)

-- the average of the points, or the center of their bounding box
fn AlecMid_center points useBounds =
(
	if not useBounds then AlecMid_average points
	else
	(
		local lo = points[1]
		local hi = points[1]
		for p in points do
		(
			lo = [amin lo.x p.x, amin lo.y p.y, amin lo.z p.z]
			hi = [amax hi.x p.x, amax hi.y p.y, amax hi.z p.z]
		)
		(lo + hi) / 2
	)
)

-- a move with the axes that are switched off zeroed
fn AlecMid_mask delta s =
(
	[if s.x then delta.x else 0, if s.y then delta.y else 0, if s.z then delta.z else 0]
)

-- objects

fn AlecMid_hasSelectedAncestor node =
(
	local p = node.parent
	while p != undefined and not p.isSelected do p = p.parent
	p != undefined
)

-- the center of the selected objects, in world space
fn AlecMid_objectsCenter s =
(
	in coordsys world (if s.bounds then selection.center else AlecMid_average (for o in selection collect o.pos))
)

-- moves the selected objects so their center is at mid; a selected child follows its selected parent, so only the top ones are moved
fn AlecMid_moveObjects mid s =
(
	in coordsys world
	(
		local delta = AlecMid_mask (mid - AlecMid_objectsCenter s) s
		for o in selection where not (AlecMid_hasSelectedAncestor o) do move o delta
	)
)

-- sub-objects

-- the vertices of the current sub-object selection, undefined for an unsupported object
fn AlecMid_selectedVerts cur node =
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
		if level > 1 do cur.ConvertSelection (if level <= 3 then #Edge else #Face) #Vertex
		cur.GetSelection #Vertex
	)
	else undefined
)

fn AlecMid_worldVert cur node v =
(
	if classOf cur == Edit_Poly then cur.GetVertex v node:node else polyop.getVert node v node:node
)

-- a plain loop: "for ... collect" with a function parameter inside raises "Bad free thunk" here
fn AlecMid_vertsCenter cur node verts useBounds =
(
	local points = #()
	for v in verts do append points (AlecMid_worldVert cur node v)
	AlecMid_center points useBounds
)

-- moves the vertices (and with them the edges and faces that were selected) so their center is at mid
fn AlecMid_moveVerts cur node verts mid s =
(
	local delta = AlecMid_mask (mid - AlecMid_vertsCenter cur node verts s.bounds) s
	if classOf cur == Edit_Poly then
	(
		cur.SetOperation #Transform
		cur.MoveSelection delta
		cur.Commit()
	)
	else
		polyop.moveVert node verts delta node:node
)

-- session

-- the session for the current selection and sub-object level, or undefined (with a message) when it cannot be moved
fn AlecMid_newSession s =
(
	local sess = AlecMid_Session settings:s
	if subObjectLevel != undefined and subObjectLevel != 0 do
	(
		sess.node = selection[1]
		sess.cur = modPanel.getCurrentObject()
		sess.verts = AlecMid_selectedVerts sess.cur sess.node
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
fn AlecMid_sessionCenter sess =
(
	if sess.verts == undefined then AlecMid_objectsCenter sess.settings
	else AlecMid_vertsCenter sess.cur sess.node sess.verts sess.settings.bounds
)

-- the move of the session with its current settings and points
fn AlecMid_apply sess =
(
	local mid = AlecMid_center sess.points sess.settings.targetBounds
	if sess.verts == undefined then AlecMid_moveObjects mid sess.settings
	else AlecMid_moveVerts sess.cur sess.node sess.verts mid sess.settings
)

fn AlecMid_removePreview sess =
(
	if sess.preview != undefined and isValidNode sess.preview do with undo off (delete sess.preview)
	sess.preview = undefined
)

-- a red dummy where the center of the selection will land; it is frozen so snaps ignore it, and showFrozenInGray is off or the viewport draws it gray
fn AlecMid_updatePreview sess =
(
	if sess.ended then ok
	else if sess.points.count == 0 then AlecMid_removePreview sess
	else
	(
		local center = AlecMid_sessionCenter sess
		local mid = AlecMid_center sess.points sess.settings.targetBounds
		local landing = center + AlecMid_mask (mid - center) sess.settings
		if sess.preview == undefined or not (isValidNode sess.preview) do
			with undo off (sess.preview = Dummy name:"AlecMid_preview" boxsize:[10, 10, 10] wireColor:red isFrozen:true showFrozenInGray:false)
		with undo off (sess.preview.pos = landing)
	)
	redrawViews()
)

-- ends the command: the dummy goes, and a picking that is still running is stopped by switching to the Select tool (pickPoint and pickObject both return then)
fn AlecMid_end =
(
	if AlecMid_active != undefined do
	(
		AlecMid_active.ended = true
		AlecMid_removePreview AlecMid_active
		AlecMid_active = undefined
		max select
		redrawViews()
	)
)

-- without points (after a picking that gave none) there is nothing to apply
fn AlecMid_accept =
(
	if AlecMid_active.points.count > 0 do undo "Mid Between" on (AlecMid_apply AlecMid_active)
	AlecMid_end()
)

-- picking

-- markers are made and deleted with undo off, so they never end up in the undo step of the move
fn AlecMid_addMarker p =
(
	with undo off (Dummy name:"AlecMid_marker" pos:p boxsize:[6, 6, 6] wireColor:orange)
)

fn AlecMid_removeMarkers markers =
(
	with undo off (delete markers)
)

-- the points the user clicks go into sess.points, one by one with the preview following, until a right click; Esc cancels and leaves it empty
fn AlecMid_pickPoints sess =
(
	local snapWasOn = snapMode.active
	snapMode.active = true
	local markers = #()
	local answer = undefined
	while classOf answer != Name do
	(
		local points = sess.points
		local text = "Mid Between: click point " + ((points.count + 1) as string) + ", right click = done, Esc = cancel"
		answer = if points.count == 0 then pickPoint snap:#3D prompt:text else pickPoint snap:#3D rubberBand:points[points.count] prompt:text
		if classOf answer == Point3 do
		(
			append points answer
			append markers (AlecMid_addMarker answer)
			AlecMid_updatePreview sess
		)
	)
	AlecMid_removeMarkers markers
	snapMode.active = snapWasOn
	if answer == #escape do sess.points = #()
)

-- only objects that are not being moved can give a point
fn AlecMid_notMoving node = not node.isSelected

-- the pivots of the picked objects go into sess.points; pickObject gives undefined for a right click and for Esc alike, so both end the picking
fn AlecMid_pickObjectPoints sess =
(
	local node = undefined
	do
	(
		local text = "Mid Between: pick object " + ((sess.points.count + 1) as string) + ", right click or Esc = done"
		node = pickObject prompt:text filter:AlecMid_notMoving select:false
		if node != undefined do
		(
			append sess.points node.pos
			AlecMid_updatePreview sess
		)
	)
	while node != undefined
)

-- a new picking starts from nothing: the old points and their dummy go first
fn AlecMid_collectPoints sess =
(
	sess.points = #()
	AlecMid_updatePreview sess
	if sess.settings.fromObjects then AlecMid_pickObjectPoints sess else AlecMid_pickPoints sess
)

-- caddy (Shift+Click)

rollout AlecMid_rollout "Mid Between"
(
	radiobuttons rdoSource "Selection center:" labels:#("Average", "Bounding box") columns:2 align:#left
	radiobuttons rdoTarget "Move to:" labels:#("Average", "Bounding box") columns:2 align:#left
	radiobuttons rdoPoints "Points:" labels:#("Snap clicks", "Object pivots") columns:2 align:#left
	label lblAxes "Move on axes:" align:#left across:4
	checkbox chkX "X" checked:true
	checkbox chkY "Y" checked:true
	checkbox chkZ "Z" checked:true
	button btnRepick "Pick other points" width:240
	button btnOk "OK" width:116 across:2
	button btnCancel "Cancel" width:116

	-- reads the controls, saves them and moves the preview
	fn store =
	(
		local s = AlecMid_Settings bounds:(rdoSource.state == 2) targetBounds:(rdoTarget.state == 2) \
			fromObjects:(rdoPoints.state == 2) x:chkX.checked y:chkY.checked z:chkZ.checked
		AlecMid_saveSettings s
		AlecMid_active.settings = s
		AlecMid_updatePreview AlecMid_active
	)

	on AlecMid_rollout open do
	(
		local s = AlecMid_active.settings
		rdoSource.state = if s.bounds then 2 else 1
		rdoTarget.state = if s.targetBounds then 2 else 1
		rdoPoints.state = if s.fromObjects then 2 else 1
		chkX.checked = s.x
		chkY.checked = s.y
		chkZ.checked = s.z
	)
	on rdoSource changed v do store()
	on rdoTarget changed v do store()
	on chkX changed v do store()
	on chkY changed v do store()
	on chkZ changed v do store()
	on rdoPoints changed v do
	(
		store()
		AlecMid_collectPoints AlecMid_active
	)
	on btnRepick pressed do AlecMid_collectPoints AlecMid_active
	on btnOk pressed do
	(
		AlecMid_accept()
		destroyDialog AlecMid_rollout
	)
	on btnCancel pressed do destroyDialog AlecMid_rollout
	on AlecMid_rollout moved p do AlecTools_saveDialogPos "MidBetween" p
	on AlecMid_rollout close do AlecMid_end()
)

-- run

-- with nothing selected, waits in the prompt line for the user to click the object to move (right click or Esc gives up)
fn AlecMid_waitForSelection =
(
	if selection.count == 0 do
		pickObject prompt:"Mid Between: pick the object to move, right click or Esc = cancel" select:true
	selection.count > 0
)

fn AlecMid_run s showCaddy =
(
	if AlecMid_active != undefined do destroyDialog AlecMid_rollout
	if not (AlecMid_waitForSelection()) then
		displayTempPrompt "Mid Between: nothing selected" 3000
	else
	(
		local sess = AlecMid_newSession s
		if sess != undefined do
		(
			AlecMid_active = sess
			if showCaddy do
				createDialog AlecMid_rollout 260 220 pos:(AlecTools_dialogPos "MidBetween" 260 220) style:#(#style_toolwindow, #style_sysmenu)
			AlecMid_collectPoints sess
			if sess.points.count == 0 then
			(
				destroyDialog AlecMid_rollout
				AlecMid_end()
			)
			else if not showCaddy do AlecMid_accept()
		)
	)
)

fn AlecMid_execute showCaddy:false =
(
	AlecMid_run (AlecMid_loadSettings()) showCaddy
)
