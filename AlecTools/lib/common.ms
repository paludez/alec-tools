-- Shared helpers for Alec Tools. Every lib/*.ms is loaded by AlecTools_load before the macros.

-- settings of every tool, one section per tool
fn AlecTools_iniFile = (getDir #userScripts) + "/AlecTools.ini"

-- where the dialog of a tool was left: undefined until the user moves it once
fn AlecTools_loadDialogPos section =
(
	local x = getINISetting (AlecTools_iniFile()) section "dialogX"
	local y = getINISetting (AlecTools_iniFile()) section "dialogY"
	if x == "" or y == "" then undefined else [x as integer, y as integer]
)

fn AlecTools_saveDialogPos section p =
(
	setINISetting (AlecTools_iniFile()) section "dialogX" ((p.x as integer) as string)
	setINISetting (AlecTools_iniFile()) section "dialogY" ((p.y as integer) as string)
)

-- p moved into the work area of the monitor it is on (the nearest one when it is off every screen), so a dialog of size w x h is fully visible
fn AlecTools_clampToScreen p w h =
(
	local screenClass = dotNetClass "System.Windows.Forms.Screen"
	local area = (screenClass.FromPoint (dotNetObject "System.Drawing.Point" p.x p.y)).WorkingArea
	[amax area.Left (amin p.x (area.Right - w)), amax area.Top (amin p.y (area.Bottom - h))]
)

-- the top-left corner of a dialog: where the user left it, the first time the middle of the Max window
fn AlecTools_dialogPos section w h =
(
	local saved = AlecTools_loadDialogPos section
	AlecTools_clampToScreen (if saved != undefined then saved else (getMAXWindowPos() + getMAXWindowSize() / 2 - [w / 2, h / 2])) w h
)

-- a caddy: a tool window where the user left it; its rollout saves the place with: on <rollout> moved p do AlecTools_saveDialogPos section p
fn AlecTools_openCaddy ro section w h =
(
	createDialog ro w h pos:(AlecTools_dialogPos section w h) style:#(#style_toolwindow, #style_sysmenu)
)

-- Esc for a caddy: a dialog does not get the key, so a timer in its rollout polls it with AlecTools_escPressed.
-- The Esc that cancels a pickbutton reaches the timer only after the command mode has left #pick, so the mode of the previous tick is kept.
struct AlecTools_EscWatch (wasDown = true, lastMode)

-- true once per new Esc press that does not end a pick; busy = the caddy runs a command that Esc ends, so the key is not for the caddy
fn AlecTools_escPressed w busy:false =
(
	local down = keyboard.escPressed
	local fresh = down and not w.wasDown and w.lastMode != #pick and not busy
	w.wasDown = down
	w.lastMode = toolMode.commandMode
	fresh
)
