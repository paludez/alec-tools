-- UniversalConverter, writing (loaded by tools/universalConverter.ms): a new material of the target class from a record (AlecConv_Rec,
-- tools/universalConverterRead.ms). What the target has no slot for is dropped and noted in the record, for the log.

-- colour × weight, for a target without the weight slot: #(colour, map)
fn AlecConv_fold r colKey wKey =
(
	local c = AlecConv_get r colKey
	local cMap = AlecConv_map r colKey
	local w = AlecConv_get r wKey
	local wMap = AlecConv_map r wKey
	if wMap != undefined then #(c, cMap) else #(c * w, cMap)
)

fn AlecConv_lerp a b t = a * (1.0 - t) + b * t

-- OpenPBR_Material

fn AlecConv_writeOpenPBR r =
(
	local m = OpenPBR_Material()
	for k in AlecConv_pbrKeys do
	(
		setProperty m k (AlecConv_get r k)
		setProperty m ((k as string + "_map") as name) (AlecConv_map r k)
	)
	m.geometry_thin_walled = AlecConv_get r #geometry_thin_walled
	-- OpenPBR has only the cutout map: an opacity under 1 without a map becomes Max's OSL Color Value (SetColor.osl) of that grey
	local opacity = AlecConv_get r #geometry_opacity
	m.geometry_opacity_map = AlecConv_map r #geometry_opacity
	if m.geometry_opacity_map == undefined and opacity < 1.0 do
	(
		local value = OSLMap()
		value.OSLPath = (getDir #maxRoot) + @"OSL\SetColor.osl"
		setProperty value #In (AlecConv_grey opacity)
		m.geometry_opacity_map = value
	)
	m.bump_map = AlecConv_map r #bump
	m.bump_map_amt = AlecConv_get r #bump
	m.geometry_normal_map = AlecConv_map r #geometry_normal
	m.coat_bump_map = AlecConv_map r #coat_bump
	m.coat_bump_map_amt = AlecConv_get r #coat_bump
	m.geometry_coat_normal_map = AlecConv_map r #geometry_coat_normal
	m.displacement_map = AlecConv_map r #displacement
	m.displacement_map_amt = AlecConv_get r #displacement
	for k in r.maps.keys where matchPattern (AlecConv_className (AlecConv_map r k)) pattern:"vray*" do
		AlecConv_note r ("V-Ray map in " + k as string + " will not render in Arnold")
	m
)

-- VRayMtl

-- a roughness value and map into a lobe's glossiness slot. The map is linked as it is: when it held roughness (mapRough) and the
-- slot holds glossiness, or the other way round, it is noted in r
fn AlecConv_setVRayRough r m mode lobe rough tex mapRough:true =
(
	local slot = AlecConv_glossSlot lobe
	local isRough = AlecConv_holdsRough mode lobe
	local p = "texmap_" + slot[2]
	if tex != undefined and isRough != mapRough do
		AlecConv_note r (toLower (lobe as string) + " map: " + (if mapRough then "roughness in a glossiness slot" else "glossiness in a roughness slot") + ", needs inverting")
	setProperty m slot[1] (if isRough then rough else 1.0 - rough)
	setProperty m (p as name) tex
	setProperty m ((p + "_on") as name) true
	setProperty m ((p + "_multiplier") as name) 100.0
)

fn AlecConv_writeVRaySurface r m mode =
(
	local diffuse = AlecConv_fold r #base_color #base_weight
	local rough = AlecConv_get r #specular_roughness
	local roughMap = AlecConv_map r #specular_roughness
	local ior = AlecConv_get r #specular_ior
	local iorMap = AlecConv_map r #specular_ior
	m.diffuse = diffuse[1]
	m.texmap_diffuse = diffuse[2]
	m.diffuse_roughness = AlecConv_get r #base_diffuse_roughness
	m.texmap_roughness = AlecConv_map r #base_diffuse_roughness
	m.reflection_metalness = AlecConv_get r #base_metalness
	m.texmap_metalness = AlecConv_map r #base_metalness
	if AlecConv_map r #specular_weight != undefined then
	(
		local refl = AlecConv_fold r #specular_color #specular_weight
		m.reflection = refl[1]
		m.texmap_reflection = refl[2]
	)
	else
	(
		m.reflection = AlecConv_get r #specular_color
		m.texmap_reflection = AlecConv_map r #specular_color
		m.reflection_weight = AlecConv_get r #specular_weight
	)
	AlecConv_setVRayRough r m mode #reflection rough roughMap
	AlecConv_setVRayRough r m mode #refraction rough roughMap
	m.reflection_lockIOR = true
	m.reflection_ior = ior
	m.refraction_ior = ior
	m.texmap_reflectionIOR = iorMap
	m.texmap_refractionIOR = iorMap
	m.anisotropy = AlecConv_get r #specular_roughness_anisotropy
	m.texmap_anisotropy = AlecConv_map r #specular_roughness_anisotropy
)

-- a transmission depth makes the transmission colour the fog colour at that depth, else it tints the refraction
fn AlecConv_writeVRayVolume r m =
(
	local depth = AlecConv_get r #transmission_depth
	local depthMap = AlecConv_map r #transmission_depth
	if depth > 0 or depthMap != undefined then
	(
		m.refraction = AlecConv_grey (AlecConv_get r #transmission_weight)
		m.texmap_refraction = AlecConv_map r #transmission_weight
		m.refraction_fogColor = AlecConv_get r #transmission_color
		m.texmap_refraction_fog = AlecConv_map r #transmission_color
		m.refraction_fogDepth = depth
		m.texmap_refraction_fog_depth = depthMap
		m.refraction_fogUnitsScale_on = true
	)
	else
	(
		local refr = AlecConv_fold r #transmission_color #transmission_weight
		m.refraction = refr[1]
		m.texmap_refraction = refr[2]
	)
	m.refraction_dispersion_on = AlecConv_get r #transmission_dispersion_scale > 0
	m.refraction_dispersion = AlecConv_get r #transmission_dispersion_abbe_number
	m.refraction_thinWalled = AlecConv_get r #geometry_thin_walled
	if AlecConv_get r #transmission_scatter != black do AlecConv_note r "transmission scatter dropped"
	if AlecConv_used r #subsurface_weight do AlecConv_note r "subsurface dropped (the VRayMtl translucency types are not checked yet)"
)

-- thin film: a thickness map (µm) goes over 0 - 1000 nm, a value to both min and max
fn AlecConv_writeVRayFilm r m =
(
	local filmMap = AlecConv_map r #thin_film_thickness
	local nm = 1000.0 * AlecConv_get r #thin_film_thickness
	m.thinFilm_on = true
	m.thinFilm_thickness_min = if filmMap != undefined then 0.0 else nm
	m.thinFilm_thickness_max = if filmMap != undefined then 1000.0 else nm
	m.texmap_thinFilm_thickness = filmMap
	m.thinFilm_ior = AlecConv_get r #thin_film_ior
	m.texmap_thinFilm_ior = AlecConv_map r #thin_film_ior
	if AlecConv_get r #thin_film_weight < 1.0 or AlecConv_map r #thin_film_weight != undefined do AlecConv_note r "thin film weight dropped"
)

fn AlecConv_writeVRayEmission r m =
(
	local glow = AlecConv_fold r #emission_color #emission_weight
	m.selfIllumination = glow[1]
	m.texmap_self_illumination = glow[2]
	m.selfIllumination_multiplier = AlecConv_get r #emission_luminance / AlecConv_nitsPerUnit
	if AlecConv_map r #emission_luminance != undefined do AlecConv_note r "emission luminance map dropped"
	AlecConv_note r "emission: unit factor not calibrated yet"
)

fn AlecConv_writeVRayLayers r m mode =
(
	local sheen = AlecConv_fold r #fuzz_color #fuzz_weight
	m.sheen_color = sheen[1]
	m.texmap_sheen = sheen[2]
	AlecConv_setVRayRough r m mode #sheen (AlecConv_get r #fuzz_roughness) (AlecConv_map r #fuzz_roughness)
	m.coat_amount = AlecConv_get r #coat_weight
	m.texmap_coat_amount = AlecConv_map r #coat_weight
	m.coat_color = AlecConv_get r #coat_color
	m.texmap_coat_color = AlecConv_map r #coat_color
	AlecConv_setVRayRough r m mode #coat (AlecConv_get r #coat_roughness) (AlecConv_map r #coat_roughness)
	m.coat_ior = AlecConv_get r #coat_ior
	m.texmap_coat_ior = AlecConv_map r #coat_ior
	m.coat_darkening = AlecConv_get r #coat_darkening
	m.texmap_coat_darkening = AlecConv_map r #coat_darkening
	m.coat_anisotropy = AlecConv_get r #coat_roughness_anisotropy
	if AlecConv_used r #thin_film_weight do AlecConv_writeVRayFilm r m
	if AlecConv_used r #emission_weight do AlecConv_writeVRayEmission r m
)

-- one bump slot: the normal map when there is one (a bump next to it is dropped), else the bump at its amount
fn AlecConv_writeVRayBump r m slot normalKey bumpKey =
(
	local normal = AlecConv_map r normalKey
	local bump = AlecConv_map r bumpKey
	local p = "texmap_" + slot
	setProperty m (p as name) (if normal != undefined then normal else bump)
	setProperty m ((p + "_multiplier") as name) (if normal != undefined then 100.0 else 100.0 * AlecConv_get r bumpKey)
	if normal != undefined and bump != undefined do AlecConv_note r (slot + ": bump dropped, the normal map kept")
)

fn AlecConv_writeVRay r mode =
(
	local m = VRayMtl()
	m.brdf_useRoughness = mode == #rough
	AlecConv_writeVRaySurface r m mode
	AlecConv_writeVRayVolume r m
	AlecConv_writeVRayLayers r m mode
	-- VRayMtl has no opacity value: an opacity under 1 without a map becomes a VRayColor of that grey
	local opacity = AlecConv_get r #geometry_opacity
	m.texmap_opacity = AlecConv_map r #geometry_opacity
	if m.texmap_opacity == undefined and opacity < 1.0 do m.texmap_opacity = VRayColor color:(AlecConv_grey opacity)
	AlecConv_writeVRayBump r m "bump" #geometry_normal #bump
	AlecConv_writeVRayBump r m "coat_bump" #geometry_coat_normal #coat_bump
	m.texmap_displacement = AlecConv_map r #displacement
	m.texmap_displacement_multiplier = AlecConv_get r #displacement
	m
)

-- Standardmaterial: diffuse, specular, glossiness, opacity and emission only

fn AlecConv_setStd m slot tex =
(
	setProperty m ((slot + "Map") as name) tex
	setProperty m ((slot + "MapEnable") as name) (tex != undefined)
)

fn AlecConv_standardDropped r =
(
	for k in #(#subsurface_weight, #coat_weight, #fuzz_weight, #thin_film_weight, #specular_roughness_anisotropy) \
		where AlecConv_used r k do AlecConv_note r ((k as string) + " dropped")
	if AlecConv_map r #displacement != undefined do AlecConv_note r "displacement dropped"
)

-- tint: a metal gets the base colour as its specular colour and a darker diffuse, as far as its metalness goes
fn AlecConv_writeStandard r tint =
(
	local m = Standardmaterial()
	local metal = AlecConv_get r #base_metalness
	local diffuse = AlecConv_fold r #base_color #base_weight
	local spec = AlecConv_get r #specular_color
	if tint and metal > 0 then
	(
		diffuse = #(diffuse[1] * (1.0 - metal), diffuse[2])
		spec = AlecConv_lerp spec (AlecConv_get r #base_color) metal
		AlecConv_note r "metalness: specular tinted with the base colour"
	)
	m.Diffuse = diffuse[1]
	AlecConv_setStd m "diffuse" diffuse[2]
	m.Specular = spec
	AlecConv_setStd m "specular" (AlecConv_map r #specular_color)
	m.specularLevel = 100.0 * AlecConv_get r #specular_weight
	AlecConv_setStd m "specularLevel" (AlecConv_map r #specular_weight)
	m.glossiness = 100.0 * (1.0 - AlecConv_get r #specular_roughness)
	AlecConv_setStd m "glossiness" (AlecConv_map r #specular_roughness)
	m.opacity = 100.0 * AlecConv_srgb (AlecConv_get r #geometry_opacity)
	AlecConv_setStd m "opacity" (AlecConv_map r #geometry_opacity)
	-- metalness to the Reflection slot, refraction to the Refraction slot, bump (or the normal map) to the Bump slot: maps as they are
	m.reflectionMapAmount = 100.0 * metal
	AlecConv_setStd m "reflection" (AlecConv_map r #base_metalness)
	m.refractionMapAmount = 100.0 * AlecConv_get r #transmission_weight
	AlecConv_setStd m "refraction" (AlecConv_map r #transmission_color)
	m.ior = AlecConv_get r #specular_ior
	local normal = AlecConv_map r #geometry_normal
	m.bumpMapAmount = if normal != undefined then 100.0 else 100.0 * AlecConv_get r #bump
	AlecConv_setStd m "bump" (if normal != undefined then normal else AlecConv_map r #bump)
	if AlecConv_used r #emission_weight do
	(
		local glow = AlecConv_fold r #emission_color #emission_weight
		m.useSelfIllumColor = true
		m.selfIllumColor = glow[1]
		AlecConv_setStd m "selfIllum" glow[2]
	)
	AlecConv_standardDropped r
	m
)
