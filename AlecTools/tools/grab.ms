-- Grab, Rotate, Scale: a transform typed on a small panel at the mouse (tools/grabCaddy.py), one field per axis, all applied together:
-- a distance in scene units (move), an angle in degrees (rotate, X then Y then Z), a percent (scale, 100 = unchanged), e.g. "-100",
-- "15+28". Scale also has an XYZ field for the axes left empty. Scale always opens on XYZ, move and rotate on X.
-- The selection changes live while typing (undo off), Enter or a right click accepts as one undo step, a left click elsewhere or the shortcut again puts it back. Esc does nothing.
-- The axes follow Max's reference coordinate system (View, Screen, World, Parent, Local, Gimbal; Grid and Working Pivot use the world);
-- rotate and scale follow Max's Use Center. Objects whose parent is also selected follow their parent.
-- No viewport tool runs: a MAXScript tool gets no keys.

AlecTools_closeCaddy()

global AlecGrab_mode = #move
global AlecGrab_nodes = #()
global AlecGrab_start = #()
global AlecGrab_center = undefined
global AlecGrab_accepted = false

-- the axes of the reference coordinate system for a node, as the rows of a rotation matrix
fn AlecGrab_screenFrame =
(
	local v = inverse (getViewTM())
	matrix3 v.row1 v.row2 v.row3 [0, 0, 0]
)

fn AlecGrab_axes node =
(
	local f = case (getRefCoordSys()) of
	(
		#local: AlecTools_localFrame node
		#gimbal: AlecTools_localFrame node
		#parent: if node.parent != undefined then AlecTools_localFrame node.parent else matrix3 1
		#screen: AlecGrab_screenFrame()
		#view: if viewport.IsPerspView() then matrix3 1 else AlecGrab_screenFrame()
		default: matrix3 1
	)
	matrix3 f.row1 f.row2 f.row3 [0, 0, 0]
)

fn AlecGrab_restore =
(
	undo off
	(
		for i = 1 to AlecGrab_nodes.count where isValidNode AlecGrab_nodes[i] do AlecGrab_nodes[i].transform = AlecGrab_start[i]
	)
)

-- a rotation about, or a scale along, the axes of the frame f, as a world matrix; v: degrees or percents per axis
fn AlecGrab_matrix f v =
(
	local m = if AlecGrab_mode == #rotate then rotateXMatrix v.x * rotateYMatrix v.y * rotateZMatrix v.z else scaleMatrix (v / 100.0)
	inverse f * m * f
)

-- the axes are read after the start is put back: a Local frame read from the last preview would drift
fn AlecGrab_apply v =
(
	for i = 1 to AlecGrab_nodes.count where isValidNode AlecGrab_nodes[i] do
	(
		local n = AlecGrab_nodes[i]
		n.transform = AlecGrab_start[i]
		local f = AlecGrab_axes n
		if AlecGrab_mode == #move then in coordsys world move n (v * f)
		else AlecTools_transformAbout n (AlecGrab_matrix f v) (if AlecGrab_center == undefined then n.pos else AlecGrab_center)
	)
)

-- a scale that reaches 0 would flatten the objects for good: they stay as they started
fn AlecGrab_usable v = AlecGrab_mode != #scale or (abs v.x > 0.01 and abs v.y > 0.01 and abs v.z > 0.01)

fn AlecGrab_name = case AlecGrab_mode of (#rotate: "Rotate"; #scale: "Scale"; default: "Grab")

-- what the caddy calls on every change: v is a point3 of scene units, degrees or percents per axis
fn AlecGrab_preview v =
(
	if AlecGrab_usable v then undo off AlecGrab_apply v else AlecGrab_restore()
	redrawViews()
)

fn AlecGrab_accept v =
(
	AlecGrab_restore()
	-- the undo name has to be a literal: undo takes an expression in that place for on/off
	if AlecGrab_usable v do case AlecGrab_mode of
	(
		#rotate: undo "Rotate" on AlecGrab_apply v
		#scale: undo "Scale" on AlecGrab_apply v
		default: undo "Grab" on AlecGrab_apply v
	)
	AlecGrab_accepted = true
	redrawViews()
)

-- when the caddy closes: back to the start unless accepted
fn AlecGrab_end =
(
	if not AlecGrab_accepted do AlecGrab_restore()
	AlecGrab_nodes = #()
	redrawViews()
)

-- the moved nodes, without the ones that follow a selected parent
fn AlecGrab_begin mode =
(
	AlecGrab_mode = mode
	AlecGrab_nodes = for o in selection where not (o.parent != undefined and o.parent.isSelected) collect o
	AlecGrab_start = for o in AlecGrab_nodes collect o.transform
	AlecGrab_center = AlecTools_useCenter AlecGrab_nodes
	AlecGrab_accepted = false
)

-- mode: #move, #rotate or #scale
fn AlecGrab_run mode =
(
	AlecTools_closeCaddy()
	AlecGrab_mode = mode
	if selection.count == 0 then displayTempPrompt ((AlecGrab_name()) + ": select something first") 3000
	else
	(
		AlecGrab_begin mode
		python.ExecuteFile (AlecTools_path "tools/grabCaddy.py")
	)
)
