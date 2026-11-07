-- LightConverter: reads a light of any source class into one record, which tools/lightConverterWrite.ms writes back out.

-- VRayShadow areaShadowType of a Sphere
global AlecLightConverter_areaSphere = 1

-- what the source light is, in renderer-neutral terms. Sizes are full sizes in scene units, node scale included
struct AlecLightConverter_Rec
(
	kind,                -- #point #distant #spot #quad #disc #cylinder #dome #ies #mesh
	label,
	enabled = true,
	length = 0.0, width = 0.0, radius = 0.0, height = 0.0,
	angle = 0.0,         -- #distant: the angular size of the light, in degrees
	gain = 1.0,          -- Arnold: intensity x 2^exposure; V-Ray: the multiplier
	normalize = false,   -- brightness independent of size (Arnold Normalize; V-Ray: power units)
	unitsSet = false,    -- V-Ray only: the source is in physical units, its swatch gives the hue only
	color = white,
	kelvin,              -- undefined: use color
	texture,             -- the source's map, undefined when none or not usable
	nearOn = false, nearStart = 0.0, nearEnd = 0.0, farOn = false, farStart = 0.0, farEnd = 0.0,
	diffuse = 1.0, specular = 1.0, volume = 1.0,
	invisible = false,
	castShadows = true, shadowColor = black, shadowDensity = 1.0,
	cone = 45.0, penumbra = 0.0, aspect = 1.0,
	spread = 1.0,
	full = true, format = 2, resolution = 512,
	iesFile = "",
	source,              -- a mesh light's geometry node
	cylinder,            -- the Cylinder of a V-Ray mesh light read as an Arnold cylinder
	shape,               -- the new Cylinder written for an Arnold cylinder
	flip = false,
	aov = "default",
	portal = false,
	doubleSided = false,
	notes = #()
)

fn AlecLightConverter_note r text = append r.notes text

fn AlecLightConverter_noteIf r cond text = if cond do AlecLightConverter_note r text

fn AlecLightConverter_absScale node = [abs node.scale.x, abs node.scale.y, abs node.scale.z]

fn AlecLightConverter_uniformRadius r node radius =
(
	local s = AlecLightConverter_absScale node
	AlecLightConverter_noteIf r (abs (s.x - s.y) > 0.001 or abs (s.x - s.z) > 0.001) "non-uniform scale: an ellipsoid in the source, renderers differ, the X scale was used"
	radius * s.x
)

-- sun and sky are not converted: LightConverter only lists them

fn AlecLightConverter_isSky m = m != undefined and (classOf m == ai_physical_sky or classOf m == VRaySky)

fn AlecLightConverter_isSunOrSky node =
(
	local c = classOf node.baseObject
	c == VRaySun or (c == Arnold_Light and node.shapeType == 6 and AlecLightConverter_isSky node.texmap) \
		or (c == VRayLight and node.type == 1 and AlecLightConverter_isSky node.texmap)
)

-- maps

-- the map is kept as it is; the writer converts a bitmap and lists a map that does not fit the target (tools/lightConverterWrite.ms)
fn AlecLightConverter_readMap r m = if m != undefined do r.texture = m

-- Arnold

fn AlecLightConverter_arnoldKind t = (#(#point, #distant, #spot, #quad, #disc, #cylinder, #dome, #ies, #mesh))[t + 1]

fn AlecLightConverter_arnoldColor r a =
(
	-- Kelvin replaces color and map
	if a.useKelvin then
	(
		r.kelvin = a.kelvin
		AlecLightConverter_noteIf r (a.useTexmap and a.texmap != undefined) "map lost: Use Color Temperature replaces it"
	)
	else
	(
		if a.useTexmap do AlecLightConverter_readMap r a.texmap
		-- a map replaces the swatch in Arnold, V-Ray would multiply it in
		r.color = if r.texture != undefined then white else a.color
		AlecLightConverter_noteIf r a.usePreset "Preset color not copied"
	)
	local f = a.filter
	r.color = color (r.color.r * f.r / 255.0) (r.color.g * f.g / 255.0) (r.color.b * f.b / 255.0)
)

fn AlecLightConverter_arnoldDecay r node =
(
	for m in node.modifiers where classOf m == Arnold_Light_Decay do
	(
		r.nearOn = m.arnold_node_use_near_atten
		r.nearStart = m.arnold_node_near_start
		r.nearEnd = m.arnold_node_near_end
		r.farOn = m.arnold_node_use_far_atten
		r.farStart = m.arnold_node_far_start
		r.farEnd = m.arnold_node_far_end
	)
)

fn AlecLightConverter_arnoldShape r node a =
(
	local s = AlecLightConverter_absScale node
	case r.kind of
	(
		#point: r.radius = AlecLightConverter_uniformRadius r node a.lightRadius
		#distant: r.angle = a.angle
		#spot:
		(
			r.radius = a.lightRadius
			r.cone = a.cone_angle
			r.penumbra = a.penumbra_angle
			r.aspect = a.aspect_ratio
			AlecLightConverter_noteIf r (a.lens_radius != 0) "Lens Radius not copied"
		)
		#quad:
		(
			r.length = a.quadX * s.x
			r.width = a.quadY * s.y
			r.spread = a.spread
			r.portal = a.portal
			AlecLightConverter_noteIf r (a.soft_edge != 0) ("Soft Edge " + a.soft_edge as string + " not copied")
			-- a fully round square is a disc
			if a.quadRoundness >= 1.0 and abs (r.length - r.width) < 0.001 then
			(
				r.kind = #disc
				r.radius = r.length / 2.0
			)
			else AlecLightConverter_noteIf r (a.quadRoundness > 0) ("Roundness " + a.quadRoundness as string + " not copied")
		)
		#disc:
		(
			r.radius = a.lightRadius * s.x
			r.spread = a.spread
			r.portal = a.portal
		)
		#cylinder:
		(
			r.radius = AlecLightConverter_uniformRadius r node a.lightRadius
			r.height = a.height * s.z
		)
		#dome:
		(
			r.format = a.format
			r.resolution = a.resolution
			AlecLightConverter_noteIf r (a.portal_mode != 1) "Portal Mode not copied"
		)
		#ies:
		(
			r.iesFile = a.filename
			r.radius = a.photometricRadius
		)
		#mesh: r.source = a.lightMesh
	)
	if r.kind == #quad or r.kind == #disc do r.resolution = a.quadResolution
)

fn AlecLightConverter_arnoldNotes r a =
(
	AlecLightConverter_noteIf r (a.transmission != 1.0) ("Transmission " + a.transmission as string + " not copied")
	AlecLightConverter_noteIf r (a.sss != 1.0) ("SSS " + a.sss as string + " not copied")
	AlecLightConverter_noteIf r (a.indirect != 1.0) ("Indirect " + a.indirect as string + " not copied")
	AlecLightConverter_noteIf r (a.max_bounces != 999) ("Max Bounces " + a.max_bounces as string + " not copied")
	AlecLightConverter_noteIf r (a.camera > 0 and a.camera != 1.0) ("Camera " + a.camera as string + " became visible")
	AlecLightConverter_note r ("Samples " + a.samples as string + " not copied (V-Ray samples globally)")
)

fn AlecLightConverter_readArnold node =
(
	local a = node.baseObject
	local r = AlecLightConverter_Rec kind:(AlecLightConverter_arnoldKind a.shapeType) label:("Arnold " + (AlecLightConverter_arnoldKind a.shapeType) as string)
	r.enabled = a.on
	r.gain = a.intensity * 2.0 ^ a.exposure
	r.normalize = a.normalize
	AlecLightConverter_arnoldColor r a
	AlecLightConverter_arnoldDecay r node
	AlecLightConverter_arnoldShape r node a
	r.diffuse = a.diffuse
	r.specular = a.specular
	r.volume = a.volume
	r.invisible = a.camera == 0 or not a.lightShapeVisible
	r.castShadows = a.cast_shadows
	r.shadowColor = a.shadow_color
	r.shadowDensity = a.shadow_density
	r.aov = a.aov
	AlecLightConverter_arnoldNotes r a
	r
)

-- V-Ray

fn AlecLightConverter_vrayKind t = (#(#quad, #dome, #point, #mesh, #disc))[t + 1]

fn AlecLightConverter_vrayMeshKind r v =
(
	local src = v.mesh_source
	r.source = src
	-- a mesh light on a single Cylinder is an Arnold cylinder
	if src != undefined and classOf src.baseObject == Cylinder and src.modifiers.count == 0 then
	(
		r.kind = #cylinder
		r.radius = src.baseObject.radius * (AlecLightConverter_absScale src).x
		r.height = src.baseObject.height * (AlecLightConverter_absScale src).z
		r.source = undefined
		r.cylinder = src
	)
	else AlecLightConverter_noteIf r (src == undefined) "mesh light without a source node: pick the mesh on the Arnold light"
)

fn AlecLightConverter_vrayShape r node v =
(
	local s = AlecLightConverter_absScale node
	case r.kind of
	(
		#quad:
		(
			r.length = v.sizeLength * s.x
			r.width = v.sizeWidth * s.y
		)
		#disc: r.radius = v.size0 * s.x
		#point: r.radius = AlecLightConverter_uniformRadius r node v.size0
		#mesh: AlecLightConverter_vrayMeshKind r v
		#dome:
		(
			r.full = v.dome_spherical
			AlecLightConverter_noteIf r (not v.dome_spherical) "Spherical (full dome) off: the Arnold Skydome is a full dome, black out the lower half of its map by hand"
			AlecLightConverter_noteIf r v.dome_finite "Finite dome not copied: the Arnold Skydome is at infinity"
			AlecLightConverter_noteIf r v.dome_affect_alpha "Affect alpha not copied"
			AlecLightConverter_noteIf r (v.dome_rayDistanceMode != 0) "Ray Dist not copied"
		)
	)
)

fn AlecLightConverter_vrayContribution r v =
(
	if r.kind == #dome or r.kind == #mesh then
	(
		r.diffuse = if v.affect_diffuse then 1.0 else 0.0
		r.specular = if v.affect_specular then 1.0 else 0.0
	)
	else
	(
		r.diffuse = if v.affect_diffuse then v.diffuse_contribution else 0.0
		r.specular = if v.affect_specular then v.specular_contribution else 0.0
	)
	r.volume = if v.affect_atmospherics then v.atmospherics_contribution else 0.0
)

fn AlecLightConverter_readDecay r v =
(
	r.nearOn = v.decay_near_on
	r.nearStart = v.decay_near_start
	r.nearEnd = v.decay_near_end
	r.farOn = v.decay_far_on
	r.farStart = v.decay_far_start
	r.farEnd = v.decay_far_end
)

-- the swatch of a light in physical units gives the hue only: its brightest channel becomes 1
fn AlecLightConverter_hue c =
(
	local top = amax #(c.r, c.g, c.b)
	if top > 0 then color (c.r * 255.0 / top) (c.g * 255.0 / top) (c.b * 255.0 / top) else c
)

fn AlecLightConverter_readVRayUnits r node v =
(
	local units = v.normalizeColor
	r.unitsSet = units != 0
	r.normalize = case units of
	(
		-- getUserProp gives on as true
		0: findItem #("on", "true") (toLower ((getUserProp node "a2v_normalize") as string)) > 0
		1: true
		3: true
		default: false
	)
	if units != 0 do r.color = AlecLightConverter_hue r.color
)

fn AlecLightConverter_readVRay node =
(
	local v = node.baseObject
	local r = AlecLightConverter_Rec kind:(AlecLightConverter_vrayKind v.type) label:("VRayLight " + (AlecLightConverter_vrayKind v.type) as string)
	r.enabled = v.on
	r.gain = v.multiplier
	r.color = v.color
	if v.color_mode == 1 do r.kelvin = v.color_temperature
	if v.texmap_on do AlecLightConverter_readMap r v.texmap
	AlecLightConverter_readVRayUnits r node v
	AlecLightConverter_vrayShape r node v
	AlecLightConverter_vrayContribution r v
	AlecLightConverter_readDecay r v
	r.invisible = v.invisible
	r.castShadows = v.castShadows
	r.doubleSided = v.doubleSided and (r.kind == #quad or r.kind == #disc)
	r.spread = 1.0 - v.lightDistribution * v.lightDistribution_strength
	r.flip = v.mesh_flip
	r.resolution = v.texmap_resolution
	AlecLightConverter_noteIf r (v.lightDistribution > 0 and v.lightDistribution_strength < 1.0) "Directional strength below 1 folded into Spread"
	AlecLightConverter_noteIf r (not v.affect_reflections and v.affect_specular) "Affect reflections off with specular on: no Arnold pair"
	AlecLightConverter_noteIf r v.skylightPortal "old portal flag not recreated"
	AlecLightConverter_noteIf r (v.excludeList != undefined and v.excludeList.count > 0 or v.includeList != undefined and v.includeList.count > 0) "include/exclude list not copied: Arnold_Light has none"
	AlecLightConverter_noteIf r (v.light_excl_type != 0) "layer or Object ID exclusion not copied"
	AlecLightConverter_note r ("Subdivs " + v.subdivs as string + " not copied (Arnold samples per light)")
	r
)

-- the highest candela value of an IES file x its multiplier, undefined when the file cannot be read. LM-63: after the TILT line come
-- 10 numbers (lamps, lumens, multiplier, vertical count, horizontal count, ...), 3 more, the angles, then the candela values
fn AlecLightConverter_iesPeak file =
(
	local f = if file != "" and doesFileExist file then openFile file mode:"rt" else undefined
	if f == undefined then undefined
	else
	(
		local tokens = #()
		local started = false
		while not eof f do
		(
			local line = readLine f
			if started then join tokens (filterString line " ,\t")
			else if matchPattern line pattern:"TILT*" do started = true
		)
		close f
		local mult = tokens[3] as float
		local verticals = tokens[4] as integer
		local horizontals = tokens[5] as integer
		local first = 13 + verticals + horizontals + 1
		local peak = 0.0
		for i = first to tokens.count do peak = amax peak (tokens[i] as float)
		peak * mult
	)
)

fn AlecLightConverter_readIES node =
(
	local v = node.baseObject
	local r = AlecLightConverter_Rec kind:#ies label:"VRayIES"
	r.enabled = v.enabled
	r.iesFile = v.ies_file
	r.color = v.color
	if v.color_mode == 1 do r.kelvin = v.color_temperature
	-- Rescale sets the file's peak in cd, Arnold's gain multiplies the file
	if v.override_intensity == 2 and v.intensity_type == 1 then
	(
		local peak = AlecLightConverter_iesPeak v.ies_file
		if peak != undefined and peak > 0 then r.gain = v.intensity_value / peak
		else AlecLightConverter_note r "Override intensity not copied: the IES file cannot be read"
	)
	else AlecLightConverter_noteIf r (v.override_intensity != 0) "Override intensity not copied: only Rescale in cd is"
	r.radius = if v.override_shape and v.shape == 3 then v.diameter / 2.0 else 0.0
	AlecLightConverter_noteIf r (v.override_shape and v.shape != 3) "Override shape other than sphere not copied"
	AlecLightConverter_noteIf r (not v.area_speculars) "Area speculars off not copied"
	AlecLightConverter_noteIf r (v.rotation_X != 0 or v.rotation_Y != 0 or v.rotation_Z != 0) "IES rotations baked into the node"
	r.diffuse = if v.affect_diffuse then v.diffuse_contribution else 0.0
	r.specular = if v.affect_specular then v.specular_contribution else 0.0
	r.volume = if v.affect_atmospherics then v.atmospherics_contribution else 0.0
	r.castShadows = v.cast_shadows
	AlecLightConverter_readDecay r v
	r
)

-- standard lights

fn AlecLightConverter_readStandard node =
(
	local v = node.baseObject
	local spot = classOf v == targetSpot or classOf v == freeSpot
	local r = AlecLightConverter_Rec kind:(if spot then #spot else #distant) label:((classOf v) as string)
	r.enabled = v.enabled
	r.color = v.rgb
	r.gain = v.multiplier
	if spot do
	(
		r.cone = v.falloff
		r.penumbra = amax 0.0 ((v.falloff - v.hotspot) / 2.0)
		-- Arnold's aspect is height / width, Max's width / height
		r.aspect = if v.coneShape == 2 then 1.0 / v.aspect else 1.0
	)
	r.nearOn = v.useNearAtten
	r.nearStart = v.nearAttenStart
	r.nearEnd = v.nearAttenEnd
	r.farOn = v.useFarAtten
	r.farStart = v.farAttenStart
	r.farEnd = v.farAttenEnd
	AlecLightConverter_noteIf r (r.nearOn or r.farOn) "Near/Far Attenuation: the Max curve differs from Arnold's decay"
	r.diffuse = if v.affectDiffuse then 1.0 else 0.0
	r.specular = if v.affectSpecular then 1.0 else 0.0
	r.castShadows = v.castShadows
	r.shadowColor = v.shadowColor
	r.shadowDensity = v.shadowMultiplier
	if classOf v.shadowGenerator == VRayShadow then
	(
		if spot and v.shadowGenerator.areaShadow do
			if v.shadowGenerator.areaShadowType == AlecLightConverter_areaSphere then r.radius = v.shadowGenerator.usize
			else AlecLightConverter_note r "VRayShadow Box area shadow not copied"
		if not spot and v.shadowGenerator.areaShadow do
		(
			r.angle = 0.52
			AlecLightConverter_note r "VRayShadow area size not copied: Angle is Arnold's default 0.52"
		)
	)
	else AlecLightConverter_note r ("shadow generator " + (classOf v.shadowGenerator) as string + " not read")
	if spot then
	(
		-- an Arnold spot needs a surface to emit. Max: albedo x multiplier x (radius / distance)^2, Arnold: albedo x gain x (radius / distance)^2
		if r.radius <= 0 do r.radius = 1.0
		local decayRadius = if v.attenDecay == 3 then v.decayRadius else 1.0
		r.gain = v.multiplier * (decayRadius / r.radius) ^ 2
		AlecLightConverter_noteIf r (v.attenDecay != 3) "no Inverse Square decay on the source: Arnold always decays, set the intensity by hand"
	)
	-- Max: albedo x multiplier. Arnold: albedo x gain / pi. Normalize on keeps the Angle from changing the brightness
	else
	(
		r.gain = v.multiplier * pi
		r.normalize = true
	)
	AlecLightConverter_noteIf r (v.excludeList != undefined and v.excludeList.count > 0 or v.includeList != undefined and v.includeList.count > 0) "include/exclude list not copied: Arnold_Light has none"
	r
)

fn AlecLightConverter_read node =
(
	local c = classOf node.baseObject
	case c of
	(
		Arnold_Light: AlecLightConverter_readArnold node
		VRayLight: AlecLightConverter_readVRay node
		VRayIES: AlecLightConverter_readIES node
		default: AlecLightConverter_readStandard node
	)
)
