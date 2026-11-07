-- UniversalConverter, writing (loaded by tools/universalConverter.ms): a new material of the target class from a record (AlecUniversalConverter_Rec,
-- tools/universalConverterRead.ms). What the target has no slot for is dropped and noted in the record, for the log.

-- colour × weight, for a target without the weight slot: #(colour, map)
fn AlecUniversalConverter_fold r colKey wKey =
(
	local c = AlecUniversalConverter_get r colKey
	local cMap = AlecUniversalConverter_map r colKey
	local w = AlecUniversalConverter_get r wKey
	local wMap = AlecUniversalConverter_map r wKey
	if wMap != undefined then #(c, cMap) else #(c * w, cMap)
)

-- one note per map in the record whose class matches the pattern: the target's renderer cannot render it
fn AlecUniversalConverter_noteMapRenderer r pattern txt =
(
	for k in r.maps.keys where matchPattern (AlecUniversalConverter_className (AlecUniversalConverter_map r k)) pattern:pattern do
		AlecUniversalConverter_note r (substituteString txt "%" (k as string))
)

-- OpenPBR_Material

fn AlecUniversalConverter_writeOpenPBR r =
(
	local m = OpenPBR_Material()
	for k in AlecUniversalConverter_pbrKeys do
	(
		setProperty m k (AlecUniversalConverter_get r k)
		setProperty m ((k as string + "_map") as name) (AlecUniversalConverter_map r k)
	)
	m.geometry_thin_walled = AlecUniversalConverter_get r #geometry_thin_walled
	-- OpenPBR has only the cutout map: an opacity under 1 without a map becomes Max's OSL Color Value (SetColor.osl) of that grey
	local opacity = AlecUniversalConverter_get r #geometry_opacity
	m.geometry_opacity_map = AlecUniversalConverter_map r #geometry_opacity
	if m.geometry_opacity_map == undefined and opacity < 1.0 do
	(
		local value = OSLMap()
		value.OSLPath = (getDir #maxRoot) + @"OSL\SetColor.osl"
		setProperty value #In (AlecUniversalConverter_grey opacity)
		m.geometry_opacity_map = value
	)
	m.bump_map = AlecUniversalConverter_map r #bump
	m.bump_map_amt = AlecUniversalConverter_get r #bump
	m.geometry_normal_map = AlecUniversalConverter_map r #geometry_normal
	m.coat_bump_map = AlecUniversalConverter_map r #coat_bump
	m.coat_bump_map_amt = AlecUniversalConverter_get r #coat_bump
	m.geometry_coat_normal_map = AlecUniversalConverter_map r #geometry_coat_normal
	m.displacement_map = AlecUniversalConverter_map r #displacement
	m.displacement_map_amt = AlecUniversalConverter_get r #displacement
	AlecUniversalConverter_noteMapRenderer r "vray*" "V-Ray map in % will not render in Arnold"
	m
)

-- VRayMtl

-- a roughness value and map into a lobe's glossiness slot. The map is linked as it is: when it held roughness (mapRough) and the
-- slot holds glossiness, or the other way round, it is noted in r
fn AlecUniversalConverter_setVRayRough r m mode lobe rough tex mapRough:true =
(
	local slot = AlecUniversalConverter_glossSlot lobe
	local isRough = AlecUniversalConverter_holdsRough mode lobe
	local p = "texmap_" + slot[2]
	if tex != undefined and isRough != mapRough do
		AlecUniversalConverter_note r (toLower (lobe as string) + " map: " + (if mapRough then "roughness in a glossiness slot" else "glossiness in a roughness slot") + ", needs inverting")
	setProperty m slot[1] (if isRough then rough else 1.0 - rough)
	setProperty m (p as name) tex
	setProperty m ((p + "_on") as name) true
	setProperty m ((p + "_multiplier") as name) 100.0
)

fn AlecUniversalConverter_writeVRaySurface r m mode =
(
	local diffuse = AlecUniversalConverter_fold r #base_color #base_weight
	local rough = AlecUniversalConverter_get r #specular_roughness
	local roughMap = AlecUniversalConverter_map r #specular_roughness
	local ior = AlecUniversalConverter_get r #specular_ior
	local iorMap = AlecUniversalConverter_map r #specular_ior
	m.diffuse = diffuse[1]
	m.texmap_diffuse = diffuse[2]
	m.diffuse_roughness = AlecUniversalConverter_get r #base_diffuse_roughness
	m.texmap_roughness = AlecUniversalConverter_map r #base_diffuse_roughness
	m.reflection_metalness = AlecUniversalConverter_get r #base_metalness
	m.texmap_metalness = AlecUniversalConverter_map r #base_metalness
	if AlecUniversalConverter_map r #specular_weight != undefined then
	(
		local refl = AlecUniversalConverter_fold r #specular_color #specular_weight
		m.reflection = refl[1]
		m.texmap_reflection = refl[2]
	)
	else
	(
		m.reflection = AlecUniversalConverter_get r #specular_color
		m.texmap_reflection = AlecUniversalConverter_map r #specular_color
		m.reflection_weight = AlecUniversalConverter_get r #specular_weight
	)
	AlecUniversalConverter_setVRayRough r m mode #reflection rough roughMap
	AlecUniversalConverter_setVRayRough r m mode #refraction rough roughMap
	m.reflection_lockIOR = true
	m.reflection_ior = ior
	m.refraction_ior = ior
	m.texmap_reflectionIOR = iorMap
	m.texmap_refractionIOR = iorMap
	m.anisotropy = AlecUniversalConverter_get r #specular_roughness_anisotropy
	m.texmap_anisotropy = AlecUniversalConverter_map r #specular_roughness_anisotropy
)

-- a transmission depth makes the transmission colour the fog colour at that depth, else it tints the refraction
fn AlecUniversalConverter_writeVRayVolume r m =
(
	local depth = AlecUniversalConverter_get r #transmission_depth
	local depthMap = AlecUniversalConverter_map r #transmission_depth
	if depth > 0 or depthMap != undefined then
	(
		m.refraction = AlecUniversalConverter_grey (AlecUniversalConverter_get r #transmission_weight)
		m.texmap_refraction = AlecUniversalConverter_map r #transmission_weight
		m.refraction_fogColor = AlecUniversalConverter_get r #transmission_color
		m.texmap_refraction_fog = AlecUniversalConverter_map r #transmission_color
		m.refraction_fogDepth = depth
		m.texmap_refraction_fog_depth = depthMap
		m.refraction_fogUnitsScale_on = true
	)
	else
	(
		local refr = AlecUniversalConverter_fold r #transmission_color #transmission_weight
		m.refraction = refr[1]
		m.texmap_refraction = refr[2]
	)
	m.refraction_dispersion_on = AlecUniversalConverter_get r #transmission_dispersion_scale > 0
	m.refraction_dispersion = AlecUniversalConverter_get r #transmission_dispersion_abbe_number
	m.refraction_thinWalled = AlecUniversalConverter_get r #geometry_thin_walled
	if AlecUniversalConverter_get r #transmission_scatter != black do AlecUniversalConverter_note r "transmission scatter dropped"
	if AlecUniversalConverter_used r #subsurface_weight do AlecUniversalConverter_note r "subsurface dropped (the VRayMtl translucency types are not checked yet)"
)

-- thin film: a thickness map (µm) goes over 0 - 1000 nm, a value to both min and max
fn AlecUniversalConverter_writeVRayFilm r m =
(
	local filmMap = AlecUniversalConverter_map r #thin_film_thickness
	local nm = 1000.0 * AlecUniversalConverter_get r #thin_film_thickness
	m.thinFilm_on = true
	m.thinFilm_thickness_min = if filmMap != undefined then 0.0 else nm
	m.thinFilm_thickness_max = if filmMap != undefined then 1000.0 else nm
	m.texmap_thinFilm_thickness = filmMap
	m.thinFilm_ior = AlecUniversalConverter_get r #thin_film_ior
	m.texmap_thinFilm_ior = AlecUniversalConverter_map r #thin_film_ior
	if AlecUniversalConverter_get r #thin_film_weight < 1.0 or AlecUniversalConverter_map r #thin_film_weight != undefined do AlecUniversalConverter_note r "thin film weight dropped"
)

fn AlecUniversalConverter_writeVRayEmission r m =
(
	local glow = AlecUniversalConverter_fold r #emission_color #emission_weight
	m.selfIllumination = glow[1]
	m.texmap_self_illumination = glow[2]
	m.selfIllumination_multiplier = AlecUniversalConverter_get r #emission_luminance / AlecUniversalConverter_nitsPerUnit
	if AlecUniversalConverter_map r #emission_luminance != undefined do AlecUniversalConverter_note r "emission luminance map dropped"
	AlecUniversalConverter_note r "emission: unit factor not calibrated yet"
)

fn AlecUniversalConverter_writeVRayLayers r m mode =
(
	local sheen = AlecUniversalConverter_fold r #fuzz_color #fuzz_weight
	m.sheen_color = sheen[1]
	m.texmap_sheen = sheen[2]
	AlecUniversalConverter_setVRayRough r m mode #sheen (AlecUniversalConverter_get r #fuzz_roughness) (AlecUniversalConverter_map r #fuzz_roughness)
	m.coat_amount = AlecUniversalConverter_get r #coat_weight
	m.texmap_coat_amount = AlecUniversalConverter_map r #coat_weight
	m.coat_color = AlecUniversalConverter_get r #coat_color
	m.texmap_coat_color = AlecUniversalConverter_map r #coat_color
	AlecUniversalConverter_setVRayRough r m mode #coat (AlecUniversalConverter_get r #coat_roughness) (AlecUniversalConverter_map r #coat_roughness)
	m.coat_ior = AlecUniversalConverter_get r #coat_ior
	m.texmap_coat_ior = AlecUniversalConverter_map r #coat_ior
	m.coat_darkening = AlecUniversalConverter_get r #coat_darkening
	m.texmap_coat_darkening = AlecUniversalConverter_map r #coat_darkening
	m.coat_anisotropy = AlecUniversalConverter_get r #coat_roughness_anisotropy
	if AlecUniversalConverter_used r #thin_film_weight do AlecUniversalConverter_writeVRayFilm r m
	if AlecUniversalConverter_used r #emission_weight do AlecUniversalConverter_writeVRayEmission r m
)

-- one bump slot: the normal map when there is one (a bump next to it is dropped), else the bump at its amount
fn AlecUniversalConverter_writeVRayBump r m slot normalKey bumpKey =
(
	local normal = AlecUniversalConverter_map r normalKey
	local bump = AlecUniversalConverter_map r bumpKey
	local p = "texmap_" + slot
	setProperty m (p as name) (if normal != undefined then normal else bump)
	setProperty m ((p + "_multiplier") as name) (if normal != undefined then 100.0 else 100.0 * AlecUniversalConverter_get r bumpKey)
	if normal != undefined and bump != undefined do AlecUniversalConverter_note r (slot + ": bump dropped, the normal map kept")
)

fn AlecUniversalConverter_writeVRay r mode =
(
	local m = VRayMtl()
	m.brdf_useRoughness = mode == #rough
	AlecUniversalConverter_writeVRaySurface r m mode
	AlecUniversalConverter_writeVRayVolume r m
	AlecUniversalConverter_writeVRayLayers r m mode
	-- VRayMtl has no opacity value: an opacity under 1 without a map becomes a VRayColor of that grey
	local opacity = AlecUniversalConverter_get r #geometry_opacity
	m.texmap_opacity = AlecUniversalConverter_map r #geometry_opacity
	if m.texmap_opacity == undefined and opacity < 1.0 do m.texmap_opacity = VRayColor color:(AlecUniversalConverter_grey opacity)
	AlecUniversalConverter_writeVRayBump r m "bump" #geometry_normal #bump
	AlecUniversalConverter_writeVRayBump r m "coat_bump" #geometry_coat_normal #coat_bump
	m.texmap_displacement = AlecUniversalConverter_map r #displacement
	m.texmap_displacement_multiplier = AlecUniversalConverter_get r #displacement
	AlecUniversalConverter_noteMapRenderer r "ai_*" "Arnold map in % will not render in V-Ray GPU"
	m
)
