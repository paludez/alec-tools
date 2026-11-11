# Tool patterns

## Macros

- Every macro is one call into `lib/common.ms`, and the tool's entry is `Alec<Tool>_run`, the prefix spelled like the tool's name:
  - `AlecTools_runTool file call`: a tool without a caddy.
  - `AlecTools_toggleTool section file call`: a tool that opens its caddy at once; pressed again, the caddy closes (as Cancel).
  - `AlecTools_runCaddyTool section file fnName`: a click applies at once with the last settings, Shift+Click or a right click on its toolbar button opens the caddy (Universal Converter, Light Converter).
  - `AlecTools_switchTool section file call`: Grab, Rotate, Scale, Transform Popup and Create Popup, which give way to each other: the open one is accepted, then the new one opens. Their caddies know each other's shortcuts from Max's hotkey file (`ToggleKey` in `lib/AlecTools_caddy.py`).
  - `AlecTools_runPython file`: a tool that is only a `.py`; a caddy made this way toggles itself (see the end of `tools/maxSettings.py`).
- Reload Alec Tools is the one exception: it must work when lib is broken.
- A macro gets an `iconName:` when the user wants one (find it with the Icon Browser macro); shortcut-only macros can go without.

## Caddy tools

- A tool with options and a preview has a caddy (see `bbox.ms` + `bboxCaddy.py`, `distribute.ms` + `distributeCaddy.py`). The `.ms` holds the logic and small functions the caddy calls; the `.py` only builds the caddy.
- Settings struct kept with `lib/settings.ms`, plus a session struct. Preview with `undo off`, OK redoes it in one `undo "Name" on`, Cancel/close restores.
- The tool file calls `AlecTools_closeCaddy()` on load and before a new session.
- BBox, Distribute, Mid Between and Measure Angle share one behavior:
  - The caddy opens as soon as the tool starts. With nothing selected, `AlecTools_hasSelection()` shows "Select objects first" for 2 s and the tool does not start (Measure Angle needs no selection and skips it).
  - Reset, OK and Cancel buttons and the help icon.
  - Enter = OK (`ENTER_WATCH = True` when the tool keeps the keyboard in a viewport), right click or Esc = Cancel.
  - BBox and Distribute also take a left click in a viewport as OK and a right click or Esc as Cancel, with no quad menu: after the caddy is shown their `_run` calls `AlecTools_clickLoop()` (`lib/viewportClicks.ms`, a mouse tool). The caddy's `closed()` calls `AlecTools_clickEnd()`, and a pick of its own is wrapped in `AlecTools_clickPause()`.
- The popups at the mouse (Grab, Rotate, Scale, Transform Popup, Create Popup) take Enter or a left click in a viewport as accept and a right click as cancel through the `ViewportClicks` class in `lib/AlecTools_caddy.py`.
- Esc on any caddy is Cancel; a subclass adds nothing for it (see "Esc on a caddy" below).
- A caddy with value boxes sets `KEY_TOGGLES = True`, so the tool's shortcut closes it while typing.
- A mouse tool of your own that runs beside a caddy skips its events while `AlecTools_overCaddy()`.

## Esc on a caddy

The rule: Esc does what Cancel does, on every caddy, wherever the focus is. All of it lives in the `Caddy` base class (`lib/AlecTools_caddy.py`); a new caddy gets it for free by overriding `closed()` (undo the preview) and, if needed, `cancel()`.

How Esc gets there (three ways, all needed; facts in the "Esc and timers" section of `max-verified.md`):

- **A text box of the caddy has the focus:** Qt delivers the key, the box passes it up, `Caddy.keyPressEvent` calls `cancel()`.
- **The caddy is the active window but no text box has the focus** (a button was clicked, an empty part, a caddy without boxes): no key event arrives at all. `Caddy.check_keys` (a 50 ms timer that every caddy starts in `showEvent`) reads Esc from Windows and posts `CANCEL_EVENT`; `Caddy.event` then calls `cancel()`. It does nothing while a pick tag is up (`pick_tag_shown()`), because that Esc belongs to the pick.
- **A viewport has the keyboard** (the Max window is active): Max gives Esc to whatever runs there, and that code closes the caddy: the click tool of `lib/viewportClicks.ms` in its `on stop` (BBox, Distribute), a `tool` of the tool itself in its `on stop` (Measure Angle), a pick loop when `pickObject` / `pickPoint` returns `undefined` / `#escape` (Mid Between).

When writing or changing a caddy:

- Do not add Esc code to a subclass, and do not reimplement `keyPressEvent` or `event` without calling the base class for the keys and events it does not take (`ViewportClicks.event` is the example).
- A pick started from a caddy button (`add_pick`) goes through `AlecTools_withPickTag`: the tag is what tells `check_keys` to leave Esc to the pick, so the pick ends and the caddy stays. A pick loop that *is* the tool (Mid Between) shows no tag, and Esc there cancels the whole tool.
- A caddy with a click tool (`AlecTools_clickLoop`) calls `AlecTools_clickPause()` before a pick of its own. `max select` in the pause does not end the click tool at once when it is called from a caddy's handler: its `on stop` comes only after the handler has returned (seen in the Listener, 2026-11-12). So the pause leaves the tool quiet (clicks ignored, its stop closes nothing) until `AlecTools_clickLoop` starts it again, which it does once both mouse buttons are up.
- A dialog, menu or Qt popup of a tool is a plain Qt class and closes on Esc by itself. While a dialog of the caddy is open the caddy is not the active window, so `check_keys` leaves it alone.
- No guard around Esc: no "is Esc down" test, no waiting for the key to come up, no `escapeEnable` switching. Callbacks call MAXScript directly. `escapeEnable = false` in `AlecTools_load` is what makes that safe.
- Say it in the texts: the caddy's `HELP` and the macro's tooltip list Esc next to Cancel.

Checking it:

- `tests/caddyPattern_test.ms` sends an Esc key event (`cp_escape`) and the watcher's `CANCEL_EVENT` (`cp_escape_watched`) to each caddy. **This proves the code path, not the keyboard:** a sent event reaches a button or the caddy itself, a real Esc does not. Every Esc change therefore ends with hand checks by the user: Esc with the focus in a text box, after a click on a button or an empty part of the caddy, with the mouse in a viewport, held for a second, and during a pick started from the caddy.
- A new caddy is added to the Esc block of that test (`CP_escTest`).
- Do not test "this name is gone from the module" in a live session: `importlib.reload` keeps names that were removed from the file.
- An exception between creating a caddy or popup and showing it leaves a hidden one behind as a child of the Max window; code that walks those children then meets an object of the old class. If a test fails on such a leftover, delete the hidden ones in Max and fix what threw.

## Caddy help

- Every caddy has a mini help: `add_help(HELP)` puts a small info icon at the right end of the title band (top right corner on a bare caddy; `help_icon(HELP)` to place it in a row instead), with the help as its tooltip; a click shows the tooltip.
- `HELP` is a module constant, `"\n".join([...])` of short lines (at most about 90 characters): one line per row or button saying what it does (`Name: ...`, the name turns bold; a continuation line is indented with four spaces), then what the mouse and keys do on the boxes (type a value or arithmetic + Enter, middle drag = ladder, right click = reset) and what OK / Enter, Cancel / Esc and the macro again do. Only what the code really does.
- Buttons and choices whose meaning is not obvious also get their own `setToolTip`.

## Viewport tools

- A tool that waits for a click (`pickObject` / `pickPoint`) runs it through `AlecTools_withPickTag text f`, so the bright tag shows in the viewport while it waits; the tag never closes a caddy.
- A tool that measures in the viewport is a `tool` started with `startTool` (see `measure*.ms`): the first click comes twice, skip `clickno == 2`; a right click ends and clears.
- Status messages go to `displayTempPrompt` / `replacePrompt`, starting with the tool's name. Lengths through `units.formatValue`.

## Toolbar

- The Alec Tools toolbar is a Qt `QToolBar` on the Max main window: `tools/AlecToolbar.py`, created by `tools/toolbar.py` at the end of `AlecTools_load`. The field rows, also used by the Transform Popup, are in `tools/AlecToolbarFields.py`, the editor in `tools/AlecToolbarEditor.py`.
- Each button runs a macro (`macros.run "Alec Tools" name`) with the macro's own text and `iconName:`.
- The buttons, order, separators and looks are kept in `AlecTools.toolbar.json` in `getDir #userScripts` (defaults in `DEFAULTS`), edited with the Edit Toolbar macro; the dock edge is in the ini. A right click on the toolbar opens no menu.
- Buttons whose macro reads `AlecTools_wantsOptions()` are listed in `WITH_OPTIONS` (right click = options, corner triangle).
- Checked buttons and fields refresh on Max's own events (`tools/toolbarEvents.ms`: a NodeEventCallback for selection, transform and geometry, plus units and scene changes) and when the mouse enters the toolbar (Use Center has no event); no timer.
