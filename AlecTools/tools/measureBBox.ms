-- Measure BBox: the bounding box of the object under the mouse and its sizes, live.
-- Moving over an object shows its box and its length, width and height; a click keeps it, so several objects can stay shown.
-- The box is in the axes of the object (rotation without scale), or in the world axes (Ctrl switches), and tight on the evaluated geometry (nodeGetBoundingBox).
-- A member of a closed group stands for its whole group. Only geometry the mouse ray hits counts (intersectRayScene).
-- Right click or Esc ends the command and the boxes and texts go from the viewports.

global AlecMBox_overlay = undefined

fn AlecMBox_draw = if AlecMBox_overlay != undefined do AlecTools_drawOverlay AlecMBox_overlay

-- the box of the object and its sizes written outside it, next to the middle of a bottom edge (X, Y) and of a vertical edge (Z);
-- in the world axes when world is true, else in the axes of the object
fn AlecMBox_addObject ov node world:false =
(
	local frame = if world then matrix3 1 else AlecTools_localFrame node
	local b = AlecTools_bounds (AlecTools_parts node) frame
	local lo = b[1]
	local hi = b[2]
	local size = hi - lo
	local t = (amax size.x size.y size.z) * 0.12
	local mid = (lo + hi) / 2
	AlecTools_addBox ov lo hi frame
	append ov.labels #([mid.x, lo.y - t, lo.z] * frame, "X " + units.formatValue size.x)
	append ov.labels #([hi.x + t, mid.y, lo.z] * frame, "Y " + units.formatValue size.y)
	append ov.labels #([lo.x - t, lo.y - t, mid.z] * frame, "Z " + units.formatValue size.z)
	size
)

-- state of the running command, global so the Ctrl watcher (lib/ctrlKey.ms) can redraw it too: the kept objects, the one under the mouse, world or local axes
global AlecMBox_kept = #()
global AlecMBox_hover = undefined
global AlecMBox_world = false

-- the overlay of the kept objects and the one under the mouse; returns the size of the last one, or undefined
fn AlecMBox_buildOverlay kept hover =
(
	AlecMBox_overlay = AlecTools_Overlay()
	local size = undefined
	for n in kept where isValidNode n do size = AlecMBox_addObject AlecMBox_overlay n world:AlecMBox_world
	if hover != undefined and isValidNode hover and findItem kept hover == 0 do size = AlecMBox_addObject AlecMBox_overlay hover world:AlecMBox_world
	size
)

fn AlecMBox_prompt node size =
(
	local axes = if AlecMBox_world then "World" else "Local"
	local tail = " | " + axes + ", Ctrl = World/Local, click = keep, right click or Esc = end"
	if node == undefined then "Measure BBox: move over an object" + tail
	else "Measure BBox: " + node.name + "  X " + units.formatValue size.x + "  Y " + units.formatValue size.y + \
		"  Z " + units.formatValue size.z + tail
)

fn AlecMBox_show =
(
	local size = AlecMBox_buildOverlay AlecMBox_kept AlecMBox_hover
	replacePrompt (AlecMBox_prompt AlecMBox_hover size)
	redrawViews()
)

fn AlecMBox_toggleWorld =
(
	AlecMBox_world = not AlecMBox_world
	AlecMBox_show()
)

tool AlecMBox_tool
(
	fn track = if AlecTools_hoverMoved viewPoint do
	(
		local node = AlecTools_objectAt viewPoint
		if node != AlecMBox_hover do
		(
			AlecMBox_hover = node
			AlecMBox_show()
		)
	)

	on start do
	(
		AlecMBox_kept = #()
		AlecMBox_hover = undefined
		AlecMBox_overlay = AlecTools_Overlay()
		AlecTools_beginOverlayTool AlecMBox_draw AlecMBox_toggleWorld
	)
	on freeMove do track()
	on mouseMove clickno do track()
	-- the first click comes twice, on press (1) and on release (2): the release is skipped
	on mousePoint clickno do if clickno != 2 do
	(
		AlecMBox_hover = AlecTools_objectAt viewPoint
		if AlecMBox_hover != undefined and findItem AlecMBox_kept AlecMBox_hover == 0 do append AlecMBox_kept AlecMBox_hover
		AlecMBox_show()
	)
	on stop do
	(
		AlecMBox_overlay = undefined
		AlecTools_endOverlayTool()
	)
)

fn AlecMBox_run =
(
	startTool AlecMBox_tool prompt:"Measure BBox: move over an object | Ctrl = World/Local, click = keep, right click or Esc = end"
)
