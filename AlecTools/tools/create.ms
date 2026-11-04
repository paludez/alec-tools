-- Create: the logic behind the Create Popup (tools/createPopup.py). In the Slate Material Editor the node is made at the mouse: the
-- editor's own context menu makes a placeholder there (tools/smeCursor.py) and the node is made at its position; when that is not
-- possible it is put next to the selected nodes. A new node takes what is selected when it fits and goes next to it instead (see
-- AlecCreate_composeTip): selected maps become the inputs of an OSL Mix, CompTex, NormalMap or Triplanar, and fill a map Multi/Sub; selected
-- materials fill a Multi/Sub; a NormalMap or a bitmap goes into the selected material's empty slot. A material node has its unused slots
-- hidden. Swap order turns round the inputs of the selected OSL Mix or CompTex. In a viewport a material is assigned to the selected objects.

-- the class called className in classes (material.classes, textureMap.classes), undefined when it is not installed
fn AlecCreate_class classes className =
(
	local found = for c in classes where (c as string) == className collect c
	if found.count == 0 then undefined else found[1]
)

fn AlecCreate_classes kind = if kind == "material" then material.classes else textureMap.classes

fn AlecCreate_installed kind className = AlecCreate_class (AlecCreate_classes kind) className != undefined

fn AlecCreate_make kind className =
(
	local cls = AlecCreate_class (AlecCreate_classes kind) className
	if cls == undefined then undefined else cls()
)

-- a new Multi/Sub made for the Slate view starts with empty slots, not with the default sub-materials
fn AlecCreate_emptySlots item className =
(
	if className == "Multimaterial" do for i = 1 to item.numsubs do item.materialList[i] = undefined
)

fn AlecCreate_activeView = sme.GetView sme.activeView

-- a node's position in the view, read in two steps: n.position.x stops with "Unknown property: pos" on a node
fn AlecCreate_nodeX n = (local p = n.position; p.x)

fn AlecCreate_nodeY n = (local p = n.position; p.y)

-- where a new node goes: right of the given nodes, else right of every node in the view, else at the origin; at the top of them
fn AlecCreate_nodePosition view nodes =
(
	local near = if nodes.count > 0 then nodes else for i = 1 to view.GetNumNodes() collect view.GetNode i
	if near.count == 0 then [0, 0]
	else [(amax (for n in near collect AlecCreate_nodeX n)) + 250, amin (for n in near collect AlecCreate_nodeY n)]
)

-- how a new node opens: with its unused slots hidden when it is a material, but not a Multi/Sub (its slots are what it is made to be filled
-- through), or an Uber Bitmap (every OSL map is of the class OSLMap). An Uber Bitmap at the mouse gets the editor's own Hide All instead
-- (tools/smeCursor.py), which a script cannot do on a node it cannot find on the screen
fn AlecCreate_collapse node item =
(
	if (superClassOf item == material and classOf item != Multimaterial) or (classOf item == OSLMap and matchPattern item.OSLShaderName pattern:"UberBitmap*") do
		node.hideUnusedNodeSlots = true
)

-- makes the node, selected
fn AlecCreate_placeNode view item pos =
(
	AlecCreate_collapse (view.CreateNode item pos) item
	view.SetSelectedNodes #(item)
)

fn AlecCreate_addNode view item nodes = AlecCreate_placeNode view item (AlecCreate_nodePosition view nodes)

fn AlecCreate_assign item =
(
	local targets = for o in selection where isProperty o #material collect o
	if targets.count == 0 then displayTempPrompt "Create: select the objects to give the material to" 3000
	else
	(
		undo "Create material" on for o in targets do o.material = item
		completeRedraw()
	)
)

-- left before right, the upper one first when they are level (the Slate view moves the inputs of a node it connects, so they can be)
fn AlecCreate_byPosition a b =
(
	local ax = AlecCreate_nodeX a
	local bx = AlecCreate_nodeX b
	local topA = AlecCreate_nodeY a
	local topB = AlecCreate_nodeY b
	if ax != bx then (if ax < bx then -1 else 1)
	else if topA != topB then (if topA < topB then -1 else 1)
	else 0
)

-- upper before lower, the left one first when they are level: the order of several materials in a Multi/Sub
fn AlecCreate_byTop a b =
(
	local ax = AlecCreate_nodeX a
	local bx = AlecCreate_nodeX b
	local topA = AlecCreate_nodeY a
	local topB = AlecCreate_nodeY b
	if topA != topB then (if topA < topB then -1 else 1)
	else if ax != bx then (if ax < bx then -1 else 1)
	else 0
)

fn AlecCreate_leftToRight nodes =
(
	qsort nodes AlecCreate_byPosition
	nodes
)

fn AlecCreate_topToBottom nodes =
(
	qsort nodes AlecCreate_byTop
	nodes
)

-- the selected maps of the view, left one first
fn AlecCreate_selectedMaps view =
	AlecCreate_leftToRight (for n in view.GetSelectedNodes() where superClassOf n.reference == textureMap collect n)

-- the selected materials of the view that are not Multi/Sub, top one first
fn AlecCreate_selectedMaterials view =
	AlecCreate_topToBottom (for n in view.GetSelectedNodes() where superClassOf n.reference == material and classOf n.reference != Multimaterial collect n)

-- the selected Multi/Sub materials of the view, top one first
fn AlecCreate_selectedMultis view =
	AlecCreate_topToBottom (for n in view.GetSelectedNodes() where classOf n.reference == Multimaterial collect n)

-- the two input slots of a map class that mixes two maps, undefined for any other class
fn AlecCreate_slots className =
(
	case className of
	(
		"osl_MixColor": #(#a_map, #b_map)
		"VRayCompTex": #(#sourceA, #sourceB)
		default: undefined
	)
)

-- the two input slots of a map in the scene, undefined when it does not mix two maps (every OSL map is of the class OSLMap)
fn AlecCreate_slotsOf item =
	AlecCreate_slots (if classOf item == OSLMap and item.OSLShaderName == "MixColor" then "osl_MixColor" else classOf item as string)

-- the selected maps of the active Slate view whose two inputs can be swapped
fn AlecCreate_swappable =
	for n in (AlecCreate_activeView()).GetSelectedNodes() where AlecCreate_slotsOf n.reference != undefined collect n.reference

fn AlecCreate_canSwap = (AlecCreate_swappable()).count > 0

-- Swap order button: each selected OSL Mix or CompTex takes its inputs the other way round, as one undo step
fn AlecCreate_swapInputs =
(
	local items = AlecCreate_swappable()
	undo "Swap inputs" on for item in items do
	(
		local slots = AlecCreate_slotsOf item
		local held = getProperty item slots[1]
		setProperty item slots[1] (getProperty item slots[2])
		setProperty item slots[2] held
	)
)

-- what goes into a slot to connect this map: a map with several outputs (Uber Bitmap has 7) through a node for its first output, the way
-- Max connects it itself. Set directly it works in the slot but the Slate view shows no link to it
fn AlecCreate_output item =
(
	if isProperty item #numIMultipleOutputChannels and item.numIMultipleOutputChannels > 1 then
	(
		local channel = MultiOutputChannelTexmapToTexmap()
		channel.sourceMap = item
		channel.outputChannelIndex = 1
		channel
	)
	else item
)

-- the map that a slot's content comes from, see AlecCreate_output
fn AlecCreate_source held =
	if classOf held == MultiOutputChannelTexmapToTexmap then held.sourceMap else held

-- the input slots of a map class in the order the selected maps fill them, undefined when count maps do not fit them
fn AlecCreate_inputs className count =
(
	local slots = case className of
	(
		"osl_MixColor": #(#a_map, #b_map, #Mix_map)
		"VRayCompTex": #(#sourceA, #sourceB)
		"VRayNormalMap": #(#normal_map)
		"VRayTriplanarTex": #(#texture)
		default: #()
	)
	if count >= 1 and count <= slots.count then slots else undefined
)

-- the selected nodes that become the inputs of a map of this class, in slot order: left one first, or from the top with three (A, B and
-- the mask of an OSL Mix); empty when they do not fit
fn AlecCreate_inputNodes view className =
(
	local maps = AlecCreate_selectedMaps view
	if AlecCreate_inputs className maps.count == undefined then #()
	else if maps.count == 3 then AlecCreate_topToBottom maps
	else maps
)

fn AlecCreate_wire item className nodes =
(
	local slots = AlecCreate_inputs className nodes.count
	for i = 1 to nodes.count do setProperty item slots[i] (AlecCreate_output nodes[i].reference)
)

-- the slot of a material that a new map of this class goes into, undefined when there is none
fn AlecCreate_materialSlot mtl className =
(
	case ((classOf mtl as string) + ":" + className) of
	(
		"VRayMtl:VRayNormalMap": #texmap_bump
		"OpenPBR_Material:VRayNormalMap": #geometry_normal_map
		"VRayMtl:VRayBitmap": #texmap_diffuse
		"VRayMtl:osl_UberBitmap2b": #texmap_diffuse
		"OpenPBR_Material:VRayBitmap": #base_color_map
		"OpenPBR_Material:osl_UberBitmap2b": #base_color_map
		default: undefined
	)
)

-- the material a new map of this class goes into: the only selected one, when its slot is empty (what is there is never replaced)
fn AlecCreate_linkTarget view className =
(
	local mats = AlecCreate_selectedMaterials view
	local slot = if mats.count == 1 then AlecCreate_materialSlot mats[1].reference className else undefined
	if slot != undefined and getProperty mats[1].reference slot == undefined then mats[1].reference else undefined
)

-- a VRayMtl's bump slot scales what is in it (30 by default), a normal map is to come through whole
fn AlecCreate_link target item className =
(
	if target != undefined do
	(
		local slot = AlecCreate_materialSlot target className
		setProperty target slot (AlecCreate_output item)
		if slot == #texmap_bump do target.texmap_bump_multiplier = 100
	)
)

-- the selected maps that go into a map Multi/Sub, top one first
fn AlecCreate_plainMaps view =
	AlecCreate_topToBottom (for n in AlecCreate_selectedMaps view where classOf n.reference != VRayMultiSubTex collect n)

-- the selected map Multi/Subs of the view
fn AlecCreate_selectedMultiTexs view =
	for n in AlecCreate_selectedMaps view where classOf n.reference == VRayMultiSubTex collect n

-- puts the maps it does not hold yet into the first free slots of a map Multi/Sub, adding slots when none is free
fn AlecCreate_fillMultiTex multi maps =
(
	local held = for i = 1 to multi.texmap_num collect AlecCreate_source multi.texmap[i]
	for m in maps where findItem held m == 0 do
	(
		local slot = findItem held undefined
		if slot == 0 do
		(
			append held undefined
			slot = held.count
			multi.texmap_num = slot
		)
		held[slot] = m
		multi.texmap[slot] = AlecCreate_output m
	)
)

-- the selected maps go into a map Multi/Sub: the selected one when there is one, else the new item, which has a slot for each of them and
-- goes in front of them
fn AlecCreate_composeMultiTex view item =
(
	local nodes = AlecCreate_plainMaps view
	local maps = for n in nodes collect n.reference
	local multis = AlecCreate_selectedMultiTexs view
	if multis.count > 0 then
	(
		AlecCreate_fillMultiTex multis[1].reference maps
		view.SetSelectedNodes #(multis[1].reference)
	)
	else
	(
		local pos = AlecCreate_nodePosition view nodes
		item.texmap_num = maps.count
		AlecCreate_fillMultiTex item maps
		AlecCreate_placeNode view item pos
	)
)

-- the references of the nodes of the active Slate view
fn AlecCreate_nodeRefs =
(
	local view = AlecCreate_activeView()
	for i = 1 to view.GetNumNodes() collect (view.GetNode i).reference
)

-- what a new node of this class does with what is selected in the active Slate view, "" when nothing: then it goes at the mouse, else
-- next to what it takes. Shown as the tip of its button
fn AlecCreate_composeTip className =
(
	local view = AlecCreate_activeView()
	local wires = (AlecCreate_inputNodes view className).count > 0
	local links = AlecCreate_linkTarget view className != undefined
	case of
	(
		(className == "Multimaterial"): if (AlecCreate_selectedMaterials view).count > 0 then "Takes the selected materials" else ""
		(className == "VRayMultiSubTex"): if (AlecCreate_plainMaps view).count > 0 then "Takes the selected maps" else ""
		(wires and links): "Takes the selected map and goes into the selected material"
		wires: "Takes the selected maps as its inputs"
		links: "Goes into the selected material"
		default: ""
	)
)

fn AlecCreate_composes className = AlecCreate_composeTip className != ""

-- a Multi/Sub slot is free when it is empty or still holds the default material that a new Multi/Sub is made with: named Material #n and of
-- the class Max makes there (a material of the user's can be named Material #n too)
fn AlecCreate_slotIsFree multi slot =
(
	local held = multi.materialList[slot]
	held == undefined or (matchPattern held.name pattern:"Material #*" and classOf held == classOf (Multimaterial()).materialList[1])
)

-- puts the materials (references) it does not hold yet into the first free slots of a Multi/Sub in the view, adding a slot when none is
-- free; the default material a slot held is taken out of the view too
fn AlecCreate_fillMulti view multi materials =
(
	local held = for i = 1 to multi.numsubs collect multi.materialList[i]
	for m in materials where findItem held m == 0 do
	(
		local slot = 1
		while slot <= multi.numsubs and not (AlecCreate_slotIsFree multi slot) do slot += 1
		if slot > multi.numsubs do multi.numsubs = slot
		local replaced = multi.materialList[slot]
		multi.materialList[slot] = m
		if replaced != undefined and view.GetNodeByRef replaced != undefined do
		(
			view.SetSelectedNodes #(replaced)
			view.DeleteSelection()
		)
	)
)

-- the selected materials go into a Multi/Sub: the selected one when there is one, else the new item, which has a slot for each of
-- them and goes in front of them
fn AlecCreate_composeMulti view item =
(
	local materials = for n in AlecCreate_selectedMaterials view collect n.reference
	local multis = AlecCreate_selectedMultis view
	if multis.count > 0 then
	(
		AlecCreate_fillMulti view multis[1].reference materials
		view.SetSelectedNodes #(multis[1].reference)
	)
	else
	(
		item.numsubs = materials.count
		for i = 1 to materials.count do item.materialList[i] = materials[i]
		AlecCreate_addNode view item (AlecCreate_selectedMaterials view)
	)
)

-- the editor's own menu (tools/smeCursor.py) made a placeholder node at the mouse, the only new node since before (AlecCreate_nodeRefs):
-- it is taken out (neither is in the undo list: the caller makes it with undo off) and the item is placed at its position, selected, as one
-- undo step. True when there was a placeholder
fn AlecCreate_takePlaceholder before =
(
	local view = AlecCreate_activeView()
	local fresh = for r in AlecCreate_nodeRefs() where findItem before r == 0 collect r
	if fresh.count == 0 then undefined
	else
	(
		local node = view.GetNodeByRef fresh[1]
		local spot = node.position
		undo off
		(
			view.SetSelectedNodes fresh
			view.DeleteSelection()
		)
		spot
	)
)

fn AlecCreate_replacePlaceholder before kind className =
(
	local view = AlecCreate_activeView()
	local spot = AlecCreate_takePlaceholder before
	if spot == undefined then false
	else
	(
		local item = AlecCreate_make kind className
		if item == undefined then displayTempPrompt ("Create: " + className + " is not installed") 3000
		else
		(
			AlecCreate_emptySlots item className
			undo "Create node" on AlecCreate_placeNode view item spot
		)
		true
	)
)

-- where a new node goes that only feeds a material: left of it
fn AlecCreate_leftOf view target =
(
	local n = view.GetNodeByRef target
	[(AlecCreate_nodeX n) - 250, AlecCreate_nodeY n]
)

-- the node goes next to the selected nodes and takes what the class combines (see AlecCreate_composeTip): the maps as its inputs, the
-- materials or maps in a Multi/Sub; then it goes into the selected material
fn AlecCreate_addToSme item className =
(
	local view = AlecCreate_activeView()
	if className == "Multimaterial" and AlecCreate_composes className then AlecCreate_composeMulti view item
	else if className == "VRayMultiSubTex" and AlecCreate_composes className then AlecCreate_composeMultiTex view item
	else
	(
		local inputs = AlecCreate_inputNodes view className
		local target = AlecCreate_linkTarget view className
		local pos = if inputs.count > 0 then AlecCreate_nodePosition view inputs
			else if target != undefined then AlecCreate_leftOf view target
			else AlecCreate_nodePosition view (view.GetSelectedNodes())
		AlecCreate_emptySlots item className
		AlecCreate_wire item className inputs
		AlecCreate_placeNode view item pos
		AlecCreate_link target item className
	)
)

-- what a texture file holds, from the words of its name; the first match of this order counts, base color last because "color" is a
-- common word. undefined when no word says: it stays out of the material
fn AlecCreate_textureRole file =
(
	local words = filterString (toLower (getFilenameFile file)) "_-. "
	local roles = #(#("rough", #("roughness", "rough", "rgh")), #("gloss", #("glossiness", "gloss")), #("metal", #("metalness", "metallic", "metal")),
		#("normal", #("normal", "normalgl", "normaldx", "nrm", "nor", "norm")), #("bump", #("bump")), #("opacity", #("opacity", "alpha")),
		#("emission", #("emission", "emissive", "emit")), #("base", #("basecolor", "albedo", "diffuse", "diff", "color", "col")))
	local found = for r in roles where (for k in r[2] where findItem words k > 0 collect k).count > 0 collect r[1]
	if found.count == 0 then undefined else found[1]
)

-- the slot of a material class that a texture of this role goes into, undefined when it has none (an OpenPBR has no glossiness)
fn AlecCreate_textureSlot className role =
(
	case (className + ":" + (role as string)) of
	(
		"VRayMtl:base": #texmap_diffuse
		"VRayMtl:rough": #texmap_reflectionGlossiness
		"VRayMtl:gloss": #texmap_reflectionGlossiness
		"VRayMtl:metal": #texmap_metalness
		"VRayMtl:normal": #texmap_bump
		"VRayMtl:bump": #texmap_bump
		"VRayMtl:opacity": #texmap_opacity
		"VRayMtl:emission": #texmap_self_illumination
		"OpenPBR_Material:base": #base_color_map
		"OpenPBR_Material:rough": #specular_roughness_map
		"OpenPBR_Material:metal": #base_metalness_map
		"OpenPBR_Material:normal": #geometry_normal_map
		"OpenPBR_Material:bump": #bump_map
		"OpenPBR_Material:opacity": #geometry_opacity_map
		"OpenPBR_Material:emission": #emission_color_map
		default: undefined
	)
)

-- the bitmap of a texture file: VRayBitmap for a VRayMtl, Uber Bitmap for an OpenPBR. What does not hold a color is read as linear data
fn AlecCreate_loadBitmap mapClass file role =
(
	local isData = role != undefined and role != "base" and role != "emission"
	local item = AlecCreate_make "map" mapClass
	if mapClass == "VRayBitmap" then
	(
		item.HDRIMapName = file
		if isData do item.color_space = 0
	)
	else
	(
		item.filename = file
		if isData do item.Filename_ColorSpace = "Raw"
	)
	item.name = filenameFromPath file
	item
)

fn AlecCreate_textureMap className file role =
	AlecCreate_loadBitmap (if className == "VRayMtl" then "VRayBitmap" else "osl_UberBitmap2b") file role

-- the map goes into the slot, a normal map through the normal node of the material's renderer, and the material is set up to use it (a
-- VRayMtl with black reflection shows no roughness or metalness; a color already there is kept). Gives the map or normal node that went in
fn AlecCreate_wireTexture item className role slot map =
(
	local input = AlecCreate_output map
	if role == "normal" do
	(
		local normalNode = AlecCreate_make "map" (if className == "VRayMtl" then "VRayNormalMap" else "Normal_Bump")
		normalNode.normal_map = input
		input = normalNode
	)
	setProperty item slot input
	case (className + ":" + role) of
	(
		"VRayMtl:rough": item.brdf_useRoughness = true
		"VRayMtl:metal": item.reflection_metalness = 1.0
		"VRayMtl:normal": item.texmap_bump_multiplier = 100
		"OpenPBR_Material:emission": item.emission_weight = 1.0
		default: ()
	)
	if className == "VRayMtl" and findItem #("rough", "gloss", "metal") role > 0 and item.Reflection == black do item.Reflection = white
	input
)

-- texture files go into the material, each to the slot its name says when that slot is empty (what is there is never replaced). Gives
-- #(material, the maps of the files that went nowhere, the maps of all the files, what went into the slots: maps or normal nodes)
fn AlecCreate_fillFromFiles item className files =
(
	local loose = #()
	local maps = #()
	local fed = #()
	for file in files do
	(
		local role = AlecCreate_textureRole file
		local slot = if role == undefined then undefined else AlecCreate_textureSlot className role
		local map = AlecCreate_textureMap className file role
		append maps map
		if slot != undefined and getProperty item slot == undefined then append fed (AlecCreate_source (AlecCreate_wireTexture item className role slot map))
		else append loose map
	)
	#(item, loose, maps, fed)
)

fn AlecCreate_materialFromFiles className files =
(
	local item = AlecCreate_make "material" className
	if className == "VRayMtl" do item.Reflection = white
	AlecCreate_fillFromFiles item className files
)

-- the material that texture files go into instead of a new one: the only one selected in the active Slate view, undefined when there is
-- none or it is of a class without texture slots here
fn AlecCreate_filesTarget =
(
	local mats = AlecCreate_selectedMaterials (AlecCreate_activeView())
	if mats.count == 1 and findItem #("VRayMtl", "OpenPBR_Material") (classOf mats[1].reference as string) > 0 then mats[1].reference else undefined
)

fn AlecCreate_collapseMaps view maps =
	for m in maps do AlecCreate_collapse (view.GetNodeByRef m) m

-- the files go into the selected material, whatever the button: their maps get nodes left of it, the ones that went nowhere under them
fn AlecCreate_fillSelected view target files =
(
	local made
	undo "Fill material" on
	(
		made = AlecCreate_fillFromFiles target (classOf target as string) files
		local pos = AlecCreate_leftOf view target
		local stack = made[4] + made[2]
		for i = 1 to stack.count do view.CreateNode stack[i] (pos + [0, 200 * (i - 1)])
		AlecCreate_collapseMaps view made[3]
		view.SetSelectedNodes #(target)
	)
	made
)

-- a new material over the Slate view goes at spot (next to the selection when undefined), the files that went nowhere as loose nodes under it
fn AlecCreate_placeFromFiles view className files spot =
(
	local made = AlecCreate_materialFromFiles className files
	local pos = if spot == undefined then AlecCreate_nodePosition view (view.GetSelectedNodes()) else spot
	undo "Create material" on
	(
		for i = 1 to made[2].count do view.CreateNode made[2][i] (pos + [0, 200 * i])
		AlecCreate_placeNode view made[1] pos
		AlecCreate_collapseMaps view made[3]
	)
	made
)

-- files buttons: over the Slate view they fill the selected material, else make a new one; over a viewport the new one goes to the
-- selected objects
fn AlecCreate_fromFiles className files inSme spot =
(
	local made
	if inSme then
	(
		local view = AlecCreate_activeView()
		local target = AlecCreate_filesTarget()
		made = if target != undefined then AlecCreate_fillSelected view target files else AlecCreate_placeFromFiles view className files spot
	)
	else
	(
		made = AlecCreate_materialFromFiles className files
		AlecCreate_assign made[1]
	)
	if made[2].count > 0 do
		displayTempPrompt ("Create: not connected: " + (made[2].count as string) + " of " + (files.count as string) + " files, no free slot or the name did not say where (see the Listener)") 4000
	for m in made[2] do format "Create: not connected: %\n" m.name
)

-- VRayBitmap and UberBitmap buttons: a node per file, all selected, as one undo step. The first goes at spot, or when it is undefined next to
-- the selection and into the selected material's empty slot (see AlecCreate_addToSme); the others go under it
fn AlecCreate_addBitmaps className files spot =
(
	local view = AlecCreate_activeView()
	local items = for file in files collect AlecCreate_loadBitmap className file (AlecCreate_textureRole file)
	undo "Create node" on
	(
		if spot == undefined then AlecCreate_addToSme items[1] className else AlecCreate_placeNode view items[1] spot
		local first = view.GetNodeByRef items[1]
		local pos = first.position
		for i = 2 to items.count do AlecCreate_collapse (view.CreateNode items[i] (pos + [0, 200 * (i - 1)])) items[i]
		view.SetSelectedNodes items
	)
)

-- the top selected node's unused slots, hidden or shown
fn AlecCreate_setTopHideUnused hide =
	(AlecCreate_topToBottom ((AlecCreate_activeView()).GetSelectedNodes()))[1].hideUnusedNodeSlots = hide

-- Add button without the editor's menu: kind is "material" or "map", className a class name; inSme is whether the mouse was over the
-- Slate view when the popup opened (then it is a node next to the selection), else a material goes to the selected objects
fn AlecCreate_add kind className inSme =
(
	local item = AlecCreate_make kind className
	if item == undefined then displayTempPrompt ("Create: " + className + " is not installed") 3000
	else if inSme then undo "Create node" on AlecCreate_addToSme item className
	else if kind == "material" do AlecCreate_assign item
)
