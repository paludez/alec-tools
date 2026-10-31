# Alec Tools

Personal tools for **3ds Max 2027** (2027.1, scene units in cm). Used through macroScript buttons and shortcuts, category "Alec Tools". Only Max 2027 matters; ignore other versions.

Renderers: the user works with **V-Ray and Arnold** (MAXtoA is installed). Tools that touch materials, maps, lights or render settings must not assume Standard/Physical materials. What the user actually uses:

- **V-Ray:** the V-Ray material (VRayMtl) and **OpenPBR**. Almost exclusively **V-Ray GPU**, so every material and map a tool creates or handles must work on GPU.
- **Arnold:** only **OpenPBR**. Maps are **OSL maps**, not Arnold's own maps, unless that is strictly necessary. It must work on the GPU too.

Check the real class names in Max before using them (do not write them from memory), and do not assume both renderers are installed on every machine, e.g. the work laptop.

## Layout

```
AlecTools/            payload, what gets installed
  core/               AlecTools_core.ms: AlecTools_root, AlecTools_path, AlecTools_purge, AlecTools_removeSavedMacros, AlecTools_load, AlecTools_reload
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
- **Editable Poly and the Edit Poly modifier do not have exactly the same commands**, and the same goes for Editable Mesh / Edit Mesh and for a spline shape / the Edit Spline modifier. For example the selection call differs (`obj.EditablePoly.SetSelection` vs `modifier.SetSelection`), and `polyop.*` queries are for Editable Poly, not for the Edit Poly modifier. Never assume a command that works on one works on the other: check it on both before writing the code (a check `.ms` that creates the object, runs the command and prints the result, run by the user), and cover both in the test.
- One tool at a time: write it, the user tests it in Max, commit only when the user asks.

## Shared code (lib/)

Before writing a helper in a tool, look in `lib/` for one that already does it. When the same logic would appear in a second tool, move it to `lib/` as `AlecTools_*` and switch the first tool to it in the same change. A helper used by one tool stays in that tool.

What exists, use it instead of rewriting it:

- `lib/settings.ms`: a dialog's choices, `AlecTools_rememberSettings section s` / `AlecTools_recallSettings section default`. They last for the current scene only (new/reset/open scene, a Max restart or a reload go back to the defaults); never put them in the ini.
- `lib/common.ms`: `AlecTools_iniFile` (dialog positions only), `AlecTools_openCaddy` (opens a dialog where the user left it; the rollout saves the place in `on moved` with `AlecTools_saveDialogPos`), `AlecTools_EscWatch` / `AlecTools_escPressed` (Esc closes a caddy: a `timer` in the rollout, never `keyboard.escPressed` directly, or the Esc that cancels a pick closes the caddy too).
- `lib/nodes.ms`: groups (`AlecTools_parts`, `AlecTools_groupObject`, `AlecTools_inClosedGroup`, `AlecTools_isClosedHead`), `AlecTools_isMeasurable`, `AlecTools_localFrame` (rotation without scale), `AlecTools_bounds` (tight bounds in any frame: use it, not `node.min/max` or `selection.center`), `AlecTools_rayHit` / `AlecTools_surfaceAt` / `AlecTools_objectAt` (what is under the mouse).
- `lib/overlay.ms`: `AlecTools_Overlay`, `AlecTools_addBox`, `AlecTools_addDimension`, `AlecTools_drawOverlay` for everything a tool draws in the viewports.
- `lib/overlayTool.ms`: every `tool` that draws calls `AlecTools_beginOverlayTool drawFn ctrlFn` in `on start` and `AlecTools_endOverlayTool()` in `on stop`; never `registerRedrawViewsCallback` or `AlecTools_watchCtrl` directly, or a reload cannot end it.
- `lib/ctrlKey.ms`: Ctrl as a switch inside a running tool (through overlayTool).

Patterns a new tool follows, so tools behave alike:

- A tool with options and a preview is a caddy (see `bbox.ms`, `distribute.ms`): settings struct kept with lib/settings.ms, a session struct, preview with `undo off`, OK redoes it in one `undo "Name" on`, Cancel/Esc/close restores. The tool file closes a caddy still open from the last load before defining its rollout again.
- A tool that measures in the viewport is a `tool` started with `startTool` (see `measure*.ms`): the first click comes twice, skip `clickno == 2`; right click/Esc ends and clears.
- Status messages go to `displayTempPrompt` / `replacePrompt`, starting with the tool's name, in English like the rest of the UI. Lengths through `units.formatValue`.
- A macro gets an `iconName:` when the user wants one (find it with the Icon Browser macro); shortcut-only macros can go without.
- `audit.md` lists known problems and planned cleanups; strike through an item when it is done, and check it before adding a helper it already plans.

## Testing

The user runs the tests and checks in Max, not Claude. Claude writes the `.ms` file and gives the `fileIn @"..."` line; the user runs it and pastes the Listener output back. Do not run anything through the `3dsmax-mcp` MCP server unless the user asks for it. Do not claim a tool works before the user has run its test. Test files live in `tests/` and create and delete their own temporary objects. Do not save the user's scene.

## Verified in Max 2027 (add only what has been checked)

- `getDir #userScripts` and `getDir #userStartupScripts` exist.
- A parenthesized block is compiled before a `fileIn` inside it runs, so a function defined by that `fileIn` must be called with `execute "fn()"` from the same block.
- `sort` works on an array of strings.
- `toolMode.commandMode` is `#pick` while a pickbutton picks. The Esc that cancels the pick shows in a 50 ms timer only after the mode has already left `#pick`.
- A global name used in a function binds to the global that existed when the function was compiled. After `globalVars.remove` (the purge) and a new definition, that function still sees the removed one (undefined). The core therefore calls lib functions by name: `(globalVars.get #name)()`.
- Edit Poly modifier: `SetSelection` returns true but the selection stays empty; use `modifier.Select #Vertex bits` (adds to the selection, the bits go in a variable because the argument is by reference) and `modifier.GetSelection`. `ConvertSelection #Face #Vertex` fills the vertex selection and keeps the face selection and the sub-object level. `modifier.MoveSelection delta` without `axis:` moves in world space; read positions back with `modifier.GetVertex v node:node` (world). Editable Poly: `polyop.moveVert node verts delta node:node` moves in world space.
- `nodeGetBoundingBox node frame` is tight on the evaluated geometry (modifiers included) in any frame and takes ~0 ms on 244k vertices. `node.min`/`node.max` is not tight on rotated objects.
- Max saves every `macroScript` it loads as `<category>-<name>.mcr` in `getDir #userMacros` and loads that copy again at startup. A renamed macro therefore showed up twice (old copy + new). `AlecTools_load` deletes the `Alec Tools-*` copies before loading the macros, which Max then saves again. The stale entry stays in the running session until Max restarts.
- `intersectRayScene` does not hit back faces (a ray from inside a box finds nothing), and a ray that starts 100000 cm away hits nothing even with geometry on its path; from ~1000 cm it works. Its hit ray's `dir` is the surface normal.
- `intersectRayEx node ray` works only on Editable Mesh (gives `#(ray, face, bary)`); on a primitive, Editable Poly or a modifier stack it gives undefined. `RayMeshGridIntersect` (`Initialize 10`, `addNode`, `buildGrid`, `intersectRay pos dir false`, `getHitFace 1`) works on all of them, on the evaluated mesh, in world space, ~1-14 ms to build + cast on a box; its face index matches `snapshotAsMesh node`, whose verts are in world space and whose `getEdgeVis` marks the hidden diagonals.
- Layers: `LayerManager.newLayerFromName`, `layer.setParent`/`getParent` (undefined on a top-level layer)/`getNumChildren`/`getChild i`, `layer.addNode node`, `layer.nodes &arr`, and read/write `isHidden`, `isFrozen`, `renderable`, `wireColor` all work; `on` is the inverse of `isHidden`. `addNode` inside `undo on` is undone by `max undo`; it restores the layer the undo system last recorded, so a move done outside an undo context is skipped.
- macroScript `iconName:` takes a Qt resource icon in every form tried: short (`"MainUI/Snow"`, under `:/Icons`, no size or extension), full path (`":/Icons/MainUI/Snow_24.png"`) and a plugin's resource (`":/chaos/icons/show_layers.svg"`, V-Ray only). The Customize UI icon picker does not list Qt resources.
- Python: PySide6 6.8.3 and `qtmax.GetQMaxMainWindow()` are available.
- In a `tool` started with `startTool`, `on mousePoint clickno` fires twice for the first click (press = 1, release = 2, same point), then once per click (3, 4, ...).
- A `registerRedrawViewsCallback` function draws in every viewport with `gw.setTransform (matrix3 1)`, `gw.setColor #line`, `gw.polyline`, `gw.text` (world points), `gw.enlargeUpdateRect #whole`, `gw.updateScreen()`; the drawing stays in place when orbiting and goes with `unregisterRedrawViewsCallback fn` + `redrawViews()`.
