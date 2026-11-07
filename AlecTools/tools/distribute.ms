-- Distribute: the selected objects are spread along one axis, with equal steps between a reference point of each (Positions)
-- or with equal space between their bounding boxes (Gaps).
-- Click: distributes at once with the last settings. Shift + click (or a toolbar right click) opens the caddy (tools/distributeCaddy.py): the objects move live as a preview with undo off, every change starts again
-- from where they were; OK moves them again in one undo step, Cancel puts them back.
-- The step (or gap) starts at the value that keeps the two ends in place; a typed value is used as a fixed step until the mode, axis or reference changes, or Auto.
-- Axes: World, or Local = the axes (rotation without scale) of any object picked for them, or else of the anchor; with neither, Local uses the world.
-- The anchor is picked in the caddy among the objects: it stays in place and the others go on both sides of it; without one the lowest object stays.
-- With an anchor the objects can also be aligned to it on the other two axes, and their rotations blended from the lowest object to the anchor to the highest.
-- While the caddy is open the viewports show a box around every object, a dimension line along the axis and the length of every step or gap (lib/overlay.ms).
-- Sizes come from nodeGetBoundingBox in the frame of the axes, which is tight on the evaluated geometry.
-- A closed group counts as one object and moves through its head; members of an open group count one by one.
-- A child of a selected object follows its parent and is not moved on its own; camera and light targets are skipped.

-- the macro loads this file on every press: a caddy still open from the last press closes first (its objects go back),
-- before AlecDistribute_active is defined again and loses track of it
AlecTools_closeCaddy()

-- settings: the last choice is the next default, for this scene (lib/settings.ms)
struct AlecDistribute_Settings
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
struct AlecDistribute_Session (settings, sources = #(), saved = #(), anchor, axesOf, step = 0.0, gap = 0.0, autoFill = true, order = #(), dims)

global AlecDistribute_active = undefined

-- what moves

-- a closed group through its head, anything else but group heads and targets as it is
fn AlecDistribute_isCandidate node =
(
	not (AlecTools_inClosedGroup node) and classOf node != Targetobject and (not (isGroupHead node) or AlecTools_isClosedHead node)
)

-- the objects that move: the candidates of nodes, without those that follow a candidate parent
fn AlecDistribute_sources nodes =
(
	local candidates = #()
	for n in nodes where AlecDistribute_isCandidate n do append candidates n
	AlecTools_topLevel candidates
)

fn AlecDistribute_newSession settings sources =
(
	local saved = #()
	for n in sources do append saved n.transform
	AlecDistribute_Session settings:settings sources:sources saved:saved
)

-- measuring

-- the object whose axes Local takes: the one picked for them, or else the anchor; undefined when neither is picked
fn AlecDistribute_axesNode sess = if sess.axesOf != undefined then sess.axesOf else sess.anchor

-- the axes the distribution happens in: Local without an object to take them from uses the world
fn AlecDistribute_frame sess =
(
	local n = AlecDistribute_axesNode sess
	if sess.settings.localAxes and n != undefined then AlecTools_localFrame n else matrix3 1
)

fn AlecDistribute_axisDir frame i = case i of (1: frame.row1; 2: frame.row2; default: frame.row3)

-- #(min, max, pivot) of a node in frame; a group with no geometry in it is measured on its head
fn AlecDistribute_measure node frame =
(
	local parts = AlecTools_parts node
	if parts.count == 0 do parts = #(node)
	local b = AlecTools_bounds parts frame
	#(b[1], b[2], node.transform.row4 * inverse frame)
)

-- the point of a measure: 1 Min, 2 Center, 3 Pivot, 4 Max
fn AlecDistribute_refPoint m ref = case ref of (1: m[1]; 2: AlecTools_boundsCenter m; 3: m[3]; default: m[2])

-- items are #(node, value, ...) sorted by value
fn AlecDistribute_byValue a b = if a[2] < b[2] then -1 else if a[2] > b[2] then 1 else 0

-- where the anchor is among the sorted items, the first one without an anchor
fn AlecDistribute_anchorIndex items anchor =
(
	local ia = 1
	for k = 1 to items.count where items[k][1] == anchor do ia = k
	ia
)

-- moves every item along the axis so its value becomes targets[k]
fn AlecDistribute_moveItems items targets frame axis =
(
	local dir = AlecDistribute_axisDir frame axis
	in coordsys world (for k = 1 to items.count do move items[k][1] (dir * (targets[k] - items[k][2])))
)

-- rotation blend

fn AlecDistribute_setRotation node q =
(
	local tm = node.transform
	local rotated = (scaleMatrix tm.scalepart) * (q as matrix3)
	rotated.row4 = tm.row4
	node.transform = rotated
)

fn AlecDistribute_slerpBetween qa qb sa sb s = if sb - sa < 1e-6 then qb else slerp qa qb ((s - sa) / (sb - sa))

-- the objects are sorted along the axis by the value they are distributed by; each one gets the rotation of the lowest object blended into the anchor's,
-- or the anchor's blended into the highest object's, by where it sits between them
fn AlecDistribute_blendRotations sess frame =
(
	local s = sess.settings
	local items = #()
	for n in sess.sources do
	(
		local m = AlecDistribute_measure n frame
		append items #(n, (if s.gaps then m[1][s.axis] else (AlecDistribute_refPoint m s.reference)[s.axis]))
	)
	qsort items AlecDistribute_byValue
	local ia = AlecDistribute_anchorIndex items sess.anchor
	local first = items[1]
	local last = items[items.count]
	local sa = items[ia][2]
	local qFirst = first[1].transform.rotation
	local qAnchor = sess.anchor.transform.rotation
	local qLast = last[1].transform.rotation
	for it in items do
		AlecDistribute_setRotation it[1] (if it[2] <= sa then AlecDistribute_slerpBetween qFirst qAnchor first[2] sa it[2] else AlecDistribute_slerpBetween qAnchor qLast sa last[2] it[2])
)

-- distribution

-- the order of the distribution, for the dimensions: after the move two objects can start at the same place and sort either way
fn AlecDistribute_keepOrder sess items =
(
	sess.order = #()
	for it in items do append sess.order it[1]
)

-- equal steps between the reference points; with autoFill the step that keeps the two ends in place
fn AlecDistribute_positions sess frame =
(
	local s = sess.settings
	local items = #()
	for n in sess.sources do append items #(n, (AlecDistribute_refPoint (AlecDistribute_measure n frame) s.reference)[s.axis])
	qsort items AlecDistribute_byValue
	local count = items.count
	AlecDistribute_keepOrder sess items
	if sess.autoFill do sess.step = (items[count][2] - items[1][2]) / (count - 1)
	local ia = AlecDistribute_anchorIndex items sess.anchor
	local targets = #()
	for k = 1 to count do append targets (items[ia][2] + (k - ia) * sess.step)
	AlecDistribute_moveItems items targets frame s.axis
)

-- the same space between the bounding boxes, sorted by their min; with autoFill the gap that keeps the two ends in place.
-- A negative gap overlaps them, at most by the width of the thinnest one.
fn AlecDistribute_gaps sess frame =
(
	local s = sess.settings
	local items = #()
	for n in sess.sources do
	(
		local m = AlecDistribute_measure n frame
		append items #(n, m[1][s.axis], m[2][s.axis] - m[1][s.axis])
	)
	qsort items AlecDistribute_byValue
	local count = items.count
	AlecDistribute_keepOrder sess items
	local widths = 0.0
	local thinnest = items[1][3]
	for it in items do
	(
		widths += it[3]
		thinnest = amin thinnest it[3]
	)
	if sess.autoFill do sess.gap = (items[count][2] + items[count][3] - items[1][2] - widths) / (count - 1)
	sess.gap = amax sess.gap (-thinnest)
	local ia = AlecDistribute_anchorIndex items sess.anchor
	local targets = #()
	targets[ia] = items[ia][2]
	for k = ia + 1 to count do targets[k] = targets[k - 1] + items[k - 1][3] + sess.gap
	for k = ia - 1 to 1 by -1 do targets[k] = targets[k + 1] - sess.gap - items[k][3]
	AlecDistribute_moveItems items targets frame s.axis
)

-- every object but the anchor gets its align reference point on the anchor's, on the checked axes other than the one of the distribution
fn AlecDistribute_alignToAnchor sess frame =
(
	local s = sess.settings
	local checked = #(s.alignX, s.alignY, s.alignZ)
	local target = AlecDistribute_refPoint (AlecDistribute_measure sess.anchor frame) s.alignReference
	for n in sess.sources where n != sess.anchor do
	(
		local p = AlecDistribute_refPoint (AlecDistribute_measure n frame) s.alignReference
		for i = 1 to 3 where checked[i] and i != s.axis do in coordsys world (move n ((AlecDistribute_axisDir frame i) * (target[i] - p[i])))
	)
)

-- dimensions: what the viewports draw while the caddy is open

fn AlecDistribute_withComponent p i v = case i of (1: [v, p.y, p.z]; 2: [p.x, v, p.z]; default: [p.x, p.y, v])

-- a box around every object; the dimension line runs along the axis, past the objects on the next axis and level with their bottom on the last one.
-- Positions: a piece from each reference point to the next, Gaps: a piece across each gap.
fn AlecDistribute_buildDims sess =
(
	local s = sess.settings
	local frame = AlecDistribute_frame sess
	local a = s.axis
	local side = #(2, 3, 1)[a]
	local below = #(3, 1, 2)[a]
	local ov = AlecTools_Overlay()
	local measures = #()
	for n in sess.order do append measures (AlecDistribute_measure n frame)
	for m in measures do AlecTools_addBox ov m[1] m[2] frame
	local corners = #()
	for m in measures do join corners #(m[1], m[2])
	local all = AlecTools_pointsBounds corners
	local lo = all[1]
	local hi = all[2]
	local offset = amax 5.0 (0.1 * (hi[a] - lo[a]))
	local place = AlecDistribute_withComponent (AlecDistribute_withComponent [0, 0, 0] side (hi[side] + offset)) below lo[below]
	local tick = (AlecDistribute_axisDir frame side) * (offset * 0.4)
	-- #(unused, where a piece ends, where the next one starts), in the order of the distribution
	local items = #()
	for m in measures do
	(
		if s.gaps then append items #(0, m[1][a], m[2][a])
		else
		(
			local v = (AlecDistribute_refPoint m s.reference)[a]
			append items #(0, v, v)
		)
	)
	for k = 1 to items.count - 1 do
	(
		local v1 = items[k][3]
		local v2 = items[k + 1][2]
		AlecTools_addDimension ov ((AlecDistribute_withComponent place a v1) * frame) ((AlecDistribute_withComponent place a v2) * frame) tick (v2 - v1)
	)
	sess.dims = ov
)

fn AlecDistribute_draw = if AlecDistribute_active != undefined and AlecDistribute_active.settings.showDims do AlecTools_drawOverlay AlecDistribute_active.dims

-- the drawing goes through lib/overlayTool.ms, so a reload ends it; a viewport tool started meanwhile has taken it over and keeps it
fn AlecDistribute_stopDrawing = if AlecTools_toolDraw == AlecDistribute_draw do AlecTools_endOverlayTool()

-- session

fn AlecDistribute_restore sess =
(
	with animate off (for i = 1 to sess.sources.count where isValidNode sess.sources[i] do sess.sources[i].transform = sess.saved[i])
)

-- from where the objects were: blend, distribute, align
fn AlecDistribute_apply sess =
(
	AlecDistribute_restore sess
	with animate off
	(
		local frame = AlecDistribute_frame sess
		local hasAnchor = sess.anchor != undefined
		if hasAnchor and sess.settings.blend do AlecDistribute_blendRotations sess frame
		if sess.settings.gaps then AlecDistribute_gaps sess frame else AlecDistribute_positions sess frame
		if hasAnchor do AlecDistribute_alignToAnchor sess frame
	)
)

-- objects deleted while the caddy is open leave the session (with their saved transforms); a deleted anchor or axes object is unpicked
fn AlecDistribute_prune sess =
(
	local keep = for i = 1 to sess.sources.count where isValidNode sess.sources[i] collect i
	sess.saved = for i in keep collect sess.saved[i]
	sess.sources = for i in keep collect sess.sources[i]
	if sess.anchor != undefined and not (isValidNode sess.anchor) do sess.anchor = undefined
	if sess.axesOf != undefined and not (isValidNode sess.axesOf) do sess.axesOf = undefined
	sess.order = for n in sess.order where isValidNode n collect n
)

-- false (and nothing moves) when fewer than 2 objects are left
fn AlecDistribute_updatePreview sess =
(
	AlecDistribute_prune sess
	local enough = sess.sources.count >= 2
	if enough do
	(
		with undo off (AlecDistribute_apply sess)
		AlecDistribute_buildDims sess
		redrawViews()
	)
	enough
)

fn AlecDistribute_end =
(
	AlecDistribute_stopDrawing()
	if AlecDistribute_active != undefined do
	(
		with undo off (AlecDistribute_restore AlecDistribute_active)
		AlecDistribute_active = undefined
		redrawViews()
	)
)

-- the objects go back and move again in one undo step, so Ctrl+Z puts them all back
fn AlecDistribute_accept =
(
	AlecDistribute_stopDrawing()
	local sess = AlecDistribute_active
	with undo off (AlecDistribute_restore sess)
	undo "Distribute" on (AlecDistribute_apply sess)
	AlecDistribute_active = undefined
	redrawViews()
)

-- what the caddy (tools/distributeCaddy.py) calls. Each change updates the preview and gives false when fewer than 2 objects are left
-- (the caddy then closes)

fn AlecDistribute_isSource node = findItem AlecDistribute_active.sources node > 0

fn AlecDistribute_anchorText = if AlecDistribute_active.anchor != undefined then AlecDistribute_active.anchor.name else "none"

fn AlecDistribute_axesText =
(
	local sess = AlecDistribute_active
	if sess.axesOf != undefined then sess.axesOf.name else if sess.anchor != undefined then "the anchor" else "none (world)"
)

-- new settings: saved for this scene; refill = the step and the gap are worked out again
fn AlecDistribute_change gaps axis localAxes reference alignX alignY alignZ alignReference blend showDims refill:false =
(
	local s = AlecDistribute_Settings gaps:gaps axis:axis localAxes:localAxes reference:reference \
		alignX:alignX alignY:alignY alignZ:alignZ alignReference:alignReference blend:blend showDims:showDims
	AlecTools_rememberSettings "Distribute" s
	AlecDistribute_active.settings = s
	if refill do AlecDistribute_active.autoFill = true
	AlecDistribute_updatePreview AlecDistribute_active
)

-- a typed step or gap is used as it is until Auto
fn AlecDistribute_setStep v =
(
	AlecDistribute_active.step = v
	AlecDistribute_active.autoFill = false
	AlecDistribute_updatePreview AlecDistribute_active
)

fn AlecDistribute_setGap v =
(
	AlecDistribute_active.gap = v
	AlecDistribute_active.autoFill = false
	AlecDistribute_updatePreview AlecDistribute_active
)

fn AlecDistribute_auto =
(
	AlecDistribute_active.autoFill = true
	AlecDistribute_updatePreview AlecDistribute_active
)

-- with Local axes a change of the object they come from changes the axes, so the step and the gap are worked out again
fn AlecDistribute_axesChanged oldAxes =
(
	if AlecDistribute_active.settings.localAxes and AlecDistribute_axesNode AlecDistribute_active != oldAxes do AlecDistribute_active.autoFill = true
	AlecDistribute_updatePreview AlecDistribute_active
)

fn AlecDistribute_setAnchor node =
(
	local oldAxes = AlecDistribute_axesNode AlecDistribute_active
	AlecDistribute_active.anchor = node
	AlecDistribute_axesChanged oldAxes
)

fn AlecDistribute_setAxesOf node =
(
	local oldAxes = AlecDistribute_axesNode AlecDistribute_active
	AlecDistribute_active.axesOf = node
	AlecDistribute_axesChanged oldAxes
)

-- picked in the viewport, among the objects (the anchor) or any object (the axes); right click or Esc keeps the one there was
fn AlecDistribute_pickAnchorNode = pickObject prompt:"Distribute: pick the anchor among the objects, right click or Esc = cancel" filter:AlecDistribute_isSource

fn AlecDistribute_pickAxesNode = pickObject prompt:"Distribute: pick the object whose axes Local takes, right click or Esc = cancel"

fn AlecDistribute_pickAnchor =
(
	local node = AlecTools_withPickTag "Distribute: click the anchor object" AlecDistribute_pickAnchorNode
	if isValidNode node then AlecDistribute_setAnchor node else AlecDistribute_updatePreview AlecDistribute_active
)

fn AlecDistribute_pickAxes =
(
	local node = AlecTools_withPickTag "Distribute: click the object whose axes Local takes" AlecDistribute_pickAxesNode
	if isValidNode node then AlecDistribute_setAxesOf node else AlecDistribute_updatePreview AlecDistribute_active
)

-- run

-- without the caddy: the settings last used in it, no anchor, the two ends stay in place; one undo step
fn AlecDistribute_applyDirect sess =
(
	undo "Distribute" on (AlecDistribute_apply sess)
	redrawViews()
	displayTempPrompt ("Distribute: " + sess.sources.count as string + " objects distributed") 3000
)

-- a caddy that is already open closes first (its objects go back), then the tool starts again from the current selection;
-- showCaddy:false distributes at once
fn AlecDistribute_run showCaddy:true =
(
	AlecTools_closeCaddy()
	local sources = AlecDistribute_sources (selection as array)
	if selection.count == 0 then
		displayTempPrompt "Distribute: select something first" 3000
	else if sources.count < 2 then
		displayTempPrompt "Distribute: select at least 2 objects" 3000
	else
	(
		local sess = AlecDistribute_newSession (AlecTools_recallSettings "Distribute" (AlecDistribute_Settings())) sources
		if showCaddy then
		(
			AlecDistribute_active = sess
			AlecDistribute_updatePreview AlecDistribute_active
			AlecTools_beginOverlayTool AlecDistribute_draw undefined
			python.ExecuteFile (AlecTools_path "tools/distributeCaddy.py")
		)
		else AlecDistribute_applyDirect sess
	)
)
