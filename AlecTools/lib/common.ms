-- Shared helpers for Alec Tools. Every lib/*.ms is loaded by AlecTools_load before the macros.

-- the Python side: lib/ and tools/ go on sys.path once here, so a tool's .py only imports AlecTools_caddy (or a tools/ module);
-- AlecTools_caddy is reloaded at every load, so a Reload picks up its changes
python.Execute "
import sys, importlib
from pymxs import runtime as rt
for _d in ('lib', 'tools'):
    _p = rt.AlecTools_path(_d)
    if _p not in sys.path:
        sys.path.append(_p)
if 'AlecTools_caddy' in sys.modules:
    importlib.reload(sys.modules['AlecTools_caddy'])
"

-- the ini of Alec Tools: where the toolbar is docked and where each caddy was left, one section per tool
fn AlecTools_iniFile = (getDir #userScripts) + "/AlecTools.ini"

-- set by a right click on a toolbar button just before it runs the macro, read once by AlecTools_wantsOptions
global AlecTools_optionsClick = false

-- true when a macro should open its caddy: Shift held, or the toolbar button was right clicked
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
	python.Execute "import AlecTools_caddy\nAlecTools_caddy.close_all()"
)

-- a tag in the active viewport while a tool waits for a click. It is no caddy: showing it closes none, AlecTools_hidePickTag() removes
-- only the tag, AlecTools_closeCaddy() removes it too. hint is the second line.
fn AlecTools_showPickTag text hint:"right click or Esc = cancel" = (python.import "AlecTools_caddy").show_pick_tag text hint

fn AlecTools_hidePickTag = (python.import "AlecTools_caddy").hide_pick_tag()

-- a short message in the viewport (2 s)
fn AlecTools_hint text = (python.import "AlecTools_caddy").show_hint text

-- true when something is selected; else shows "Select objects first" for 2 s
fn AlecTools_hasSelection =
(
	if selection.count == 0 do AlecTools_hint "Select objects first"
	selection.count > 0
)

-- runs f (a function that picks) with the tag text shown, and takes the tag away after it, also when f stops with an error
fn AlecTools_withPickTag text f hint:"right click or Esc = cancel" =
(
	AlecTools_showPickTag text hint:hint
	local result = try (f()) catch (AlecTools_hidePickTag(); throw())
	AlecTools_hidePickTag()
	result
)

-- for a macro that toggles its caddy: closes it when it is the open one, and says so
fn AlecTools_closeIfOpen section =
(
	local isOpen = AlecTools_caddyOpen == section
	if isOpen do AlecTools_closeCaddy()
	isOpen
)

-- How a macro starts its tool. A macro is compiled before its tool file is loaded, so the call into the file goes through execute.

-- loads tools/<file> and runs call, a line of MAXScript that calls a function of that file
fn AlecTools_runTool file call =
(
	fileIn (AlecTools_path ("tools/" + file))
	execute call
)

fn AlecTools_runPython file = python.ExecuteFile (AlecTools_path ("tools/" + file))

-- a tool whose caddy toggles: pressed again, its open caddy (section) closes; otherwise fnName runs with showCaddy: true when Shift
-- is held or the toolbar button was right clicked (read first, before the file loads)
fn AlecTools_runCaddyTool section file fnName =
(
	local showCaddy = AlecTools_wantsOptions()
	if not (AlecTools_closeIfOpen section) do AlecTools_runTool file (fnName + " showCaddy:" + showCaddy as string)
)

-- a tool that is its own caddy (no options): pressed again, it closes
fn AlecTools_toggleTool section file call = if not (AlecTools_closeIfOpen section) do AlecTools_runTool file call

-- Grab, Rotate, Scale, Transform Popup and Create Popup give way to each other (SWITCH_MACROS in lib/AlecTools_caddy.py): pressed again,
-- the tool's own caddy closes (cancelled); otherwise the one of the group that is open is accepted first, its change kept, and the tool
-- starts. file is a .py (the tool is its own caddy) or a .ms that call runs. Its shortcut is learned for the open caddy to recognise
fn AlecTools_switchTool section file call =
(
	(python.import "AlecTools_caddy").note_shortcut section
	if not (AlecTools_closeIfOpen section) do
	(
		(python.import "AlecTools_caddy").accept_group()
		if matchPattern file pattern:"*.py" then AlecTools_runPython file else AlecTools_runTool file call
	)
)

-- runs f (a function that picks or starts a tool) with Max's snap toggle set to on: and its rubber band off, and puts both back after,
-- also when f stops with an error
fn AlecTools_withSnaps f on:true =
(
	local wasOn = snapMode.active
	local wasBand = snapMode.displayRubberBand
	snapMode.active = on
	-- Max's own rubber band would draw a line from the first picked point to the mouse, over the tool's own lines
	snapMode.displayRubberBand = false
	local result = try (f()) catch (snapMode.active = wasOn; snapMode.displayRubberBand = wasBand; throw())
	snapMode.active = wasOn
	snapMode.displayRubberBand = wasBand
	result
)

-- the renderers installed on this machine (the work laptop may lack one)
fn AlecTools_hasVRay = VRayMtl != undefined
fn AlecTools_hasArnold = Arnold_Light != undefined

-- the end of a batch tool (the converters): the summary in the Listener with one indented line per detail, and in the prompt
fn AlecTools_report summary details =
(
	format "%\n" summary
	for line in details do format "  %\n" line
	displayTempPrompt (summary + " (details in the Listener)") 5000
)
