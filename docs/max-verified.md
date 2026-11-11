# Verified in Max 2027

Facts checked in Max 2027. Add only what has been checked, in the section it belongs to.

## MAXScript language

- Names ignore case: `local box = Box()` makes `Box()` a call of the undefined local ("Call needs function or class, got: undefined"). `name as string` gives the spelling Max met first in the session, not the one written (`#refraction as string` gave "Refraction"): put `toLower` on a name turned into text that is shown or compared.
- `where`, `at` and `by` are keywords (no variables of those names). `convert` and `container` are read-only system names: a local `fn convert` stops with "Cannot assign to read-only variable". `sign` is not a function.
- `someFn().count` is a syntax error ("at ., expected <factor>"); write `(someFn()).count`.
- `copy` of an array gives `OK` (also `copy #(1, 2)`); `deepCopy` gives a real array. Build a new array instead (`a + #()`, `a + #(x)`), or use `deepCopy`.
- `node.children as array` stops with "Unable to convert: #children() to type: Array"; collect them with `for c in node.children collect c`.
- A parenthesized block is compiled before a `fileIn` inside it runs, so a function defined by that `fileIn` must be called with `execute "fn()"` from the same block.
- A global name used in a function binds to the global that existed when the function was compiled. After `globalVars.remove` (the purge) and a new definition, that function still sees the removed one (undefined). The core therefore calls lib functions by name: `(globalVars.get #name)()`.
- `theHold.getUndoNames()` is empty in an MCP call (undo is off there), so undo steps cannot be checked through MCP.

## Macros

- Max saves every `macroScript` it loads as `<category>-<name>.mcr` in `getDir #userMacros` and loads that copy again at startup. A renamed macro therefore showed up twice (old copy + new). `AlecTools_load` deletes the `Alec Tools-*` copies before loading the macros, which Max then saves again. The stale entry stays in the running session until Max restarts.
- macroScript `iconName:` takes a Qt resource icon in every form tried: short (`"MainUI/Snow"`, under `:/Icons`, no size or extension), full path (`":/Icons/MainUI/Snow_24.png"`) and a plugin's resource (`":/chaos/icons/show_layers.svg"`, V-Ray only). The Customize UI icon picker does not list Qt resources.

## Esc and timers

- **The cause of the Esc crashes is `escapeEnable = true`.** Esc then interrupts whatever MAXScript runs next, also a script Max itself runs from Qt (the Listener shows `** interrupted **` in `Macro_SceneExplorer.mcr`, its `isChecked`), and the exception escapes through the Qt binding (the dump: an uncaught C++ exception with a Qt event, Python, `_pymxs` and `Maxscrpt` on the stack). Seen with the toolbar's 250 ms QTimer, at the pick of Mid Between started from its toolbar button, and on the Max Settings caddy.
- `escapeEnable = false` for the whole session, set in `AlecTools_load`, stops it. Switching it off only around a call and back on afterwards does not: the interrupt lands a moment later.
- Experiment (`tests/esc_experiment.py`, a Qt window with none of the guards of `lib/AlecTools_caddy.py`, one session, 2026-11-12). With `escapeEnable` off: 173 ticks of a 250 ms QTimer running MAXScript with Esc held down, 15 times a window hidden on Esc that then ran MAXScript, and 10 `pickPoint` calls from a Qt button ended with Esc (they return `#escape`), no crash. With it on: Max crashed 2 seconds after the first Esc with the timer running.
- A text box (`QLineEdit`) or a button of a caddy does not use Esc and passes it up: an Esc key event sent to one reaches `Caddy.keyPressEvent`, which cancels (checked with a sent event in `tests/caddyPattern_test.ms`, 2026-11-12, on BBox, Distribute, Measure Angle, Grab, Rotate, Scale, Transform Popup, Create Popup, Max Settings and the toolbar editor; a real key press is a hand check).
- A real Esc on an active caddy arrives as a Qt key event only while one of its text boxes has the focus; with the focus on a button or on the caddy itself nothing arrives (hand check, 2026-11-12). The caddy therefore also reads Esc from Windows (`Caddy.check_keys`).
- Seen once (2026-11-12, `escapeEnable` off): a Mid Between `pickObject` ended with Esc printed `** interrupted **` in the Listener, without a crash; the other Esc-ended picks of that session returned normally. Cause not known.
- Esc pressed while a `pickObject` / `pickPoint` waits in a viewport ends the pick, also when the pick was started from a caddy button and the caddy is still the active window (hand check, 2026-11-12, Mid Between).
- Qt timers keep firing while `pickObject`, `startTool` or a native file dialog waits, so a caddy's key watcher runs during them.
- `max select` called from a Qt handler while a `startTool` tool runs (the handler runs inside the tool's wait) ends the tool late: `on stop` fires after the handler has returned, also after a `pickObject` the handler ran (trace in the Listener, 2026-11-12, BBox). A flag meant to mark that stop must stay set until then, not be reset right after `max select`. With the click tool kept quiet until it starts again, the pick from BBox and Distribute leaves the caddy open (hand check, 2026-11-12). Called from a redraw callback instead, the same `max select` fired no `on stop` at all.
- With `escapeEnable` off, Esc cannot stop a runaway script.
- A change in `core/` (where it is set) needs a Max restart, not a Reload.
- No event filter on the whole QApplication, only on your own widgets.

## Qt and Python

- PySide6 6.8.3 and `qtmax.GetQMaxMainWindow()` are available.
- Max turns its shortcuts off while a widget given to `qtmax.DisableMaxAcceleratorsOnFocus(widget, True)` (or a child) has the focus, and on again at focus-out. QLineEdit, QSpinBox, QDoubleSpinBox, QComboBox, QTextEdit and a few others get it on their own. It needs real focus: a QFrame with `grabKeyboard` gets no focus-in, so Max shortcuts (X, Y, Z, `-`) still ran. Letter keys on a panel go through a focused QLineEdit (`tools/grabCaddy.py`).
- A Python method named `move` on a QWidget subclass hides `QWidget.move(x, y)`: the shared caddy placement then stops with "takes 2 positional arguments but 3 were given".
- `(python.import "AlecTools_caddy").show_pick_tag text` calls the Python function with a MAXScript string, quotes included, once lib/ is on `sys.path`. A pymxs list reaches a MAXScript function as an array.
- `getMAXWindowPos()` is in physical pixels, Qt's geometry in logical ones (equal at scale 1.0).

## Viewport tools and picks

- In a `tool` started with `startTool`, `on mousePoint clickno` fires twice for the first click (press = 1, release = 2, same point), then once per click (3, 4, ...).
- A scripted `tool` gets no key events: only mouse handlers, with `ctrlKey` / `shiftKey` / `altKey` true or false at each mouse event. A `WM_MOUSEMOVE` posted (`PostMessageW`) to the window under the cursor did not reach the tool's `freeMove`; moving the real cursor 1 pixel with `SetCursorPos` (and back at the next tick) did. That is how `lib/ctrlKey.py` makes Ctrl switch at once.
- A `tool` started with `startTool` holds the mouse: a click on a caddy (a Qt window over the viewport) reaches the tool's `mousePoint`, and the Qt button is never pressed. The tool hands it on with `AlecTools_caddy.click_caddy()` (the button under the cursor gets `click()`), as in Measure Angle.
- `toolMode.axisConstraints` reads and writes Max's axis constraint (`#x`, `#y`, `#z`, `#xy`, `#yz`, `#zx`); a `tool` can read it on every mouse move, so F5-F8 work inside a running tool without reading keys.
- A pure-Python `QTimer` that posts `WM_RBUTTONDOWN` + `WM_RBUTTONUP` (`PostMessageW`) to `viewport.getHWnd()` ends a running `pickPoint`, which returns `#rightClick` (tests use it).
- A `registerRedrawViewsCallback` function draws in every viewport with `gw.setTransform (matrix3 1)`, `gw.setColor #line`, `gw.polyline`, `gw.text` (world points), `gw.enlargeUpdateRect #whole`, `gw.updateScreen()`; the drawing stays in place when orbiting and goes with `unregisterRedrawViewsCallback fn` + `redrawViews()`.
- `viewport.getViewportFromScreenCoord [x, y]` (screen pixels) gives `#(panel, viewport index, id, hwnd, point inside the viewport, undefined)` for a point on a viewport; with `viewport.activeViewport` and `getViewSize()` it gives the active viewport's screen rectangle (`AlecTools_activeViewRect`).
- `completeRedraw()` is needed after a script assigns a material to objects, or the viewport shows it only after the next click.

## Nodes, bounds and rays

- `nodeGetBoundingBox node frame` is tight on the evaluated geometry (modifiers included) in any frame and takes ~0 ms on 244k vertices. `node.min`/`node.max` is not tight on rotated objects. It gives no usable box on a light.
- `intersectRayScene` does not hit back faces (a ray from inside a box finds nothing), and a ray that starts 100000 cm away hits nothing even with geometry on its path; from ~1000 cm it works. Its hit ray's `dir` is the surface normal.
- `intersectRayEx node ray` works only on Editable Mesh (gives `#(ray, face, bary)`); on a primitive, Editable Poly or a modifier stack it gives undefined. `RayMeshGridIntersect` (`Initialize 10`, `addNode`, `buildGrid`, `intersectRay pos dir false`, `getHitFace 1`) works on all of them, on the evaluated mesh, in world space, ~1-14 ms to build + cast on a box; its face index matches `snapshotAsMesh node`, whose verts are in world space and whose `getEdgeVis` marks the hidden diagonals.
- A camera from a USD stage is a `USDCameraObject` with a `USDXformableController`: `isProperty n #pos` and `isProperty n #scale` are false and reading `n.pos` stops with "Unknown property", while `n.transform` works (its axes had length ~100 on the one checked).
- `numKeys` of a node's PRS transform controller is -1 (it holds no keys itself); its Position / Rotation / Scale subs give the real counts (0 on a new box).
- Layers: `LayerManager.newLayerFromName`, `layer.setParent`/`getParent` (undefined on a top-level layer)/`getNumChildren`/`getChild i`, `layer.addNode node`, `layer.nodes &arr`, and read/write `isHidden`, `isFrozen`, `renderable`, `wireColor` all work; `on` is the inverse of `isHidden`. `addNode` inside `undo on` is undone by `max undo`; it restores the layer the undo system last recorded, so a move done outside an undo context is skipped.
- `InstanceMgr.GetInstances` does not give the nodes in selection order.

## Edit Poly

- Edit Poly modifier: `SetSelection` returns true but the selection stays empty; use `modifier.Select #Vertex bits` (adds to the selection, the bits go in a variable because the argument is by reference) and `modifier.GetSelection`. `ConvertSelection #Face #Vertex` fills the vertex selection and keeps the face selection and the sub-object level.
- Edit Poly modifier: `GetVertex v node:` and `MoveSelection delta` both follow Max's reference coordinate system (`getRefCoordSys()`): with Local, the read gives other values and a move goes along the object's axes; `axis:` and `parent:` change nothing. With `setRefCoordSys #world` around them (restore it after) they read and move in world space.
- Editable Poly: `polyop.moveVert node verts delta node:node` moves in world space.

## Materials and maps

- `classOf` of any OSL map is `OSLMap`; the shader is `map.OSLShaderName` (`"MixColor"`). Map classes (V-Ray): `VRayBitmap`, `VRayColor`, `VRayCompTex` (`sourceA`, `sourceB`), `VRayNormalMap`, `VRayEdgesTex`, `VRayTriplanarTex`, `VRayMultiSubTex`; OSL: `osl_UberBitmap2b`, `osl_MixColor`. Materials: `VRayMtl`, `OpenPBR_Material`, `Multimaterial`. The sky map class is `ai_physical_sky`; `UberBitmap2.osl` is in `<maxRoot>\OSL`.
- Inputs: `VRayNormalMap` `normal_map`, `bump_map`; `VRayTriplanarTex` `texture`; `osl_MixColor` `a_map`, `b_map`, `Mix_map`; `VRayMtl` `texmap_diffuse`, `texmap_bump` (`texmap_bump_multiplier` default 30); `OpenPBR_Material` `base_color_map`, `geometry_normal_map`; `Normal_Bump` `normal_map`.
- `VRayMultiSubTex`: `texmap_num` (default 20) sets the length of `texmap` and its sibling arrays, also past 20; writing `texmap.count` alone leaves the siblings at their old length.
- Bitmaps: `VRayBitmap` `HDRIMapName` (reads back with its slashes changed, compare by file name), `color_space` default 4, set to 0 for data maps; `osl_UberBitmap2b` `filename`, `Filename_ColorSpace` default `"auto"`, `"Raw"` accepted.
- `getPropNames` on a new `VRayMtl` lists only part of it (BRDF options, `texmap_*` with `_on`/`_multiplier`, `option_openPBRMode`) and leaves out the main parameters (diffuse, reflection, glossiness, IOR, ...).
- `OpenPBR_Material` has `emission_weight` (default 0, not in the OpenPBR spec), `emission_luminance` default 1000, maps as `<param>_map` + `_map_on`, and only `geometry_opacity_map` (no constant opacity).
- `ai_standard_surface` maps are `<param>_shader` + `_connected`. Physical's coat weight is `coating`, its thin film is in nm (default 555). Standard defaults: `Specular` 0.9 grey, `specularLevel` 0, `glossiness` 10.
- VRayMtl fog: setting `refraction_fogDepth` changes `refraction_fogMult` with it (depth 2 read back multiplier 0.5, and setting the multiplier to 1 after the depth undid the depth), so the depth alone is the value.
- `VRayBlendMtl baseMtl:x coatMtl_0:y blend_0:c` leaves `coatMtl_0` / `blend_0` at their defaults: use the `coatMtl`, `Blend`, `texmap_blend` arrays.
- A `Multimaterial()` is made with two default sub-materials named "Material #n" (`materialList[i] = undefined` empties the slots).
- A map with several outputs (`numIMultipleOutputChannels` > 1: `osl_UberBitmap2b` has 7, `osl_MixColor` has 1) set directly into a slot from a script stays in the slot, but the Slate view shows no link and deleting its node leaves it there. Through `MultiOutputChannelTexmapToTexmap` (`sourceMap`, `outputChannelIndex`) the view links it, makes no extra node, and deleting the map's node empties the slot. A slot set from a script after both nodes exist is linked for a single-output map. Deleting the input's node and reading the slot tells from a script whether the view knows a link.

## Slate Material Editor

- `sme` view: `view.GetNode i`, `view.GetSelectedNodes()` (not in click order) and `CreateNode ref pos` give nodes with `.position` (a point2) and `.reference`. `n.position.x` chained stops with "Unknown property: pos"; read `local p = n.position` first. `CreateNode` snaps the node to a grid of about 20 units (made at [100, 200], it reads [93, 198]).
- The view has no pan or zoom calls (`NodeView` has only node, selection, layout and zoom-extents calls), and they are not readable. A fresh view is at zoom 1.0 (a node moved by 300 moves 300 px).
- Connecting maps (`a_map` / `sourceA` set to a map that is a node of the view, then `CreateNode`) makes the view move the input nodes, so they can end up level.
- A node's `hideUnusedNodeSlots` can be set on the node `view.CreateNode` returns and reads back true; a new map or Multi/Sub node reads false. A float controller (`Linear_Float`) is orange in the Navigator.
- The graph is a Win32 window of class `DragDropWindow` (child of the `MaxSDK::QMaxWinHost` widget). Its `QWidget.grab()` is black; `widget.screen().grabWindow(0, x, y, w, h)` of the same region gives real pixels while the editor is on top.
- A node at the mouse (`tools/smeCursor.py`): a right click on an empty spot opens a Qt `QMenu` (Materials, Maps, Controllers, Sample Slots, ...) whose entries create the node centered on the click. `PostMessageW` of `WM_RBUTTONDOWN` + `WM_RBUTTONUP` with client coordinates opens it without moving the real mouse; over a node the menu is another one (no Materials / Maps).
- That menu runs its own loop inside the processing of the posted click, so a script that calls `processEvents()` is stuck there until the menu is closed (it froze Max for 2 minutes): drive it from a `QTimer` that only runs Qt and closes the menus at a deadline. The submenus are rebuilt when they open, so look the menu up again at every tick (`QApplication.activePopupWidget()` is the innermost open one). `QAction.trigger()` on the entry does nothing, but `setActiveAction(action)` + `QTest.keyClick(menu, Key_Right)` (open) / `Key_Return` (choose) does; a `QTest.mouseClick` on an entry closed the menu without choosing.
- Making any class at the mouse: the menu makes a plain Max map (Maps > General > Checker) as a placeholder at the click; its `.position` is where to `CreateNode` the real item after the placeholder is deleted. This needs one Max-standard menu entry for every class (no V-Ray menu names, and not the "Choose HDR image" file dialog that Maps > V-Ray > V-Ray Bitmap opens), about 180-200 ms from click to node.
- A node's right click menu has Show/Hide Slots > Maps > Hide All (`tools/smeCursor.py` can choose it at a screen point over the node); it makes an Uber Bitmap node shorter and `node.height` shows that at once. A script has no call for it: `hideUnusedNodeSlots` and `ShowAllAdditionalParams` are other things.

## Lights

- `Arnold_Light`: `useColor`, `usePreset`, `useKelvin`, `useTexmap` are independent booleans for a script (setting one does not clear the others), and it has no `excludeList`. A new one made by a script starts with the values of the last one made in the session (`useKelvin` and `color` were seen), not with its defaults. Deleting the target of one with `targeted` on deletes the light too.
- `VRayLight`: `sizeLength`/`sizeWidth` are full sizes, `size0`/`size1` half sizes on a Plane (`size0` is the radius on a Disc or Sphere). `multiplier` set before `normalizeColor` did not read back as set; set `normalizeColor` first. In Temperature mode its `color` reads as that temperature, at once after `color_temperature` changes (3200 K: 255 175.7 76.5, 6500 K: white).
- `VRayLight` mesh: setting `mesh_source` keeps the source node, even with `mesh_replaceOnPick` on. A node used as `mesh_source` cannot be linked to that light ("Cannot link: would create dependency loop").
- `targetSpot()` and `VRaySun()` made by a script have `target` undefined.
- A light's Shadows On checkbox is `node.baseObject.castShadows` (macro recorder); `node.castShadows` is the Object Properties flag of the node.
- Arnold GPU vs V-Ray GPU renders (exposure control off): with Normalize off, a Quad, Disc or Point of gain G and a VRayLight in Default units with multiplier G match within a few percent, no factor of 2. Normalize on a Quad divides by its area in square scene units (cm) and matches. An Arnold Point or Spot with radius 0 and Normalize off renders nothing.
- Arnold's spot `aspect_ratio` 0.5 comes out wide along world X where Max's `aspect` 0.5 comes out tall along Y. An Arnold cylinder's axis lies along its local Y, not Z (seen by the user in the viewport against a Cylinder).
