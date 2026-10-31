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

- MAXScript for macros and anything that touches the scene. Python (pymxs) for files, images, JSON and complex UI.
- Names: `AlecTools_` for shared helpers, `Alec<ToolName>_` for a tool's own functions (e.g. `AlecSmartVis_`).
- Short functions, no unused functions, no dead code, no commented-out code.
- No empty `try ... catch ()`. Let errors reach the Listener, or report `getCurrentException()`.
- Macros stay thin: they call a tool function, nothing more.
- **Editable Poly and the Edit Poly modifier do not have exactly the same commands**, and the same goes for Editable Mesh / Edit Mesh and for a spline shape / the Edit Spline modifier. For example the selection call differs (`obj.EditablePoly.SetSelection` vs `modifier.SetSelection`), and `polyop.*` queries are for Editable Poly, not for the Edit Poly modifier. Never assume a command that works on one works on the other: check it on both before writing the code (a check `.ms` that creates the object, runs the command and prints the result, run by the user), and cover both in the test.
- One tool at a time: write it, the user tests it in Max, commit only when the user asks.

## Testing

The user runs the tests and checks in Max, not Claude. Claude writes the `.ms` file and gives the `fileIn @"..."` line; the user runs it and pastes the Listener output back. Do not run anything through the `3dsmax-mcp` MCP server unless the user asks for it. Do not claim a tool works before the user has run its test. Test files live in `tests/` and create and delete their own temporary objects. Do not save the user's scene.

## Verified in Max 2027 (add only what has been checked)

- `getDir #userScripts` and `getDir #userStartupScripts` exist.
- A parenthesized block is compiled before a `fileIn` inside it runs, so a function defined by that `fileIn` must be called with `execute "fn()"` from the same block.
- `sort` works on an array of strings.
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
