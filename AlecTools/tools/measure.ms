-- Measure: the distance between two or more points clicked with snaps, live.
-- While the mouse moves, a line follows it from the last point with its length and the running total.
-- Every fixed segment keeps its line and length in the viewports; the prompt line shows the same numbers.
-- Ctrl switches to Area: the points close into a polygon (a line back to the first point) and its area and perimeter are shown.
-- Right click or Esc ends the command and the lines and texts go from the viewports.

-- the drawing callback of an older load is the old function value, so it is removed by that value before the name is defined again
global AlecMeasure_draw
unregisterRedrawViewsCallback AlecMeasure_draw

global AlecMeasure_overlay = undefined

fn AlecMeasure_draw = if AlecMeasure_overlay != undefined do AlecTools_drawOverlay AlecMeasure_overlay

-- the sum of the segment lengths of a polyline, closed back to the first point when closed is true
fn AlecMeasure_total points closed:false =
(
	local sum = 0.0
	for i = 2 to points.count do sum += distance points[i - 1] points[i]
	if closed and points.count > 2 do sum += distance points[points.count] points[1]
	sum
)

-- the area of the polygon through the points (in 3D, not only flat on a plane), in square system units
fn AlecMeasure_area points =
(
	local sum = [0, 0, 0]
	for i = 1 to points.count do sum += cross points[i] points[(mod i points.count) as integer + 1]
	(length sum) / 2
)

-- an area in square meters, written with 2 decimals
fn AlecMeasure_formatArea a =
(
	local m = units.decodeValue "1m"
	(formattedPrint (a / (m * m)) format:".2f") + " m2"
)

fn AlecMeasure_average points =
(
	local sum = [0, 0, 0]
	for p in points do sum += p
	sum / points.count
)

-- the overlay of the points: a line and its length per segment, and the total next to the last point when there are 2 segments or more;
-- in area mode the closing segment too, and the area and perimeter in the middle of the polygon
fn AlecMeasure_buildOverlay points area:false =
(
	local ov = AlecTools_Overlay()
	local segs = for i = 2 to points.count collect #(points[i - 1], points[i])
	if area and points.count > 2 do append segs #(points[points.count], points[1])
	for s in segs do
	(
		append ov.lines s
		append ov.labels #((s[1] + s[2]) / 2, units.formatValue (distance s[1] s[2]))
	)
	if area then
	(
		if points.count > 2 do
			append ov.labels #(AlecMeasure_average points, "Area: " + AlecMeasure_formatArea (AlecMeasure_area points) + \
				"  Perimeter: " + units.formatValue (AlecMeasure_total points closed:true))
	)
	else if points.count > 2 do
		append ov.labels #(points[points.count], "Total: " + units.formatValue (AlecMeasure_total points))
	ov
)

fn AlecMeasure_prompt points area =
(
	local text = "Measure: click point " + (points.count as string)
	if area then
	(
		if points.count > 2 do
			text += " | area " + AlecMeasure_formatArea (AlecMeasure_area points) + ", perimeter " + units.formatValue (AlecMeasure_total points closed:true)
	)
	else if points.count > 1 do
		text += " | last " + units.formatValue (distance points[points.count - 1] points[points.count]) + \
			", total " + units.formatValue (AlecMeasure_total points)
	text + " | " + (if area then "Area" else "Distance") + ", Ctrl = Distance/Area, right click or Esc = end"
)

-- state of the running command, global so the Ctrl watcher (lib/ctrlKey.ms) can redraw it too: the clicked points, the cursor, area mode
global AlecMeasure_fixed = #()
global AlecMeasure_cursor = undefined
global AlecMeasure_areaMode = false

fn AlecMeasure_show =
(
	local points = if AlecMeasure_cursor == undefined then copy AlecMeasure_fixed else AlecMeasure_fixed + #(AlecMeasure_cursor)
	AlecMeasure_overlay = AlecMeasure_buildOverlay points area:AlecMeasure_areaMode
	replacePrompt (AlecMeasure_prompt points AlecMeasure_areaMode)
	redrawViews()
)

fn AlecMeasure_toggleArea =
(
	AlecMeasure_areaMode = not AlecMeasure_areaMode
	AlecMeasure_show()
)

tool AlecMeasure_tool
(
	on start do
	(
		AlecMeasure_fixed = #()
		AlecMeasure_cursor = undefined
		AlecMeasure_overlay = AlecTools_Overlay()
		registerRedrawViewsCallback AlecMeasure_draw
		AlecTools_watchCtrl AlecMeasure_toggleArea
	)
	-- the first click comes twice, on press (1) and on release (2): the release is skipped
	on mousePoint clickno do if clickno != 2 do
	(
		append AlecMeasure_fixed worldPoint
		AlecMeasure_cursor = worldPoint
		AlecMeasure_show()
	)
	on freeMove do if AlecMeasure_fixed.count > 0 do
	(
		AlecMeasure_cursor = worldPoint
		AlecMeasure_show()
	)
	on mouseMove clickno do if AlecMeasure_fixed.count > 0 do
	(
		AlecMeasure_cursor = worldPoint
		AlecMeasure_show()
	)
	on stop do
	(
		AlecTools_stopWatchCtrl()
		unregisterRedrawViewsCallback AlecMeasure_draw
		AlecMeasure_overlay = undefined
		redrawViews()
	)
)

fn AlecMeasure_run =
(
	local snapWasOn = snapMode.active
	snapMode.active = true
	startTool AlecMeasure_tool snap:#3D prompt:"Measure: click the first point | Ctrl = Distance/Area, right click or Esc = end"
	snapMode.active = snapWasOn
)
