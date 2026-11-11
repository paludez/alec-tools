-- The viewport clicks of a caddy without a pick of its own (BBox, Distribute): a mouse tool runs while the caddy is open, so a left click is OK
-- and a right click is Cancel, and Max opens no quad menu. The tool's file calls AlecTools_clickLoop() after the caddy is shown (it returns
-- when the caddy has closed) and the caddy's closed() calls AlecTools_clickEnd(). A caddy that runs a pick of its own pauses the tool first
-- with AlecTools_clickPause(). Max ends the paused tool only after the caddy's handler has returned, so the tool stays quiet (no click
-- counts, its stop closes nothing) until the loop starts it again. Esc in a viewport ends the tool as a right click does: Cancel.

global AlecTools_clickRun = false
global AlecTools_clickActive = false
global AlecTools_clickQuiet = false

tool AlecTools_clickTool
(
	on start do
	(
		AlecTools_clickActive = true
		AlecTools_clickQuiet = false
	)
	on mousePoint clickno do if clickno != 2 and not AlecTools_clickQuiet and not (AlecTools_overCaddy()) do
	(
		(python.import "AlecTools_caddy").accept_open()
		#stop
	)
	on stop do
	(
		AlecTools_clickActive = false
		if AlecTools_clickRun and not AlecTools_clickQuiet do AlecTools_closeCaddy()
	)
)

fn AlecTools_clickPause =
(
	if AlecTools_clickActive do
	(
		AlecTools_clickQuiet = true
		max select
	)
)

fn AlecTools_clickEnd =
(
	AlecTools_clickRun = false
	AlecTools_clickPause()
)

fn AlecTools_clickLoop =
(
	local caddy = python.import "AlecTools_caddy"
	AlecTools_clickRun = true
	while AlecTools_clickRun do
	(
		-- a button still down (the click that ended a pick of the caddy) is not a click for the tool: it starts once both are up
		while (caddy.button_down caddy.VK_LBUTTON) or (caddy.button_down caddy.VK_RBUTTON) do sleep 0.01
		startTool AlecTools_clickTool prompt:"left click = OK, right click = Cancel"
	)
)
