-- Ctrl as a switch inside a running tool: a tool does not receive keys, so a timer watches Ctrl and calls an action each time it goes down.
-- One tool runs at a time, so one watcher is enough: AlecTools_watchCtrl fn in the tool's start, AlecTools_stopWatchCtrl() in its stop.

global AlecTools_ctrlTimer = undefined
global AlecTools_ctrlWasDown = false
global AlecTools_ctrlAction = undefined

fn AlecTools_ctrlTick =
(
	local down = keyboard.controlPressed
	if down and not AlecTools_ctrlWasDown do AlecTools_ctrlAction()
	AlecTools_ctrlWasDown = down
)

fn AlecTools_stopWatchCtrl =
(
	if AlecTools_ctrlTimer != undefined do
	(
		AlecTools_ctrlTimer.stop()
		AlecTools_ctrlTimer.dispose()
		AlecTools_ctrlTimer = undefined
	)
)

fn AlecTools_watchCtrl action =
(
	AlecTools_stopWatchCtrl()
	AlecTools_ctrlAction = action
	AlecTools_ctrlWasDown = keyboard.controlPressed
	AlecTools_ctrlTimer = dotNetObject "System.Windows.Forms.Timer"
	AlecTools_ctrlTimer.interval = 50
	dotNet.addEventHandler AlecTools_ctrlTimer "Tick" AlecTools_ctrlTick
	AlecTools_ctrlTimer.start()
)
