-- Test for the USD Preview Surface reading of tools/universalConverterRead.ms. Run in Max (needs USD for 3ds Max and V-Ray):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\universalConverterUsd_test.ms"
-- Makes materials in memory only (no scene objects), reads them and writes Natural VRayMtls. Prints PASS/FAIL lines to the Listener.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/universalConverterRead.ms")
fileIn (AlecTools_path "tools/universalConverterWrite.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	fn near a b = abs (a - b) < 0.001
	fn usdToVRay m =
	(
		local r = AlecConv_newRec()
		AlecConv_readUsd r m
		#(r, AlecConv_writeVRay r #natural)
	)

	-- metallic workflow: metallic and IOR are used, the specular colour is not
	local usd = MaxUsdPreviewSurface metallic:0.7 ior:1.8 roughness:0.3 specularColor:red
	local res = usdToVRay usd
	local v = res[2]
	if not (check "metallic: metalness and IOR" (near v.reflection_metalness 0.7 and near v.reflection_ior 1.8)) do failures += 1
	if not (check "metallic: reflection stays white" (v.reflection == white)) do failures += 1
	if not (check "metallic: roughness as glossiness" (near v.reflection_glossiness 0.7)) do failures += 1
	if not (check "metallic: specular colour noted as dropped" \
		(findItem res[1].notes "specular colour dropped: the metallic workflow does not use it" != 0)) do failures += 1

	-- specular workflow: F0 0.04 grey is IOR 1.5 and a white reflection, metallic and IOR are ignored
	usd = MaxUsdPreviewSurface metallic:0.7 ior:3.0 specularColor:(AlecConv_grey 0.04)
	usd.useSpecularWorkflow = true
	v = (usdToVRay usd)[2]
	if not (check "specular: IOR from F0 0.04" (abs (v.reflection_ior - 1.5) < 0.01)) do failures += 1
	if not (check "specular: white reflection, metalness 0" (v.reflection == white and v.reflection_metalness == 0.0)) do failures += 1

	-- specular workflow: a coloured F0 gives its hue as the reflection colour
	usd = MaxUsdPreviewSurface specularColor:(color 204 102 0)
	usd.useSpecularWorkflow = true
	v = (usdToVRay usd)[2]
	if not (check "specular: hue as reflection colour" (near v.reflection.r 255 and near v.reflection.g 127.5 and near v.reflection.b 0)) do failures += 1
	if not (check "specular: IOR from the brightest channel (0.8)" (abs (v.reflection_ior - 17.944) < 0.05)) do failures += 1

	-- specular workflow: a specular map is the reflection colour with IOR 50
	local tex = Checker()
	usd = MaxUsdPreviewSurface specularColor_map:tex
	usd.useSpecularWorkflow = true
	v = (usdToVRay usd)[2]
	if not (check "specular map: reflection map, IOR 50" (v.texmap_reflection == tex and near v.reflection_ior 50.0)) do failures += 1

	-- no refraction: opacity is a cutout (VRayMtl opacity), refraction stays black
	usd = MaxUsdPreviewSurface opacity:0.5
	v = (usdToVRay usd)[2]
	if not (check "opacity: cutout, no refraction" (v.texmap_opacity != undefined and v.refraction == black)) do failures += 1

	format "universalConverterUsd_test: % failure(s)\n" failures
)
