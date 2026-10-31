-- Get Materials: puts the materials of the selected objects in the Slate Material Editor, tab "Get Materials".
-- SME creates the whole node tree (sub-materials, maps) for a material and LayoutAll arranges it.

fn AlecGetMaterials_selectionMaterials =
(
	local mats = #()
	for obj in selection where obj.material != undefined and findItem mats obj.material == 0 do append mats obj.material
	mats
)

fn AlecGetMaterials_view tabName =
(
	if not sme.isOpen() do sme.Open()
	local index = sme.GetViewByName tabName
	if index == 0 do index = sme.CreateView tabName
	sme.activeView = index
	sme.GetView index
)

fn AlecGetMaterials_execute tabName:"Get Materials" =
(
	local mats = AlecGetMaterials_selectionMaterials()
	if mats.count == 0 then
		displayTempPrompt "Get Materials: nu e nimic de pus in SME, selectia nu are materiale" 3000
	else
	(
		local view = AlecGetMaterials_view tabName
		local added = for m in mats where view.GetNodeByRef m == undefined collect m
		for m in added do view.CreateNode m [0, 0]
		-- before the layout: hidden slots make the nodes short
		for i = 1 to view.GetNumNodes() do (view.GetNode i).hideUnusedNodeSlots = true
		view.LayoutAll()
		if added.count > 0 do
		(
			view.SetSelectedNodes added
			view.ZoomExtents type:#selected
		)
	)
)
