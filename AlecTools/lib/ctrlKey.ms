-- Ctrl as a switch inside a running tool. A tool does not receive keys, and no MAXScript may run from a timer, so lib/ctrlKey.py
-- watches Ctrl in Python and nudges the cursor 1 pixel and back when it changes; the tool calls AlecTools_ctrlSeen() in its freeMove and mouseMove,
-- which runs the action each time Ctrl goes down. One tool runs at a time, so one watcher is enough; tools start and stop it through
-- lib/overlayTool.ms.

global AlecTools_ctrlWasDown = false
global AlecTools_ctrlAction = undefined

fn AlecTools_ctrlSeen =
(
	local down = keyboard.controlPressed
	if down and not AlecTools_ctrlWasDown and AlecTools_ctrlAction != undefined do AlecTools_ctrlAction()
	AlecTools_ctrlWasDown = down
)

-- the Python side stops its timer and starts a new one only while an action is set
fn AlecTools_runCtrlWatch = python.ExecuteFile (AlecTools_path "lib/ctrlKey.py")

fn AlecTools_stopWatchCtrl =
(
	if AlecTools_ctrlAction != undefined do
	(
		AlecTools_ctrlAction = undefined
		AlecTools_runCtrlWatch()
	)
)

fn AlecTools_watchCtrl action =
(
	AlecTools_ctrlAction = action
	AlecTools_ctrlWasDown = keyboard.controlPressed
	AlecTools_runCtrlWatch()
)
