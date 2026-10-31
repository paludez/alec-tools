-- Start and end of a viewport tool (Measure*, Measure Angle): its drawing callback and its Ctrl watcher (lib/ctrlKey.ms).
-- One tool runs at a time; the running one's callback is kept here, so AlecTools_load can end it before the purge orphans it.

global AlecTools_toolDraw = undefined
-- the screen point of the last hover that cast a ray into the scene
global AlecTools_lastHover = undefined

-- true when the mouse has moved at least 2 pixels since the last hover that counted: the tools that cast a ray into the scene
-- on every move skip the moves too small to change what is under the mouse
fn AlecTools_hoverMoved p =
(
	local moved = AlecTools_lastHover == undefined or distance p AlecTools_lastHover >= 2
	if moved do AlecTools_lastHover = p
	moved
)

fn AlecTools_endOverlayTool =
(
	AlecTools_stopWatchCtrl()
	if AlecTools_toolDraw != undefined do unregisterRedrawViewsCallback AlecTools_toolDraw
	AlecTools_toolDraw = undefined
	redrawViews()
)

-- ctrlAction undefined = the tool has no Ctrl switch
fn AlecTools_beginOverlayTool drawFn ctrlAction =
(
	AlecTools_endOverlayTool()
	AlecTools_lastHover = undefined
	AlecTools_toolDraw = drawFn
	registerRedrawViewsCallback drawFn
	if ctrlAction != undefined do AlecTools_watchCtrl ctrlAction
)
