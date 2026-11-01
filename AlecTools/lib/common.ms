-- Shared helpers for Alec Tools. Every lib/*.ms is loaded by AlecTools_load before the macros.

-- the ini of Alec Tools: where the toolbar is docked and where each caddy was left, one section per tool
fn AlecTools_iniFile = (getDir #userScripts) + "/AlecTools.ini"

-- set by a right click on a toolbar button just before it runs the macro, read once by AlecTools_wantsOptions
global AlecTools_optionsClick = false

-- true when a macro should open its caddy or dialog: Shift held, or the toolbar button was right clicked
fn AlecTools_wantsOptions =
(
	local wanted = keyboard.shiftPressed or AlecTools_optionsClick
	AlecTools_optionsClick = false
	wanted
)

-- the screen rectangle of the active viewport as #(top-left corner, size), in pixels, or undefined (no viewport found).
-- No call gives it: a grid of points over the Max window is tried with viewport.getViewportFromScreenCoord, which for a point
-- on a viewport gives #(panel, viewport index, id, hwnd, point inside the viewport, ...); 100 px steps, smaller than any viewport
fn AlecTools_activeViewRect =
(
	local active = viewport.activeViewport
	local origin = getMAXWindowPos()
	local size = getMAXWindowSize()
	local found = undefined
	for y = origin.y + 50 to origin.y + size.y - 50 by 100 while found == undefined do
		for x = origin.x + 50 to origin.x + size.x - 50 by 100 while found == undefined do
		(
			local r = viewport.getViewportFromScreenCoord [x, y]
			if classOf r == Array and r[2] == active do found = #([x, y] - r[5], getViewSize())
		)
	found
)

-- the Slate Material Editor view named tabName, made when it is not there, opened and active
fn AlecTools_smeView tabName =
(
	if not sme.isOpen() do sme.Open()
	local index = sme.GetViewByName tabName
	if index == 0 do index = sme.CreateView tabName
	sme.activeView = index
	sme.GetView index
)

-- the section of the Qt caddy that is open (lib/AlecTools_caddy.py sets it), "" when none
global AlecTools_caddyOpen = ""

-- closes the Qt caddy that is open, so its preview is undone (its closed()) before a tool starts a new one
fn AlecTools_closeCaddy =
(
	if AlecTools_caddyOpen != "" do python.Execute "import AlecTools_caddy\nAlecTools_caddy.close_all()"
)
