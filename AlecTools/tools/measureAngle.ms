-- Measure Angle, advanced: what the caddy (Shift + click on the button, or a toolbar right click) starts. Needs tools/measureAngle.ms loaded.
-- Lines (the default): 4 clicks with snaps, 2 for each line; from the third click on, the second line follows the mouse and the angle with it.
-- Where the lines meet the segments are extended to that point and the angle is written there. Lines that do not meet (skew in 3D)
-- make no angle: the line between their closest points is drawn with that closest distance written on it.
-- A fifth click starts a new measure from that point.
-- Ctrl switches the plane on and off (World XY unless the caddy chose another): the lines are projected on that plane, through
-- the first point, and the angle is the one seen looking straight at it, e.g. from the top view for World XY.
-- Every run opens the caddy (tools/measureAngleCaddy.py: what to measure, which plane) and starts measuring at once; changing an option
-- starts the measurement again. It needs no selection.
-- Angles are written both ways (a and 180 - a), since two lines make both. Right click ends and clears the viewports and closes the caddy.

global AlecMeasureAngle_overlay = undefined

-- true while the tools are stopped on purpose (an option changed, the caddy closing): that is no end of the measurement
global AlecMeasureAngle_stopping = false
-- true while a running tool hands a click on the caddy on (AlecMeasureAngle_caddyClick); a stop asked then waits for the tool's #stop
global AlecMeasureAngle_inClick = false
global AlecMeasureAngle_stopAsked = false
-- #(what, plane) when an option changed: the loop in AlecMeasureAngle_run starts the measurement again once the old one has stopped
global AlecMeasureAngle_wanted = undefined

-- a measurement ended by a right click closes the caddy
fn AlecMeasureAngle_ended =
(
	if not AlecMeasureAngle_stopping and not AlecMeasureAngle_stopAsked and AlecMeasureAngle_wanted == undefined do AlecTools_closeCaddy()
	AlecMeasureAngle_stopAsked = false
)

-- a click of a running tool on the caddy (the tool holds the mouse) clicks the caddy's button there. Gives undefined when the click
-- was not on the caddy, #stop when that button asked the measurement to stop (an option changed, the caddy closed), else #done
fn AlecMeasureAngle_caddyClick =
(
	if not (AlecTools_overCaddy()) then undefined
	else
	(
		AlecMeasureAngle_inClick = true
		try ((python.import "AlecTools_caddy").click_caddy()) catch (AlecMeasureAngle_inClick = false; throw())
		AlecMeasureAngle_inClick = false
		if AlecMeasureAngle_stopAsked then #stop else #done
	)
)

fn AlecMeasureAngle_draw = if AlecMeasureAngle_overlay != undefined do AlecTools_drawOverlay AlecMeasureAngle_overlay

-- the angle between two directions, 0..180 degrees
fn AlecMeasureAngle_between u v =
(
	local d = dot (normalize u) (normalize v)
	acos (amax -1.0 (amin 1.0 d))
)

-- an angle and the one that completes it to 180, as "a deg / b deg"
fn AlecMeasureAngle_format a =
(
	(formattedPrint a format:".1f") + " deg / " + (formattedPrint (180.0 - a) format:".1f") + " deg"
)

-- the closest points of the lines through p1 p2 and p3 p4: #(on the first, on the second), or undefined when they are parallel
fn AlecMeasureAngle_closest p1 p2 p3 p4 =
(
	local u = p2 - p1
	local v = p4 - p3
	local w = p1 - p3
	local a = dot u u
	local b = dot u v
	local c = dot v v
	local den = a * c - b * b
	if den < 1e-9 * a * c then undefined
	else
	(
		local d = dot u w
		local e = dot v w
		#(p1 + u * ((b * e - c * d) / den), p3 + v * ((a * e - b * d) / den))
	)
)

-- a line from the end of the segment a b nearest to p, out to p, when p is outside the segment
fn AlecMeasureAngle_addExtension ov a b p =
(
	local t = (dot (p - a) (b - a)) / (dot (b - a) (b - a))
	if t < 0 then append ov.lines #(a, p)
	else if t > 1 do append ov.lines #(b, p)
)

-- the end of the segment a b farther from p
fn AlecMeasureAngle_farEnd a b p = if distance a p > distance b p then a else b

-- the angle at the meeting points c of the segments p1 p2 and p3 p4, toward each segment's far end, so the click order does not matter
fn AlecMeasureAngle_cornerAngle p1 p2 p3 p4 c =
(
	AlecMeasureAngle_between ((AlecMeasureAngle_farEnd p1 p2 c[1]) - c[1]) ((AlecMeasureAngle_farEnd p3 p4 c[2]) - c[2])
)

-- the overlay of the line points (2 to 4, the last one may be the mouse): the segments, and with both lines the angle where they meet
fn AlecMeasureAngle_linesOverlay points =
(
	local ov = AlecTools_Overlay()
	if points.count >= 2 do append ov.lines #(points[1], points[2])
	if points.count >= 4 do
	(
		append ov.lines #(points[3], points[4])
		local u = points[2] - points[1]
		local v = points[4] - points[3]
		if length u > 0.0001 and length v > 0.0001 do
		(
			local c = AlecMeasureAngle_closest points[1] points[2] points[3] points[4]
			if c == undefined then
				append ov.labels #((points[1] + points[2] + points[3] + points[4]) / 4, "parallel")
			else
			(
				AlecMeasureAngle_addExtension ov points[1] points[2] c[1]
				AlecMeasureAngle_addExtension ov points[3] points[4] c[2]
				local gap = distance c[1] c[2]
				if gap > 0.01 then
				(
					append ov.lines #(c[1], c[2])
					append ov.labels #((c[1] + c[2]) / 2, "do not meet, closest distance " + units.formatValue gap)
				)
				else append ov.labels #(c[1], AlecMeasureAngle_format (AlecMeasureAngle_cornerAngle points[1] points[2] points[3] points[4] c))
			)
		)
	)
	ov
)

-- the points moved onto the plane of the given normal through the first one
fn AlecMeasureAngle_project points normal =
(
	local n = normalize normal
	for p in points collect p - n * (dot (p - points[1]) n)
)

-- state of the running command, global so the Ctrl watcher (lib/ctrlKey.ms) and the caddy can reach it:
-- the plane on or off, its normal and name, the clicked line points and the mouse point
global AlecMeasureAngle_flat = false
global AlecMeasureAngle_normal = [0, 0, 1]
global AlecMeasureAngle_planeName = "World XY"
global AlecMeasureAngle_fixed = #()
global AlecMeasureAngle_cursor = undefined

-- the end of the prompt: the plane in use and the keys
fn AlecMeasureAngle_promptTail =
(
	" | " + (if AlecMeasureAngle_flat then AlecMeasureAngle_planeName else "3D") + ", Ctrl = 3D/" + AlecMeasureAngle_planeName + " | right click = end and clear"
)

fn AlecMeasureAngle_prompt =
(
	local tail = AlecMeasureAngle_promptTail()
	local n = AlecMeasureAngle_fixed.count
	if n < 4 then "Measure Angle: click point " + ((n + 1) as string) + " of 4 (line " + (if n < 2 then "1" else "2") + ")" + tail
	else "Measure Angle: click = new measure" + tail
)

-- the clicked line points, plus the mouse as the end of a line that has only its start, projected when the plane is on
fn AlecMeasureAngle_linePoints =
(
	local points = for p in AlecMeasureAngle_fixed collect p
	if AlecMeasureAngle_cursor != undefined and (mod points.count 2) == 1 do append points AlecMeasureAngle_cursor
	if AlecMeasureAngle_flat and points.count > 0 then AlecMeasureAngle_project points AlecMeasureAngle_normal else points
)

-- the Measure Angle caddy, while open, shows the last angle in its result line (its module is imported: it put lib on sys.path)
fn AlecMeasureAngle_showResult =
(
	local labels = AlecMeasureAngle_overlay.labels
	if AlecTools_caddyOpen == "MeasureAngle" and labels.count > 0 do
		(python.import "AlecTools_caddy").show_result (labels[labels.count][2] as string)
)

fn AlecMeasureAngle_show =
(
	AlecMeasureAngle_overlay = AlecMeasureAngle_linesOverlay (AlecMeasureAngle_linePoints())
	AlecMeasureAngle_showResult()
	replacePrompt (AlecMeasureAngle_prompt())
	redrawViews()
)

-- Ctrl keeps the clicked points: the same lines are measured again in the other way
fn AlecMeasureAngle_toggleFlat =
(
	AlecMeasureAngle_flat = not AlecMeasureAngle_flat
	AlecMeasureAngle_show()
)

tool AlecMeasureAngle_tool
(
	fn track =
	(
		AlecTools_ctrlSeen()
		if not (AlecTools_overCaddy()) do
		(
			AlecMeasureAngle_cursor = worldPoint
			AlecMeasureAngle_show()
		)
	)

	on start do
	(
		AlecMeasureAngle_fixed = #()
		AlecMeasureAngle_cursor = undefined
		AlecMeasureAngle_overlay = AlecTools_Overlay()
		AlecTools_beginOverlayTool AlecMeasureAngle_draw AlecMeasureAngle_toggleFlat
	)
	on freeMove do track()
	on mouseMove clickno do track()
	-- the first click comes twice, on press (1) and on release (2): the release is skipped
	on mousePoint clickno do if clickno != 2 do
	(
		local c = AlecMeasureAngle_caddyClick()
		if c != undefined then c
		else
		(
			if AlecMeasureAngle_fixed.count == 4 do AlecMeasureAngle_fixed = #()
			append AlecMeasureAngle_fixed worldPoint
			AlecMeasureAngle_cursor = worldPoint
			AlecMeasureAngle_show()
		)
	)
	on stop do
	(
		AlecMeasureAngle_overlay = undefined
		AlecTools_endOverlayTool()
		AlecMeasureAngle_ended()
	)
)

fn AlecMeasureAngle_pick = startTool AlecMeasureAngle_tool snap:#3D prompt:(AlecMeasureAngle_prompt())

fn AlecMeasureAngle_start normal name flat =
(
	AlecMeasureAngle_normal = normal
	AlecMeasureAngle_planeName = name
	AlecMeasureAngle_flat = flat
	AlecMeasureAngle_fixed = #()
	AlecTools_withSnaps AlecMeasureAngle_pick
)

-- defined in tools/measureAngleDialog.ms, which the caddy loads; declared here so AlecMeasureAngle_run below is bound to it
global AlecMeasureAngle_dialogStart

-- the macro's entry: the caddy opens, then the measurement starts with its saved choices (it returns when the measurement ends)
fn AlecMeasureAngle_run =
(
	AlecTools_closeCaddy()
	AlecTools_runPython "measureAngleCaddy.py"
	AlecMeasureAngle_wanted = AlecTools_recallSettings "MeasureAngle" #(2, 1)
	while AlecMeasureAngle_wanted != undefined do
	(
		local w = AlecMeasureAngle_wanted
		AlecMeasureAngle_wanted = undefined
		AlecMeasureAngle_dialogStart w[1] w[2]
	)
)
