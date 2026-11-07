# Alec Tools

Personal tools for **3ds Max 2027** (2027.1, scene units in cm). Used through macroScript buttons and shortcuts, category "Alec Tools". Only Max 2027 matters; ignore other versions.

Renderers: the user works with **V-Ray and Arnold** (MAXtoA is installed). Tools that touch materials, maps, lights or render settings must not assume Standard/Physical materials. What the user actually uses:

- **V-Ray:** the V-Ray material (VRayMtl) and **OpenPBR**. Almost exclusively **V-Ray GPU**, so every material and map a tool creates or handles must work on GPU.
- **Arnold:** only **OpenPBR**. Maps are **OSL maps**, not Arnold's own maps, unless that is strictly necessary. It must work on the GPU too.

Check the real class names in Max before using them (do not write them from memory), and do not assume both renderers are installed on every machine, e.g. the work laptop.

## Layout

```
AlecTools/            payload, what gets installed
  core/               AlecTools_core.ms: AlecTools_root, AlecTools_path, AlecTools_purge, AlecTools_removeSavedMacros, AlecTools_openLog (Listener copy in AlecTools.listener.log), AlecTools_load, AlecTools_reload
  lib/                shared helpers (AlecTools_*), auto-loaded before the macros
  tools/              one file per tool, holds the logic, loaded on demand by its macro
  macros/             thin .mcr/.ms files: buttons and shortcuts only, they call into tools/
installer/            AlecTools_Load.ms (startup loader), AlecTools_install.ms + mzp.run (laptop install)
tests/                *_test.ms, run inside Max, print PASS/FAIL
tools/build_mzp.ps1   builds dist/AlecTools.mzp (build.bat)
```

## How it is deployed

- This PC: live. `<userStartupScripts>\AlecTools_Load.ms` loads from the folder in `<userScripts>\AlecTools.root.txt` (points at `D:/P R O I E C T E/AI/3DS MAX/AlecTools`). After editing, the user presses the "Reload Alec Tools" macro; no Max restart.
- Work laptop (no admin): the user downloads `AlecTools.mzp` from the private GitHub repo (`paludez/alec-tools`, file in the repo root) and drags it into Max.
- **Every commit that goes to GitHub comes with a fresh `AlecTools.mzp`:** commit the code, run `tools/build_mzp.ps1` on the clean tree (it also copies the mzp to the repo root), commit the mzp, then push. Otherwise build the mzp only when the user asks.
- Never copy files into `usermacros`, never hardcode `getDir #userMacros` or `D:` paths in tools. Reach files with `AlecTools_path "tools/x.ms"`. The one exception is `AlecTools_removeSavedMacros` in the core, which deletes Max's own `Alec Tools-*` copies there (see the last section).

## Rules for code

- **Language: only the user writes in Romanian. Claude thinks, answers and writes everything in English**: replies in chat, code, comments, UI messages, tests, commit messages, audit.md, README.md and this file. No exceptions.

- MAXScript for macros and anything that touches the scene. Python (pymxs) for files, images, JSON and complex UI.
- Names: `AlecTools_` for shared helpers, `Alec<ToolName>_` for a tool's own functions (e.g. `AlecSmartVis_`).
- Short functions, no unused functions, no dead code, no commented-out code.
- No empty `try ... catch ()`. Let errors reach the Listener, or report `getCurrentException()`.
- Macros stay thin: they call a tool function, nothing more.
- **Every caddy is a toggle and never uses Esc.** ("Caddy" is the name of every floating Qt panel of the tools, in the UI, comments and docs; the macros called Transform Popup and Create Popup keep their button text.) Running its macro or pressing its shortcut again closes it, also while typing in one of its text boxes (`AlecTools_closeIfOpen` in the macro, `KEY_TOGGLES = True` for a caddy with text boxes). No caddy, menu or dialog closes or cancels on Esc: Esc crashed Max.
- **Editable Poly and the Edit Poly modifier do not have exactly the same commands**, and the same goes for Editable Mesh / Edit Mesh and for a spline shape / the Edit Spline modifier. For example the selection call differs (`obj.EditablePoly.SetSelection` vs `modifier.SetSelection`), and `polyop.*` queries are for Editable Poly, not for the Edit Poly modifier. Never assume a command that works on one works on the other: check it on both before writing the code (a check `.ms` that creates the object, runs the command and prints the result, run by the user), and cover both in the test.
- One tool at a time: write it, the user tests it in Max, commit only when the user asks.
- **Never ask, suggest or remind about commits, pushes or building the mzp** (no "commit now?" questions, buttons or recommendations at the end of a task). The user decides when; wait until they say it.

## Shared code (lib/)

Before writing a helper in a tool, look in `lib/` for one that already does it. When the same logic would appear in a second tool, move it to `lib/` as `AlecTools_*` and switch the first tool to it in the same change. A helper used by one tool stays in that tool.

What exists, use it instead of rewriting it:

- `lib/settings.ms`: a caddy's choices, `AlecTools_rememberSettings section s` / `AlecTools_recallSettings section default`. They last for the current scene only (new/reset/open scene, a Max restart or a reload go back to the defaults); never put them in the ini.
- `lib/common.ms`: `AlecTools_iniFile` (toolbar dock and caddy positions only), `AlecTools_wantsOptions` (Shift or a toolbar right click: open the caddy), `AlecTools_activeViewRect`, `AlecTools_caddyOpen` / `AlecTools_closeCaddy`, `AlecTools_smeView` (a Slate view by name, made and made active), `AlecTools_showPickTag` (a tag in the viewport while a tool waits for an object to be clicked); how a macro starts its tool, one call per macro: `AlecTools_runTool file call`, `AlecTools_runCaddyTool section file fnName` (toggle + Shift/right click for the caddy), `AlecTools_toggleTool`, `AlecTools_runPython file`; `AlecTools_withSnaps f on:` (snap toggle forced and put back, also on an error), `AlecTools_hasVRay` / `AlecTools_hasArnold`, `AlecTools_report summary details` (a batch tool's result). It also puts lib/ and tools/ on Python's `sys.path` at load and reloads `AlecTools_caddy`, so a tool's `.py` just imports it.
- `lib/AlecTools_caddy.py`: the Max-style Qt caddy (also `without_escape`, `escape_down`, `evaluate`, and `NoEscape`: first base class of any other Qt popup, dialog or menu of a tool, so Esc does nothing on it) every tool with options uses (no MAXScript rollouts). Subclass `Caddy(section, title, okTip, cancelTip)`, add rows in `build()` with `add_choice`, `add_toggle(s)`, `add_value` (a box to type in, with the middle-drag ladder), `add_pick`, `add_button`, `add_help(text)` (the mini help: a small info icon whose tooltip is `text`, lines split by `\n`, at the right end of the title band, or the top right corner of a bare caddy; `help_icon(text)` gives the icon to place in a row of one's own; both give None when the mini help is turned off in the toolbar editor), override `ok()` and `closed()`, set `CLICK_AWAY = True` to close on a click elsewhere, `KEY_TOGGLES = True` for a caddy with text boxes whose macro's shortcut pressed again cancels it (its macro also calls `AlecTools_closeIfOpen`); open with `show()`. It opens in the active viewport where it was left, Enter works, Esc does nothing (it crashed Max), only one is open at a time.
- `lib/nodes.ms`: groups (`AlecTools_parts`, `AlecTools_groupObject`, `AlecTools_inClosedGroup`, `AlecTools_isClosedHead`), `AlecTools_isMeasurable`, `AlecTools_localFrame` (rotation without scale), `AlecTools_bounds` (tight bounds in any frame: use it, not `node.min/max` or `selection.center`), `AlecTools_boundsCenter`, `AlecTools_topLevel` (the nodes without an ancestor among them: the ones that move on their own), `AlecTools_isUsdPrim`, `AlecTools_rayHit` / `AlecTools_surfaceAt` / `AlecTools_objectAt` (what is under the mouse).
- `lib/overlay.ms`: `AlecTools_Overlay`, `AlecTools_addBox`, `AlecTools_addDimension`, `AlecTools_drawOverlay` for everything a tool draws in the viewports.
- `lib/overlayTool.ms`: every `tool` that draws calls `AlecTools_beginOverlayTool drawFn ctrlFn` in `on start` and `AlecTools_endOverlayTool()` in `on stop`; never `registerRedrawViewsCallback` or `AlecTools_watchCtrl` directly, or a reload cannot end it.
- `lib/ctrlKey.ms` (+ `ctrlKey.py`): Ctrl as a switch inside a running tool (through overlayTool); the tool calls `AlecTools_ctrlSeen()` first thing in its `freeMove` and `mouseMove`.

Patterns every new tool follows (caddy, toolbar, measuring tools, prompts, icons) are in `docs/patterns.md`: read it before writing or changing a tool.

## Testing

Tests live in `tests/` and create and delete their own temporary objects. Do not save the user's scene.

- **Every test ends by printing the failure count and then one `FAIL <label>` line per failed check, as its last lines** (see `tests/create_test.ms`).
- **With the `3dsmax-mcp` server:** run the tests yourself with `execute_maxscript` (`AlecTools_reload()` first, then `fileIn`). `format` output does not come back: read `getDir #userScripts + "/AlecTools.listener.log"` with a .NET FileStream (`FileShare.ReadWrite`) after `flushLog()`, and return only the non-PASS lines. Define helpers as `global X = fn ...`. Only hand the user checks that need their mouse or keyboard.
- **Without it:** write the `.ms` file and give the user the `fileIn @"..."` line; they paste back only the last lines.
- `execute_python` is blocked while `safe_mode` is on in `mcp_config.ini`. The user changes that setting, not you; do not get around the block.
- Do not claim a tool works before its test has run. Look a command up in the Autodesk MAXScript docs before asking for a check in Max.
- `.tools/python/` (if present) has Python 3.11 with `pyflakes` and `PySide6` for static checks: `.tools/python/python.exe -m pyflakes AlecTools`. It has no `pymxs`.

## Working with the user

- Replies are very short and plain: what changed, what to do next. No internals unless asked.
- Commit, push and build the mzp only when the user says so. Do not suggest them.
- Do not edit `PLAN_*.md` unless asked.

## Verified in Max 2027

Facts checked in Max (MAXScript/Qt quirks, API behavior) are in `docs/max-verified.md`. Read the relevant ones before touching that area (Edit Poly, rays, layers, tool mouse events, viewport drawing, Qt focus/shortcuts, macro saving), and add new ones there, only after they have been checked.
- The most important one: **never call MAXScript from a Qt or .NET timer** (it crashed Max); refresh from Max callbacks instead.
