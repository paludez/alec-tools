# Alec Tools

Personal tools for **3ds Max 2027**, written in MAXScript and Python (PySide6) with the help of AI. I use them through buttons and shortcuts, in a V-Ray and Arnold workflow.

Personal code, no warranty. It changes often.

## Install

1. Download `AlecTools.mzp` from the root of the repo.
2. Drag it into the 3ds Max window (or run it from **Scripting > Run Script**).
3. The tools show up in **Customize User Interface**, in the **Alec Tools** category.

No admin rights needed. For a new version, repeat the steps; the install replaces the old one.

## The tools

All of them are in **Customize User Interface**, category **Alec Tools**, where you bind them to a shortcut or a button. Some open a *caddy*: a small window with a live preview and OK / Cancel buttons.

### Visibility and materials

| Tool | What it does |
| --- | --- |
| **Smart Hide**, **Smart Hide Unsel**, **Smart Unhide** | Hides the selection, hides everything not selected, shows everything. Works on objects and on sub-objects (Editable Poly, Edit Poly, Editable Mesh, Edit Mesh, splines). |
| **Get Materials** | Puts the materials of the selected objects in the Slate Material Editor, on the "Get Materials" tab. |
| **Match Material** | Copies the material of a picked object to the selected objects, in one undo step. |

### Placement

| Tool | What it does |
| --- | --- |
| **Mid Between** | Moves the selection so its center lands in the middle of some points. Click: pick the points (with snaps or from the pivots of objects), right click applies. Shift+Click: the same, with a caddy. A red dummy shows where the center will land. |
| **Distribute** | Spreads the selected objects along an axis, with equal steps between reference points or equal space between bounding boxes. Caddy with a live preview. |
| **BBox** | Makes box cages around the selection (displayed as box, not rendered): one for the whole selection or one per object, in world or local axes. Caddy with a preview. |
| **Use Pivot Point Center**, **Use Selection Center**, **Use Transform Coordinate Center** | Three buttons that switch Max's transform center. The active one shows pressed. |

### Measuring

All of them end with a right click or Esc, and their lines and texts leave the viewport.

| Tool | What it does |
| --- | --- |
| **Measure** | The distance between points picked with snaps, live, with the total. With Ctrl it measures an area and a perimeter. |
| **Measure Angle** | The angle between two lines (4 clicks with snaps). With Ctrl, the angle in World XY. Shift+Click opens an advanced dialog (edges, faces, planes). |
| **Measure BBox** | The bounding box of the object under the mouse and its sizes. A click keeps it on screen. Ctrl switches between the object's axes and the world's. |
| **Measure Clearance** | From the surface under the mouse, along its normal, to the next surface (floor to ceiling, wall to wall). With Ctrl, the thickness of a wall or a slab. |
| **Measure Gap** | The free space between the bounding boxes of two objects: pick a reference object, move over another and see the distance, split into X, Y and Z. |

### Layers, icons, system

| Tool | What it does |
| --- | --- |
| **Move to Layer** | A popup at the cursor with the layer tree, like M in Blender. Clicking a name moves the selection there; with nothing selected it makes the layer current. You can toggle hide / freeze / render and filter by typing. |
| **Icon Browser** | The icons that ship with Max. Filter by name; a click copies the icon's reference. |
| **Reload Alec Tools** | Reloads the tools without restarting Max. |
