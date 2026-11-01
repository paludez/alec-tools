-- Test for the VRayMtl modes of tools/universalConverter.ms (OpenPBR mode is never written). Run in Max (needs V-Ray):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\universalConverterMode_test.ms"
-- Makes materials in memory only (no scene objects). Prints PASS/FAIL lines to the Listener.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/universalConverter.ms")

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	local auto = AlecConv_Settings()

	-- Auto: roughness sources and VRayMtls in OpenPBR mode get Roughness, Natural VRayMtls and Standard keep Natural
	local pbrVRay = VRayMtl option_openPBRMode:true
	if not (check "auto: OpenPBR_Material -> Roughness" (AlecConv_vrayTargetMode auto "openpbr_material" (OpenPBR_Material()) == #rough)) do failures += 1
	if not (check "auto: VRayMtl in OpenPBR mode -> Roughness" (AlecConv_vrayTargetMode auto "vraymtl" pbrVRay == #rough)) do failures += 1
	if not (check "auto: Natural VRayMtl stays Natural" (AlecConv_vrayTargetMode auto "vraymtl" (VRayMtl()) == #natural)) do failures += 1
	if not (check "auto: Standard -> Natural" (AlecConv_vrayTargetMode auto "standardmaterial" (Standardmaterial()) == #natural)) do failures += 1

	-- a VRayMtl in OpenPBR mode comes out with OpenPBR mode off, its refraction roughness 0.2 as glossiness 0.8
	pbrVRay.refraction_glossiness = 0.2
	pbrVRay.texmap_refractionGlossiness = Checker()
	pbrVRay.texmap_refractionGlossiness_on = true
	local job = AlecConv_Job settings:auto
	local out = AlecConv_vrayModeChange job pbrVRay #rough
	if not (check "mode change: OpenPBR mode off, Use roughness on" (not out.option_openPBRMode and out.brdf_useRoughness)) do failures += 1
	if not (check "mode change: refraction roughness to glossiness" (abs (out.refraction_glossiness - 0.8) < 0.001)) do failures += 1
	if not (check "mode change: refraction map noted" \
		(findItem job.log "    refraction map: roughness in a glossiness slot, needs inverting" != 0)) do
	(
		failures += 1
		format "    map read: %, log: %\n" (AlecConv_vrayMap pbrVRay "refractionGlossiness") job.log
	)

	format "universalConverterMode_test: % failure(s)\n" failures
)
