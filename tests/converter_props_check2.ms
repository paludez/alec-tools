-- Second property check for UniversalConverter, for what getPropNames did not list:
--   VRayMtl (getPropNames skipped its main parameters), a texture's Output (StandardTextureOutput),
--   and Standard's map aliases (diffuseMap, ...MapAmount, ...MapEnable).
-- Creates instances in memory only. Writes converter_props2.txt next to this file.
-- Run:  fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\converter_props_check2.ms"

global AlecConvCheck2_out = getFilenamePath (getSourceFileName()) + "converter_props2.txt"

global AlecConvCheck2_standardNames = #(
	#diffuseMap, #diffuseMapAmount, #diffuseMapEnable, #specularMap, #specularMapAmount, #specularMapEnable,
	#specularLevelMap, #specularLevelMapAmount, #specularLevelMapEnable, #glossinessMap, #glossinessMapAmount,
	#glossinessMapEnable, #selfIllumMap, #selfIllumMapAmount, #selfIllumMapEnable, #opacityMap, #opacityMapAmount,
	#opacityMapEnable, #bumpMap, #bumpMapAmount, #bumpMapEnable, #displacementMap, #displacementMapAmount
)

-- showProperties lists every property as "  .name (alias) : type"; each line is written with its value.
fn AlecConvCheck2_showAll f title inst =
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

fn AlecConvCheck2_standard f =
(
	format "== Standardmaterial aliases\n" to:f
	local m = Standardmaterial()
	for p in AlecConvCheck2_standardNames do
		if isProperty m p then format "%  =  %\n" p (getProperty m p) to:f
		else format "% MISSING\n" p to:f
	format "\n" to:f
)

fn AlecConvCheck2_run =
(
	local f = createFile AlecConvCheck2_out
	if VRayMtl != undefined then AlecConvCheck2_showAll f "VRayMtl" (VRayMtl()) else format "MISSING class VRayMtl\n"
	AlecConvCheck2_showAll f "Output.output (StandardTextureOutput)" (Output()).output
	AlecConvCheck2_standard f
	close f
	format "Written: %\n" AlecConvCheck2_out
)

AlecConvCheck2_run()
