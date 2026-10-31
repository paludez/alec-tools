-- Measure Clearance: from the surface under the mouse, along its normal, to the next surface in front of it, live.
-- Moving over geometry shows the line and its length (floor to ceiling, wall to wall, the space under a table); a click keeps it.
-- Ctrl turns the direction into the surface instead: the thickness of a wall or a slab.
-- Only visible geometry the ray hits counts (intersectRayScene). Right click or Esc ends the command and the viewports are cleared.

global AlecClear_overlay = undefined

fn AlecClear_draw = if AlecClear_overlay != undefined do AlecTools_drawOverlay AlecClear_overlay

-- the closest visible geometry hit by the ray, as AlecTools_rayHit gives it; the ray starts a hair off the surface so it does not hit the face it leaves
fn AlecClear_firstHit pos dir = AlecTools_rayHit (ray (pos + dir * 0.01) dir)

-- the measurement from a surface point along dir: #(start, end) with end undefined when nothing is in front
fn AlecClear_measure pos dir =
(
	local hit = AlecClear_firstHit pos dir
	#(pos, if hit == undefined then undefined else hit[2].pos)
)

-- how far back the inward ray starts: past the far side of the object; from 100000 away intersectRayScene hits nothing at all
fn AlecClear_far node = (distance node.min node.max) + 1.0

-- the measurement from a surface point into its object: back faces are not hit, so the ray comes back from past the object along dir
-- and the last surface before the point is where the object ends
fn AlecClear_measureInward pos dir node =
(
	local far = AlecClear_far node
	local r = ray (pos + dir * far) -dir
	local best = undefined
	local bestDist = -1.0
	for hit in intersectRayScene r where not hit[1].isHidden and AlecTools_isMeasurable hit[1] do
	(
		local d = distance r.pos hit[2].pos
		if d < far - 0.01 and d > bestDist do
		(
			bestDist = d
			best = hit[2].pos
		)
	)
	#(pos, best)
)

-- the measurement under a screen point: the surface hit there, then along its normal (or against it when inward)
fn AlecClear_measureAt screenPoint inward =
(
	local hit = AlecTools_surfaceAt screenPoint
	if hit == undefined then undefined
	else if inward then AlecClear_measureInward hit[2].pos -hit[2].dir hit[1]
	else AlecClear_measure hit[2].pos hit[2].dir
)

-- a line and its length per measurement; one with nothing in front gets a short stub and "no hit"
fn AlecClear_buildOverlay measures =
(
	local ov = AlecTools_Overlay()
	for m in measures where m != undefined do
	(
		if m[2] == undefined then append ov.labels #(m[1], "no hit")
		else
		(
			append ov.lines #(m[1], m[2])
			append ov.labels #((m[1] + m[2]) / 2, units.formatValue (distance m[1] m[2]))
		)
	)
	ov
)

fn AlecClear_prompt m inward =
(
	local tail = " | " + (if inward then "Inward" else "Outward") + ", Ctrl = Outward/Inward, click = keep, right click or Esc = end"
	if m == undefined then "Measure Clearance: move over a surface" + tail
	else if m[2] == undefined then "Measure Clearance: nothing in front" + tail
	else "Measure Clearance: " + units.formatValue (distance m[1] m[2]) + tail
)

-- state of the running command, global so the Ctrl watcher (lib/ctrlKey.ms) can redraw it too:
-- the kept measurements, the screen point under the mouse and its measurement, the direction
global AlecClear_kept = #()
global AlecClear_screen = undefined
global AlecClear_current = undefined
global AlecClear_inward = false

fn AlecClear_show =
(
	AlecClear_current = if AlecClear_screen == undefined then undefined else AlecClear_measureAt AlecClear_screen AlecClear_inward
	AlecClear_overlay = AlecClear_buildOverlay (AlecClear_kept + #(AlecClear_current))
	replacePrompt (AlecClear_prompt AlecClear_current AlecClear_inward)
	redrawViews()
)

fn AlecClear_toggleInward =
(
	AlecClear_inward = not AlecClear_inward
	AlecClear_show()
)

tool AlecClear_tool
(
	on start do
	(
		AlecClear_kept = #()
		AlecClear_screen = undefined
		AlecClear_current = undefined
		AlecClear_overlay = AlecTools_Overlay()
		AlecTools_beginOverlayTool AlecClear_draw AlecClear_toggleInward
	)
	on freeMove do if AlecTools_hoverMoved viewPoint do
	(
		AlecClear_screen = viewPoint
		AlecClear_show()
	)
	on mouseMove clickno do if AlecTools_hoverMoved viewPoint do
	(
		AlecClear_screen = viewPoint
		AlecClear_show()
	)
	-- the first click comes twice, on press (1) and on release (2): the release is skipped
	on mousePoint clickno do if clickno != 2 do
	(
		AlecClear_screen = viewPoint
		AlecClear_show()
		if AlecClear_current != undefined and AlecClear_current[2] != undefined do append AlecClear_kept AlecClear_current
	)
	on stop do
	(
		AlecClear_overlay = undefined
		AlecTools_endOverlayTool()
	)
)

fn AlecClear_run =
(
	startTool AlecClear_tool prompt:(AlecClear_prompt undefined AlecClear_inward)
)
