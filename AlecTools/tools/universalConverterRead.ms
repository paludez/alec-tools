-- UniversalConverter, reading (loaded by tools/universalConverter.ms): every supported material is read into one record, AlecUniversalConverter_Rec,
-- that holds the OpenPBR parameters under their OpenPBR_Material names, plus the geometry slots under the names OpenPBR_Material
-- gives their maps without "_map" (#geometry_opacity, #bump, #geometry_normal, #coat_bump, #geometry_coat_normal, #displacement).
-- A map in the record gives its parameter in the record's terms: a roughness map is roughness, whatever the source slot held.
-- Maps are linked as they are: the tool never makes, changes or swaps a map node.

-- cd/m2 per emission unit of V-Ray or Arnold (white, multiplier 1). Not measured yet: 1000 takes the VRayMtl default (1) to the
-- OpenPBR_Material default (1000); every converted emission is logged as uncalibrated
global AlecUniversalConverter_nitsPerUnit = 1000.0

-- the OpenPBR_Material parameters that have a value and a <name>_map
global AlecUniversalConverter_pbrKeys = #(#base_weight, #base_color, #base_metalness, #base_diffuse_roughness, #specular_weight, #specular_color,
	#specular_roughness, #specular_roughness_anisotropy, #specular_ior, #transmission_weight, #transmission_color, #transmission_depth,
	#transmission_scatter, #transmission_scatter_anisotropy, #transmission_dispersion_scale, #transmission_dispersion_abbe_number,
	#subsurface_weight, #subsurface_color, #subsurface_radius, #subsurface_radius_scale, #subsurface_scatter_anisotropy, #coat_weight,
	#coat_color, #coat_roughness, #coat_roughness_anisotropy, #coat_ior, #coat_darkening, #fuzz_weight, #fuzz_color, #fuzz_roughness,
	#emission_weight, #emission_color, #emission_luminance, #thin_film_weight, #thin_film_thickness, #thin_film_ior)

struct AlecUniversalConverter_Rec (vals = Dictionary #name, maps = Dictionary #name, notes = #())

-- record access

fn AlecUniversalConverter_get r k = if hasDictValue r.vals k then getDictValue r.vals k else undefined

fn AlecUniversalConverter_map r k = if hasDictValue r.maps k then getDictValue r.maps k else undefined

fn AlecUniversalConverter_set r k v m:undefined =
(
	putDictValue r.vals k v
	if m == undefined then removeDictValue r.maps k else putDictValue r.maps k m
)

fn AlecUniversalConverter_note r txt = appendIfUnique r.notes txt

-- true when the parameter has a map or a value other than zero
fn AlecUniversalConverter_used r k = AlecUniversalConverter_map r k != undefined or AlecUniversalConverter_get r k != 0.0

-- classes and colours

fn AlecUniversalConverter_className x = toLower ((classOf x) as string)

fn AlecUniversalConverter_isA x cls = x != undefined and AlecUniversalConverter_className x == cls

fn AlecUniversalConverter_peak c = (amax #(c.r, c.g, c.b)) / 255.0

fn AlecUniversalConverter_luma c = (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) / 255.0

fn AlecUniversalConverter_grey v = (local g = 255.0 * v; color g g g)

-- an sRGB value (0 - 1) in linear
fn AlecUniversalConverter_linear v = if v <= 0.04045 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4

-- a colour as #(weight, colour at weight 1): the weight is its brightest channel; black gives white at weight 0
fn AlecUniversalConverter_split c = (local w = AlecUniversalConverter_peak c; #(w, if w > 0 then c * (1.0 / w) else white))

-- a map slot as the record takes it: off, missing or at 0 % gives none
fn AlecUniversalConverter_slotMap tex isOn amount = if tex != undefined and isOn and amount > 0.0 then tex else undefined

-- normal maps

fn AlecUniversalConverter_isNormalNode n = AlecUniversalConverter_isA n "normal_bump" or AlecUniversalConverter_isA n "vraynormalmap"

-- a bump slot's map goes to the record as a normal map when it is a normal-map node, else as a bump
fn AlecUniversalConverter_readBump r bumpKey normalKey tex amount =
(
	if AlecUniversalConverter_isNormalNode tex then
	(
		if amount != 1.0 do AlecUniversalConverter_note r ("bump amount on a normal map (" + amount as string + ") not converted")
		AlecUniversalConverter_set r normalKey 1.0 m:tex
	)
	else if tex != undefined do AlecUniversalConverter_set r bumpKey amount m:tex
)

-- OpenPBR_Material

fn AlecUniversalConverter_pbrMap m k =
(
	local tex = getProperty m ((k as string + "_map") as name)
	if tex != undefined and getProperty m ((k as string + "_map_on") as name) then tex else undefined
)

fn AlecUniversalConverter_readOpenPBR r m =
(
	for k in AlecUniversalConverter_pbrKeys do AlecUniversalConverter_set r k (getProperty m k) m:(AlecUniversalConverter_pbrMap m k)
	AlecUniversalConverter_set r #geometry_thin_walled m.geometry_thin_walled
	AlecUniversalConverter_set r #geometry_opacity 1.0 m:(AlecUniversalConverter_pbrMap m #geometry_opacity)
	AlecUniversalConverter_set r #bump m.bump_map_amt m:(AlecUniversalConverter_pbrMap m #bump)
	AlecUniversalConverter_set r #geometry_normal 1.0 m:(AlecUniversalConverter_pbrMap m #geometry_normal)
	AlecUniversalConverter_set r #coat_bump m.coat_bump_map_amt m:(AlecUniversalConverter_pbrMap m #coat_bump)
	AlecUniversalConverter_set r #geometry_coat_normal 1.0 m:(AlecUniversalConverter_pbrMap m #geometry_coat_normal)
	AlecUniversalConverter_set r #displacement m.displacement_map_amt m:(AlecUniversalConverter_pbrMap m #displacement)
	if AlecUniversalConverter_pbrMap m #geometry_tangent != undefined do AlecUniversalConverter_note r "tangent map dropped"
)

-- every record starts as a new OpenPBR_Material, so a parameter a source does not have keeps the OpenPBR default
fn AlecUniversalConverter_newRec =
(
	local r = AlecUniversalConverter_Rec()
	AlecUniversalConverter_readOpenPBR r (OpenPBR_Material())
	r
)

-- emission given in V-Ray or Arnold units: weight 1, luminance through AlecUniversalConverter_nitsPerUnit
fn AlecUniversalConverter_unitEmission r c tex amount =
(
	if tex != undefined or (c != black and amount > 0) then
	(
		AlecUniversalConverter_set r #emission_weight 1.0
		AlecUniversalConverter_set r #emission_color c m:tex
		AlecUniversalConverter_set r #emission_luminance (amount * AlecUniversalConverter_nitsPerUnit)
		AlecUniversalConverter_note r "emission: unit factor not calibrated yet"
	)
	else AlecUniversalConverter_set r #emission_weight 0.0
)

-- VRayMtl

fn AlecUniversalConverter_vrayMap m slot =
(
	local p = "texmap_" + slot
	local amountProp = (p + "_multiplier") as name
	AlecUniversalConverter_slotMap (getProperty m (p as name)) (getProperty m ((p + "_on") as name)) \
		(if isProperty m amountProp then getProperty m amountProp else 100.0)
)

fn AlecUniversalConverter_vrayMode m = if m.option_openPBRMode then #pbr else if m.brdf_useRoughness then #rough else #natural

-- whether a VRayMtl glossiness value holds roughness: OpenPBR mode renames reflection, refraction and coat to roughness; Use roughness
-- is taken to flip reflection only (render check 2 of the plan decides it). Sheen is always glossiness.
fn AlecUniversalConverter_holdsRough mode lobe =
(
	case mode of
	(
		#pbr: lobe != #sheen
		#rough: lobe == #reflection
		default: false
	)
)

-- #(glossiness property, map slot) of a lobe
fn AlecUniversalConverter_glossSlot lobe =
(
	case lobe of
	(
		#reflection: #(#reflection_glossiness, "reflectionGlossiness")
		#refraction: #(#refraction_glossiness, "refractionGlossiness")
		#coat: #(#coat_glossiness, "coat_glossiness")
		#sheen: #(#sheen_glossiness, "sheen_glossiness")
	)
)

-- the roughness of a VRayMtl lobe as #(value, map); the map is linked as it is
fn AlecUniversalConverter_vrayRough m mode lobe =
(
	local slot = AlecUniversalConverter_glossSlot lobe
	local v = getProperty m slot[1]
	local tex = AlecUniversalConverter_vrayMap m slot[2]
	if AlecUniversalConverter_holdsRough mode lobe then #(v, tex) else #(1.0 - v, tex)
)

fn AlecUniversalConverter_readVRayNotes r m =
(
	if not m.reflection_lockGlossiness and m.hilight_glossiness != m.reflection_glossiness do
		AlecUniversalConverter_note r "highlight glossiness differs from reflection glossiness, not used"
	if m.brdf_type != 4 or m.gtr_gamma != 2.0 or AlecUniversalConverter_vrayMap m "gtr_tail_falloff" != undefined do
		AlecUniversalConverter_note r "BRDF other than GGX (tail 2), read as GGX"
	if m.compensate_camera_exposure do AlecUniversalConverter_note r "compensate camera exposure dropped"
	if m.translucency_on != 0 do AlecUniversalConverter_note r "translucency read as subsurface (approximate)"
	if m.anisotropy != 0.0 do AlecUniversalConverter_note r "anisotropy converted approximately"
	if m.anisotropy < 0.0 or m.anisotropy_rotation != 0.0 or AlecUniversalConverter_vrayMap m "anisotropy_rotation" != undefined do
		AlecUniversalConverter_note r "anisotropy rotation dropped"
)

-- reflection, refraction, roughness and IOR: OpenPBR has one roughness and one IOR, so the lobe that shows gives them
fn AlecUniversalConverter_readVRayLobes r m mode =
(
	local refrMap = AlecUniversalConverter_vrayMap m "refraction"
	local refr = AlecUniversalConverter_split m.refraction
	local trans = if refrMap != undefined then 1.0 else refr[1]
	local useRefr = trans > 0.5
	local reflR = AlecUniversalConverter_vrayRough m mode #reflection
	local refrR = AlecUniversalConverter_vrayRough m mode #refraction
	local reflIor = if m.reflection_lockIOR then m.refraction_ior else m.reflection_ior
	local rough = if useRefr then refrR else reflR
	local iorSlot = if useRefr or m.reflection_lockIOR then "refractionIOR" else "reflectionIOR"
	AlecUniversalConverter_set r #specular_color m.reflection m:(AlecUniversalConverter_vrayMap m "reflection")
	AlecUniversalConverter_set r #specular_weight m.reflection_weight
	AlecUniversalConverter_set r #specular_roughness rough[1] m:rough[2]
	AlecUniversalConverter_set r #specular_ior (if useRefr then m.refraction_ior else reflIor) m:(AlecUniversalConverter_vrayMap m iorSlot)
	if trans > 0 and (reflR[1] != refrR[1] or reflR[2] != refrR[2]) do
		AlecUniversalConverter_note r ("reflection and refraction roughness differ, kept the " + (if useRefr then "refraction" else "reflection") + " one")
	if trans > 0 and reflIor != m.refraction_ior do
		AlecUniversalConverter_note r ("reflection and refraction IOR differ, kept the " + (if useRefr then "refraction" else "reflection") + " one")
	if not m.reflection_fresnel do
	(
		AlecUniversalConverter_set r #specular_ior 25.0
		AlecUniversalConverter_note r "Fresnel off: IOR 25 instead"
	)
	AlecUniversalConverter_set r #transmission_weight trans
	#(refr[2], refrMap)
)

-- fog: a fog colour other than white is the transmission colour at the fog depth, else the refraction colour is a surface tint.
-- The depth is the value: V-Ray keeps refraction_fogMult at 1 / depth
fn AlecUniversalConverter_readVRayFog r m tint =
(
	local fogMap = AlecUniversalConverter_vrayMap m "refraction_fog"
	local depth = m.refraction_fogDepth
	if AlecUniversalConverter_get r #transmission_weight > 0 and (m.refraction_fogColor != white or fogMap != undefined) then
	(
		AlecUniversalConverter_set r #transmission_color m.refraction_fogColor m:fogMap
		AlecUniversalConverter_set r #transmission_depth depth m:(AlecUniversalConverter_vrayMap m "refraction_fog_depth")
		if tint[1] != white or tint[2] != undefined do AlecUniversalConverter_note r "refraction tint dropped, the fog colour kept"
		if m.refraction_fogBias != 0.0 do AlecUniversalConverter_note r "fog bias dropped"
	)
	else
	(
		AlecUniversalConverter_set r #transmission_color tint[1] m:tint[2]
		AlecUniversalConverter_set r #transmission_depth 0.0
	)
	AlecUniversalConverter_set r #transmission_dispersion_scale (if m.refraction_dispersion_on then 1.0 else 0.0)
	AlecUniversalConverter_set r #transmission_dispersion_abbe_number m.refraction_dispersion
	AlecUniversalConverter_set r #geometry_thin_walled m.refraction_thinWalled
	if m.translucency_on != 0 do
	(
		AlecUniversalConverter_set r #subsurface_weight m.translucency_amount m:(AlecUniversalConverter_vrayMap m "translucency_amount")
		AlecUniversalConverter_set r #subsurface_color m.translucency_color m:(AlecUniversalConverter_vrayMap m "translucent")
		AlecUniversalConverter_set r #subsurface_radius depth
		AlecUniversalConverter_set r #subsurface_radius_scale m.refraction_fogColor
	)
)

fn AlecUniversalConverter_readVRayLayers r m mode =
(
	local sheenMap = AlecUniversalConverter_vrayMap m "sheen"
	local sheen = AlecUniversalConverter_split m.sheen_color
	local fuzzR = AlecUniversalConverter_vrayRough m mode #sheen
	local coatR = AlecUniversalConverter_vrayRough m mode #coat
	AlecUniversalConverter_set r #fuzz_weight (if sheenMap != undefined then 1.0 else sheen[1])
	AlecUniversalConverter_set r #fuzz_color (if sheenMap != undefined then m.sheen_color else sheen[2]) m:sheenMap
	AlecUniversalConverter_set r #fuzz_roughness fuzzR[1] m:fuzzR[2]
	AlecUniversalConverter_set r #coat_weight m.coat_amount m:(AlecUniversalConverter_vrayMap m "coat_amount")
	AlecUniversalConverter_set r #coat_color m.coat_color m:(AlecUniversalConverter_vrayMap m "coat_color")
	AlecUniversalConverter_set r #coat_roughness coatR[1] m:coatR[2]
	AlecUniversalConverter_set r #coat_ior m.coat_ior m:(AlecUniversalConverter_vrayMap m "coat_ior")
	AlecUniversalConverter_set r #coat_darkening m.coat_darkening m:(AlecUniversalConverter_vrayMap m "coat_darkening")
	AlecUniversalConverter_set r #coat_roughness_anisotropy (abs m.coat_anisotropy)
	AlecUniversalConverter_set r #specular_roughness_anisotropy (abs m.anisotropy) m:(AlecUniversalConverter_vrayMap m "anisotropy")
)

-- thin film: without a map V-Ray is taken to use the max thickness; a map t gives min + t × (max - min) nm
fn AlecUniversalConverter_readVRayFilm r m =
(
	local tMap = AlecUniversalConverter_vrayMap m "thinFilm_thickness"
	local lo = m.thinFilm_thickness_min
	local hi = m.thinFilm_thickness_max
	AlecUniversalConverter_set r #thin_film_weight (if m.thinFilm_on then 1.0 else 0.0)
	AlecUniversalConverter_set r #thin_film_thickness (hi / 1000.0) m:tMap
	AlecUniversalConverter_set r #thin_film_ior m.thinFilm_ior m:(AlecUniversalConverter_vrayMap m "thinFilm_ior")
)

fn AlecUniversalConverter_readVRay r m =
(
	local mode = AlecUniversalConverter_vrayMode m
	AlecUniversalConverter_set r #base_weight 1.0
	AlecUniversalConverter_set r #base_color m.diffuse m:(AlecUniversalConverter_vrayMap m "diffuse")
	AlecUniversalConverter_set r #base_metalness m.reflection_metalness m:(AlecUniversalConverter_vrayMap m "metalness")
	AlecUniversalConverter_set r #base_diffuse_roughness m.diffuse_roughness m:(AlecUniversalConverter_vrayMap m "roughness")
	AlecUniversalConverter_readVRayFog r m (AlecUniversalConverter_readVRayLobes r m mode)
	AlecUniversalConverter_readVRayLayers r m mode
	AlecUniversalConverter_readVRayFilm r m
	AlecUniversalConverter_unitEmission r m.selfIllumination (AlecUniversalConverter_vrayMap m "self_illumination") m.selfIllumination_multiplier
	AlecUniversalConverter_set r #geometry_opacity 1.0 m:(AlecUniversalConverter_vrayMap m "opacity")
	AlecUniversalConverter_readBump r #bump #geometry_normal (if m.texmap_bump_on then m.texmap_bump else undefined) (m.texmap_bump_multiplier / 100.0)
	if m.coat_bump_lock then
	(
		AlecUniversalConverter_set r #coat_bump (AlecUniversalConverter_get r #bump) m:(AlecUniversalConverter_map r #bump)
		AlecUniversalConverter_set r #geometry_coat_normal 1.0 m:(AlecUniversalConverter_map r #geometry_normal)
	)
	else AlecUniversalConverter_readBump r #coat_bump #geometry_coat_normal (if m.texmap_coat_bump_on then m.texmap_coat_bump else undefined) \
		(m.texmap_coat_bump_multiplier / 100.0)
	AlecUniversalConverter_set r #displacement m.texmap_displacement_multiplier m:(if m.texmap_displacement_on then m.texmap_displacement else undefined)
	AlecUniversalConverter_readVRayNotes r m
)

-- PhysicalMaterial

fn AlecUniversalConverter_physMap m slot =
(
	local tex = getProperty m ((slot + "_map") as name)
	if tex != undefined and getProperty m ((slot + "_map_on") as name) then tex else undefined
)

-- roughness_inv on: the value is glossiness
fn AlecUniversalConverter_physRough v tex inverted = #(if inverted then 1.0 - v else v, tex)

fn AlecUniversalConverter_readPhysicalSurface r m =
(
	local rough = AlecUniversalConverter_physRough m.roughness (AlecUniversalConverter_physMap m "roughness") m.roughness_inv
	if not m.trans_roughness_lock do
	(
		local transRough = AlecUniversalConverter_physRough m.trans_roughness (AlecUniversalConverter_physMap m "trans_rough") m.trans_roughness_inv
		if m.transparency > 0 and transRough[1] != rough[1] do
			AlecUniversalConverter_note r ("reflection and transmission roughness differ, kept the " + (if m.transparency > 0.5 then "transmission" else "reflection") + " one")
		if m.transparency > 0.5 do rough = transRough
	)
	AlecUniversalConverter_set r #base_weight m.base_weight m:(AlecUniversalConverter_physMap m "base_weight")
	AlecUniversalConverter_set r #base_color m.base_color m:(AlecUniversalConverter_physMap m "base_color")
	AlecUniversalConverter_set r #base_metalness m.metalness m:(AlecUniversalConverter_physMap m "metalness")
	AlecUniversalConverter_set r #base_diffuse_roughness m.diff_roughness m:(AlecUniversalConverter_physMap m "diff_rough")
	AlecUniversalConverter_set r #specular_color m.refl_color m:(AlecUniversalConverter_physMap m "refl_color")
	AlecUniversalConverter_set r #specular_weight m.reflectivity m:(AlecUniversalConverter_physMap m "reflectivity")
	AlecUniversalConverter_set r #specular_roughness rough[1] m:rough[2]
	AlecUniversalConverter_set r #specular_ior m.trans_ior m:(AlecUniversalConverter_physMap m "trans_ior")
	AlecUniversalConverter_set r #specular_roughness_anisotropy m.anisotropy m:(AlecUniversalConverter_physMap m "anisotropy")
	if not m.brdf_mode do AlecUniversalConverter_note r "custom reflectivity curve read as IOR Fresnel"
	if m.anisotropy != 0.0 do AlecUniversalConverter_note r "anisotropy angle dropped"
)

fn AlecUniversalConverter_readPhysicalVolume r m =
(
	AlecUniversalConverter_set r #transmission_weight m.transparency m:(AlecUniversalConverter_physMap m "transparency")
	AlecUniversalConverter_set r #transmission_color m.trans_color m:(AlecUniversalConverter_physMap m "trans_color")
	AlecUniversalConverter_set r #transmission_depth m.trans_depth
	AlecUniversalConverter_set r #transmission_scatter m.trans_scatter_color
	AlecUniversalConverter_set r #transmission_dispersion_scale (if m.dispersion > 0 then 1.0 else 0.0)
	if m.dispersion > 0 do AlecUniversalConverter_set r #transmission_dispersion_abbe_number m.dispersion
	AlecUniversalConverter_set r #geometry_thin_walled m.thin_walled
	AlecUniversalConverter_set r #subsurface_weight m.scattering m:(AlecUniversalConverter_physMap m "scattering")
	AlecUniversalConverter_set r #subsurface_color m.sss_color m:(AlecUniversalConverter_physMap m "sss_color")
	AlecUniversalConverter_set r #subsurface_radius (m.sss_depth * m.sss_scale)
	AlecUniversalConverter_set r #subsurface_radius_scale m.sss_scatter_color
	if AlecUniversalConverter_physMap m "sss_scale" != undefined do AlecUniversalConverter_note r "subsurface scale map dropped"
)

fn AlecUniversalConverter_readPhysicalLayers r m =
(
	local coatR = AlecUniversalConverter_physRough m.coat_roughness (AlecUniversalConverter_physMap m "coat_rough") m.coat_roughness_inv
	AlecUniversalConverter_set r #coat_weight m.coating m:(AlecUniversalConverter_physMap m "coat")
	AlecUniversalConverter_set r #coat_color m.coat_color m:(AlecUniversalConverter_physMap m "coat_color")
	AlecUniversalConverter_set r #coat_roughness coatR[1] m:coatR[2]
	AlecUniversalConverter_set r #coat_ior m.coat_ior
	AlecUniversalConverter_set r #coat_darkening m.coat_affect_color
	if m.coating > 0 and m.coat_affect_roughness > 0 do AlecUniversalConverter_note r "coat affect roughness dropped"
	AlecUniversalConverter_set r #fuzz_weight m.sheen m:(AlecUniversalConverter_physMap m "sheen")
	AlecUniversalConverter_set r #fuzz_color m.sheen_color m:(AlecUniversalConverter_physMap m "sheen_color")
	AlecUniversalConverter_set r #fuzz_roughness m.sheen_roughness m:(AlecUniversalConverter_physMap m "sheen_rough")
	-- thin_film_map is the weight map; the thickness is in nm
	AlecUniversalConverter_set r #thin_film_weight m.thin_film m:(AlecUniversalConverter_physMap m "thin_film")
	AlecUniversalConverter_set r #thin_film_thickness (m.thin_film_thickness / 1000.0)
	AlecUniversalConverter_set r #thin_film_ior m.thin_film_ior m:(AlecUniversalConverter_physMap m "thin_film_ior")
	-- Physical emission is in cd/m2 like OpenPBR: no unit factor
	AlecUniversalConverter_set r #emission_weight m.emission m:(AlecUniversalConverter_physMap m "emission")
	AlecUniversalConverter_set r #emission_color m.emit_color m:(AlecUniversalConverter_physMap m "emit_color")
	AlecUniversalConverter_set r #emission_luminance m.emit_luminance
	if m.emission > 0 and m.emit_kelvin != 6500.0 do AlecUniversalConverter_note r "emission colour temperature dropped"
)

fn AlecUniversalConverter_readPhysical r m =
(
	AlecUniversalConverter_readPhysicalSurface r m
	AlecUniversalConverter_readPhysicalVolume r m
	AlecUniversalConverter_readPhysicalLayers r m
	AlecUniversalConverter_set r #geometry_opacity 1.0 m:(AlecUniversalConverter_physMap m "cutout")
	AlecUniversalConverter_readBump r #bump #geometry_normal (AlecUniversalConverter_physMap m "bump") m.bump_map_amt
	AlecUniversalConverter_readBump r #coat_bump #geometry_coat_normal (AlecUniversalConverter_physMap m "coat_bump") m.clearcoat_bump_map_amt
	AlecUniversalConverter_set r #displacement m.displacement_map_amt m:(AlecUniversalConverter_physMap m "displacement")
)

-- Standardmaterial

fn AlecUniversalConverter_stdMap m slot =
(
	AlecUniversalConverter_slotMap (getProperty m ((slot + "Map") as name)) (getProperty m ((slot + "MapEnable") as name)) \
		(getProperty m ((slot + "MapAmount") as name))
)

fn AlecUniversalConverter_readStandard r m =
(
	local gloss = m.glossiness / 100.0
	local level = m.specularLevel / 100.0
	-- Standard's opacity percentage is sRGB (no gamma 1 then): the record holds it linear
	local opacity = AlecUniversalConverter_linear (m.opacity / 100.0)
	local glow = if m.useSelfIllumColor then m.selfIllumColor else m.Diffuse * (m.selfIllumAmount / 100.0)
	-- the Reflection slot gives the metalness and the Refraction slot the refraction: each map as it is, its amount as the value
	local reflMap = AlecUniversalConverter_stdMap m "reflection"
	local refrMap = AlecUniversalConverter_stdMap m "refraction"
	AlecUniversalConverter_set r #base_color m.Diffuse m:(AlecUniversalConverter_stdMap m "diffuse")
	AlecUniversalConverter_set r #base_metalness (if reflMap != undefined then m.reflectionMapAmount / 100.0 else 0.0) m:reflMap
	AlecUniversalConverter_set r #transmission_weight (if refrMap != undefined then m.refractionMapAmount / 100.0 else 0.0)
	AlecUniversalConverter_set r #transmission_color white m:refrMap
	AlecUniversalConverter_set r #specular_ior m.ior
	AlecUniversalConverter_set r #specular_color m.Specular m:(AlecUniversalConverter_stdMap m "specular")
	AlecUniversalConverter_set r #specular_weight level m:(AlecUniversalConverter_stdMap m "specularLevel")
	AlecUniversalConverter_set r #specular_roughness (1.0 - gloss) m:(AlecUniversalConverter_stdMap m "glossiness")
	AlecUniversalConverter_set r #geometry_opacity opacity m:(AlecUniversalConverter_stdMap m "opacity")
	AlecUniversalConverter_unitEmission r glow (AlecUniversalConverter_stdMap m "selfIllum") 1.0
	AlecUniversalConverter_readBump r #bump #geometry_normal (if m.bumpMapEnable then m.bumpMap else undefined) (m.bumpMapAmount / 100.0)
	AlecUniversalConverter_set r #displacement (m.displacementMapAmount / 100.0) m:m.displacementMap
	AlecUniversalConverter_note r "Standard (Blinn) read approximately"
)

-- ai_standard_surface: maps are <param>_shader, used while <param>_connected

fn AlecUniversalConverter_aiMap m p =
(
	local tex = getProperty m ((p + "_shader") as name)
	if tex != undefined and getProperty m ((p + "_connected") as name) then tex else undefined
)

fn AlecUniversalConverter_aiSet r k m p = AlecUniversalConverter_set r k (getProperty m (p as name)) m:(AlecUniversalConverter_aiMap m p)

fn AlecUniversalConverter_readArnoldSurface r m =
(
	AlecUniversalConverter_aiSet r #base_weight m "base"
	AlecUniversalConverter_aiSet r #base_color m "base_color"
	AlecUniversalConverter_aiSet r #base_metalness m "metalness"
	AlecUniversalConverter_aiSet r #base_diffuse_roughness m "diffuse_roughness"
	AlecUniversalConverter_aiSet r #specular_weight m "specular"
	AlecUniversalConverter_aiSet r #specular_color m "specular_color"
	AlecUniversalConverter_aiSet r #specular_roughness m "specular_roughness"
	AlecUniversalConverter_aiSet r #specular_ior m "specular_IOR"
	AlecUniversalConverter_aiSet r #specular_roughness_anisotropy m "specular_anisotropy"
	if m.specular_anisotropy != 0.0 and m.specular_rotation != 0.0 do AlecUniversalConverter_note r "anisotropy rotation dropped"
	AlecUniversalConverter_aiSet r #transmission_weight m "transmission"
	AlecUniversalConverter_aiSet r #transmission_color m "transmission_color"
	AlecUniversalConverter_aiSet r #transmission_depth m "transmission_depth"
	AlecUniversalConverter_aiSet r #transmission_scatter m "transmission_scatter"
	AlecUniversalConverter_aiSet r #transmission_scatter_anisotropy m "transmission_scatter_anisotropy"
	AlecUniversalConverter_set r #transmission_dispersion_scale (if m.transmission_dispersion > 0 then 1.0 else 0.0)
	if m.transmission_dispersion > 0 do AlecUniversalConverter_set r #transmission_dispersion_abbe_number m.transmission_dispersion
	if m.transmission_extra_roughness != 0.0 do AlecUniversalConverter_note r "transmission extra roughness dropped"
	AlecUniversalConverter_set r #geometry_thin_walled m.thin_walled
)

fn AlecUniversalConverter_readArnoldLayers r m =
(
	local radius = AlecUniversalConverter_split m.subsurface_radius
	local film = m.thin_film_thickness
	AlecUniversalConverter_aiSet r #subsurface_weight m "subsurface"
	AlecUniversalConverter_aiSet r #subsurface_color m "subsurface_color"
	AlecUniversalConverter_set r #subsurface_radius (radius[1] * m.subsurface_scale)
	AlecUniversalConverter_set r #subsurface_radius_scale radius[2]
	AlecUniversalConverter_aiSet r #fuzz_weight m "sheen"
	AlecUniversalConverter_aiSet r #fuzz_color m "sheen_color"
	AlecUniversalConverter_aiSet r #fuzz_roughness m "sheen_roughness"
	AlecUniversalConverter_aiSet r #coat_weight m "coat"
	AlecUniversalConverter_aiSet r #coat_color m "coat_color"
	AlecUniversalConverter_aiSet r #coat_roughness m "coat_roughness"
	AlecUniversalConverter_aiSet r #coat_ior m "coat_IOR"
	AlecUniversalConverter_aiSet r #coat_darkening m "coat_affect_color"
	-- Arnold thin film is in nm and has no weight: 0 is off
	AlecUniversalConverter_set r #thin_film_weight (if film > 0 then 1.0 else 0.0)
	AlecUniversalConverter_set r #thin_film_thickness (film / 1000.0) m:(AlecUniversalConverter_aiMap m "thin_film_thickness")
	AlecUniversalConverter_aiSet r #thin_film_ior m "thin_film_IOR"
)

fn AlecUniversalConverter_readArnold r m =
(
	AlecUniversalConverter_readArnoldSurface r m
	AlecUniversalConverter_readArnoldLayers r m
	AlecUniversalConverter_unitEmission r m.emission_color (AlecUniversalConverter_aiMap m "emission_color") m.emission
	AlecUniversalConverter_set r #geometry_opacity (AlecUniversalConverter_luma m.opacity) m:(AlecUniversalConverter_aiMap m "opacity")
	AlecUniversalConverter_set r #geometry_normal 1.0 m:(AlecUniversalConverter_aiMap m "normal")
	AlecUniversalConverter_set r #geometry_coat_normal 1.0 m:(AlecUniversalConverter_aiMap m "coat_normal")
	if AlecUniversalConverter_aiMap m "tangent" != undefined do AlecUniversalConverter_note r "tangent dropped"
)

-- MaxUsdPreviewSurface (USD for 3ds Max, scripts/materials/UsdPreviewSurface.ms, a Physical delegate). It has no refraction:
-- opacity is a cutout. The metallic workflow ignores the specular colour; the specular workflow ignores metallic and IOR.

-- the IOR whose Fresnel reflectance at normal incidence is f0 (0 - 1); 50 for a mirror, as the USD plugin uses
fn AlecUniversalConverter_f0Ior f0 = if f0 >= 0.9 then 50.0 else (1.0 + sqrt f0) / (1.0 - sqrt f0)

-- specular workflow: the specular colour is the reflectance at normal incidence, so its brightest channel gives the IOR and its hue
-- the reflection colour; a map is the reflection colour with Fresnel almost off (IOR 50)
fn AlecUniversalConverter_readUsdSpecular r m =
(
	local spec = AlecUniversalConverter_split m.specularColor
	local tex = m.specularColor_map
	AlecUniversalConverter_set r #base_metalness 0.0
	AlecUniversalConverter_set r #specular_color (if tex != undefined then white else spec[2]) m:tex
	AlecUniversalConverter_set r #specular_ior (if tex != undefined then 50.0 else AlecUniversalConverter_f0Ior spec[1])
	if tex != undefined do AlecUniversalConverter_note r "specular map: Fresnel off (IOR 50), as the USD plugin renders it"
)

fn AlecUniversalConverter_readUsd r m =
(
	AlecUniversalConverter_set r #base_color m.diffuseColor m:m.diffuseColor_map
	AlecUniversalConverter_set r #specular_roughness m.roughness m:m.roughness_map
	if m.useSpecularWorkflow then AlecUniversalConverter_readUsdSpecular r m
	else
	(
		AlecUniversalConverter_set r #base_metalness m.metallic m:m.metallic_map
		AlecUniversalConverter_set r #specular_ior m.ior m:m.ior_map
		if m.specularColor != black or m.specularColor_map != undefined do
			AlecUniversalConverter_note r "specular colour dropped: the metallic workflow does not use it"
	)
	AlecUniversalConverter_set r #coat_weight m.clearcoat m:m.clearcoat_map
	AlecUniversalConverter_set r #coat_roughness m.clearcoatRoughness m:m.clearcoatRoughness_map
	AlecUniversalConverter_set r #geometry_opacity m.opacity m:m.opacity_map
	if m.opacityThreshold > 0 do AlecUniversalConverter_note r "opacity threshold (cutout) not converted"
	AlecUniversalConverter_unitEmission r m.emissiveColor m.emissiveColor_map 1.0
	AlecUniversalConverter_set r #geometry_normal m.bump_map_amt m:m.normal_map
	AlecUniversalConverter_set r #displacement 1.0 m:m.displacement_map
	if m.occlusion_map != undefined do AlecUniversalConverter_note r "occlusion map dropped"
)

-- the reader of a material class (AlecUniversalConverter_className), undefined for an unsupported one
fn AlecUniversalConverter_reader cls =
(
	case cls of
	(
		"vraymtl": AlecUniversalConverter_readVRay
		"openpbr_material": AlecUniversalConverter_readOpenPBR
		"physicalmaterial": AlecUniversalConverter_readPhysical
		"standardmaterial": AlecUniversalConverter_readStandard
		"ai_standard_surface": AlecUniversalConverter_readArnold
		"maxusdpreviewsurface": AlecUniversalConverter_readUsd
		default: undefined
	)
)
