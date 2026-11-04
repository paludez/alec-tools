-- Test for tools/create.ms (the logic of the Create Popup). Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\create_test.ms"
-- Makes a testBox and a Slate view "AlecCreateTest" and deletes them at the end. Does not save the scene.
-- Prints PASS/FAIL lines, then the number of failures and one FAIL line per failed check as the last lines.

fileIn (AlecTools_path "tools/create.ms")

(
	local failed = #()
	fn check label ok failed =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		if not ok do append failed label
	)

	check "class found" ((AlecCreate_class material.classes "VRayMtl") != undefined) failed
	check "class missing is undefined" ((AlecCreate_class material.classes "NoSuchMaterial") == undefined) failed
	check "installed: a material" (AlecCreate_installed "material" "Multimaterial") failed
	check "installed: a map" (AlecCreate_installed "map" "Checker") failed
	check "installed: a missing class" (not (AlecCreate_installed "map" "NoSuchMap")) failed
	check "installed: a map is not a material" (not (AlecCreate_installed "material" "Checker")) failed

	-- every class of the popup exists in this Max (the names are the ones in createPopup.py)
	for name in #("VRayMtl", "OpenPBR_Material") do
		check ("material class " + name) ((AlecCreate_make "material" name) != undefined) failed
	for name in #("VRayBitmap", "osl_UberBitmap2b", "VRayColor", "VRayCompTex", "VRayNormalMap", "VRayEdgesTex", "VRayTriplanarTex", "VRayMultiSubTex", "osl_MixColor") do
		check ("map class " + name) ((AlecCreate_make "map" name) != undefined) failed

	-- in a viewport the material goes to the selection
	-- made with undo off: inside a running script everything folds into one undo step, so max undo would undo the box too. For the same
	-- reason each max undo below comes right after the one thing it is to undo
	local testBox
	with undo off
	(
		testBox = Box()
		select testBox
	)
	AlecCreate_add "material" "VRayMtl" false
	check "viewport VRayMtl assigned" (classOf testBox.material == VRayMtl) failed
	max undo
	check "viewport assignment is undone by one undo" (testBox.material == undefined) failed
	AlecCreate_add "material" "OpenPBR_Material" false
	check "viewport OpenPBR assigned" (classOf testBox.material == OpenPBR_Material) failed
	local before = testBox.material
	clearSelection()
	AlecCreate_add "material" "VRayMtl" false
	check "viewport nothing selected changes nothing" (testBox.material == before) failed
	select testBox
	AlecCreate_add "material" "NoSuchMaterial" false
	check "viewport missing class changes nothing" (testBox.material == before) failed
	AlecCreate_add "map" "VRayBitmap" false
	check "viewport map changes nothing" (testBox.material == before) failed

	-- in the Slate Material Editor it becomes a node next to the selected ones
	if not sme.isOpen() do sme.Open()
	local old = sme.GetViewByName "AlecCreateTest"
	if old != 0 do sme.DeleteView old false
	local index = sme.CreateView "AlecCreateTest"
	sme.activeView = index
	local view = sme.GetView index

	AlecCreate_add "map" "VRayBitmap" true
	check "sme map is a node before the undo" (view.GetNumNodes() == 1) failed
	max undo
	check "sme node is undone by one undo" (view.GetNumNodes() == 0) failed

	-- Swap order is one undo step: the mix is made with undo off, so max undo reaches only the swap; the view is made anew after it
	local undoA = Checker()
	local undoB = Noise()
	local undoMix = AlecCreate_make "map" "osl_MixColor"
	with undo off
	(
		undoMix.a_map = undoA
		undoMix.b_map = undoB
		view.CreateNode undoMix [0, 0]
		view.SetSelectedNodes #(undoMix)
	)
	AlecCreate_swapInputs()
	check "swap is applied before the undo" (undoMix.a_map == undoB and undoMix.b_map == undoA) failed
	max undo
	check "swap is undone by one undo" (undoMix.a_map == undoA and undoMix.b_map == undoB) failed
	sme.DeleteView index false
	index = sme.CreateView "AlecCreateTest"
	sme.activeView = index
	view = sme.GetView index

	AlecCreate_add "map" "VRayBitmap" true
	check "sme first map is a node" (view.GetNumNodes() == 1) failed
	local first = view.GetNode 1
	AlecCreate_add "map" "osl_UberBitmap2b" true
	check "sme second map is a node" (view.GetNumNodes() == 2) failed
	local second = (view.GetSelectedNodes())[1]
	check "sme second node is selected and right of the first" ((AlecCreate_nodeX second) > (AlecCreate_nodeX first)) failed
	check "sme missing class adds no node" (AlecCreate_add "map" "NoSuchMap" true; view.GetNumNodes() == 2) failed
	AlecCreate_add "material" "VRayMtl" true
	check "sme material is a node" (view.GetNumNodes() == 3) failed

	-- two-input maps: with exactly two maps selected they become the inputs, left one first; otherwise the map is only added
	local mapA = (view.GetNode 1).reference
	local mapB = (view.GetNode 2).reference
	view.SetSelectedNodes #(mapB, mapA)
	AlecCreate_add "map" "osl_MixColor" true
	check "mix adds a node" (view.GetNumNodes() == 4) failed
	local mix = (view.GetSelectedNodes())[1].reference
	check "mix is the OSL MixColor shader" (classOf mix == OSLMap and mix.OSLShaderName == "MixColor") failed
	check "mix A is the left map" (mix.a_map == mapA) failed
	check "mix B is the right map" (AlecCreate_source mix.b_map == mapB) failed
	-- the Slate view moves the inputs of a node it connects, so CompTex gets two fresh maps, the second added right of the first
	view.SetSelectedNodes #()
	AlecCreate_add "map" "VRayColor" true
	local mapC = (view.GetSelectedNodes())[1].reference
	AlecCreate_add "map" "VRayNormalMap" true
	local mapD = (view.GetSelectedNodes())[1].reference
	view.SetSelectedNodes #(mapD, mapC)
	AlecCreate_add "map" "VRayCompTex" true
	local comp = (view.GetSelectedNodes())[1].reference
	check "comptex A is the left map" (comp.sourceA == mapC) failed
	check "comptex B is the right map" (comp.sourceB == mapD) failed
	view.SetSelectedNodes #(mapA)
	AlecCreate_add "map" "osl_MixColor" true
	local lone = (view.GetSelectedNodes())[1].reference
	check "mix with one map selected takes it as A" (view.GetNumNodes() == 8 and lone.a_map == mapA and lone.b_map == undefined) failed
	view.SetSelectedNodes #()
	AlecCreate_add "map" "VRayCompTex" true
	check "comptex with nothing selected is only added" (view.GetNumNodes() == 9) failed
	AlecCreate_add "map" "VRayBitmap" true
	check "a map that does not mix is only added" (view.GetNumNodes() == 10) failed

	-- composes: only a two-input class with exactly two maps selected
	view.SetSelectedNodes #(mapA, mapB)
	check "composes: mix with two maps selected" (AlecCreate_composes "osl_MixColor") failed
	check "composes: comptex with two maps selected" (AlecCreate_composes "VRayCompTex") failed
	check "composes: a bitmap never" (not (AlecCreate_composes "VRayBitmap")) failed
	view.SetSelectedNodes #(mapA)
	check "composes: mix with one map selected" (AlecCreate_composes "osl_MixColor") failed

	-- replacePlaceholder: the node the editor's own menu made (CreateNode stands in for it) is replaced by the item, at its position
	before = AlecCreate_nodeRefs()
	local placeholder = Checker()
	view.CreateNode placeholder [3000, 2000]
	local count = view.GetNumNodes()
	check "replacePlaceholder finds the placeholder" (AlecCreate_replacePlaceholder before "map" "VRayBitmap") failed
	local made = (view.GetSelectedNodes())[1]
	check "replacePlaceholder keeps the node count" (view.GetNumNodes() == count) failed
	check "replacePlaceholder makes the item, selected" (classOf made.reference == VRayBitmap) failed
	check "replacePlaceholder puts it at the placeholder's position" (abs ((AlecCreate_nodeX made) - 2993) < 30 and abs ((AlecCreate_nodeY made) - 1998) < 30) failed
	check "replacePlaceholder takes the placeholder out" (view.GetNodeByRef placeholder == undefined) failed
	check "replacePlaceholder without a placeholder is false" (not (AlecCreate_replacePlaceholder (AlecCreate_nodeRefs()) "map" "VRayBitmap")) failed
	before = AlecCreate_nodeRefs()
	view.CreateNode (Checker()) [3000, 2400]
	check "replacePlaceholder with a missing class is still handled" (AlecCreate_replacePlaceholder before "map" "NoSuchMap") failed
	before = AlecCreate_nodeRefs()
	view.CreateNode (Checker()) [3000, 2800]
	AlecCreate_replacePlaceholder before "material" "Multimaterial"
	local emptyMulti = (view.GetSelectedNodes())[1].reference
	check "a new Multi/Sub has empty slots" (classOf emptyMulti == Multimaterial and emptyMulti.materialList[1] == undefined) failed
	view.SetSelectedNodes #()
	AlecCreate_add "material" "Multimaterial" true
	emptyMulti = (view.GetSelectedNodes())[1].reference
	check "a new Multi/Sub next to the selection has empty slots too" (classOf emptyMulti == Multimaterial and emptyMulti.materialList[1] == undefined) failed

	-- Multi/Sub: combines the selected materials, nothing else
	view.SetSelectedNodes #()
	check "composes: multi with nothing selected" (not (AlecCreate_composes "Multimaterial")) failed
	view.SetSelectedNodes #(mapA)
	check "composes: multi with only a map selected" (not (AlecCreate_composes "Multimaterial")) failed
	local matL = VRayMtl()
	local matR = OpenPBR_Material()
	-- the upper one first, also when it is the one on the right
	view.CreateNode matL [4300, 0]
	view.CreateNode matR [4000, 300]
	view.SetSelectedNodes #(matR, matL)
	check "composes: multi with materials selected" (AlecCreate_composes "Multimaterial") failed
	count = view.GetNumNodes()
	AlecCreate_add "material" "Multimaterial" true
	local multi = (view.GetSelectedNodes())[1].reference
	check "multi from two materials is one new node" (view.GetNumNodes() == count + 1 and classOf multi == Multimaterial) failed
	check "multi has a slot for each material" (multi.numsubs == 2) failed
	check "multi slots are in order top to bottom" (multi.materialList[1] == matL and multi.materialList[2] == matR) failed
	view.SetSelectedNodes #(multi)
	check "composes: a multi alone is not materials" (not (AlecCreate_composes "Multimaterial")) failed

	-- a selected Multi/Sub takes the selected material into its first free slot, or gets one more slot when it is full
	local partial = Multimaterial numsubs:4
	partial.materialList[1] = VRayMtl()
	partial.materialList[3] = VRayMtl()
	view.CreateNode partial [4600, 0]
	local matNew = VRayMtl()
	view.CreateNode matNew [4900, 0]
	view.SetSelectedNodes #(partial, matNew)
	count = view.GetNumNodes()
	AlecCreate_add "material" "Multimaterial" true
	check "multi and material add no node (the default it replaces leaves the view)" (view.GetNumNodes() == count - 1) failed
	check "material goes to the first free slot" (partial.materialList[2] == matNew and partial.numsubs == 4) failed
	view.SetSelectedNodes #(partial, matNew)
	AlecCreate_add "material" "Multimaterial" true
	check "a material the multi already holds is not added again" (partial.materialList[4] != matNew) failed
	-- a material of the user's named as the Slate Material Editor names them is not a free slot
	local named = Multimaterial numsubs:2
	local mine = VRayMtl()
	mine.name = "Material #99"
	named.materialList[1] = mine
	view.CreateNode named [4600, 400]
	local matNamed = VRayMtl()
	view.CreateNode matNamed [4900, 400]
	view.SetSelectedNodes #(named, matNamed)
	AlecCreate_add "material" "Multimaterial" true
	check "a material named Material #n is kept" (named.materialList[1] == mine) failed
	check "the next slot takes the new material" (named.materialList[2] == matNamed) failed
	local full = Multimaterial numsubs:1
	full.materialList[1] = VRayMtl()
	view.CreateNode full [5200, 0]
	local matMore = VRayMtl()
	view.CreateNode matMore [5500, 0]
	view.SetSelectedNodes #(full, matMore)
	AlecCreate_add "material" "Multimaterial" true
	check "a full multi gets one more slot" (full.numsubs == 2 and full.materialList[2] == matMore) failed

	-- a new material has its unused slots hidden, in both ways of making it; a map and a Multi/Sub do not
	view.SetSelectedNodes #()
	AlecCreate_add "material" "VRayMtl" true
	check "a material next to the selection hides its unused slots" (view.GetSelectedNodes())[1].hideUnusedNodeSlots failed
	before = AlecCreate_nodeRefs()
	view.CreateNode (Checker()) [5800, 0]
	AlecCreate_replacePlaceholder before "material" "OpenPBR_Material"
	check "a material at the mouse hides its unused slots" (view.GetSelectedNodes())[1].hideUnusedNodeSlots failed
	view.SetSelectedNodes #()
	AlecCreate_add "map" "VRayColor" true
	check "a map keeps its unused slots" (not (view.GetSelectedNodes())[1].hideUnusedNodeSlots) failed
	view.SetSelectedNodes #()
	AlecCreate_add "map" "osl_UberBitmap2b" true
	check "an Uber Bitmap hides its unused slots" (view.GetSelectedNodes())[1].hideUnusedNodeSlots failed
	AlecCreate_setTopHideUnused false
	check "setTopHideUnused shows them again" (not (view.GetSelectedNodes())[1].hideUnusedNodeSlots) failed
	view.SetSelectedNodes #()
	AlecCreate_add "material" "Multimaterial" true
	check "a Multi/Sub keeps its slots" (not (view.GetSelectedNodes())[1].hideUnusedNodeSlots) failed

	-- Swap order: every selected mix turns round, an empty input goes along, anything else is left alone
	view.SetSelectedNodes #(mapA)
	check "swap: a plain map cannot" (not (AlecCreate_canSwap())) failed
	view.SetSelectedNodes #()
	check "swap: nothing selected cannot" (not (AlecCreate_canSwap())) failed
	view.SetSelectedNodes #(mix, comp, mapA)
	check "swap: a mix or a comptex can" (AlecCreate_canSwap()) failed
	AlecCreate_swapInputs()
	check "swap: OSL Mix takes its inputs the other way" (AlecCreate_source mix.a_map == mapB and mix.b_map == mapA) failed
	check "swap: CompTex takes its inputs the other way" (comp.sourceA == mapD and comp.sourceB == mapC) failed
	view.SetSelectedNodes #(lone)
	AlecCreate_swapInputs()
	check "swap: an empty input goes along" (lone.a_map == undefined and lone.b_map == mapA) failed

	-- the selected maps become the inputs of the new map
	fn newNode view className nodes =
	(
		view.SetSelectedNodes nodes
		AlecCreate_add "map" className true
		(view.GetSelectedNodes())[1].reference
	)
	local texTop = Checker()
	local texMid = Noise()
	local texLow = Checker()
	view.CreateNode texTop [6000, 0]
	view.CreateNode texMid [6000, 300]
	view.CreateNode texLow [6000, 600]
	local normal = newNode view "VRayNormalMap" #(texTop)
	check "normal map takes the selected map" (classOf normal == VRayNormalMap and normal.normal_map == texTop) failed
	local tri = newNode view "VRayTriplanarTex" #(texTop)
	check "triplanar takes the selected map" (classOf tri == VRayTriplanarTex and tri.texture == texTop) failed
	local compOne = newNode view "VRayCompTex" #(texTop)
	check "comptex with one map takes it as A" (compOne.sourceA == texTop and compOne.sourceB == undefined) failed
	local mixMask = newNode view "osl_MixColor" #(texLow, texTop, texMid)
	check "mix with three maps: A, B, mask from the top" (mixMask.a_map == texTop and mixMask.b_map == texMid and mixMask.Mix_map == texLow) failed
	view.SetSelectedNodes #(texTop, texMid)
	check "composes: normal map with two maps does not" (not (AlecCreate_composes "VRayNormalMap")) failed
	view.SetSelectedNodes #(texTop, texMid, texLow)
	check "composes: comptex with three maps does not" (not (AlecCreate_composes "VRayCompTex")) failed

	-- a map Multi/Sub takes the selected maps; a selected one takes them into its free slots
	-- fresh maps: the Slate view has moved the ones wired above
	local multiTop = Checker()
	local multiLow = Noise()
	view.CreateNode multiTop [8000, 0]
	view.CreateNode multiLow [8000, 300]
	local multiTex = newNode view "VRayMultiSubTex" #(multiLow, multiTop)
	check "map multi has a slot per map, top to bottom" (classOf multiTex == VRayMultiSubTex and multiTex.texmap_num == 2 and multiTex.texmap[1] == multiTop and multiTex.texmap[2] == multiLow) failed
	local count2 = view.GetNumNodes()
	view.SetSelectedNodes #(multiTex, texMid, multiTop)
	AlecCreate_add "map" "VRayMultiSubTex" true
	check "a selected map multi takes the new map, once" (view.GetNumNodes() == count2 and multiTex.texmap_num == 3 and multiTex.texmap[3] == texMid) failed
	multiTex.texmap[1] = undefined
	local texFree = Noise()
	view.CreateNode texFree [6000, 900]
	view.SetSelectedNodes #(multiTex, texFree)
	AlecCreate_add "map" "VRayMultiSubTex" true
	check "a free slot of a map multi is filled first" (multiTex.texmap_num == 3 and multiTex.texmap[1] == texFree) failed
	view.SetSelectedNodes #(multiTex)
	check "composes: a map multi alone does not" (not (AlecCreate_composes "VRayMultiSubTex")) failed

	-- the new map goes into the selected material's empty slot
	local mtlV = VRayMtl()
	local mtlP = OpenPBR_Material()
	view.CreateNode mtlV [6600, 0]
	view.CreateNode mtlP [6600, 300]
	local bumpMap = newNode view "VRayNormalMap" #(mtlV)
	check "normal map goes into a VRayMtl's bump" (mtlV.texmap_bump == bumpMap and mtlV.texmap_bump_multiplier == 100) failed
	check "normal map is left of the material" ((AlecCreate_nodeX (view.GetNodeByRef bumpMap)) < (AlecCreate_nodeX (view.GetNodeByRef mtlV))) failed
	local pbrNormal = newNode view "VRayNormalMap" #(mtlP, texTop)
	check "material + map make the whole chain" (pbrNormal.normal_map == texTop and mtlP.geometry_normal_map == pbrNormal) failed
	local diffuse = newNode view "VRayBitmap" #(mtlV)
	check "a bitmap goes into a VRayMtl's diffuse" (mtlV.texmap_diffuse == diffuse) failed
	local base = newNode view "osl_UberBitmap2b" #(mtlP)
	check "a bitmap goes into an OpenPBR's base color" (AlecCreate_source mtlP.base_color_map == base) failed
	-- the Slate view knows the link when deleting the map's node empties the slot; an Uber Bitmap has several outputs, so this needs AlecCreate_output
	local linkMtl = VRayMtl()
	view.CreateNode linkMtl [6600, 900]
	local linkUber = newNode view "osl_UberBitmap2b" #(linkMtl)
	view.SetSelectedNodes #(linkUber)
	view.DeleteSelection()
	check "the view knows an Uber Bitmap's link to a material" (linkMtl.texmap_diffuse == undefined) failed
	local linkTop = AlecCreate_make "map" "osl_UberBitmap2b"
	view.CreateNode linkTop [6600, 1200]
	local linkMix = newNode view "osl_MixColor" #(linkTop)
	check "an Uber Bitmap into a mix is its first output" (classOf linkMix.a_map == MultiOutputChannelTexmapToTexmap and linkMix.a_map.outputChannelIndex == 1 and AlecCreate_source linkMix.a_map == linkTop) failed
	view.SetSelectedNodes #(linkTop)
	view.DeleteSelection()
	check "the view knows an Uber Bitmap's link to a mix" (linkMix.a_map == undefined) failed
	view.SetSelectedNodes #(mtlV)
	check "composes: an occupied slot does not" (not (AlecCreate_composes "VRayNormalMap") and not (AlecCreate_composes "VRayBitmap")) failed
	local bumpKept = mtlV.texmap_bump
	AlecCreate_add "map" "VRayNormalMap" true
	check "an occupied slot is not replaced" (mtlV.texmap_bump == bumpKept) failed
	local mtlA = VRayMtl()
	local mtlB = VRayMtl()
	view.CreateNode mtlA [7000, 0]
	view.CreateNode mtlB [7000, 300]
	view.SetSelectedNodes #(mtlA, mtlB)
	check "composes: two materials do not" (not (AlecCreate_composes "VRayNormalMap")) failed
	view.SetSelectedNodes #(mtlA)
	check "composes: a map with no slot there does not" (not (AlecCreate_composes "VRayEdgesTex")) failed
	check "tip: says what it does" (AlecCreate_composeTip "VRayBitmap" == "Goes into the selected material") failed

	-- a material from texture files: the file names say the slots (the files need not exist for the wiring)
	check "role: albedo" (AlecCreate_textureRole "C:/t/Wood_Albedo_2K.png" == "base") failed
	check "role: roughness wins over color" (AlecCreate_textureRole "C:/t/color_roughness.png" == "rough") failed
	check "role: short normal" (AlecCreate_textureRole "C:/t/wood-nrm.exr" == "normal") failed
	check "role: a word inside a word does not count" (AlecCreate_textureRole "C:/t/abnormal.png" == undefined) failed
	local files = #("C:/t/wood_albedo.png", "C:/t/wood_roughness.png", "C:/t/wood_metallic.png", "C:/t/wood_normal.png", "C:/t/wood_height.png", "C:/t/wood2_albedo.png")
	local madeV = AlecCreate_materialFromFiles "VRayMtl" files
	local fileV = madeV[1]
	check "files VRayMtl: base goes in, as a VRayBitmap" (classOf fileV.texmap_diffuse == VRayBitmap and filenameFromPath fileV.texmap_diffuse.HDRIMapName == "wood_albedo.png") failed
	check "files VRayMtl: roughness goes in, in roughness mode, as data" (fileV.brdf_useRoughness and fileV.texmap_reflectionGlossiness.color_space == 0) failed
	check "files VRayMtl: base stays color" (fileV.texmap_diffuse.color_space != 0) failed
	check "files VRayMtl: metal goes in" (fileV.texmap_metalness != undefined and fileV.reflection_metalness == 1.0) failed
	check "files VRayMtl: reflection is white" (fileV.Reflection == white) failed
	check "files VRayMtl: normal through a VRayNormalMap at 100" (classOf fileV.texmap_bump == VRayNormalMap and fileV.texmap_bump.normal_map != undefined and fileV.texmap_bump_multiplier == 100) failed
	check "files VRayMtl: unknown and second of a role stay loose" (madeV[2].count == 2) failed
	local fileP = (AlecCreate_materialFromFiles "OpenPBR_Material" files)[1]
	check "files OpenPBR: base goes in, as an Uber Bitmap" (fileP.base_color_map != undefined and filenameFromPath (AlecCreate_source fileP.base_color_map).filename == "wood_albedo.png") failed
	check "files OpenPBR: roughness as Raw data" ((AlecCreate_source fileP.specular_roughness_map).Filename_ColorSpace == "Raw") failed
	check "files OpenPBR: normal through Normal_Bump" (classOf fileP.geometry_normal_map == Normal_Bump) failed
	check "files OpenPBR: a glossiness file stays loose" ((AlecCreate_materialFromFiles "OpenPBR_Material" #("C:/t/a_gloss.png"))[2].count == 1) failed
	view.SetSelectedNodes #()
	count = view.GetNumNodes()
	AlecCreate_fromFiles "VRayMtl" #("C:/t/wood_albedo.png", "C:/t/wood_height.png") true [9000, 0]
	local placedMtl = (view.GetSelectedNodes())[1]
	check "fromFiles: the material is selected, at the spot" (classOf placedMtl.reference == VRayMtl and abs ((AlecCreate_nodeX placedMtl) - 8993) < 30) failed
	check "fromFiles: hides its unused slots" placedMtl.hideUnusedNodeSlots failed
	check "fromFiles: material, its bitmap and the loose one are nodes" (view.GetNumNodes() == count + 3) failed
	view.SetSelectedNodes #()
	AlecCreate_fromFiles "OpenPBR_Material" #("C:/t/wood_albedo.png", "C:/t/wood_height.png") true [9000, 800]
	local placedPbr = (view.GetSelectedNodes())[1].reference
	check "fromFiles: a wired Uber Bitmap hides its unused slots" (view.GetNodeByRef (AlecCreate_source placedPbr.base_color_map)).hideUnusedNodeSlots failed

	-- with a material selected the files go into it, whatever the button, and no new material is made
	local fillV = VRayMtl()
	view.CreateNode fillV [10000, 0]
	local keptDiffuse = Checker()
	fillV.texmap_diffuse = keptDiffuse
	view.SetSelectedNodes #(fillV)
	check "filesTarget: the selected material" (AlecCreate_filesTarget() == fillV) failed
	count = view.GetNumNodes()
	AlecCreate_fromFiles "OpenPBR_Material" #("C:/t/oak_albedo.png", "C:/t/oak_roughness.png", "C:/t/oak_normal.png") true undefined
	check "fill: no new material, it stays selected" (classOf (view.GetSelectedNodes())[1].reference == VRayMtl and (view.GetSelectedNodes())[1].reference == fillV) failed
	check "fill: an occupied slot is kept" (fillV.texmap_diffuse == keptDiffuse) failed
	check "fill: the free slots take the files, as the material's own class of maps" (classOf fillV.texmap_reflectionGlossiness == VRayBitmap and classOf fillV.texmap_bump == VRayNormalMap) failed
	check "fill: reflection goes white for the roughness" (fillV.brdf_useRoughness and fillV.Reflection == white) failed
	check "fill: the maps are nodes" (view.GetNodeByRef fillV.texmap_reflectionGlossiness != undefined and view.GetNodeByRef fillV.texmap_bump != undefined) failed
	local keepRough = fillV.texmap_reflectionGlossiness
	view.SetSelectedNodes #(keepRough)
	view.DeleteSelection()
	check "fill: the view knows the link" (fillV.texmap_reflectionGlossiness == undefined) failed
	local fillP = OpenPBR_Material()
	view.CreateNode fillP [10000, 800]
	view.SetSelectedNodes #(fillP)
	AlecCreate_fromFiles "VRayMtl" #("C:/t/oak_albedo.png") true undefined
	local fillUber = AlecCreate_source fillP.base_color_map
	check "fill: an OpenPBR takes an Uber Bitmap" (classOf fillUber == OSLMap and view.GetNodeByRef fillUber != undefined) failed
	view.SetSelectedNodes #(fillUber)
	view.DeleteSelection()
	check "fill: the view knows an Uber Bitmap's link" (fillP.base_color_map == undefined) failed
	local fillA = VRayMtl()
	local fillB = VRayMtl()
	view.CreateNode fillA [10400, 0]
	view.CreateNode fillB [10400, 300]
	view.SetSelectedNodes #(fillA, fillB)
	check "filesTarget: two materials are none" (AlecCreate_filesTarget() == undefined) failed
	view.SetSelectedNodes #(multi)
	check "filesTarget: a Multi/Sub is none" (AlecCreate_filesTarget() == undefined) failed

	-- the bitmap buttons: a node per file, loaded and all selected; the first follows the rules of a new node
	view.SetSelectedNodes #()
	count = view.GetNumNodes()
	AlecCreate_addBitmaps "VRayBitmap" #("C:/t/pine_albedo.png", "C:/t/pine_roughness.png") [11000, 0]
	local picked = AlecCreate_topToBottom (view.GetSelectedNodes())
	check "bitmaps: a node per file, all selected" (view.GetNumNodes() == count + 2 and picked.count == 2) failed
	check "bitmaps: the first is at the spot, loaded" (abs ((AlecCreate_nodeX picked[1]) - 10993) < 30 and filenameFromPath picked[1].reference.HDRIMapName == "pine_albedo.png") failed
	check "bitmaps: the second is under it, as data" ((AlecCreate_nodeY picked[2]) > (AlecCreate_nodeY picked[1]) and picked[2].reference.color_space == 0) failed
	AlecCreate_addBitmaps "osl_UberBitmap2b" #("C:/t/pine_normal.png") [11000, 800]
	local pickedUber = (view.GetSelectedNodes())[1]
	check "bitmaps: an Uber Bitmap is loaded, as data, and collapsed" (filenameFromPath pickedUber.reference.filename == "pine_normal.png" and pickedUber.reference.Filename_ColorSpace == "Raw" and pickedUber.hideUnusedNodeSlots) failed
	local bitmapMtl = VRayMtl()
	view.CreateNode bitmapMtl [11400, 0]
	view.SetSelectedNodes #(bitmapMtl)
	AlecCreate_addBitmaps "VRayBitmap" #("C:/t/pine_albedo.png") undefined
	check "bitmaps: with a material selected it goes into its slot" (filenameFromPath bitmapMtl.texmap_diffuse.HDRIMapName == "pine_albedo.png") failed

	with undo off (select testBox)
	AlecCreate_fromFiles "OpenPBR_Material" #("C:/t/wood_albedo.png") false undefined
	check "fromFiles over a viewport goes to the selection" (classOf testBox.material == OpenPBR_Material and testBox.material.base_color_map != undefined) failed

	sme.DeleteView index false
	delete testBox

	format "failures: %\n" failed.count
	for label in failed do format "FAIL %\n" label
)
