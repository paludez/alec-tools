-- Grab, Rotate, Scale: a transform typed on a small panel at the mouse (tools/grabCaddy.py). X, Y, Z pick the axis at any time, the rest
-- is the value: a distance in scene units (move), an angle in degrees (rotate), a percent (scale, 100 = unchanged), e.g. "x-100",
-- "z45", "y15+28". Scale with no axis (the same axis key again) scales on all three. The last axis of each mode is kept.
-- The selection changes live while typing (undo off), Enter or a right click accepts as one undo step, Esc puts it back.
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

-- a rotation about, or a scale along, axis (0 = all three, scale only) of the frame f, as a world matrix
fn AlecGrab_matrix f axis value =
(
	local m
	if AlecGrab_mode == #rotate then
		m = case axis of (1: rotateXMatrix value; 2: rotateYMatrix value; default: rotateZMatrix value)
	else
	(
		local k = value / 100.0
		local s = if axis == 0 then [k, k, k] else [1, 1, 1]
		if axis != 0 do s[axis] = k
		m = scaleMatrix s
	)
	inverse f * m * f
)

fn AlecGrab_apply axis value =
(
	for i = 1 to AlecGrab_nodes.count where isValidNode AlecGrab_nodes[i] do
	(
		local n = AlecGrab_nodes[i]
		local f = AlecGrab_axes n
		n.transform = AlecGrab_start[i]
		if AlecGrab_mode == #move then in coordsys world move n (f[axis] * value)
		else AlecTools_transformAbout n (AlecGrab_matrix f axis value) (if AlecGrab_center == undefined then n.pos else AlecGrab_center)
	)
)

-- a scale that reaches 0 would flatten the objects for good: they stay as they started
fn AlecGrab_usable value = AlecGrab_mode != #scale or abs value > 0.01

fn AlecGrab_name = case AlecGrab_mode of (#rotate: "Rotate"; #scale: "Scale"; default: "Grab")

-- what the caddy calls on every change: axis 1-3 (0 = all, scale only), value in scene units, degrees or percent
fn AlecGrab_preview axis value =
(
	AlecTools_rememberSettings (AlecGrab_name()) axis
	if AlecGrab_usable value then undo off AlecGrab_apply axis value else AlecGrab_restore()
	redrawViews()
)

fn AlecGrab_accept axis value =
(
	AlecGrab_restore()
	-- the undo name has to be a literal: undo takes an expression in that place for on/off
	if AlecGrab_usable value do case AlecGrab_mode of
	(
		#rotate: undo "Rotate" on AlecGrab_apply axis value
		#scale: undo "Scale" on AlecGrab_apply axis value
		default: undo "Grab" on AlecGrab_apply axis value
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

-- the last axis of this mode: X for move and rotate, all three for scale
fn AlecGrab_lastAxis = AlecTools_recallSettings (AlecGrab_name()) (if AlecGrab_mode == #scale then 0 else 1)

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
