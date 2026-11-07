-- Measure BBox: the bounding box of the object under the mouse and its sizes, live.
-- Moving over an object shows its box and its length, width and height; a click keeps it, so several objects can stay shown.
-- The box is in the axes of the object (rotation without scale), or in the world axes (Ctrl switches), and tight on the evaluated geometry (nodeGetBoundingBox).
-- A member of a closed group stands for its whole group. Only geometry the mouse ray hits counts (intersectRayScene).
-- Right click or Esc ends the command and the boxes and texts go from the viewports.

global AlecMeasureBBox_overlay = undefined

fn AlecMeasureBBox_draw = if AlecMeasureBBox_overlay != undefined do AlecTools_drawOverlay AlecMeasureBBox_overlay

-- the box of the object and its sizes written outside it, next to the middle of a bottom edge (X, Y) and of a vertical edge (Z);
-- in the world axes when world is true, else in the axes of the object
fn AlecMeasureBBox_addObject ov node world:false =
(
	local frame = if world then matrix3 1 else AlecTools_localFrame node
	local b = AlecTools_bounds (AlecTools_parts node) frame
	local lo = b[1]
	local hi = b[2]
	local size = hi - lo
	local t = (amax size.x size.y size.z) * 0.12
	local mid = AlecTools_boundsCenter b
	AlecTools_addBox ov lo hi frame
	append ov.labels #([mid.x, lo.y - t, lo.z] * frame, "X " + units.formatValue size.x)
	append ov.labels #([hi.x + t, mid.y, lo.z] * frame, "Y " + units.formatValue size.y)
	append ov.labels #([lo.x - t, lo.y - t, mid.z] * frame, "Z " + units.formatValue size.z)
	size
)

-- state of the running command, global so the Ctrl watcher (lib/ctrlKey.ms) can redraw it too: the kept objects, the one under the mouse, world or local axes
global AlecMeasureBBox_kept = #()
global AlecMeasureBBox_hover = undefined
global AlecMeasureBBox_world = false

-- the overlay of the kept objects and the one under the mouse; returns the size of the last one, or undefined
fn AlecMeasureBBox_buildOverlay kept hover =
(
	AlecMeasureBBox_overlay = AlecTools_Overlay()
	local size = undefined
	for n in kept where isValidNode n do size = AlecMeasureBBox_addObject AlecMeasureBBox_overlay n world:AlecMeasureBBox_world
	if hover != undefined and isValidNode hover and findItem kept hover == 0 do size = AlecMeasureBBox_addObject AlecMeasureBBox_overlay hover world:AlecMeasureBBox_world
	size
)

fn AlecMeasureBBox_prompt node size =
(
	local axes = if AlecMeasureBBox_world then "World" else "Local"
	local tail = " | " + axes + ", Ctrl = World/Local | click = keep | right click or Esc = end and clear"
	if node == undefined then "Measure BBox: move over an object" + tail
	else "Measure BBox: " + node.name + "  X " + units.formatValue size.x + "  Y " + units.formatValue size.y + \
		"  Z " + units.formatValue size.z + tail
)

fn AlecMeasureBBox_show =
(
	local size = AlecMeasureBBox_buildOverlay AlecMeasureBBox_kept AlecMeasureBBox_hover
	replacePrompt (AlecMeasureBBox_prompt AlecMeasureBBox_hover size)
	redrawViews()
)

-- the axes of the scene (Local unless Ctrl chose World before), taken when the command starts
fn AlecMeasureBBox_recall = AlecMeasureBBox_world = AlecTools_recallSettings "MeasureBBox" false

fn AlecMeasureBBox_toggleWorld =
(
	AlecMeasureBBox_world = not AlecMeasureBBox_world
	AlecTools_rememberSettings "MeasureBBox" AlecMeasureBBox_world
	AlecMeasureBBox_show()
)

tool AlecMeasureBBox_tool
(
	fn track =
	(
		AlecTools_ctrlSeen()
		if AlecTools_hoverMoved viewPoint do
		(
			local node = AlecTools_objectAt viewPoint
			if node != AlecMeasureBBox_hover do
			(
				AlecMeasureBBox_hover = node
				AlecMeasureBBox_show()
			)
		)
	)

	on start do
	(
		AlecMeasureBBox_kept = #()
		AlecMeasureBBox_hover = undefined
		AlecMeasureBBox_overlay = AlecTools_Overlay()
		AlecTools_beginOverlayTool AlecMeasureBBox_draw AlecMeasureBBox_toggleWorld
	)
	on freeMove do track()
	on mouseMove clickno do track()
	-- the first click comes twice, on press (1) and on release (2): the release is skipped
	on mousePoint clickno do if clickno != 2 do
	(
		AlecMeasureBBox_hover = AlecTools_objectAt viewPoint
		if AlecMeasureBBox_hover != undefined and findItem AlecMeasureBBox_kept AlecMeasureBBox_hover == 0 do append AlecMeasureBBox_kept AlecMeasureBBox_hover
		AlecMeasureBBox_show()
	)
	on stop do
	(
		AlecMeasureBBox_overlay = undefined
		AlecTools_endOverlayTool()
	)
)

fn AlecMeasureBBox_run =
(
	AlecMeasureBBox_recall()
	startTool AlecMeasureBBox_tool prompt:(AlecMeasureBBox_prompt undefined undefined)
)
