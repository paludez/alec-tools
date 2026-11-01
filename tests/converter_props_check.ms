-- Property check for UniversalConverter: which classes exist, and every property with its default value.
-- Creates material and map instances in memory only (nothing in the scene, nothing in the Material Editor).
-- Writes the full list to converter_props.txt next to this file and prints a short summary in the Listener.
-- Run:  fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\converter_props_check.ms"

global AlecConvCheck_out = getFilenamePath (getSourceFileName()) + "converter_props.txt"

global AlecConvCheck_materials = #(
	"VRayMtl", "OpenPBR_Material", "PhysicalMaterial", "Standardmaterial", "ai_Standard_Surface", "glTFMaterial",
	"MaxUsdPreviewSurface", "Multimaterial", "Blend", "DoubleSided", "TopBottom", "Shell_Material",
	"VRayBlendMtl", "VRay2SidedMtl", "VRayOverrideMtl", "VRayMtlWrapper", "VRayLightMtl", "ai_mix_shader"
)

global AlecConvCheck_maps = #(
	"Bitmaptexture", "VRayBitmap", "OSLMap", "output", "Mix", "RGB_Multiply", "VRayCompTex", "Normal_Bump", "VRayNormalMap"
)

fn AlecConvCheck_classNamed name superList =
(
	for c in superList.classes where (stricmp (c as string) name) == 0 do return c
	undefined
)

fn AlecConvCheck_dump f c =
(
	local inst = try (c()) catch (format "FAIL create %: %\n" c (getCurrentException()); undefined)
	if inst != undefined do
	(
		format "== %\n" c to:f
		for p in getPropNames inst do
		(
			local v = try (getProperty inst p) catch ("<" + getCurrentException() + ">")
			format "%  =  %\n" p v to:f
		)
		format "\n" to:f
	)
	inst != undefined
)

fn AlecConvCheck_run =
(
	local f = createFile AlecConvCheck_out
	for pair in #(#(AlecConvCheck_materials, material), #(AlecConvCheck_maps, textureMap)) do
		for name in pair[1] do
		(
			local c = AlecConvCheck_classNamed name pair[2]
			if c == undefined then
			(
				format "MISSING class %\n" name
				format "== % MISSING\n\n" name to:f
			)
			else if AlecConvCheck_dump f c do format "OK %\n" name
		)
	close f
	format "Written: %\n" AlecConvCheck_out
)

AlecConvCheck_run()
