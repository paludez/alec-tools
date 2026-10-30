macroScript SME_GetFromSelection
category:"Alec Tools"
toolTip:"Get Materials"
buttonText:"Get Materials"
(
	on execute do
	(
		local tabName = "Get Materials"
		local gap = 80

		if selection.count == 0 then
		(
			messageBox "Selecteaza un obiect in viewport mai intai!" title:"Alec Tools"
		)
		else
		(
			local refs = #()
			for obj in selection do
			(
				if obj.material != undefined and findItem refs obj.material == 0 do
					append refs obj.material
				AlecSME_collectLightMaps obj refs
			)

			if refs.count == 0 then
			(
				messageBox "Niciun material sau mapa de lumina in selectie!" title:"Alec Tools"
			)
			else
			(
				if not sme.isOpen() do sme.Open()
				local viewIndex = sme.GetViewByName tabName
				if viewIndex == 0 do viewIndex = sme.CreateView tabName
				sme.activeView = viewIndex
				local theView = sme.GetView viewIndex
				try ((sme.GetMainframe()).setfocus()) catch ()

				local rightEdge = undefined
				local nodeCount = theView.GetNumNodes()
				for i = 1 to nodeCount do
				(
					local existing = theView.GetNode i
					local sz = AlecSME_nodeSize existing
					local p = existing.position
					local edge = p.x + sz[1]
					if rightEdge == undefined or edge > rightEdge do rightEdge = edge
				)

				local createdRefs = #()
				local stackY = 0
				local columnX = if rightEdge == undefined then 0 else (rightEdge + gap)

				for refRoot in refs do
				(
					local already = undefined
					try (already = theView.GetNodeByRef refRoot) catch ()
					if already == undefined do
					(
						local pending = #(refRoot)
						local treeRefs = #()
						while pending.count > 0 do
						(
							local ref = pending[pending.count]
							deleteItem pending pending.count
							if findItem treeRefs ref == 0 do
							(
								local found = undefined
								try (found = theView.GetNodeByRef ref) catch ()
								if found == undefined do
								(
									append treeRefs ref
									local kids = AlecSME_childRefs ref
									for k = kids.count to 1 by -1 do append pending kids[k]
								)
							)
						)

						local made = #()
						for ref in treeRefs do
						(
							local pos = [0, 0]
							local newNode = theView.CreateNode ref pos
							if newNode != undefined do
							(
								try (newNode.hideUnusedNodeSlots = true) catch ()
								append made ref
							)
						)

						if made.count > 0 do
						(
							local rootNode = theView.GetNodeByRef refRoot
							if rootNode != undefined do
							(
								local bounds = AlecSME_layoutNode theView rootNode 0 0 made gap
								local dx = columnX - bounds[1]
								local dy = stackY - bounds[2]
								for ref in made do
								(
									local n = theView.GetNodeByRef ref
									if n != undefined do n.position = n.position + [dx, dy]
								)
								stackY = bounds[4] + dy + gap
								join createdRefs made
							)
						)
					)
				)

				if createdRefs.count > 0 do
				(
					try (theView.SetSelectedNodes createdRefs) catch ()
					try (theView.ZoomExtents type:#selected) catch ()
				)
				redrawViews()
			)
		)
	)
)

fn AlecSME_childRefs ref =
(
	local kids = #()
	if ref == undefined do return kids
	local nSubs = 0
	try (nSubs = getNumSubMtls ref) catch ()
	for i = 1 to nSubs do
	(
		local subMtl = getSubMtl ref i
		if subMtl != undefined and findItem kids subMtl == 0 do append kids subMtl
	)
	local nTex = 0
	try (nTex = getNumSubTexmaps ref) catch ()
	for i = 1 to nTex do
	(
		local tex = getSubTexmap ref i
		if tex != undefined and findItem kids tex == 0 do append kids tex
	)
	kids
)

fn AlecSME_nodeSize theNode =
(
	local w = 180
	local h = 120
	try (if theNode.width != undefined and theNode.width > 10 do w = theNode.width) catch ()
	try (if theNode.height != undefined and theNode.height > 10 do h = theNode.height) catch ()
	#(w, h)
)

-- Places theNode with its right edge at xRight. New children go to the left.
-- Returns #(minX, minY, maxX, maxY). Nodes already in the view are not moved.
fn AlecSME_layoutNode theView theNode xRight yTop createdRefs gap =
(
	local sz = AlecSME_nodeSize theNode
	local x = xRight - sz[1]
	theNode.position = [x, yTop]
	local cursorY = yTop
	local minX = x
	local maxX = x + sz[1]
	local maxY = yTop + sz[2]
	local kids = AlecSME_childRefs theNode.reference
	for kid in kids do
	(
		if findItem createdRefs kid != 0 do
		(
			local childNode = undefined
			try (childNode = theView.GetNodeByRef kid) catch ()
			if childNode != undefined do
			(
				local bounds = AlecSME_layoutNode theView childNode (x - gap) cursorY createdRefs gap
				cursorY = bounds[4] + gap
				if bounds[1] < minX do minX = bounds[1]
				if bounds[3] > maxX do maxX = bounds[3]
				if bounds[4] > maxY do maxY = bounds[4]
			)
		)
	)
	#(minX, yTop, maxX, maxY)
)

fn AlecSME_tryAddRef refs ref =
(
	if ref == undefined do return false
	if not (isKindOf ref TextureMap or isKindOf ref Material) do return false
	if findItem refs ref != 0 do return false
	append refs ref
	true
)

fn AlecSME_mapFromColorSlot val =
(
	if val == undefined do return undefined
	if isKindOf val TextureMap do return val
	if isKindOf val Material do return val
	if isKindOf val ColorMap do
	(
		try (
			if val.mapEnabled and val.map != undefined do return val.map
		) catch ()
	)
	undefined
)

fn AlecSME_tryPropMap obj propName refs =
(
	local val = undefined
	try (val = getProperty obj propName) catch ()
	local m = AlecSME_mapFromColorSlot val
	if m == undefined and isKindOf val TextureMap do m = val
	if m != undefined do AlecSME_tryAddRef refs m
)

fn AlecSME_scanMapProps obj refs =
(
	local props = undefined
	try (props = getPropNames obj) catch ()
	if props == undefined do return()
	for p in props do
	(
		local pn = (p as string)
		if not (matchPattern pn pattern:"*map*" ignoreCase:true) do continue
		if matchPattern pn pattern:"*_on" ignoreCase:true do continue
		if matchPattern pn pattern:"*_multiplier" ignoreCase:true do continue
		if matchPattern pn pattern:"*_resolution" ignoreCase:true do continue
		if matchPattern pn pattern:"*_adaptiveness" ignoreCase:true do continue
		AlecSME_tryPropMap obj p refs
	)
)

fn AlecSME_collectStandardLightMaps lt refs =
(
	AlecSME_tryPropMap lt #projectorMap refs
	AlecSME_tryPropMap lt #shadowProjectorMap refs
	AlecSME_tryPropMap lt #filterMap refs
	AlecSME_tryPropMap lt #LightMap refs
	AlecSME_tryPropMap lt #color refs
)

fn AlecSME_collectVRayLightMaps lt refs =
(
	local named = #(
		#texmap, #light_map, #texmap_color, #texmap_translucency,
		#texmap_opacity, #texmap_width, #texmap_distortion
	)
	for n in named do AlecSME_tryPropMap lt n refs
	AlecSME_scanMapProps lt refs
)

fn AlecSME_collectArnoldLightMaps lt refs =
(
	AlecSME_tryPropMap lt #color refs
	AlecSME_scanMapProps lt refs
	local props = undefined
	try (props = getPropNames lt) catch ()
	if props != undefined do
	(
		for p in props do
		(
			local pn = (p as string)
			if matchPattern pn pattern:"arnold_link_*" ignoreCase:true do
				AlecSME_tryPropMap lt p refs
		)
	)
)

fn AlecSME_collectLightMaps obj refs =
(
	if not isKindOf obj Light do return()
	local cn = (classof obj as string)
	if matchPattern cn pattern:"VRay*" ignoreCase:true then
		AlecSME_collectVRayLightMaps obj refs
	else if matchPattern cn pattern:"*Arnold*" ignoreCase:true or matchPattern cn pattern:"ai_*" ignoreCase:true then
		AlecSME_collectArnoldLightMaps obj refs
	else
		AlecSME_collectStandardLightMaps obj refs
)
