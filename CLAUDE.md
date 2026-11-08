# Alec Tools

Personal tools for **3ds Max 2027** (2027.1, scene units in cm), used through macroScript buttons and shortcuts, category "Alec Tools". Only Max 2027 matters.

Renderers: **V-Ray and Arnold** (MAXtoA installed). Tools that touch materials, maps, lights or render settings must not assume Standard/Physical materials.

- **V-Ray:** VRayMtl and **OpenPBR**, almost exclusively **V-Ray GPU**: every material and map a tool creates must work on GPU.
- **Arnold:** only **OpenPBR**, with **OSL maps** (not Arnold's own maps unless strictly necessary). Must work on GPU too.

Check real class names in Max before using them, and do not assume both renderers are installed on every machine.

## Layout

```
AlecTools/            payload, what gets installed
  core/               AlecTools_core.ms: AlecTools_root, AlecTools_path, AlecTools_purge, AlecTools_removeSavedMacros, AlecTools_openLog, AlecTools_load, AlecTools_reload
  lib/                shared helpers (AlecTools_*), auto-loaded before the macros
  tools/              one file per tool, holds the logic, loaded on demand by its macro
  macros/             thin .mcr/.ms files: buttons and shortcuts only, they call into tools/
installer/            AlecTools_Load.ms (startup loader), AlecTools_install.ms + mzp.run
tests/                *_test.ms, run inside Max, print PASS/FAIL
tools/build_mzp.ps1   builds dist/AlecTools.mzp (build.bat)
```

## Deployment

- This PC: live. `<userStartupScripts>\AlecTools_Load.ms` loads from the folder in `<userScripts>\AlecTools.root.txt` (the `AlecTools` folder here). After editing, the user presses the "Reload Alec Tools" macro.
- Work laptop (no admin): the user downloads `AlecTools.mzp` from the private GitHub repo `paludez/alec-tools` and drags it into Max.
- Commit, mzp build and push happen only through the user's `/release` skill.
- Never copy files into `usermacros`, never hardcode `getDir #userMacros` or `D:` paths. Reach files with `AlecTools_path "tools/x.ms"`. Only exception: `AlecTools_removeSavedMacros` in the core.

## Rules for code

- **Only the user writes Romanian. Everything of mine is English**: replies, code, comments, UI text, tests, commits, docs.
- MAXScript for macros and anything that touches the scene. Python (pymxs) for files, images, JSON and complex UI.
- Names: `AlecTools_` for shared helpers, `Alec<ToolName>_` for a tool's own functions.
- Short functions, no unused functions, no dead or commented-out code.
- No empty `try ... catch ()`. Let errors reach the Listener, or report `getCurrentException()`.
- Macros stay thin: they call a tool function, nothing more.
- **Every caddy (floating Qt panel) is a toggle and never uses Esc.** Running its macro or shortcut again closes it, also while typing in one of its text boxes (`AlecTools_closeIfOpen` in the macro, `KEY_TOGGLES = True` for a caddy with text boxes). No caddy, menu or dialog closes on Esc: it crashed Max.
- **Editable Poly vs Edit Poly modifier, Editable Mesh vs Edit Mesh, spline vs Edit Spline do not share all commands** (e.g. `obj.EditablePoly.SetSelection` vs `modifier.SetSelection`; `polyop.*` is for Editable Poly only). Check on both before writing code, and cover both in the test.
- One tool at a time. The user decides about commits, pushes and the mzp: **never ask, suggest or remind about them.**

## Shared code (lib/)

Look in `lib/` before writing a helper. When the same logic would appear in a second tool, move it to `lib/` as `AlecTools_*` and switch the first tool in the same change.

- `settings.ms`: `AlecTools_rememberSettings section s` / `AlecTools_recallSettings section default` (current scene only, never in the ini).
- `common.ms`: `AlecTools_iniFile` (toolbar dock and caddy positions only), `AlecTools_wantsOptions`, `AlecTools_activeViewRect`, `AlecTools_caddyOpen` / `AlecTools_closeCaddy`, `AlecTools_smeView`, `AlecTools_showPickTag`, `AlecTools_withSnaps`, `AlecTools_hasVRay` / `AlecTools_hasArnold`, `AlecTools_report`. A macro starts its tool with one call: `AlecTools_runTool`, `AlecTools_runCaddyTool section file fnName`, `AlecTools_toggleTool`, `AlecTools_runPython`.
- `AlecTools_caddy.py`: the Qt caddy every tool with options uses (no MAXScript rollouts). Subclass `Caddy`, add rows with `add_choice`, `add_toggle(s)`, `add_value`, `add_pick`, `add_button`, `add_help`; override `ok()` / `closed()`; `CLICK_AWAY`, `KEY_TOGGLES`; open with `show()`. Any other Qt popup, dialog or menu takes `NoEscape` as first base class.
- `nodes.ms`: groups (`AlecTools_parts`, `AlecTools_groupObject`, `AlecTools_inClosedGroup`, `AlecTools_isClosedHead`), `AlecTools_isMeasurable`, `AlecTools_localFrame`, `AlecTools_bounds` (use it, not `node.min/max` or `selection.center`), `AlecTools_boundsCenter`, `AlecTools_topLevel`, `AlecTools_isUsdPrim`, `AlecTools_rayHit` / `AlecTools_surfaceAt` / `AlecTools_objectAt`.
- `overlay.ms`: `AlecTools_Overlay`, `AlecTools_addBox`, `AlecTools_addDimension`, `AlecTools_drawOverlay` for everything drawn in viewports.
- `overlayTool.ms`: every drawing `tool` calls `AlecTools_beginOverlayTool drawFn ctrlFn` in `on start` and `AlecTools_endOverlayTool()` in `on stop`; never `registerRedrawViewsCallback` or `AlecTools_watchCtrl` directly.
- `ctrlKey.ms` (+ `.py`): Ctrl as a switch inside a running tool; call `AlecTools_ctrlSeen()` first in `freeMove` and `mouseMove`.

Patterns for new tools (caddy, toolbar, measuring tools, prompts, icons): `docs/patterns.md`. Read it before writing or changing a tool.

## Testing

- **I run the tests myself** through `3dsmax-mcp` (`execute_maxscript`): `AlecTools_reload()` first, then `fileIn`. `format` output does not come back: read `getDir #userScripts + "/AlecTools.listener.log"` with a .NET FileStream (`FileShare.ReadWrite`) after `flushLog()`, return only non-PASS lines. Define helpers as `global X = fn ...`. Only checks that need the user's mouse or keyboard go to the user.
- Tests live in `tests/`, create and delete their own objects, never save the user's scene.
- **Every test ends with the failure count, then one `FAIL <label>` line per failed check, as its last lines.**
- `execute_python` is blocked by `safe_mode` in `mcp_config.ini`; the user changes it, not me.
- Check the Autodesk MAXScript docs before asking the user for a check. Do not claim a tool works before its test ran.
- Static check of `.py` files: `.tools/python/python.exe -m pyflakes AlecTools` (no `pymxs`/`qtmax` there).

## Verified in Max 2027

`docs/max-verified.md` has facts checked in Max (Edit Poly, rays, layers, tool mouse events, viewport drawing, Qt focus/shortcuts, macro saving). Read the relevant ones before touching that area; add new ones only after checking.
- **Never call MAXScript from a Qt or .NET timer** (it crashed Max); refresh from Max callbacks.
