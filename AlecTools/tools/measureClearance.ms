-- Measure Clearance: from the surface under the mouse, along its normal, to the next surface in front of it, live.
-- Moving over geometry shows the line and its length (floor to ceiling, wall to wall, the space under a table); a click keeps it.
-- Ctrl turns the direction into the surface instead: the thickness of a wall or a slab.
-- Only visible geometry the ray hits counts (intersectRayScene). Right click or Esc ends the command and the viewports are cleared.

global AlecMeasureClearance_overlay = undefined

fn AlecMeasureClearance_draw = if AlecMeasureClearance_overlay != undefined do AlecTools_drawOverlay AlecMeasureClearance_overlay

-- the closest visible geometry hit by the ray, as AlecTools_rayHit gives it; the ray starts a hair off the surface so it does not hit the face it leaves
fn AlecMeasureClearance_firstHit pos dir = AlecTools_rayHit (ray (pos + dir * 0.01) dir)

-- the measurement from a surface point along dir: #(start, end) with end undefined when nothing is in front
fn AlecMeasureClearance_measure pos dir =
(
	local hit = AlecMeasureClearance_firstHit pos dir
	#(pos, if hit == undefined then undefined else hit[2].pos)
)

-- how far back the inward ray starts: past the far side of the object; from 100000 away intersectRayScene hits nothing at all
fn AlecMeasureClearance_far node = (distance node.min node.max) + 1.0

-- the measurement from a surface point into its object: back faces are not hit, so the ray comes back from past the object along dir
-- and the last surface before the point is where the object ends
fn AlecMeasureClearance_measureInward pos dir node =
(
	local far = AlecMeasureClearance_far node
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
fn AlecMeasureClearance_measureAt screenPoint inward =
(
	local hit = AlecTools_surfaceAt screenPoint
	if hit == undefined then undefined
	else if inward then AlecMeasureClearance_measureInward hit[2].pos -hit[2].dir hit[1]
	else AlecMeasureClearance_measure hit[2].pos hit[2].dir
)

-- a line and its length per measurement; one with nothing in front gets a short stub and "no hit"
fn AlecMeasureClearance_buildOverlay measures =
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

fn AlecMeasureClearance_prompt m inward =
(
	local tail = " | " + (if inward then "Inward" else "Outward") + ", Ctrl = Outward/Inward | click = keep | right click or Esc = end and clear"
	if m == undefined then "Measure Clearance: move over a surface" + tail
	else if m[2] == undefined then "Measure Clearance: nothing in front" + tail
	else "Measure Clearance: " + units.formatValue (distance m[1] m[2]) + tail
)

-- state of the running command, global so the Ctrl watcher (lib/ctrlKey.ms) can redraw it too:
-- the kept measurements, the screen point under the mouse and its measurement, the direction
global AlecMeasureClearance_kept = #()
global AlecMeasureClearance_screen = undefined
global AlecMeasureClearance_current = undefined
global AlecMeasureClearance_inward = false

fn AlecMeasureClearance_show =
(
	AlecMeasureClearance_current = if AlecMeasureClearance_screen == undefined then undefined else AlecMeasureClearance_measureAt AlecMeasureClearance_screen AlecMeasureClearance_inward
	AlecMeasureClearance_overlay = AlecMeasureClearance_buildOverlay (AlecMeasureClearance_kept + #(AlecMeasureClearance_current))
	replacePrompt (AlecMeasureClearance_prompt AlecMeasureClearance_current AlecMeasureClearance_inward)
	redrawViews()
)

-- the direction of the scene (Outward unless Ctrl chose Inward before), taken when the command starts
fn AlecMeasureClearance_recall = AlecMeasureClearance_inward = AlecTools_recallSettings "MeasureClearance" false

fn AlecMeasureClearance_toggleInward =
(
	AlecMeasureClearance_inward = not AlecMeasureClearance_inward
	AlecTools_rememberSettings "MeasureClearance" AlecMeasureClearance_inward
	AlecMeasureClearance_show()
)

tool AlecMeasureClearance_tool
(
	on start do
	(
		AlecMeasureClearance_kept = #()
		AlecMeasureClearance_screen = undefined
		AlecMeasureClearance_current = undefined
		AlecMeasureClearance_overlay = AlecTools_Overlay()
		AlecTools_beginOverlayTool AlecMeasureClearance_draw AlecMeasureClearance_toggleInward
	)
	fn track =
	(
		AlecTools_ctrlSeen()
		if AlecTools_hoverMoved viewPoint do
		(
			AlecMeasureClearance_screen = viewPoint
			AlecMeasureClearance_show()
		)
	)
	on freeMove do track()
	on mouseMove clickno do track()
	-- the first click comes twice, on press (1) and on release (2): the release is skipped
	on mousePoint clickno do if clickno != 2 do
	(
		AlecMeasureClearance_screen = viewPoint
		AlecMeasureClearance_show()
		if AlecMeasureClearance_current != undefined and AlecMeasureClearance_current[2] != undefined do append AlecMeasureClearance_kept AlecMeasureClearance_current
	)
	on stop do
	(
		AlecMeasureClearance_overlay = undefined
		AlecTools_endOverlayTool()
	)
)

fn AlecMeasureClearance_run =
(
	AlecMeasureClearance_recall()
	startTool AlecMeasureClearance_tool prompt:(AlecMeasureClearance_prompt undefined AlecMeasureClearance_inward)
)
