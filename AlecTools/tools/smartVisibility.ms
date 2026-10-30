fn AlecSmartVis_objectCommand opName =
(
	case opName of
	(
		#hide: max hide selection
		#hideUnselected: max hide inv
		#unhideAll: max unhide all
	)
)

fn AlecSmartVis_invertMesh node =
(
	local level = subObjectLevel
	local sel = case level of
	(
		1: getVertSelection node
		2: getEdgeSelection node
		default: getFaceSelection node
	)
	local n = case level of
	(
		1: meshop.getNumVerts node
		2: meshop.getNumEdges node
		default: meshop.getNumFaces node
	)
	local inv = #{1..n} - (AlecTools_bits sel)
	case level of
	(
		1: setVertSelection node inv
		2: setEdgeSelection node inv
		default: setFaceSelection node inv
	)
)

fn AlecSmartVis_invertSpline node =
(
	local level = subObjectLevel
	local n = numSplines node
	if level >= 3 then
		setSplineSelection node (AlecTools_indices (#{1..n} - (AlecTools_bits (getSplineSelection node)))) keep:false
	else for i = 1 to n do
	(
		local count = if level == 1 then numKnots node i else numSegments node i
		local sel = if level == 1 then getKnotSelection node i else getSegSelection node i
		local inv = AlecTools_indices (#{1..count} - (AlecTools_bits sel))
		if level == 1 then
			setKnotSelection node i inv keep:(i > 1)
		else
			setSegSelection node i inv keep:(i > 1)
	)
)

fn AlecSmartVis_hideSpline curObj =
(
	if classOf curObj == Edit_Spline then
		ApplyOperation Edit_Spline SplineOps.Hide
	else
		splineOps.hide selection[1]
)

fn AlecSmartVis_unhideSpline curObj =
(
	if classOf curObj == Edit_Spline then
		ApplyOperation Edit_Spline SplineOps.UnHideAll
	else
		splineOps.unhideAll selection[1]
)

fn AlecSmartVis_run curObj opName =
(
	local c = classOf curObj
	local node = if selection.count > 0 then selection[1] else undefined
	if c == Edit_Poly or c == Editable_Poly then
	(
		case opName of
		(
			#hide: curObj.ButtonOp #HideSelection
			#hideUnselected: curObj.ButtonOp #HideUnselected
			default: curObj.ButtonOp #UnhideAll
		)
		true
	)
	else if c == Editable_Mesh or c == Edit_Mesh then
	(
		if node != undefined do
		(
			if opName == #hideUnselected do AlecSmartVis_invertMesh node
			if opName == #unhideAll then meshOps.unhideAll node else meshOps.hide node
		)
		true
	)
	else if c == Edit_Spline or isKindOf curObj Shape or (node != undefined and isKindOf node Shape) then
	(
		if opName == #hideUnselected and node != undefined do AlecSmartVis_invertSpline node
		if opName == #unhideAll then AlecSmartVis_unhideSpline curObj else AlecSmartVis_hideSpline curObj
		true
	)
	else
		false
)

fn AlecSmartVis_execute opName =
(
	if subObjectLevel != undefined and subObjectLevel > 0 then
	(
		local curObj = modPanel.getCurrentObject()
		if curObj != undefined and AlecSmartVis_run curObj opName then
		(
			redrawViews()
			completeRedraw()
		)
		else
			AlecSmartVis_objectCommand opName
	)
	else
		AlecSmartVis_objectCommand opName
)
