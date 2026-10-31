# Alec Tools audit (2026-10-31)

Scope: the whole payload (core, lib, macros, all 15 tools), the installer and the build. Tests were not audited.
Done items are struck through, with what was done and whether it was tested in Max.

No function is defined and left unused (checked with grep).

## Bugs / risks

1. ~~**Reload while a viewport tool runs:** the purge removed the globals but left the .NET Ctrl timer and the redraw
   callback running, which then called undefined functions.~~
   **Done, tested:** `AlecTools_load` calls `AlecTools_endOverlayTool()` (looked up by name) before the purge.
   Test in `tests/core_test.ms`. The Reload button cannot be pressed while a tool runs, so this matters for a reload
   from the Listener and for the tests.

2. ~~**Esc during a pick closed the whole caddy** (BBox, Distribute), and an Esc held after a Measure Angle command
   could close its dialog.~~
   **Done, tested:** `AlecTools_EscWatch` / `AlecTools_escPressed` in `lib/common.ms`: Esc counts only as a new press,
   and only when `toolMode.commandMode` was not `#pick` on the previous tick (the Esc that cancels a pick reaches the
   timer after the mode has left `#pick`).

3. ~~**Mid Between, objects, Bounding box:** `selection.center` comes from `node.min/max`, which is not tight on
   rotated objects.~~
   **Done, tested:** `AlecTools_bounds` on the selection, in world. Test with a rotated box in `tests/midBetween_test.ms`.

4. ~~**Mid Between on Edit Poly changed the user's vertex selection:** `ConvertSelection` added the vertices of the
   edges/faces to it, and it stayed after Cancel.~~
   **Done, tested:** the vertices are read through `GetEdgeVertex` / `GetFaceDegree` / `GetFaceVertex`, the
   selection is not touched. Test in `tests/midBetween_test.ms`.

5. ~~**BBox left an empty "BBox helpers" layer** after Cancel.~~
   **Done, tested:** the session remembers whether the layer was there (`hadLayer`); Cancel removes it if not.
   Test in `tests/bbox_test.ms`.

6. ~~**Hover in orthographic viewports** might hit nothing (a ray that starts very far away).~~
   **Checked, not a problem:** BBox and Gap work in Top/Front/Left; Clearance and Angle Edges/Faces are used in perspective.

7. ~~**Distribute: an object deleted while the caddy is open** made the next change in the caddy fail.~~
   **Done, tested:** `AlecDist_prune` drops deleted objects (and unpicks a deleted anchor or axes object) before
   every preview; with fewer than 2 left the caddy closes. Test in `tests/distribute_test.ms`.

8. ~~**The MeasureAngle macro read Shift after `fileIn`.**~~
   **Done, tested:** Shift is read first.

9. ~~**The installer deleted the old install before copying**, so a copy that failed half way left the laptop without tools.~~
   **Done, not tested:** it copies to `AlecTools.new`, then deletes the old folder and renames the new one.
   Needs a new `AlecTools.mzp` to test.

10. ~~**`moveToLayer.py`:** `QGuiApplication.screenAt(pos)` gives `None` when the cursor is on no screen, and it crashed.~~
    **Done, tested:** falls back to `primaryScreen()`.

## Performance

11. ~~**BBox made every cage again on each tick of the Offset spinner.**~~
    **Done, tested:** `AlecBBox_Spec` + `AlecBBox_fitCage`: Offset resizes the cages in place; when their number
    changes (Copy with an offset of 0), they are made again. Test in `tests/bbox_test.ms`.
12. ~~**Measure Angle, Edges/Faces:** every new object under the mouse took a `snapshotAsMesh` and a
    `RayMeshGridIntersect`, also when moving back and forth between the 2 objects of a measure.~~
    **Done, tested:** the last 2 objects are cached (`AlecAngle_pickCache`). Test in `tests/measureAngleDialog_test.ms`.
13. ~~**Measure Clearance / BBox / Gap / Angle cast a ray into the scene on every mouse move.**~~
    **Done, tested:** `AlecTools_hoverMoved` in `lib/overlayTool.ms`: a ray only when the mouse moved 2 pixels or more.
14. ~~**`AlecTools_bounds`** took the box of `nodes[1]` twice.~~
    **Done, tested:** rewritten on `AlecTools_pointsBounds` (item 17).
15. ~~**Icon Browser** opened on the slowest source (all Qt resources).~~
    **Done, tested:** it opens on the last source of this scene (`lib/settings.ms`).

## Simplifications

16. ~~**Settings in the INI were written 4 times** (Distribute, Mid Between, BBox, Measure Angle).~~
    **Done, tested, differently:** settings are no longer in the INI but in memory, for the current scene only
    (`lib/settings.ms`): a new / reset / opened scene, a Max restart or a reload go back to each tool's defaults.
    Dialog positions stay in the INI. Test in `tests/settings_test.ms`.
17. ~~**Min/max over 3 axes was repeated** (`AlecTools_bounds`, Distribute dims, Mid Between).~~
    **Done, tested:** `AlecTools_pointsBounds` in `lib/nodes.ms`.
18. ~~**The average of points was written twice** (Measure, Mid Between).~~
    **Done, tested:** `AlecTools_average` in `lib/nodes.ms`.
19. ~~**Two recursions over the members of a group** (Move to Layer, `lib/nodes.ms`).~~
    **Done, tested:** `AlecTools_groupMembers` in `lib/nodes.ms`. Test in `tests/nodes_test.ms`.
20. ~~**The Measure* tools copied the same start/stop code.**~~
    **Done, tested:** `lib/overlayTool.ms`, used by measure, measureBBox, measureClearance, measureGap, measureAngle
    and the 2 tools of measureAngleDialog.
21. ~~**The caddies repeated their opening code.**~~
    **Done, tested:** `AlecTools_openCaddy` + the shared Esc. The timer, `on moved` and the destroyDialog on load stay in
    each rollout (MAXScript cannot add handlers to a rollout from outside).

## Consistency

22. ~~**Mixed languages:** Match Material / Get Materials / Smart Visibility / Move to Layer / Icon Browser spoke Romanian.~~
    **Done, tested:** every message is in English, README.md included.
23. ~~**No `iconName`:** Get Materials, the 3 Smart Visibility macros and the 3 Use * Center macros.~~
    **No change:** the user does not need icons on these.
24. ~~**Shift on macros:** Mid Between and Measure Angle use Shift for the caddy/dialog, BBox and Distribute always open it.~~
    **No change:** intended, and the tooltips say so.

## Tests

- No test: `iconBrowser.py` and `moveToLayer.py` (UI), `lib/common.ms` (dialog position / clamp, Esc watch) and
  `lib/ctrlKey.ms`.
