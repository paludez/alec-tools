-- Measure Gap: the free space between the bounding boxes of two objects, live.
-- Click an object to make it the reference; moving over another one shows both boxes, the shortest line between them and its length,
-- and, when the boxes are apart on more than one axis, that line split into its X, Y and Z legs with their lengths.
-- A click on another object makes it the new reference. Boxes that overlap on every axis are written as "overlap".
-- Axes: the world, or the reference object's own (rotation without scale); Ctrl switches. Boxes are tight on the evaluated geometry.
-- A member of a closed group stands for its whole group. Right click or Esc ends the command and the viewports are cleared.

global AlecMeasureGap_overlay = undefined

fn AlecMeasureGap_draw = if AlecMeasureGap_overlay != undefined do AlecTools_drawOverlay AlecMeasureGap_overlay

-- the frame the boxes are measured in: the world, or the axes of the reference
fn AlecMeasureGap_frame ref world = if world then matrix3 1 else AlecTools_localFrame ref

-- the closest points of two boxes #(lo, hi) on one axis: the facing sides when they are apart, the middle of the shared part when they overlap
fn AlecMeasureGap_axisPair loA hiA loB hiB =
(
	if hiA < loB then #(hiA, loB)
	else if hiB < loA then #(loA, hiB)
	else
	(
		local v = ((amax loA loB) + (amin hiA hiB)) / 2
		#(v, v)
	)
)

-- the closest points of the boxes of a and b, in frame: #(point on a, point on b)
fn AlecMeasureGap_closest a b frame =
(
	local ba = AlecTools_bounds (AlecTools_parts a) frame
	local bb = AlecTools_bounds (AlecTools_parts b) frame
	local x = AlecMeasureGap_axisPair ba[1].x ba[2].x bb[1].x bb[2].x
	local y = AlecMeasureGap_axisPair ba[1].y ba[2].y bb[1].y bb[2].y
	local z = AlecMeasureGap_axisPair ba[1].z ba[2].z bb[1].z bb[2].z
	#([x[1], y[1], z[1]], [x[2], y[2], z[2]])
)

fn AlecMeasureGap_addBox ov node frame =
(
	local b = AlecTools_bounds (AlecTools_parts node) frame
	AlecTools_addBox ov b[1] b[2] frame
)

-- a leg of the gap along one axis, from p to q (in frame), with its length; skipped when it has none
fn AlecMeasureGap_addLeg ov p q frame axisName =
(
	local d = distance p q
	if d > 0.0001 do
	(
		append ov.lines #(p * frame, q * frame)
		append ov.labels #(((p + q) / 2) * frame, axisName + " " + units.formatValue d)
	)
)

-- both boxes, the shortest line between them with its length, and its X, Y, Z legs when it is not along one axis
fn AlecMeasureGap_buildOverlay ref other world =
(
	local ov = AlecTools_Overlay()
	local frame = AlecMeasureGap_frame ref world
	AlecMeasureGap_addBox ov ref frame
	if other != undefined do
	(
		AlecMeasureGap_addBox ov other frame
		local c = AlecMeasureGap_closest ref other frame
		local p = c[1]
		local q = c[2]
		local d = q - p
		local legs = (if abs d.x > 0.0001 then 1 else 0) + (if abs d.y > 0.0001 then 1 else 0) + (if abs d.z > 0.0001 then 1 else 0)
		if legs == 0 then append ov.labels #(p * frame, "overlap")
		else
		(
			append ov.lines #(p * frame, q * frame)
			append ov.labels #(((p + q) / 2) * frame, units.formatValue (length d))
			if legs > 1 do
			(
				local px = [q.x, p.y, p.z]
				local pxy = [q.x, q.y, p.z]
				AlecMeasureGap_addLeg ov p px frame "X"
				AlecMeasureGap_addLeg ov px pxy frame "Y"
				AlecMeasureGap_addLeg ov pxy q frame "Z"
			)
		)
	)
	ov
)

fn AlecMeasureGap_prompt ref other world =
(
	local tail = " | " + (if world then "World" else "Local") + ", Ctrl = World/Local | click = new reference | right click or Esc = end and clear"
	if ref == undefined then "Measure Gap: click the reference object" + tail
	else if other == undefined then "Measure Gap: " + ref.name + " -> move over another object" + tail
	else
	(
		local c = AlecMeasureGap_closest ref other (AlecMeasureGap_frame ref world)
		local d = c[2] - c[1]
		"Measure Gap: " + ref.name + " -> " + other.name + "  " + units.formatValue (length d) + \
			"  (X " + units.formatValue (abs d.x) + "  Y " + units.formatValue (abs d.y) + "  Z " + units.formatValue (abs d.z) + ")" + tail
	)
)

-- state of the running command, global so the Ctrl watcher (lib/ctrlKey.ms) can redraw it too: the reference, the object under the mouse, the axes
global AlecMeasureGap_ref = undefined
global AlecMeasureGap_other = undefined
global AlecMeasureGap_world = true

fn AlecMeasureGap_show =
(
	if AlecMeasureGap_ref != undefined and not (isValidNode AlecMeasureGap_ref) do AlecMeasureGap_ref = undefined
	if AlecMeasureGap_other != undefined and not (isValidNode AlecMeasureGap_other) do AlecMeasureGap_other = undefined
	AlecMeasureGap_overlay = if AlecMeasureGap_ref == undefined then AlecTools_Overlay() else AlecMeasureGap_buildOverlay AlecMeasureGap_ref AlecMeasureGap_other AlecMeasureGap_world
	replacePrompt (AlecMeasureGap_prompt AlecMeasureGap_ref AlecMeasureGap_other AlecMeasureGap_world)
	redrawViews()
)

-- the axes of the scene (World unless Ctrl chose Local before), taken when the command starts
fn AlecMeasureGap_recall = AlecMeasureGap_world = AlecTools_recallSettings "MeasureGap" true

fn AlecMeasureGap_toggleWorld =
(
	AlecMeasureGap_world = not AlecMeasureGap_world
	AlecTools_rememberSettings "MeasureGap" AlecMeasureGap_world
	AlecMeasureGap_show()
)

tool AlecMeasureGap_tool
(
	fn track = if AlecTools_hoverMoved viewPoint do
	(
		local node = AlecTools_objectAt viewPoint
		if node == AlecMeasureGap_ref do node = undefined
		if node != AlecMeasureGap_other do
		(
			AlecMeasureGap_other = node
			AlecMeasureGap_show()
		)
	)

	on start do
	(
		AlecMeasureGap_ref = undefined
		AlecMeasureGap_other = undefined
		AlecMeasureGap_overlay = AlecTools_Overlay()
		AlecTools_beginOverlayTool AlecMeasureGap_draw AlecMeasureGap_toggleWorld
	)
	fn moved =
	(
		AlecTools_ctrlSeen()
		if AlecMeasureGap_ref != undefined do track()
	)
	on freeMove do moved()
	on mouseMove clickno do moved()
	-- the first click comes twice, on press (1) and on release (2): the release is skipped
	on mousePoint clickno do if clickno != 2 do
	(
		local node = AlecTools_objectAt viewPoint
		if node != undefined do
		(
			AlecMeasureGap_ref = node
			AlecMeasureGap_other = undefined
			AlecMeasureGap_show()
		)
	)
	on stop do
	(
		AlecMeasureGap_overlay = undefined
		AlecTools_endOverlayTool()
	)
)

fn AlecMeasureGap_run =
(
	AlecMeasureGap_recall()
	startTool AlecMeasureGap_tool prompt:(AlecMeasureGap_prompt undefined undefined AlecMeasureGap_world)
)
