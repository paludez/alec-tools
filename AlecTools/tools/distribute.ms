-- Distribute: the selected objects are spread along one axis, with equal steps between a reference point of each (Positions)
-- or with equal space between their bounding boxes (Gaps).
-- The button always opens a caddy (AlecDist_rollout). The objects move live as a preview with undo off, every change starts again
-- from where they were; OK moves them again in one undo step, Cancel or Esc puts them back.
-- The step (or gap) starts at the value that keeps the two ends in place; a typed value is used as a fixed step until the mode, axis or reference changes, or Auto.
-- Axes: World, or Local = the axes (rotation without scale) of any object picked for them, or else of the anchor; with neither, Local uses the world.
-- The anchor is picked in the caddy among the objects: it stays in place and the others go on both sides of it; without one the lowest object stays.
-- With an anchor the objects can also be aligned to it on the other two axes, and their rotations blended from the lowest object to the anchor to the highest.
-- While the caddy is open the viewports show a box around every object, a dimension line along the axis and the length of every step or gap (lib/overlay.ms).
-- Sizes come from nodeGetBoundingBox in the frame of the axes, which is tight on the evaluated geometry.
-- A closed group counts as one object and moves through its head; members of an open group count one by one.
-- A child of a selected object follows its parent and is not moved on its own; camera and light targets are skipped.

-- the macro loads this file on every press: a caddy still open from the last press closes first (its objects go back),
-- before its rollout and AlecDist_active are defined again and lose track of it
if AlecDist_rollout != undefined and AlecDist_rollout.open do destroyDialog AlecDist_rollout
-- the drawing callback of an older load is the old function value, so it is removed by that value before the name is defined again
global AlecDist_draw
unregisterRedrawViewsCallback AlecDist_draw

-- settings: the last choice is the next default, for this scene (lib/settings.ms)
struct AlecDist_Settings
(
	gaps = false,       -- equal space between bounding boxes instead of equal steps between reference points
	axis = 1,           -- 1 X, 2 Y, 3 Z
	localAxes = false,  -- the axes of the object picked for them (or of the anchor) instead of the world
	reference = 3,      -- the point that gets the equal steps: 1 Min, 2 Center, 3 Pivot, 4 Max
	alignX = false, alignY = false, alignZ = false, -- align to the anchor on these axes; the one along the distribution is ignored
	alignReference = 3, -- the point matched to the same point of the anchor, as reference
	blend = false,      -- blend the rotations: lowest object > anchor > highest object
	showDims = true     -- draw the boxes, the dimension line and the lengths in the viewports while the caddy is open
)

-- one run of the tool: the objects that move, their transforms before the tool (every preview starts from them), the anchor and the object Local takes its axes from (undefined until picked),
-- the step and the gap in use, autoFill = the step and the gap are worked out from the scene on the next update,
-- order = the objects in the order they were distributed, and dims = what the viewports draw (an AlecTools_Overlay)
struct AlecDist_Session (settings, sources = #(), saved = #(), anchor, axesOf, step = 0.0, gap = 0.0, autoFill = true, order = #(), dims)

global AlecDist_active = undefined

-- what moves

-- a closed group through its head, anything else but group heads and targets as it is
fn AlecDist_isCandidate node =
(
	not (AlecTools_inClosedGroup node) and classOf node != Targetobject and (not (isGroupHead node) or AlecTools_isClosedHead node)
)

fn AlecDist_hasAncestorIn node nodes =
(
	local p = node.parent
	while p != undefined and findItem nodes p == 0 do p = p.parent
	p != undefined
)

-- the objects that move: the candidates of nodes, without those that follow a candidate parent
fn AlecDist_sources nodes =
(
	local candidates = #()
	for n in nodes where AlecDist_isCandidate n do append candidates n
	local sources = #()
	for n in candidates where not (AlecDist_hasAncestorIn n candidates) do append sources n
	sources
)

fn AlecDist_newSession settings sources =
(
	local saved = #()
	for n in sources do append saved n.transform
	AlecDist_Session settings:settings sources:sources saved:saved
)

-- measuring

-- the object whose axes Local takes: the one picked for them, or else the anchor; undefined when neither is picked
fn AlecDist_axesNode sess = if sess.axesOf != undefined then sess.axesOf else sess.anchor

-- the axes the distribution happens in: Local without an object to take them from uses the world
fn AlecDist_frame sess =
(
	local n = AlecDist_axesNode sess
	if sess.settings.localAxes and n != undefined then AlecTools_localFrame n else matrix3 1
)

fn AlecDist_axisDir frame i = case i of (1: frame.row1; 2: frame.row2; default: frame.row3)

-- #(min, max, pivot) of a node in frame; a group with no geometry in it is measured on its head
fn AlecDist_measure node frame =
(
	local parts = AlecTools_parts node
	if parts.count == 0 do parts = #(node)
	local b = AlecTools_bounds parts frame
	#(b[1], b[2], node.transform.row4 * inverse frame)
)

-- the point of a measure: 1 Min, 2 Center, 3 Pivot, 4 Max
fn AlecDist_refPoint m ref = case ref of (1: m[1]; 2: (m[1] + m[2]) / 2; 3: m[3]; default: m[2])

-- items are #(node, value, ...) sorted by value
fn AlecDist_byValue a b = if a[2] < b[2] then -1 else if a[2] > b[2] then 1 else 0

-- where the anchor is among the sorted items, the first one without an anchor
fn AlecDist_anchorIndex items anchor =
(
	local ia = 1
	for k = 1 to items.count where items[k][1] == anchor do ia = k
	ia
)

-- moves every item along the axis so its value becomes targets[k]
fn AlecDist_moveItems items targets frame axis =
(
	local dir = AlecDist_axisDir frame axis
	in coordsys world (for k = 1 to items.count do move items[k][1] (dir * (targets[k] - items[k][2])))
)

-- rotation blend

fn AlecDist_setRotation node q =
(
	local tm = node.transform
	local rotated = (scaleMatrix tm.scalepart) * (q as matrix3)
	rotated.row4 = tm.row4
	node.transform = rotated
)

fn AlecDist_slerpBetween qa qb sa sb s = if sb - sa < 1e-6 then qb else slerp qa qb ((s - sa) / (sb - sa))

-- the objects are sorted along the axis by the value they are distributed by; each one gets the rotation of the lowest object blended into the anchor's,
-- or the anchor's blended into the highest object's, by where it sits between them
fn AlecDist_blendRotations sess frame =
(
	local s = sess.settings
	local items = #()
	for n in sess.sources do
	(
		local m = AlecDist_measure n frame
		append items #(n, (if s.gaps then m[1][s.axis] else (AlecDist_refPoint m s.reference)[s.axis]))
	)
	qsort items AlecDist_byValue
	local ia = AlecDist_anchorIndex items sess.anchor
	local first = items[1]
	local last = items[items.count]
	local sa = items[ia][2]
	local qFirst = first[1].transform.rotation
	local qAnchor = sess.anchor.transform.rotation
	local qLast = last[1].transform.rotation
	for it in items do
		AlecDist_setRotation it[1] (if it[2] <= sa then AlecDist_slerpBetween qFirst qAnchor first[2] sa it[2] else AlecDist_slerpBetween qAnchor qLast sa last[2] it[2])
)

-- distribution

-- the order of the distribution, for the dimensions: after the move two objects can start at the same place and sort either way
fn AlecDist_keepOrder sess items =
(
	sess.order = #()
	for it in items do append sess.order it[1]
)

-- equal steps between the reference points; with autoFill the step that keeps the two ends in place
fn AlecDist_positions sess frame =
(
	local s = sess.settings
	local items = #()
	for n in sess.sources do append items #(n, (AlecDist_refPoint (AlecDist_measure n frame) s.reference)[s.axis])
	qsort items AlecDist_byValue
	local count = items.count
	AlecDist_keepOrder sess items
	if sess.autoFill do sess.step = (items[count][2] - items[1][2]) / (count - 1)
	local ia = AlecDist_anchorIndex items sess.anchor
	local targets = #()
	for k = 1 to count do append targets (items[ia][2] + (k - ia) * sess.step)
	AlecDist_moveItems items targets frame s.axis
)

-- the same space between the bounding boxes, sorted by their min; with autoFill the gap that keeps the two ends in place.
-- A negative gap overlaps them, at most by the width of the thinnest one.
fn AlecDist_gaps sess frame =
(
	local s = sess.settings
	local items = #()
	for n in sess.sources do
	(
		local m = AlecDist_measure n frame
		append items #(n, m[1][s.axis], m[2][s.axis] - m[1][s.axis])
	)
	qsort items AlecDist_byValue
	local count = items.count
	AlecDist_keepOrder sess items
	local widths = 0.0
	local thinnest = items[1][3]
	for it in items do
	(
		widths += it[3]
		thinnest = amin thinnest it[3]
	)
	if sess.autoFill do sess.gap = (items[count][2] + items[count][3] - items[1][2] - widths) / (count - 1)
	sess.gap = amax sess.gap (-thinnest)
	local ia = AlecDist_anchorIndex items sess.anchor
	local targets = #()
	targets[ia] = items[ia][2]
	for k = ia + 1 to count do targets[k] = targets[k - 1] + items[k - 1][3] + sess.gap
	for k = ia - 1 to 1 by -1 do targets[k] = targets[k + 1] - sess.gap - items[k][3]
	AlecDist_moveItems items targets frame s.axis
)

-- every object but the anchor gets its align reference point on the anchor's, on the checked axes other than the one of the distribution
fn AlecDist_alignToAnchor sess frame =
(
	local s = sess.settings
	local checked = #(s.alignX, s.alignY, s.alignZ)
	local target = AlecDist_refPoint (AlecDist_measure sess.anchor frame) s.alignReference
	for n in sess.sources where n != sess.anchor do
	(
		local p = AlecDist_refPoint (AlecDist_measure n frame) s.alignReference
		for i = 1 to 3 where checked[i] and i != s.axis do in coordsys world (move n ((AlecDist_axisDir frame i) * (target[i] - p[i])))
	)
)

-- dimensions: what the viewports draw while the caddy is open

fn AlecDist_withComponent p i v = case i of (1: [v, p.y, p.z]; 2: [p.x, v, p.z]; default: [p.x, p.y, v])

-- a box around every object; the dimension line runs along the axis, past the objects on the next axis and level with their bottom on the last one.
-- Positions: a piece from each reference point to the next, Gaps: a piece across each gap.
fn AlecDist_buildDims sess =
(
	local s = sess.settings
	local frame = AlecDist_frame sess
	local a = s.axis
	local side = #(2, 3, 1)[a]
	local below = #(3, 1, 2)[a]
	local ov = AlecTools_Overlay()
	local measures = #()
	for n in sess.order do append measures (AlecDist_measure n frame)
	for m in measures do AlecTools_addBox ov m[1] m[2] frame
	local corners = #()
	for m in measures do join corners #(m[1], m[2])
	local all = AlecTools_pointsBounds corners
	local lo = all[1]
	local hi = all[2]
	local offset = amax 5.0 (0.1 * (hi[a] - lo[a]))
	local place = AlecDist_withComponent (AlecDist_withComponent [0, 0, 0] side (hi[side] + offset)) below lo[below]
	local tick = (AlecDist_axisDir frame side) * (offset * 0.4)
	-- #(unused, where a piece ends, where the next one starts), in the order of the distribution
	local items = #()
	for m in measures do
	(
		if s.gaps then append items #(0, m[1][a], m[2][a])
		else
		(
			local v = (AlecDist_refPoint m s.reference)[a]
			append items #(0, v, v)
		)
	)
	for k = 1 to items.count - 1 do
	(
		local v1 = items[k][3]
		local v2 = items[k + 1][2]
		AlecTools_addDimension ov ((AlecDist_withComponent place a v1) * frame) ((AlecDist_withComponent place a v2) * frame) tick (v2 - v1)
	)
	sess.dims = ov
)

fn AlecDist_draw = if AlecDist_active != undefined and AlecDist_active.settings.showDims do AlecTools_drawOverlay AlecDist_active.dims

-- session

fn AlecDist_restore sess =
(
	with animate off (for i = 1 to sess.sources.count where isValidNode sess.sources[i] do sess.sources[i].transform = sess.saved[i])
)

-- from where the objects were: blend, distribute, align
fn AlecDist_apply sess =
(
	AlecDist_restore sess
	with animate off
	(
		local frame = AlecDist_frame sess
		local hasAnchor = sess.anchor != undefined
		if hasAnchor and sess.settings.blend do AlecDist_blendRotations sess frame
		if sess.settings.gaps then AlecDist_gaps sess frame else AlecDist_positions sess frame
		if hasAnchor do AlecDist_alignToAnchor sess frame
	)
)

-- objects deleted while the caddy is open leave the session (with their saved transforms); a deleted anchor or axes object is unpicked
fn AlecDist_prune sess =
(
	local keep = for i = 1 to sess.sources.count where isValidNode sess.sources[i] collect i
	sess.saved = for i in keep collect sess.saved[i]
	sess.sources = for i in keep collect sess.sources[i]
	if sess.anchor != undefined and not (isValidNode sess.anchor) do sess.anchor = undefined
	if sess.axesOf != undefined and not (isValidNode sess.axesOf) do sess.axesOf = undefined
	sess.order = for n in sess.order where isValidNode n collect n
)

-- false (and nothing moves) when fewer than 2 objects are left
fn AlecDist_updatePreview sess =
(
	AlecDist_prune sess
	local enough = sess.sources.count >= 2
	if enough do
	(
		with undo off (AlecDist_apply sess)
		AlecDist_buildDims sess
		redrawViews()
	)
	enough
)

fn AlecDist_end =
(
	unregisterRedrawViewsCallback AlecDist_draw
	if AlecDist_active != undefined do
	(
		with undo off (AlecDist_restore AlecDist_active)
		AlecDist_active = undefined
		redrawViews()
	)
)

-- the objects go back and move again in one undo step, so Ctrl+Z puts them all back
fn AlecDist_accept =
(
	unregisterRedrawViewsCallback AlecDist_draw
	local sess = AlecDist_active
	with undo off (AlecDist_restore sess)
	undo "Distribute" on (AlecDist_apply sess)
	AlecDist_active = undefined
	redrawViews()
)

-- caddy

rollout AlecDist_rollout "Distribute"
(
	radiobuttons rdoMode "Mode:" labels:#("Positions (equal steps)", "Gaps (equal space)") columns:2 align:#left
	radiobuttons rdoAxis "Axis:" labels:#("X", "Y", "Z") columns:3 align:#left across:2
	radiobuttons rdoSpace "Axes:" labels:#("World", "Local") columns:2 align:#left
	pickbutton pckAxes "Local axes of: the anchor" width:254 align:#left across:2
	button btnClearAxes "x" width:20 align:#right tooltip:"Back to the axes of the anchor"
	radiobuttons rdoRef "Reference:" labels:#("Min", "Center", "Pivot", "Max") columns:4 align:#left
	spinner spnStep "Step: " range:[0, 1e6, 0] type:#worldunits fieldWidth:60 align:#left across:2
	spinner spnGap "Gap: " range:[-1e6, 1e6, 0] type:#worldunits fieldWidth:60 align:#left
	button btnAuto "Auto: keep the two ends in place" width:280
	fn isSource node = findItem AlecDist_active.sources node > 0
	pickbutton pckAnchor "Anchor: none" width:254 filter:isSource align:#left across:2
	button btnClearAnchor "x" width:20 align:#right tooltip:"No anchor: the lowest object stays in place"
	label lblAlign "Align to anchor on:" align:#left across:4
	checkbox chkX "X" align:#right
	checkbox chkY "Y" align:#right
	checkbox chkZ "Z" align:#right
	radiobuttons rdoAlignRef "Align reference:" labels:#("Min", "Center", "Pivot", "Max") columns:4 align:#left
	checkbox chkBlend "Blend rotations: lowest > anchor > highest" align:#left
	checkbox chkDims "Show dimensions in the viewports" align:#left
	button btnReset "Reset" width:280
	button btnOk "OK" width:136 across:2
	button btnCancel "Cancel" width:136
	-- Esc closes the caddy, also when the viewport has the focus, but not the Esc that cancels a pick (lib/common.ms)
	timer tmrEsc interval:100
	local escWatch = AlecTools_EscWatch()

	-- what applies right now is enabled; the spinners show the step and the gap in use
	fn showState =
	(
		local sess = AlecDist_active
		local s = sess.settings
		local hasAnchor = sess.anchor != undefined
		spnStep.enabled = not s.gaps
		spnGap.enabled = s.gaps
		rdoRef.enabled = not s.gaps
		spnStep.value = sess.step
		spnGap.value = sess.gap
		pckAxes.text = "Local axes of: " + (if sess.axesOf != undefined then sess.axesOf.name else if hasAnchor then "the anchor" else "none (world)")
		pckAxes.enabled = s.localAxes
		btnClearAxes.enabled = s.localAxes and sess.axesOf != undefined
		pckAnchor.text = "Anchor: " + (if hasAnchor then sess.anchor.name else "none")
		btnClearAnchor.enabled = hasAnchor
		lblAlign.enabled = hasAnchor
		chkX.enabled = hasAnchor and s.axis != 1
		chkY.enabled = hasAnchor and s.axis != 2
		chkZ.enabled = hasAnchor and s.axis != 3
		rdoAlignRef.enabled = hasAnchor
		chkBlend.enabled = hasAnchor
	)

	fn update =
	(
		if AlecDist_updatePreview AlecDist_active then showState()
		else
		(
			displayTempPrompt "Distribute: fewer than 2 objects left" 3000
			destroyDialog AlecDist_rollout
		)
	)

	fn fill s =
	(
		rdoMode.state = if s.gaps then 2 else 1
		rdoAxis.state = s.axis
		rdoSpace.state = if s.localAxes then 2 else 1
		rdoRef.state = s.reference
		chkX.checked = s.alignX
		chkY.checked = s.alignY
		chkZ.checked = s.alignZ
		rdoAlignRef.state = s.alignReference
		chkBlend.checked = s.blend
		chkDims.checked = s.showDims
	)

	-- reads the controls, saves them and updates the preview; refill = the step and the gap are worked out again
	fn store refill:false =
	(
		local s = AlecDist_Settings gaps:(rdoMode.state == 2) axis:rdoAxis.state localAxes:(rdoSpace.state == 2) reference:rdoRef.state \
			alignX:chkX.checked alignY:chkY.checked alignZ:chkZ.checked alignReference:rdoAlignRef.state blend:chkBlend.checked showDims:chkDims.checked
		AlecTools_rememberSettings "Distribute" s
		AlecDist_active.settings = s
		if refill do AlecDist_active.autoFill = true
		update()
	)

	-- with Local axes a change of the object they come from changes the axes, so the step and the gap are worked out again
	fn axesChanged oldAxes =
	(
		if AlecDist_active.settings.localAxes and AlecDist_axesNode AlecDist_active != oldAxes do AlecDist_active.autoFill = true
		update()
	)

	fn setAnchor node =
	(
		local oldAxes = AlecDist_axesNode AlecDist_active
		AlecDist_active.anchor = node
		axesChanged oldAxes
	)

	fn setAxesOf node =
	(
		local oldAxes = AlecDist_axesNode AlecDist_active
		AlecDist_active.axesOf = node
		axesChanged oldAxes
	)

	on AlecDist_rollout open do
	(
		fill AlecDist_active.settings
		showState()
	)
	on rdoMode changed v do store refill:true
	on rdoAxis changed v do store refill:true
	on rdoSpace changed v do store refill:true
	on rdoRef changed v do store refill:true
	on chkX changed v do store()
	on chkY changed v do store()
	on chkZ changed v do store()
	on rdoAlignRef changed v do store()
	on chkBlend changed v do store()
	on chkDims changed v do store()
	on spnStep changed v do
	(
		AlecDist_active.step = v
		AlecDist_active.autoFill = false
		update()
	)
	on spnGap changed v do
	(
		AlecDist_active.gap = v
		AlecDist_active.autoFill = false
		update()
	)
	on btnAuto pressed do
	(
		AlecDist_active.autoFill = true
		update()
	)
	on pckAnchor picked node do setAnchor node
	on btnClearAnchor pressed do setAnchor undefined
	on pckAxes picked node do setAxesOf node
	on btnClearAxes pressed do setAxesOf undefined
	on btnReset pressed do
	(
		fill (AlecDist_Settings())
		store refill:true
	)
	on btnOk pressed do
	(
		AlecDist_accept()
		destroyDialog AlecDist_rollout
	)
	on btnCancel pressed do destroyDialog AlecDist_rollout
	on tmrEsc tick do if AlecTools_escPressed escWatch do destroyDialog AlecDist_rollout
	on AlecDist_rollout moved p do AlecTools_saveDialogPos "Distribute" p
	on AlecDist_rollout close do AlecDist_end()
)

-- run

-- a caddy that is already open closes first (its objects go back), then the tool starts again from the current selection
fn AlecDist_run =
(
	if AlecDist_rollout.open do destroyDialog AlecDist_rollout
	local sources = AlecDist_sources (selection as array)
	if sources.count < 2 then
		displayTempPrompt "Distribute: select at least 2 objects" 3000
	else
	(
		AlecDist_active = AlecDist_newSession (AlecTools_recallSettings "Distribute" (AlecDist_Settings())) sources
		AlecDist_updatePreview AlecDist_active
		registerRedrawViewsCallback AlecDist_draw
		AlecTools_openCaddy AlecDist_rollout "Distribute" 300 391
	)
)
