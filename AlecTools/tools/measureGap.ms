-- Measure Gap: the free space between the bounding boxes of two objects, live.
-- Click an object to make it the reference; moving over another one shows both boxes, the shortest line between them and its length,
-- and, when the boxes are apart on more than one axis, that line split into its X, Y and Z legs with their lengths.
-- A click on another object makes it the new reference. Boxes that overlap on every axis are written as "overlap".
-- Axes: the world, or the reference object's own (rotation without scale); Ctrl switches. Boxes are tight on the evaluated geometry.
-- A member of a closed group stands for its whole group. Right click or Esc ends the command and the viewports are cleared.

-- the drawing callback of an older load is the old function value, so it is removed by that value before the name is defined again
global AlecGap_draw
unregisterRedrawViewsCallback AlecGap_draw

global AlecGap_overlay = undefined

fn AlecGap_draw = if AlecGap_overlay != undefined do AlecTools_drawOverlay AlecGap_overlay

-- the frame the boxes are measured in: the world, or the axes of the reference
fn AlecGap_frame ref world = if world then matrix3 1 else AlecTools_localFrame ref

-- the closest points of two boxes #(lo, hi) on one axis: the facing sides when they are apart, the middle of the shared part when they overlap
fn AlecGap_axisPair loA hiA loB hiB =
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
fn AlecGap_closest a b frame =
(
	local ba = AlecTools_bounds (AlecTools_parts a) frame
	local bb = AlecTools_bounds (AlecTools_parts b) frame
	local x = AlecGap_axisPair ba[1].x ba[2].x bb[1].x bb[2].x
	local y = AlecGap_axisPair ba[1].y ba[2].y bb[1].y bb[2].y
	local z = AlecGap_axisPair ba[1].z ba[2].z bb[1].z bb[2].z
	#([x[1], y[1], z[1]], [x[2], y[2], z[2]])
)

fn AlecGap_addBox ov node frame =
(
	local b = AlecTools_bounds (AlecTools_parts node) frame
	AlecTools_addBox ov b[1] b[2] frame
)

-- a leg of the gap along one axis, from p to q (in frame), with its length; skipped when it has none
fn AlecGap_addLeg ov p q frame axisName =
(
	local d = distance p q
	if d > 0.0001 do
	(
		append ov.lines #(p * frame, q * frame)
		append ov.labels #(((p + q) / 2) * frame, axisName + " " + units.formatValue d)
	)
)

-- both boxes, the shortest line between them with its length, and its X, Y, Z legs when it is not along one axis
fn AlecGap_buildOverlay ref other world =
(
	local ov = AlecTools_Overlay()
	local frame = AlecGap_frame ref world
	AlecGap_addBox ov ref frame
	if other != undefined do
	(
		AlecGap_addBox ov other frame
		local c = AlecGap_closest ref other frame
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
				AlecGap_addLeg ov p px frame "X"
				AlecGap_addLeg ov px pxy frame "Y"
				AlecGap_addLeg ov pxy q frame "Z"
			)
		)
	)
	ov
)

fn AlecGap_prompt ref other world =
(
	local tail = " | " + (if world then "World" else "Local") + ", Ctrl = World/Local, click = new reference, right click or Esc = end"
	if ref == undefined then "Measure Gap: click the reference object" + tail
	else if other == undefined then "Measure Gap: " + ref.name + " -> move over another object" + tail
	else
	(
		local c = AlecGap_closest ref other (AlecGap_frame ref world)
		local d = c[2] - c[1]
		"Measure Gap: " + ref.name + " -> " + other.name + "  " + units.formatValue (length d) + \
			"  (X " + units.formatValue (abs d.x) + "  Y " + units.formatValue (abs d.y) + "  Z " + units.formatValue (abs d.z) + ")" + tail
	)
)

-- state of the running command, global so the Ctrl watcher (lib/ctrlKey.ms) can redraw it too: the reference, the object under the mouse, the axes
global AlecGap_ref = undefined
global AlecGap_other = undefined
global AlecGap_world = true

fn AlecGap_show =
(
	if AlecGap_ref != undefined and not (isValidNode AlecGap_ref) do AlecGap_ref = undefined
	if AlecGap_other != undefined and not (isValidNode AlecGap_other) do AlecGap_other = undefined
	AlecGap_overlay = if AlecGap_ref == undefined then AlecTools_Overlay() else AlecGap_buildOverlay AlecGap_ref AlecGap_other AlecGap_world
	replacePrompt (AlecGap_prompt AlecGap_ref AlecGap_other AlecGap_world)
	redrawViews()
)

fn AlecGap_toggleWorld =
(
	AlecGap_world = not AlecGap_world
	AlecGap_show()
)

tool AlecGap_tool
(
	fn track =
	(
		local node = AlecTools_objectAt viewPoint
		if node == AlecGap_ref do node = undefined
		if node != AlecGap_other do
		(
			AlecGap_other = node
			AlecGap_show()
		)
	)

	on start do
	(
		AlecGap_ref = undefined
		AlecGap_other = undefined
		AlecGap_overlay = AlecTools_Overlay()
		registerRedrawViewsCallback AlecGap_draw
		AlecTools_watchCtrl AlecGap_toggleWorld
	)
	on freeMove do if AlecGap_ref != undefined do track()
	on mouseMove clickno do if AlecGap_ref != undefined do track()
	-- the first click comes twice, on press (1) and on release (2): the release is skipped
	on mousePoint clickno do if clickno != 2 do
	(
		local node = AlecTools_objectAt viewPoint
		if node != undefined do
		(
			AlecGap_ref = node
			AlecGap_other = undefined
			AlecGap_show()
		)
	)
	on stop do
	(
		AlecTools_stopWatchCtrl()
		unregisterRedrawViewsCallback AlecGap_draw
		AlecGap_overlay = undefined
		redrawViews()
	)
)

fn AlecGap_run =
(
	startTool AlecGap_tool prompt:(AlecGap_prompt undefined undefined AlecGap_world)
)
