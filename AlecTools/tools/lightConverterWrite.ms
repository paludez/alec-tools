-- LightConverter: writes the record of tools/lightConverterRead.ms as a new light. Each writer gives the new node, without its
-- transform, name or target: tools/lightConverter.ms takes those from the old node.

-- the area Arnold's Normalize divides by, in square scene units, 0 when there is none. A sphere's is its cross-section
fn AlecLightConverter_area r =
(
	case r.kind of
	(
		#quad: r.length * r.width
		#disc: pi * r.radius ^ 2
		#point: pi * r.radius ^ 2
		#cylinder: 2.0 * pi * r.radius * r.height
		#mesh:
		(
			if r.shape != undefined then 2.0 * pi * r.radius * r.height
			else if r.source == undefined then 0.0
			else
			(
				local m = snapshotAsMesh r.source
				local area = meshop.getFaceArea m #{1..m.numFaces}
				free m
				area
			)
		)
		default: 0.0
	)
)

-- Kelvin as a color in the scene's rendering space, for the lights that have no temperature: a VRayLight in Temperature mode gives it.
-- One temporary VRayLight serves a whole run and the colors are kept per rounded temperature; both are made with undo off, so the
-- undo step of the run does not hold them. AlecLightConverter_endKelvin deletes the light and the colors at the end of the run
global AlecLightConverter_kelvinColors = Dictionary #integer
global AlecLightConverter_kelvinLight = undefined

fn AlecLightConverter_kelvinColor kelvin =
(
	local key = kelvin as integer
	if AlecLightConverter_kelvinColors[key] == undefined do
		with undo off
		(
			if not isValidNode AlecLightConverter_kelvinLight do AlecLightConverter_kelvinLight = VRayLight color_mode:1
			AlecLightConverter_kelvinLight.color_temperature = kelvin
			AlecLightConverter_kelvinColors[key] = AlecLightConverter_kelvinLight.color
		)
	AlecLightConverter_kelvinColors[key]
)

fn AlecLightConverter_endKelvin =
(
	with undo off
		if isValidNode AlecLightConverter_kelvinLight do delete AlecLightConverter_kelvinLight
	AlecLightConverter_kelvinLight = undefined
	AlecLightConverter_kelvinColors = Dictionary #integer
)

-- V-Ray's Temperature has its brightest channel at 1, Arnold's Kelvin renders brighter by about 1 / luminance (ACEScg weights)
fn AlecLightConverter_kelvinLuminance kelvin =
(
	local c = AlecLightConverter_kelvinColor kelvin
	(0.2722 * c.r + 0.6741 * c.g + 0.0537 * c.b) / 255.0
)

-- maps

-- Bitmap: only Spherical Environment has an Arnold format
fn AlecLightConverter_bitmapFormat r m =
(
	if m.coords.mappingType == 1 and m.coords.mapping == 0 then 2
	else
	(
		AlecLightConverter_note r "Bitmap mapping has no Skydome format, latlong was used"
		2
	)
)

-- the Arnold Skydome format of a map: 0 mirrored ball, 1 angular, 2 latlong
fn AlecLightConverter_mapFormat r m =
(
	case of
	(
		(classOf m == Bitmaptexture): AlecLightConverter_bitmapFormat r m
		(classOf m != VRayBitmap): 2
		(m.mapType == 0): 1
		(m.mapType == 2): 2
		(m.mapType == 3): 0
		default:
		(
			AlecLightConverter_note r "VRayBitmap Mapping type has no Skydome format, latlong was used"
			2
		)
	)
)

-- a map with several outputs sits in a slot through a node for its first output, the way Max connects it itself; the real map is behind it
fn AlecLightConverter_mapSource m =
	if classOf m == MultiOutputChannelTexmapToTexmap and m.sourceMap != undefined then m.sourceMap else m

fn AlecLightConverter_isUberBitmap m = classOf m == OSLMap and matchPattern m.OSLShaderName pattern:"UberBitmap*"

fn AlecLightConverter_isArnoldMap m = matchPattern ((classOf m) as string) pattern:"ai_*"

fn AlecLightConverter_textureClass name =
(
	local found = for c in textureMap.classes where (c as string) == name collect c
	if found.count == 0 then undefined else found[1]
)

-- a V-Ray bitmap becomes an Uber Bitmap OSL map (class osl_UberBitmap2b, as the Create tool makes it) in the Arnold light's slot.
-- Its multiplier cannot go with the map, so it goes into the gain. Any other map is copied as it is; a map that is not an OSL map is
-- listed, Arnold GPU may not render it
fn AlecLightConverter_arnoldTexture r =
(
	local m = AlecLightConverter_mapSource r.texture
	local uber = AlecLightConverter_textureClass "osl_UberBitmap2b"
	if classOf m == VRayBitmap and uber != undefined then
	(
		local u = uber()
		u.filename = m.HDRIMapName
		u.name = filenameFromPath m.HDRIMapName
		r.gain *= m.multiplier * m.renderMultiplier
		local channel = MultiOutputChannelTexmapToTexmap()
		channel.sourceMap = u
		channel.outputChannelIndex = 1
		channel
	)
	else
	(
		AlecLightConverter_noteIf r (classOf m != OSLMap) ("WARNING: the " + (classOf m) as string + " map was copied as it is: it is not an OSL map, Arnold GPU may not render it")
		r.texture
	)
)

-- an Uber Bitmap becomes a V-Ray bitmap. Any other map is copied as it is; an Arnold map is listed, V-Ray cannot render it
fn AlecLightConverter_vrayTexture r =
(
	local m = AlecLightConverter_mapSource r.texture
	if AlecLightConverter_isUberBitmap m then
	(
		local v = VRayBitmap()
		v.HDRIMapName = m.filename
		v.name = filenameFromPath m.filename
		v
	)
	else
	(
		AlecLightConverter_noteIf r (AlecLightConverter_isArnoldMap m) ("WARNING: the " + (classOf m) as string + " map was copied as it is: it is an Arnold map, V-Ray cannot render it")
		r.texture
	)
)

-- to V-Ray

fn AlecLightConverter_setDecay n r =
(
	n.decay_near_on = r.nearOn
	n.decay_near_start = r.nearStart
	n.decay_near_end = r.nearEnd
	n.decay_far_on = r.farOn
	n.decay_far_start = r.farStart
	n.decay_far_end = r.farEnd
)

fn AlecLightConverter_setContribution n r =
(
	n.affect_diffuse = r.diffuse > 0
	n.affect_specular = r.specular > 0
	n.affect_atmospherics = r.volume > 0
	n.atmospherics_contribution = r.volume
	if r.kind == #dome or r.kind == #mesh then
		AlecLightConverter_noteIf r ((r.diffuse != 0 and r.diffuse != 1.0) or (r.specular != 0 and r.specular != 1.0)) "fractional Diffuse or Specular not copied: this V-Ray type has no amount"
	else
	(
		n.diffuse_contribution = r.diffuse
		n.specular_contribution = r.specular
	)
)

-- Look: the surface looks the same at this size. Independent: the units behave like Normalize when the size changes.
-- The units go first: V-Ray may convert the multiplier when they change
fn AlecLightConverter_setUnits n r independent =
(
	if independent and r.kind != #dome then
	(
		n.normalizeColor = if r.normalize then 3 else 4
		n.multiplier = r.gain
		AlecLightConverter_note r ("units: independent of size, " + (if r.normalize then "Radiant power (W)" else "Radiance (W/m2/sr)") + ", not measured values")
	)
	else
	(
		local area = AlecLightConverter_area r
		n.normalizeColor = 0
		n.multiplier = if r.normalize and area > 0 then r.gain / area else r.gain
		setUserProp n "a2v_normalize" (if r.normalize then "on" else "off")
		AlecLightConverter_note r "units: look, Default (image)"
	)
)

fn AlecLightConverter_vrayLightShape n r =
(
	case r.kind of
	(
		#quad:
		(
			n.sizeLength = r.length
			n.sizeWidth = r.width
		)
		#disc: n.size0 = r.radius
		#point: n.size0 = r.radius
		#dome:
		(
			n.dome_spherical = true
			n.texmap_locktodome = 1
		)
		#mesh:
		(
			n.mesh_replaceOnPick = false
			n.mesh_source = r.source
			n.mesh_flip = r.flip
		)
	)
	if r.kind == #quad or r.kind == #disc do
	(
		n.lightDistribution = 1.0 - r.spread
		n.lightDistribution_strength = 1.0
		AlecLightConverter_noteIf r (r.spread == 0) "Spread 0: the V-Ray beam stays a 90 degree cone"
	)
)

fn AlecLightConverter_vrayLightMap n r =
(
	if r.texture != undefined do
		if r.kind == #quad or r.kind == #disc or r.kind == #dome then
		(
			n.texmap = AlecLightConverter_vrayTexture r
			n.texmap_on = true
			n.texmap_resolution = r.resolution
		)
		else AlecLightConverter_note r ("map lost: V-Ray has no map on a " + r.kind as string + " light")
)

fn AlecLightConverter_vrayLightType kind = case kind of
(
	#quad: 0
	#dome: 1
	#point: 2
	#mesh: 3
	#disc: 4
)

fn AlecLightConverter_writeVRayLight r independent =
(
	-- a sphere without a surface emits nothing
	if r.kind == #point and r.radius <= 0 do
	(
		r.radius = 0.1
		AlecLightConverter_note r "Radius 0: the V-Ray Sphere got a radius of 0.1 so that it has a surface"
	)
	local n = VRayLight type:(AlecLightConverter_vrayLightType r.kind)
	n.on = r.enabled
	n.color = r.color
	n.color_mode = if r.kelvin != undefined then 1 else 0
	if r.kelvin != undefined do n.color_temperature = r.kelvin
	AlecLightConverter_setUnits n r independent
	AlecLightConverter_vrayLightShape n r
	AlecLightConverter_vrayLightMap n r
	AlecLightConverter_setContribution n r
	if r.kind != #dome do AlecLightConverter_setDecay n r
	n.invisible = r.invisible
	n.baseObject.castShadows = r.castShadows
	n.doubleSided = false
	n.intensityRaysOn = false
	AlecLightConverter_noteIf r (r.shadowDensity != 1.0 or r.shadowColor != black) "shadow color or density not copied: VRayLight has none"
	n
)

-- a new Cylinder is the shape of the mesh light, with the base at the center of the Arnold cylinder less half its height.
-- It does not render: only the light does
fn AlecLightConverter_writeCylinder r independent =
(
	r.shape = Cylinder radius:r.radius height:r.height sides:32 heightsegs:1
	r.shape.renderable = false
	r.source = r.shape
	r.kind = #mesh
	AlecLightConverter_note r "Cylinder: a VRayLight Mesh on a new Cylinder that does not render"
	AlecLightConverter_writeVRayLight r independent
)

fn AlecLightConverter_writeIES r =
(
	local n = VRayIES()
	n.enabled = r.enabled
	n.ies_file = r.iesFile
	n.color = r.color
	n.color_mode = if r.kelvin != undefined then 1 else 0
	if r.kelvin != undefined do n.color_temperature = r.kelvin
	-- Rescale sets the file's peak in cd, Arnold's gain multiplies the file
	local peak = if r.gain == 1.0 then undefined else AlecLightConverter_iesPeak r.iesFile
	n.override_intensity = 0
	if peak != undefined then
	(
		n.intensity_type = 1
		n.intensity_value = peak * r.gain
		n.override_intensity = 2
	)
	else AlecLightConverter_noteIf r (r.gain != 1.0) "Arnold gain not copied: the IES file cannot be read"
	n.override_shape = r.radius > 0
	if r.radius > 0 do
	(
		n.shape = 3
		n.diameter = 2.0 * r.radius
	)
	AlecLightConverter_noteIf r (r.texture != undefined) "map lost: VRayIES has no map"
	n.affect_diffuse = r.diffuse > 0
	n.diffuse_contribution = r.diffuse
	n.affect_specular = r.specular > 0
	n.specular_contribution = r.specular
	n.affect_atmospherics = r.volume > 0
	n.atmospherics_contribution = r.volume
	n.cast_shadows = r.castShadows
	AlecLightConverter_setDecay n r
	n
)

fn AlecLightConverter_setStandard n r =
(
	n.enabled = r.enabled
	n.rgb = if r.kelvin != undefined then AlecLightConverter_kelvinColor r.kelvin else r.color
	AlecLightConverter_noteIf r (r.kelvin != undefined) ("Kelvin " + r.kelvin as string + " became RGB: standard lights have no temperature")
	AlecLightConverter_noteIf r (r.texture != undefined) "map lost: V-Ray has no map on a standard light"
	n.affectDiffuse = r.diffuse > 0
	n.affectSpecular = r.specular > 0
	AlecLightConverter_noteIf r ((r.diffuse != 0 and r.diffuse != 1.0) or (r.specular != 0 and r.specular != 1.0)) "fractional Diffuse or Specular not copied: standard lights have on/off"
	n.useNearAtten = r.nearOn
	n.nearAttenStart = r.nearStart
	n.nearAttenEnd = r.nearEnd
	n.useFarAtten = r.farOn
	n.farAttenStart = r.farStart
	n.farAttenEnd = r.farEnd
	AlecLightConverter_noteIf r (r.nearOn or r.farOn) "Near/Far Attenuation: the Max curve differs from Arnold's decay"
	n.shadowGenerator = VRayShadow()
	n.shadowGenerator.transparentShadows = false
	-- always on. On the base object: the node has a castShadows of its own (Object Properties)
	n.baseObject.castShadows = true
	n.shadowColor = r.shadowColor
	n.shadowMultiplier = r.shadowDensity
)

fn AlecLightConverter_writeSpot r targeted =
(
	local n = if targeted then targetSpot() else freeSpot()
	AlecLightConverter_setStandard n r
	n.falloff = r.cone
	n.hotspot = amax 0.0 (amin (r.cone - 2.0) (r.cone - 2.0 * r.penumbra))
	n.coneShape = if r.aspect == 1.0 then 1 else 2
	-- Arnold's aspect is height / width, Max's width / height. Max's rectangular spot has no round version
	n.aspect = 1.0 / r.aspect
	AlecLightConverter_noteIf r (r.aspect != 1.0) "Aspect Ratio: the elliptical Arnold spot became a rectangle"
	-- Max: albedo x multiplier x (radius / distance)^2. Arnold: albedo x gain x area / (pi x distance^2), area = pi x radius^2,
	-- or with Normalize no area. Without a radius or Normalize the Arnold spot emits nothing
	n.attenDecay = 3
	n.decayRadius = if not r.normalize and r.radius > 0 then r.radius else 1.0
	n.multiplier = if r.normalize then r.gain / pi else if r.radius > 0 then r.gain else 0.0
	AlecLightConverter_noteIf r (not r.normalize and r.radius <= 0) "Radius 0 with Normalize off: the Arnold spot emits nothing, the multiplier is 0"
	if r.radius > 0 do
	(
		n.shadowGenerator.areaShadow = true
		n.shadowGenerator.areaShadowType = AlecLightConverter_areaSphere
		n.shadowGenerator.usize = r.radius
	)
	n
)

fn AlecLightConverter_writeDirect r targeted =
(
	local n = if targeted then TargetDirectionallight() else Directionallight()
	AlecLightConverter_setStandard n r
	-- a Distant lights the whole scene, a Target Direct only its beam unless it overshoots
	n.overShoot = true
	-- Max: albedo x multiplier. Arnold: albedo x gain / pi, and without Normalize the gain is a radiance, so the light also
	-- grows with the solid angle of its disc
	n.multiplier = if r.normalize then r.gain / pi else r.gain * 2.0 * (1.0 - cos (r.angle / 2.0))
	AlecLightConverter_noteIf r (not r.normalize and r.angle <= 0) "Angle 0 with Normalize off: the Arnold distant light emits nothing, the multiplier is 0"
	-- Arnold's Angle makes soft shadows: the VRayShadow gets an area shadow, its size is V-Ray's own (scene units, not degrees)
	if r.angle > 0 do
	(
		n.shadowGenerator.areaShadow = true
		n.shadowGenerator.areaShadowType = AlecLightConverter_areaSphere
		AlecLightConverter_note r ("Angle " + r.angle as string + " became an area shadow with V-Ray's default size: set the size by hand")
	)
	n
)

fn AlecLightConverter_writeVRay r targeted independent =
(
	if r.kelvin != undefined do r.gain /= AlecLightConverter_kelvinLuminance r.kelvin
	case r.kind of
	(
		#spot: AlecLightConverter_writeSpot r targeted
		#distant: AlecLightConverter_writeDirect r targeted
		#ies: AlecLightConverter_writeIES r
		#cylinder: AlecLightConverter_writeCylinder r independent
		default: AlecLightConverter_writeVRayLight r independent
	)
)

-- to Arnold

fn AlecLightConverter_arnoldShapeType kind = (findItem #(#point, #distant, #spot, #quad, #disc, #cylinder, #dome, #ies, #mesh) kind) - 1

fn AlecLightConverter_setArnoldColor n r tex =
(
	n.useKelvin = r.kelvin != undefined
	n.useColor = r.kelvin == undefined
	n.usePreset = false
	n.useTexmap = tex != undefined and r.kelvin == undefined
	if r.kelvin != undefined do n.kelvin = r.kelvin
	AlecLightConverter_noteIf r (tex != undefined and r.kelvin != undefined) "map lost: Use Color Temperature replaces it"
	if tex != undefined do n.texmap = tex
	-- a map replaces the swatch in Arnold, so the swatch V-Ray multiplies in goes to the filter
	if tex != undefined then n.filter = r.color else n.color = r.color
	if r.kind == #dome and tex != undefined do
	(
		r.format = AlecLightConverter_mapFormat r r.texture
		n.format = r.format
	)
)

fn AlecLightConverter_setArnoldShape n r =
(
	case r.kind of
	(
		#point: n.lightRadius = r.radius
		#spot:
		(
			n.lightRadius = r.radius
			n.cone_angle = r.cone
			n.penumbra_angle = amin r.penumbra (r.cone / 2.0)
			n.aspect_ratio = r.aspect
		)
		#quad:
		(
			n.quadX = r.length
			n.quadY = r.width
			n.soft_edge = 0.0
			n.spread = r.spread
			n.quadResolution = r.resolution
		)
		#disc:
		(
			n.lightRadius = r.radius
			n.spread = r.spread
			n.quadResolution = r.resolution
		)
		#cylinder:
		(
			n.lightRadius = r.radius
			n.height = r.height
		)
		#distant: n.angle = r.angle
		#dome: n.resolution = r.resolution
		#ies:
		(
			n.filename = r.iesFile
			n.photometricRadius = r.radius
		)
		#mesh:
		(
			n.lightMesh = r.source
			AlecLightConverter_noteIf r r.flip "Flip normals not copied: add a flipping Normal modifier to the mesh"
		)
	)
)

-- a new Arnold_Light starts with the values of the last one made in this session, not with its defaults
fn AlecLightConverter_resetArnold n =
(
	n.filter = white
	n.texmap = undefined
	n.spread = 1.0
	n.soft_edge = 0.0
	n.quadRoundness = 0.0
	n.spotRoundness = 1.0
	n.lens_radius = 0.0
	n.aspect_ratio = 1.0
	n.portal = false
	n.portal_mode = 1
	n.transmission = 1.0
	n.sss = 1.0
	n.indirect = 1.0
	n.max_bounces = 999
	n.samples = 1
	n.volume_samples = 2
	n.cast_volumetric_shadows = true
)

fn AlecLightConverter_writeArnold r =
(
	if r.kelvin != undefined do r.gain *= AlecLightConverter_kelvinLuminance r.kelvin
	-- Kelvin replaces the map; a dome format is read from the original map
	local tex = if r.texture != undefined and r.kelvin == undefined then AlecLightConverter_arnoldTexture r else r.texture
	local n = Arnold_Light shapeType:(AlecLightConverter_arnoldShapeType r.kind)
	AlecLightConverter_resetArnold n
	n.on = r.enabled
	n.normalize = r.normalize
	AlecLightConverter_setArnoldColor n r tex
	AlecLightConverter_setArnoldShape n r
	-- the map folded its multiplier into the gain. Exposure cannot be rebuilt, the whole gain goes to intensity
	local area = AlecLightConverter_area r
	n.intensity = if r.normalize and not r.unitsSet and area > 0 then r.gain * area else r.gain
	n.exposure = 0.0
	n.lightShapeVisible = not r.invisible
	n.camera = if r.invisible then 0.0 else 1.0
	n.diffuse = r.diffuse
	n.specular = r.specular
	n.volume = r.volume
	n.cast_shadows = r.castShadows
	n.shadow_color = r.shadowColor
	n.shadow_density = r.shadowDensity
	n.aov = r.aov
	AlecLightConverter_noteIf r (r.kind == #mesh and not r.invisible) "the mesh surface will not show in camera: Arnold mesh lights are not visible"
	if r.nearOn or r.farOn do
	(
		local decay = Arnold_Light_Decay()
		addModifier n decay
		decay.arnold_node_use_near_atten = r.nearOn
		decay.arnold_node_near_start = r.nearStart
		decay.arnold_node_near_end = r.nearEnd
		decay.arnold_node_use_far_atten = r.farOn
		decay.arnold_node_far_start = r.farStart
		decay.arnold_node_far_end = r.farEnd
	)
	n
)
