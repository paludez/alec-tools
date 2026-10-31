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
