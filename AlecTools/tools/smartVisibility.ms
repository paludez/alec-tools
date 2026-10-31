-- Smart Hide / Hide Unselected / Unhide All.
-- In sub-object mode on a Line / Edit Spline, Editable Mesh / Edit Mesh or Editable Poly / Edit Poly it acts on the
-- sub-objects, in every other case on the objects. Hide Unselected inverts the selection and hides it; the selection afterwards does not matter.

fn AlecSmartVis_objectRun opName =
(
	case opName of
	(
		#hide: max hide selection
		#hideUnselected: max hide inv
		#unhideAll: max unhide all
	)
)

fn AlecSmartVis_editablePolyRun poly opName =
(
	case opName of
	(
		#hide: poly.ButtonOp #HideSelection
		#hideUnselected: poly.ButtonOp #HideUnselected
		#unhideAll: poly.ButtonOp #UnhideAll
	)
)

-- the Edit_Poly modifier has separate button codes for the vertex level and the face levels, none for edge and border
fn AlecSmartVis_editPolyRun poly opName =
(
	local verb = case opName of
	(
		#hide: "Hide"
		#hideUnselected: "HideUnselected"
		#unhideAll: "UnHideAll"
	)
	poly.ButtonOp ((verb + (if subObjectLevel == 1 then "Vertex" else "Face")) as name)
)

-- the Editable_* classes are operated on through the node, the Edit_* modifiers through ApplyOperation
fn AlecSmartVis_meshRun node cur opName =
(
	if opName == #hideUnselected do max select invert
	if classOf cur == Edit_Mesh then
		ApplyOperation Edit_Mesh (if opName == #unhideAll then meshOps.unhideAll else meshOps.hide)
	else if opName == #unhideAll then
		meshOps.unhideAll node
	else
		meshOps.hide node
)

fn AlecSmartVis_splineRun node cur opName =
(
	if opName == #hideUnselected do max select invert
	if classOf cur == Edit_Spline then
		ApplyOperation Edit_Spline (if opName == #unhideAll then SplineOps.UnHideAll else SplineOps.Hide)
	else if opName == #unhideAll then
		splineOps.unhideAll node
	else
		splineOps.hide node
)

-- true when the object being edited is one of the supported kinds and the operation ran
fn AlecSmartVis_subObjectRun opName =
(
	local cur = modPanel.getCurrentObject()
	local node = selection[1]
	local c = classOf cur
	if node == undefined then
		false
	else if c == Editable_Poly then
	(
		AlecSmartVis_editablePolyRun cur opName
		true
	)
	else if c == Edit_Poly and subObjectLevel != 2 and subObjectLevel != 3 then
	(
		AlecSmartVis_editPolyRun cur opName
		true
	)
	else if c == Editable_Mesh or c == Edit_Mesh then
	(
		AlecSmartVis_meshRun node cur opName
		true
	)
	else if c == SplineShape or c == Line or c == Edit_Spline then
	(
		AlecSmartVis_splineRun node cur opName
		true
	)
	else
		false
)

fn AlecSmartVis_execute opName =
(
	if subObjectLevel == undefined or subObjectLevel == 0 then
		AlecSmartVis_objectRun opName
	else if AlecSmartVis_subObjectRun opName then
		redrawViews()
	else
		displayTempPrompt "Smart Visibility: obiectul sau nivelul de sub-obiect nu e suportat" 3000
)
