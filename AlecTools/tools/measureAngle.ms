-- Measure Angle: the angle between two lines, live.
-- Lines (the default): 4 clicks with snaps, 2 for each line; from the third click on, the second line follows the mouse and the angle with it.
-- Where the lines meet the segments are extended to that point and the angle is written there. Lines that do not meet (skew in 3D)
-- make no angle: the line between their closest points is drawn with that closest distance written on it.
-- A fifth click starts a new measure from that point.
-- Ctrl switches the plane on and off (World XY unless the dialog chose another): the lines are projected on that plane, through
-- the first point, and the angle is the one seen looking straight at it, e.g. from the top view for World XY.
-- Shift + click on the button opens the dialog (tools/measureAngleDialog.ms): edges and faces, and other planes.
-- Angles are written both ways (a and 180 - a), since two lines make both. Right click or Esc ends and clears the viewports.

-- the drawing callback of an older load is the old function value, so it is removed by that value before the name is defined again
global AlecAngle_draw
unregisterRedrawViewsCallback AlecAngle_draw

global AlecAngle_overlay = undefined

fn AlecAngle_draw = if AlecAngle_overlay != undefined do AlecTools_drawOverlay AlecAngle_overlay

-- the angle between two directions, 0..180 degrees
fn AlecAngle_between u v =
(
	local d = dot (normalize u) (normalize v)
	acos (amax -1.0 (amin 1.0 d))
)

-- an angle and the one that completes it to 180, as "a deg / b deg"
fn AlecAngle_format a =
(
	(formattedPrint a format:".1f") + " deg / " + (formattedPrint (180.0 - a) format:".1f") + " deg"
)

-- the closest points of the lines through p1 p2 and p3 p4: #(on the first, on the second), or undefined when they are parallel
fn AlecAngle_closest p1 p2 p3 p4 =
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
fn AlecAngle_addExtension ov a b p =
(
	local t = (dot (p - a) (b - a)) / (dot (b - a) (b - a))
	if t < 0 then append ov.lines #(a, p)
	else if t > 1 do append ov.lines #(b, p)
)

-- the end of the segment a b farther from p
fn AlecAngle_farEnd a b p = if distance a p > distance b p then a else b

-- the angle at the meeting points c of the segments p1 p2 and p3 p4, toward each segment's far end, so the click order does not matter
fn AlecAngle_cornerAngle p1 p2 p3 p4 c =
(
	AlecAngle_between ((AlecAngle_farEnd p1 p2 c[1]) - c[1]) ((AlecAngle_farEnd p3 p4 c[2]) - c[2])
)

-- the overlay of the line points (2 to 4, the last one may be the mouse): the segments, and with both lines the angle where they meet
fn AlecAngle_linesOverlay points =
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
			local c = AlecAngle_closest points[1] points[2] points[3] points[4]
			if c == undefined then
				append ov.labels #((points[1] + points[2] + points[3] + points[4]) / 4, "parallel")
			else
			(
				AlecAngle_addExtension ov points[1] points[2] c[1]
				AlecAngle_addExtension ov points[3] points[4] c[2]
				local gap = distance c[1] c[2]
				if gap > 0.01 then
				(
					append ov.lines #(c[1], c[2])
					append ov.labels #((c[1] + c[2]) / 2, "do not meet, closest distance " + units.formatValue gap)
				)
				else append ov.labels #(c[1], AlecAngle_format (AlecAngle_cornerAngle points[1] points[2] points[3] points[4] c))
			)
		)
	)
	ov
)

-- the points moved onto the plane of the given normal through the first one
fn AlecAngle_project points normal =
(
	local n = normalize normal
	for p in points collect p - n * (dot (p - points[1]) n)
)

-- state of the running command, global so the Ctrl watcher (lib/ctrlKey.ms) and the dialog can reach it:
-- the plane on or off, its normal and name, the clicked line points and the mouse point
global AlecAngle_flat = false
global AlecAngle_normal = [0, 0, 1]
global AlecAngle_planeName = "World XY"
global AlecAngle_fixed = #()
global AlecAngle_cursor = undefined
-- the dialog (tools/measureAngleDialog.ms): while it is open the result is also written there
global AlecAngle_dialog

-- the end of the prompt: the plane in use and the keys
fn AlecAngle_promptTail =
(
	" | " + (if AlecAngle_flat then AlecAngle_planeName else "3D") + ", Ctrl = 3D/" + AlecAngle_planeName + ", right click or Esc = end"
)

-- the angle (or why there is none) of the overlay, written in the dialog when it is open
fn AlecAngle_report ov =
(
	if AlecAngle_dialog != undefined and AlecAngle_dialog.open do
		AlecAngle_dialog.lblResult.text = if ov.labels.count == 0 then "" else ov.labels[ov.labels.count][2]
)

fn AlecAngle_prompt =
(
	local tail = AlecAngle_promptTail()
	local n = AlecAngle_fixed.count
	if n < 4 then "Measure Angle: click point " + ((n + 1) as string) + " of 4 (line " + (if n < 2 then "1" else "2") + ")" + tail
	else "Measure Angle: click = new measure" + tail
)

-- the clicked line points, plus the mouse as the end of a line that has only its start, projected when the plane is on
fn AlecAngle_linePoints =
(
	local points = for p in AlecAngle_fixed collect p
	if AlecAngle_cursor != undefined and (mod points.count 2) == 1 do append points AlecAngle_cursor
	if AlecAngle_flat and points.count > 0 then AlecAngle_project points AlecAngle_normal else points
)

fn AlecAngle_show =
(
	AlecAngle_overlay = AlecAngle_linesOverlay (AlecAngle_linePoints())
	AlecAngle_report AlecAngle_overlay
	replacePrompt (AlecAngle_prompt())
	redrawViews()
)

-- Ctrl keeps the clicked points: the same lines are measured again in the other way
fn AlecAngle_toggleFlat =
(
	AlecAngle_flat = not AlecAngle_flat
	AlecAngle_show()
)

tool AlecAngle_tool
(
	fn track =
	(
		AlecAngle_cursor = worldPoint
		AlecAngle_show()
	)

	on start do
	(
		AlecAngle_fixed = #()
		AlecAngle_cursor = undefined
		AlecAngle_overlay = AlecTools_Overlay()
		registerRedrawViewsCallback AlecAngle_draw
		AlecTools_watchCtrl AlecAngle_toggleFlat
	)
	on freeMove do track()
	on mouseMove clickno do track()
	-- the first click comes twice, on press (1) and on release (2): the release is skipped
	on mousePoint clickno do if clickno != 2 do
	(
		if AlecAngle_fixed.count == 4 do AlecAngle_fixed = #()
		append AlecAngle_fixed worldPoint
		AlecAngle_cursor = worldPoint
		AlecAngle_show()
	)
	on stop do
	(
		AlecTools_stopWatchCtrl()
		unregisterRedrawViewsCallback AlecAngle_draw
		AlecAngle_overlay = undefined
		redrawViews()
	)
)

-- the plain button: 3D, Ctrl = World XY; the dialog passes its own plane, already on
fn AlecAngle_run normal:[0, 0, 1] name:"World XY" flat:false =
(
	AlecAngle_normal = normal
	AlecAngle_planeName = name
	AlecAngle_flat = flat
	local snapWasOn = snapMode.active
	snapMode.active = true
	startTool AlecAngle_tool snap:#3D prompt:("Measure Angle: click point 1 of 4" + AlecAngle_promptTail())
	snapMode.active = snapWasOn
)
