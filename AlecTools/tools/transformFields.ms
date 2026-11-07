-- The position and rotation fields on the toolbar (AlecToolbar.py, AlecToolbarFields.py). World Move: the selection's world position (one object:
-- its pivot, several: the center of their bounds), moved as one. World Rotate follows Max's Use Center: each object about its
-- own pivot (Pivot Point Center), or several objects as one about the center of their bounds (Selection Center) or the world
-- origin (Transform Coordinate Center). Local: moves and rotations along each object's own axes, about its pivot.
-- Scale (percent, 100 = unscaled) gives each object its own value, like World Rotate about each pivot. Size (scene units)
-- is one object's size along its own axes; several objects count as one, their combined size along the world axes.
-- A World row's values come as #(x, y, z), undefined where the selected objects differ; set takes the same, undefined left
-- as it is, and add:true adds to each object's own value. A row that only moves by what is entered gets #relative.
-- undoable:false is for the preview of a ladder drag, which the toolbar redoes as one undo step on release.

-- the selected nodes the fields work on: a USD prim has no pos or scale, so its fields stay off
fn AlecTransformFields_selected = for n in selection where not (AlecTools_isUsdPrim n) collect n

-- the nodes whose geometry makes up the selection: a closed group counts through its members, as in Measure
fn AlecTransformFields_selectedParts =
(
	local parts = #()
	for n in AlecTransformFields_selected() do join parts (AlecTools_parts n)
	parts
)

-- the selected nodes that move on their own: a child whose parent is also selected moves with it
fn AlecTransformFields_movers =
(
	AlecTools_topLevel (AlecTransformFields_selected())
)

-- a ladder drag saves the transforms when it starts and puts them back before each step, so every step applies the whole
-- change to where the objects started
global AlecTransformFields_held = #()

fn AlecTransformFields_hold = AlecTransformFields_held = for n in AlecTransformFields_movers() collect #(n, n.transform)

fn AlecTransformFields_restore =
(
	undo off
		for h in AlecTransformFields_held where isValidNode h[1] do h[1].transform = h[2]
	true
)

-- #relative while something is selected: a Local row is on
fn AlecTransformFields_relative = if (AlecTransformFields_selected()).count == 0 then undefined else #relative

fn AlecTransformFields_boundsCenter = AlecTools_boundsCenter (AlecTools_bounds (AlecTransformFields_selectedParts()) (matrix3 1))

-- the values with the entered ones put in (or added, add:true); undefined entered values leave theirs
fn AlecTransformFields_entered current values add =
(
	local result = copy current
	for i in 1 to 3 where values[i] != undefined do result[i] = if add then current[i] + values[i] else values[i]
	result
)

-- one #(x, y, z) for several [x, y, z] values: undefined on an axis where they differ, undefined with no values
fn AlecTransformFields_shared values =
(
	if values.count == 0 do return undefined
	for i in 1 to 3 collect
		if (for v in values where abs (v[i] - values[1][i]) > 0.001 collect v).count == 0 then values[1][i] else undefined
)

-- the shown world position as a point3, or undefined with nothing selected
fn AlecTransformFields_worldPoint =
(
	local sel = AlecTransformFields_selected()
	case sel.count of
	(
		0: undefined
		1: sel[1].transform.row4
		default: AlecTransformFields_boundsCenter()
	)
)

fn AlecTransformFields_worldPosition =
(
	local p = AlecTransformFields_worldPoint()
	if p == undefined then undefined else #(p.x, p.y, p.z)
)

-- moves the selection as one so the shown world position takes the entered values
fn AlecTransformFields_setWorldPosition values add:false undoable:true =
(
	local p = AlecTransformFields_worldPoint()
	local delta = (AlecTransformFields_entered p values add) - p
	undo "World Position" undoable
		for n in AlecTransformFields_movers() do move n delta
	true
)

-- moves each object by delta along its own axes, in scene units whatever its scale
fn AlecTransformFields_moveLocal delta undoable:true =
(
	undo "Local Position" undoable
		for n in AlecTransformFields_movers() do
		(
			local frame = AlecTools_localFrame n
			move n (frame.row1 * delta.x + frame.row2 * delta.y + frame.row3 * delta.z)
		)
	true
)

-- a node's world XYZ angles as Max shows them
fn AlecTransformFields_angles n =
(
	local e = n.transform.rotation as eulerAngles
	[e.x, e.y, e.z]
)

-- the world XYZ angles of the selected objects (undefined where they differ), #relative when several turn as one, or
-- undefined with nothing selected
fn AlecTransformFields_worldRotation =
(
	local movers = AlecTransformFields_movers()
	if movers.count > 1 and getCoordCenter() != #local do return #relative
	AlecTransformFields_shared (for n in movers collect AlecTransformFields_angles n)
)

fn AlecTransformFields_rotationMatrix a = rotateXMatrix a.x * rotateYMatrix a.y * rotateZMatrix a.z

-- gives each object the entered world angles, about its own pivot, or one object about the Use Center
fn AlecTransformFields_setWorldRotation values add:false undoable:true =
(
	local center = AlecTools_useCenter (AlecTransformFields_selected())
	undo "World Rotation" undoable
		for n in AlecTransformFields_movers() do
		(
			local target = AlecTransformFields_rotationMatrix (AlecTransformFields_entered (AlecTransformFields_angles n) values add)
			local r = inverse (n.transform.rotationPart as matrix3) * target
			AlecTools_transformAbout n r (if center == undefined then n.transform.row4 else center)
		)
	true
)

-- turns the selection as one by these angles around the world axes, about the Use Center
fn AlecTransformFields_rotateWorld angles undoable:true =
(
	local center = AlecTools_useCenter (AlecTransformFields_selected())
	local r = AlecTransformFields_rotationMatrix angles
	undo "World Rotation" undoable
		for n in AlecTransformFields_movers() do AlecTools_transformAbout n r (if center == undefined then n.transform.row4 else center)
	true
)

-- turns each object by these angles around its own X, Y and Z, about its pivot
fn AlecTransformFields_rotateLocal angles undoable:true =
(
	undo "Local Rotation" undoable
		for n in AlecTransformFields_movers() do
			in coordsys local about pivot rotate n (eulerAngles angles.x angles.y angles.z)
	true
)

-- each object's own scale in percent (100 = unscaled), undefined where the selected objects differ
fn AlecTransformFields_scale = AlecTransformFields_shared (for n in AlecTransformFields_movers() collect n.scale * 100)

-- a scale or size cannot reach 0: an axis whose new value is that small keeps the old one
fn AlecTransformFields_usable current target =
(
	for i in 1 to 3 where target[i] < 0.001 do target[i] = current[i]
	target
)

-- gives each object the entered scale (percent) along its own axes, about its pivot
fn AlecTransformFields_setScale values add:false undoable:true =
(
	undo "Scale" undoable
		for n in AlecTransformFields_movers() do
		(
			local current = n.scale * 100
			n.scale = (AlecTransformFields_usable current (AlecTransformFields_entered current values add)) / 100
		)
	true
)

-- an object's size along its own axes, as drawn (scale and modifiers included), in scene units
fn AlecTransformFields_nodeSize n =
(
	local b = AlecTools_bounds (AlecTools_parts n) (AlecTools_localFrame n)
	b[2] - b[1]
)

-- the size of the selected objects taken as one, along the world axes
fn AlecTransformFields_selectionSize =
(
	local b = AlecTools_bounds (AlecTransformFields_selectedParts()) (matrix3 1)
	b[2] - b[1]
)

-- one object: its own size, along its own axes; several: the size of all of them together, along the world axes
fn AlecTransformFields_size =
(
	local movers = AlecTransformFields_movers()
	if movers.count > 1 then (local s = AlecTransformFields_selectionSize(); #(s.x, s.y, s.z)) else AlecTransformFields_shared (for n in movers collect AlecTransformFields_nodeSize n)
)

-- several objects as one: scales them and their distances about the center of their bounds, along the world axes
fn AlecTransformFields_setSelectionSize values add =
(
	local b = AlecTools_bounds (AlecTransformFields_selectedParts()) (matrix3 1)
	local current = b[2] - b[1]
	local target = AlecTransformFields_entered current values add
	local factor = [1, 1, 1]
	for i in 1 to 3 where current[i] > 0.0001 and target[i] > 0.0001 do factor[i] = target[i] / current[i]
	for n in AlecTransformFields_movers() do in coordsys world about (AlecTools_boundsCenter b) scale n factor
)

-- gives one object the entered size by scaling it along its own axes, about its pivot (several objects: see above);
-- an axis with no size stays
fn AlecTransformFields_setSize values add:false undoable:true =
(
	undo "Size" undoable
		if (AlecTransformFields_movers()).count > 1 then AlecTransformFields_setSelectionSize values add
		else for n in AlecTransformFields_movers() do
		(
			local current = AlecTransformFields_nodeSize n
			local target = AlecTransformFields_entered current values add
			local s = n.scale
			for i in 1 to 3 where current[i] > 0.0001 and target[i] > 0.0001 do s[i] = s[i] * target[i] / current[i]
			n.scale = s
		)
	true
)
