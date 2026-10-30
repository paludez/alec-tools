macroScript MidBetween2Points
category:"Alec Tools"
toolTip:"Middle between 2 Points Snap"
buttonText:"Middle between 2 Points Snap"
(
    fn getBasePolyVerts obj subLvl =
    (
        local verts = #{}

        case subLvl of
        (
            1:
            (
                verts = polyOp.getVertSelection obj
            )
            2:
            (
                local edges = polyOp.getEdgeSelection obj
                if not edges.isEmpty do
                    verts = polyOp.getVertsUsingEdge obj edges
            )
            3:
            (
                local edges = polyOp.getEdgeSelection obj
                if not edges.isEmpty do
                    verts = polyOp.getVertsUsingEdge obj edges
            )
            4:
            (
                local faces = polyOp.getFaceSelection obj
                if not faces.isEmpty do
                    verts = polyOp.getVertsUsingFace obj faces
            )
            5:
            (
                local faces = polyOp.getFaceSelection obj
                if not faces.isEmpty do
                    verts = polyOp.getVertsUsingFace obj faces
            )
        )

        verts
    )

    fn getEditPolySelectionType subLvl =
    (
        case subLvl of
        (
            1: #Vertex
            2: #Edge
            3: #Edge
            4: #Face
            5: #Face
            default: undefined
        )
    )

    on execute do
    (
        -- Capturam Alt imediat la pornirea macro-ului.
        local useGeometryCenter = keyboard.altPressed

        if selection.count == 0 then
        (
            messageBox "Selecteaza mai intai un obiect!" title:"M2P Snap"
            return false
        )

        local obj = selection[1]
        local subLvl = subObjectLevel

        if subLvl == undefined do
            subLvl = 0

        local useEditPolyMod = false
        local epMod = undefined
        local selVerts = #{}
        local sourceLevelType = undefined
        local sourceSelection = #{}

        if subLvl > 0 then
        (
            local activeObject = undefined

            try
            (
                activeObject = modPanel.getCurrentObject()
            )
            catch
            (
                activeObject = undefined
            )

            if activeObject != undefined and
               isKindOf activeObject Edit_Poly and
               (findItem obj.modifiers activeObject) > 0 then
            (
                useEditPolyMod = true
                epMod = activeObject
            )

            if useEditPolyMod then
            (
                sourceLevelType = getEditPolySelectionType subLvl

                if sourceLevelType == undefined then
                (
                    messageBox "Nivel de sub-obiect nesuportat." title:"M2P Snap"
                    return false
                )

                sourceSelection = epMod.GetSelection sourceLevelType

                if sourceSelection.isEmpty then
                (
                    messageBox "Selecteaza cel putin un Vertex / Edge / Face!" title:"M2P Snap"
                    return false
                )

                if sourceLevelType != #Vertex do
                    epMod.ConvertSelection sourceLevelType #Vertex

                selVerts = epMod.GetSelection #Vertex

                if selVerts.isEmpty then
                (
                    messageBox "Nu s-au putut obtine vertexii selectati." title:"M2P Snap"
                    return false
                )
            )
            else
            (
                if classOf obj.baseObject != Editable_Poly then
                (
                    messageBox "Pentru sub-obiecte, foloseste un Editable Poly de baza sau activeaza un Edit Poly modifier in stack." title:"M2P Snap"
                    return false
                )

                selVerts = getBasePolyVerts obj subLvl

                if selVerts.isEmpty then
                (
                    messageBox "Selecteaza cel putin un Vertex / Edge / Face!" title:"M2P Snap"
                    return false
                )
            )
        )

        local snapWasOn = snapMode.active
        snapMode.active = true

        local pt1 = pickPoint snap:#3D prompt:"M2P: Click pe PRIMUL punct..."

        if classOf pt1 != Point3 then
        (
            snapMode.active = snapWasOn
            return false
        )

        local pt2 = pickPoint snap:#3D rubberBand:pt1 prompt:"M2P: Click pe AL DOILEA punct..."

        if classOf pt2 != Point3 then
        (
            snapMode.active = snapWasOn
            return false
        )

        local midPt = (pt1 + pt2) / 2.0

        undo "Mid Between 2 Points" on
        (
            if subLvl > 0 then
            (
                if useEditPolyMod then
                (
                    -- GetVertex cu node:obj returneaza World Space.
                    local posSumWorld = [0,0,0]
                    local cnt = 0

                    for v in selVerts do
                    (
                        posSumWorld += epMod.GetVertex v node:obj
                        cnt += 1
                    )

                    if cnt > 0 do
                    (
                        local selWorldCenter = posSumWorld / cnt
                        local deltaWorld = midPt - selWorldCenter

                        -- Convertim deplasarea World Space in local space.
                        local invTM = inverse obj.transform
                        invTM.row4 = [0,0,0]
                        local deltaLocal = deltaWorld * invTM

                        subObjectLevel = 1
                        epMod.SetSelection #Vertex selVerts
                        epMod.SetOperation #Transform
                        epMod.MoveSelection deltaLocal
                        epMod.Commit()

                        subObjectLevel = subLvl
                        epMod.SetSelection sourceLevelType sourceSelection
                    )
                )
                else
                (
                    -- Editable Poly de baza: citire/scriere in World Space.
                    local posSumWorld = [0,0,0]
                    local cnt = 0

                    for v in selVerts do
                    (
                        posSumWorld += polyOp.getVert obj v node:obj
                        cnt += 1
                    )

                    if cnt > 0 do
                    (
                        local selWorldCenter = posSumWorld / cnt
                        local deltaWorld = midPt - selWorldCenter

                        for v in selVerts do
                        (
                            local vertWorld = polyOp.getVert obj v node:obj
                            polyOp.setVert obj v (vertWorld + deltaWorld) node:obj
                        )
                    )
                )

                update obj
                redrawViews()
            )
            else
            (
                local targetCenterWorld = [0,0,0]

                if useGeometryCenter then
                (
                    -- Alt+click: centrul bounding box-ului geometriei selectate.
                    local haveBounds = false
                    local minPt = [0,0,0]
                    local maxPt = [0,0,0]

                    for o in selection do
                    (
                        local bb = nodeGetBoundingBox o (matrix3 1)

                        if not haveBounds then
                        (
                            minPt = bb[1]
                            maxPt = bb[2]
                            haveBounds = true
                        )
						else
						(
							minPt.x = amin minPt.x bb[1].x
							minPt.y = amin minPt.y bb[1].y
							minPt.z = amin minPt.z bb[1].z

							maxPt.x = amax maxPt.x bb[2].x
							maxPt.y = amax maxPt.y bb[2].y
							maxPt.z = amax maxPt.z bb[2].z
						)
                    )

                    if haveBounds do
                        targetCenterWorld = (minPt + maxPt) / 2.0
                )
                else
                (
                    -- Click normal: centrul pivoturilor obiectelor selectate.
                    for o in selection do
                        targetCenterWorld += o.pos

                    targetCenterWorld /= selection.count
                )

                local deltaWorld = midPt - targetCenterWorld

                in coordsys world
                (
                    for o in selection do
                        move o deltaWorld
                )
            )
        )

        snapMode.active = snapWasOn

				if subLvl == 0 then
		(
			if useGeometryCenter then
				displayTempPrompt "Bounding Box to Mid2P" 3000
			else
				displayTempPrompt "Pivot to Mid2P" 3000
		)
    )
)