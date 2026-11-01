-- Property and behavior check for the Light Converter: which classes exist, every property with its default value,
-- and how the lights behave (exclusive color types, size and axes, targets, mesh source, shadow generator).
-- Creates temporary lights, deletes them at the end, does not save the scene and adds nothing to undo.
-- Writes everything to light_props.txt next to this file and prints a short summary in the Listener.
-- Run:  fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\light_props_check.ms"

global AlecLightCheck_out = getFilenamePath (getSourceFileName()) + "light_props.txt"
global AlecLightCheck_nodes = #()

fn AlecLightCheck_classNamed name superList =
(
	local found = undefined
	for c in superList.classes while found == undefined where (stricmp (c as string) name) == 0 do found = c
	found
)

-- showProperties lists every property as "  .name (alias) : type"; each line is written with its value
fn AlecLightCheck_showAll f title inst =
(
	format "== %\n" title to:f
	local ss = stringStream ""
	showProperties inst to:ss
	seek ss 0
	while not eof ss do
	(
		local line = trimLeft (readLine ss)
		if line.count > 1 and line[1] == "." do
		(
			local name = (filterString (substring line 2 -1) " :")[1]
			local v = try (getProperty inst name) catch ("<" + getCurrentException() + ">")
			format "%  =  %\n" line v to:f
		)
	)
	format "\n" to:f
)

-- the names of a class list that match one of the patterns
fn AlecLightCheck_listClasses f title superList patterns =
(
	format "== classes: %\n" title to:f
	for c in superList.classes do
		for p in patterns where matchPattern (c as string) pattern:p do
		(
			format "%\n" c to:f
			exit
		)
	format "\n" to:f
)

fn AlecLightCheck_dumpClass f name superList =
(
	local c = AlecLightCheck_classNamed name superList
	if c == undefined then
	(
		format "MISSING class %\n" name
		format "== % MISSING\n\n" name to:f
	)
	else
	(
		format "OK %\n" name
		AlecLightCheck_showAll f name (c())
	)
)

fn AlecLightCheck_keep node =
(
	append AlecLightCheck_nodes node
	node
)

-- the size of a light's icon along its own axes, how Length and Width lie on the node
fn AlecLightCheck_localSize node =
(
	local box = nodeGetBoundingBox node node.transform
	box[2] - box[1]
)

fn AlecLightCheck_read f inst names =
	for n in names do
		format "  .% = %\n" n (try (getProperty inst n) catch ("<" + getCurrentException() + ">")) to:f

fn AlecLightCheck_arnold f =
(
	format "== Arnold_Light behavior\n" to:f
	for t = 0 to 8 do
	(
		local a = AlecLightCheck_keep (Arnold_Light shapeType:t)
		format "shapeType %: viewport size %, props different from type 0 are in the dump below\n" t (AlecLightCheck_localSize a) to:f
	)
	local a = AlecLightCheck_keep (Arnold_Light shapeType:3 quadX:100.0 quadY:40.0)
	format "quad quadX 100 quadY 40: local size %, emits along local -Z if the arrow says so; transform %\n" (AlecLightCheck_localSize a) a.transform to:f
	-- are useColor, usePreset, useKelvin and useTexmap exclusive?
	format "defaults:\n" to:f
	AlecLightCheck_read f a #(#useColor, #usePreset, #useKelvin, #useTexmap, #camera, #lightShapeVisible, #normalize, #filter)
	a.useKelvin = true
	format "after useKelvin on:\n" to:f
	AlecLightCheck_read f a #(#useColor, #usePreset, #useKelvin, #useTexmap)
	a.useTexmap = true
	format "after useTexmap on:\n" to:f
	AlecLightCheck_read f a #(#useColor, #usePreset, #useKelvin, #useTexmap)
	a.useColor = true
	format "after useColor on:\n" to:f
	AlecLightCheck_read f a #(#useColor, #usePreset, #useKelvin, #useTexmap)
	a.targeted = true
	format "targeted on: node.target = %, targDist = %\n" a.target a.targDist to:f
	if a.target != undefined do AlecLightCheck_keep a.target
	format "exclude: excludeList %, includeList %, inclExclType %\n" (isProperty a #excludeList) (isProperty a #includeList) (isProperty a #inclExclType) to:f
	format "\n" to:f
	AlecLightCheck_showAll f "Arnold_Light (quad)" a
)

fn AlecLightCheck_vray f =
(
	format "== VRayLight behavior\n" to:f
	for t = 0 to 4 do
	(
		local v = AlecLightCheck_keep (VRayLight type:t)
		format "type %:\n" t to:f
		AlecLightCheck_read f v #(#size0, #size1, #size2, #sizeLength, #sizeWidth, #sizeRadius, #sizeU, #sizeV)
	)
	local v = AlecLightCheck_keep (VRayLight type:0)
	v.sizeLength = 100.0
	v.sizeWidth = 40.0
	format "plane sizeLength 100 sizeWidth 40: local size %, size0 %, size1 %\n" (AlecLightCheck_localSize v) v.size0 v.size1 to:f
	local d = AlecLightCheck_keep (VRayLight type:4)
	d.size0 = 30.0
	format "disc size0 30: local size %, sizeRadius %\n" (AlecLightCheck_localSize d) d.sizeRadius to:f
	local s = AlecLightCheck_keep (VRayLight type:2)
	s.size0 = 30.0
	format "sphere size0 30: local size %, sizeRadius %\n" (AlecLightCheck_localSize s) s.sizeRadius to:f
	local c = AlecLightCheck_keep (Cylinder radius:10 height:50)
	local m = AlecLightCheck_keep (VRayLight type:3)
	local r = try (m.mesh_source = c; "set") catch ("<" + getCurrentException() + ">")
	format "mesh_source on a cylinder: % reads %, replaceOnPick %\n" r m.mesh_source m.mesh_replaceOnPick to:f
	format "\n" to:f
	AlecLightCheck_showAll f "VRayLight (plane)" v
	AlecLightCheck_showAll f "VRayLight (mesh)" m
)

fn AlecLightCheck_standard f =
(
	format "== Standard lights\n" to:f
	local t = AlecLightCheck_keep (TargetSpot())
	format "TargetSpot: target %\n" t.target to:f
	if t.target != undefined do AlecLightCheck_keep t.target
	local r = try (t.shadowGenerator = VRayShadow(); "set") catch ("<" + getCurrentException() + ">")
	format "shadowGenerator: % reads %\n" r t.shadowGenerator to:f
	local free = AlecLightCheck_keep (FreeSpot())
	local dir = AlecLightCheck_keep (TargetDirectionallight())
	if dir.target != undefined do AlecLightCheck_keep dir.target
	local freeDir = AlecLightCheck_keep (Directionallight())
	format "classes: % % % %\n\n" (classOf t) (classOf free) (classOf dir) (classOf freeDir) to:f
	AlecLightCheck_showAll f "TargetSpot" t
	AlecLightCheck_showAll f "TargetDirectionallight" dir
	if classOf t.shadowGenerator != UndefinedClass do AlecLightCheck_showAll f "shadowGenerator" t.shadowGenerator
)

fn AlecLightCheck_sun f =
(
	local sun = AlecLightCheck_keep (VRaySun())
	format "== VRaySun target: %\n\n" sun.target to:f
	if sun.target != undefined do AlecLightCheck_keep sun.target
	AlecLightCheck_showAll f "VRaySun" sun
	local ies = AlecLightCheck_keep (VRayIES())
	if ies.target != undefined do AlecLightCheck_keep ies.target
	AlecLightCheck_showAll f "VRayIES" ies
)

fn AlecLightCheck_run =
(
	local f = createFile AlecLightCheck_out
	AlecLightCheck_listClasses f "lights" light #("*")
	AlecLightCheck_listClasses f "maps" textureMap #("*sky*", "*sun*", "*bitmap*", "*image*", "*OSL*", "ai_*")
	AlecLightCheck_listClasses f "modifiers" modifier #("*arnold*")
	AlecLightCheck_listClasses f "render elements" renderElement #("*select*", "*light*")
	for name in #("VRaySky", "VRayBitmap", "OSLMap", "OSL_UberBitmap2", "Physical_Sky", "ai_physical_sky", "ai_image", "Bitmaptexture") do
		AlecLightCheck_dumpClass f name textureMap
	for name in #("Arnold_Light_Decay", "Arnold_Light_Gobo", "Arnold_Light_Barndoor", "ArnoldLightBlockerFilterModifier") do
		AlecLightCheck_dumpClass f name modifier
	AlecLightCheck_dumpClass f "VRayLightSelect" renderElement
	with undo off with redraw off
	(
		for one in #(
			#("Arnold_Light", AlecLightCheck_arnold), #("VRayLight", AlecLightCheck_vray),
			#("VRayShadow", AlecLightCheck_standard), #("VRaySun", AlecLightCheck_sun)) do
			if (AlecLightCheck_classNamed one[1] light) != undefined or one[1] == "VRayShadow" then
				try (one[2] f; format "OK behavior %\n" one[1])
				catch format "FAIL behavior %: %\n" one[1] (getCurrentException())
			else format "MISSING class %\n" one[1]
		for n in AlecLightCheck_nodes where isValidNode n do delete n
	)
	close f
	format "Written: %\n" AlecLightCheck_out
)

AlecLightCheck_run()
