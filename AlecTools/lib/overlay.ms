-- Viewport overlay shared by the tools: boxes, lines and text, in world space, drawn with gw.* from a tool's own redraw callback:
--   fn AlecX_draw = if <the tool is running> do AlecTools_drawOverlay ov
--   registerRedrawViewsCallback AlecX_draw ... unregisterRedrawViewsCallback AlecX_draw
-- The overlay is filled when something changes, not on every redraw. Lengths are written with units.formatValue (scene units).

-- boxes = #(bottom 4 corners, top 4 corners), lines = #(p1, p2), labels = #(point, text)
struct AlecTools_Overlay (boxes = #(), lines = #(), labels = #(), boxColor = green, lineColor = yellow, textColor = yellow)

-- the box lo..hi of frame, as world corners
fn AlecTools_addBox ov lo hi frame =
(
	append ov.boxes #( \
		#([lo.x, lo.y, lo.z] * frame, [hi.x, lo.y, lo.z] * frame, [hi.x, hi.y, lo.z] * frame, [lo.x, hi.y, lo.z] * frame), \
		#([lo.x, lo.y, hi.z] * frame, [hi.x, lo.y, hi.z] * frame, [hi.x, hi.y, hi.z] * frame, [lo.x, hi.y, hi.z] * frame))
)

-- a dimension from p1 to p2 (world): the line, a tick (the vector tick, both ways) at each end, and length written past the middle on the tick side
fn AlecTools_addDimension ov p1 p2 tick length =
(
	append ov.lines #(p1, p2)
	append ov.lines #(p1 - tick, p1 + tick)
	append ov.lines #(p2 - tick, p2 + tick)
	append ov.labels #((p1 + p2) / 2 + tick * 1.5, units.formatValue length)
)

-- text at a world point with a black outline (drawn shifted 1 pixel around it), so it reads on any background
fn AlecTools_drawLabel p text col =
(
	local s = gw.hTransPoint p
	for d in #([-1, 0, 0], [1, 0, 0], [0, -1, 0], [0, 1, 0], [-1, -1, 0], [1, 1, 0], [-1, 1, 0], [1, -1, 0]) do
		gw.hText (s + d) text color:black
	gw.hText s text color:col
)

fn AlecTools_drawOverlay ov =
(
	gw.setTransform (matrix3 1)
	gw.setColor #line ov.boxColor
	for b in ov.boxes do
	(
		gw.polyline b[1] true
		gw.polyline b[2] true
		for i = 1 to 4 do gw.polyline #(b[1][i], b[2][i]) false
	)
	gw.setColor #line ov.lineColor
	for l in ov.lines do gw.polyline l false
	for t in ov.labels do AlecTools_drawLabel t[1] t[2] ov.textColor
	gw.enlargeUpdateRect #whole
	gw.updateScreen()
)
