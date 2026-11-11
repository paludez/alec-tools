# Alec Tools

Personal tools for **3ds Max 2027** (2027.1, scene units in cm), used through macroScript buttons and shortcuts, category "Alec Tools". Only Max 2027 matters.

Renderers: **V-Ray and Arnold** (MAXtoA installed). Tools that touch materials, maps, lights or render settings must not assume Standard/Physical materials.

- **V-Ray:** VRayMtl and **OpenPBR**, almost exclusively **V-Ray GPU**: every material and map a tool creates must work on GPU.
- **Arnold:** only **OpenPBR**, with **OSL maps** (not Arnold's own maps unless strictly necessary). Must work on GPU too.

Check real class names in Max before using them, and do not assume both renderers are installed on every machine (`AlecTools_hasVRay` / `AlecTools_hasArnold`).

## Layout

```
AlecTools/            payload, what gets installed
  core/               AlecTools_core.ms: AlecTools_root, AlecTools_path, AlecTools_load, AlecTools_reload
  lib/                shared helpers (AlecTools_*), loaded before the macros
  tools/              one file per tool, holds the logic, loaded on demand by its macro
  macros/             thin .mcr files: buttons and shortcuts only, they call into tools/
installer/            AlecTools_Load.ms (startup loader), AlecTools_install.ms + mzp.run
tests/                *_test.ms, run inside Max, print PASS/FAIL
tools/build_mzp.ps1   builds AlecTools.mzp in the repo root (build.bat)
docs/                 patterns.md, max-verified.md
```

## Deployment

- This PC: live. `<userStartupScripts>\AlecTools_Load.ms` loads from the folder in `<userScripts>\AlecTools.root.txt` (the `AlecTools` folder here). After editing, the user presses the "Reload Alec Tools" macro. A change in `core/` needs a Max restart.
- Work laptop (no admin): the user downloads `AlecTools.mzp` from the private GitHub repo `paludez/alec-tools` and drags it into Max.
- Commit, mzp build and push happen only through the user's `/release` skill: **never ask, suggest or remind about them.**
- Never copy files into `usermacros`, never hardcode `getDir #userMacros` or `D:` paths. Reach files with `AlecTools_path "tools/x.ms"`. Only exception: `AlecTools_removeSavedMacros` in the core.

## Rules for code

- **Only the user writes Romanian. Everything of mine is English**: replies, code, comments, UI text, tests, commits, docs.
- MAXScript for macros and anything that touches the scene. Python (pymxs) for files, images, JSON and Qt UI.
- Names: `AlecTools_` for shared helpers, `Alec<ToolName>_` for a tool's own functions.
- Short functions, no unused functions, no dead or commented-out code.
- No empty `try ... catch ()`. Let errors reach the Listener, or report `getCurrentException()`.
- Macros stay thin: one call into `lib/common.ms`, nothing more.
- **Every caddy (floating Qt panel) is a toggle.** Running its macro or shortcut again closes it, also while typing in one of its text boxes (the macro calls `AlecTools_toggleTool` / `AlecTools_switchTool` / `AlecTools_runCaddyTool`; `KEY_TOGGLES = True` for a caddy with text boxes).
- **`escapeEnable = false` for the whole session (set in `AlecTools_load`) must stay, and no code turns it back on.** With it on, Esc near MAXScript that runs from Qt or Python crashes Max. With it off, Esc is safe: a timer running MAXScript, a window closing on Esc and picks ended with Esc were all tested (`tests/esc_experiment.py`, details in `docs/max-verified.md`).
- **Esc on a caddy is Cancel** (`Caddy.keyPressEvent` from one of its text boxes, `Caddy.check_keys` when the caddy is active without one; both call `cancel()`), and Esc in a viewport cancels the click tool or pick a caddy runs there. Menus, dialogs and Qt popups close on Esc the plain Qt way. No guard around Esc: callbacks call MAXScript directly. A viewport `tool` (Measure and friends) gets no Esc code of its own; it ends with a right click. **Before touching Esc or a caddy's keys, read "Esc on a caddy" in `docs/patterns.md`**; a passing test does not prove a real key press, so such a change ends with hand checks.
- Prefer Max callbacks (`NodeEventCallback`, `callbacks.addScript`) to a Qt timer for refreshing; a timer that runs MAXScript is allowed.
- **Editable Poly vs Edit Poly modifier, Editable Mesh vs Edit Mesh, spline vs Edit Spline do not share all commands** (e.g. `polyop.*` is for Editable Poly only). Check on both before writing code, and cover both in the test.
- One tool at a time.

## Shared code (lib/)

Look in `lib/` before writing a helper. When the same logic would appear in a second tool, move it to `lib/` as `AlecTools_*` and switch the first tool in the same change.

- `settings.ms`: `AlecTools_rememberSettings section s` / `AlecTools_recallSettings section default` (kept in memory, forgotten when the scene changes, never in the ini).
- `common.ms`: `AlecTools_iniFile` (toolbar dock, caddy positions, Max Settings), `AlecTools_wantsOptions`, `AlecTools_activeViewRect`, `AlecTools_caddyOpen` / `AlecTools_closeCaddy` / `AlecTools_overCaddy`, `AlecTools_hasSelection`, `AlecTools_hint`, `AlecTools_withPickTag`, `AlecTools_withSnaps`, `AlecTools_smeView`, `AlecTools_hasVRay` / `AlecTools_hasArnold`, `AlecTools_report`. A macro starts its tool with one call: `AlecTools_runTool`, `AlecTools_toggleTool`, `AlecTools_switchTool`, `AlecTools_runCaddyTool`, `AlecTools_runPython`.
- `AlecTools_caddy.py`: the Qt caddy every tool with options uses (no MAXScript rollouts). Subclass `Caddy`, add rows with `add_choice`, `add_toggle(s)`, `add_value`, `add_pick`, `add_button`, `add_help`; override `ok()` / `closed()`; `CLICK_AWAY`, `KEY_TOGGLES`, `ENTER_WATCH`; open with `show()`. Other Qt popups, dialogs and menus are plain Qt classes.
- `viewportClicks.ms`: `AlecTools_clickLoop` / `AlecTools_clickEnd` / `AlecTools_clickPause`, left click = OK and right click = Cancel in a viewport while a caddy is open.
- `nodes.ms`: groups (`AlecTools_parts`, `AlecTools_groupObject`, `AlecTools_inClosedGroup`, `AlecTools_isClosedHead`), `AlecTools_isMeasurable`, `AlecTools_localFrame`, `AlecTools_bounds` (use it, not `node.min/max` or `selection.center`), `AlecTools_boundsCenter`, `AlecTools_topLevel`, `AlecTools_useCenter`, `AlecTools_transformAbout`, `AlecTools_isUsdPrim`, `AlecTools_rayHit` / `AlecTools_surfaceAt` / `AlecTools_objectAt`.
- `overlay.ms`: `AlecTools_Overlay`, `AlecTools_addBox`, `AlecTools_addDimension`, `AlecTools_drawOverlay` for everything drawn in viewports.
- `overlayTool.ms`: every drawing `tool` calls `AlecTools_beginOverlayTool drawFn ctrlFn` in `on start` and `AlecTools_endOverlayTool()` in `on stop`; never `registerRedrawViewsCallback` or `AlecTools_watchCtrl` directly.
- `ctrlKey.ms` (+ `.py`): Ctrl as a switch inside a running tool; call `AlecTools_ctrlSeen()` first in `freeMove` and `mouseMove`.

Read before writing or changing a tool:

- `docs/patterns.md`: how tools are built (caddy, toolbar, macros, measuring tools, prompts, icons).
- `docs/max-verified.md`: facts checked in Max 2027, by area. Read the relevant section first; add new ones only after checking.

## Testing

- **I run the tests myself** with the `max-test` skill (through `3dsmax-mcp`); it reloads Alec Tools, runs the test in an empty scene and returns only the failures. Only checks that need the user's mouse or keyboard go to the user.
- Tests live in `tests/`, create and delete their own objects, never save the user's scene.
- **Every test ends with the failure count, then one `FAIL <label>` line per failed check, as its last lines.**
- `execute_python` is blocked by `safe_mode` in `mcp_config.ini`; the user changes it, not me.
- Check the Autodesk MAXScript docs before asking the user for a check. Do not claim a tool works before its test ran.
- Static check of `.py` files: `.tools/python/python.exe -m pyflakes AlecTools` (no `pymxs`/`qtmax` there).
