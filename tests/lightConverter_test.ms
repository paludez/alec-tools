-- Test for tools/lightConverter.ms. Run in Max (needs Arnold and V-Ray; press Reload Alec Tools first):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\lightConverter_test.ms"
-- Makes its own lights, converts only those, deletes them. Does not save the scene. Prints PASS/FAIL lines to the Listener.

-- outside the block below: a block is compiled before a fileIn inside it runs
fileIn (AlecTools_path "tools/lightConverter.ms")

global AlecLightTest_failures = #()

fn AlecLightTest_check label ok =
(
	format "% %\n" (if ok then "PASS" else "FAIL") label
	if not ok do append AlecLightTest_failures label
)

fn AlecLightTest_near a b = abs (a - b) < 0.01

fn AlecLightTest_nearPos a b = distance a b < 0.01

-- converts these nodes and gives the new ones; prints the report
fn AlecLightTest_convert nodes target units:1 =
(
	select nodes
	local job = AlecLight_Job settings:(AlecLight_Settings input:1 target:target units:units)
	AlecLight_convertAll job
	AlecLight_report job
	job.news
)

fn AlecLightTest_clean nodes =
(
	for n in nodes where isValidNode n do delete n
)

fn AlecLightTest_quadLook =
(
	local a = Arnold_Light shapeType:3 quadX:100.0 quadY:40.0 intensity:2.0 exposure:3.0 normalize:false pos:[10, 20, 30] name:"t_quad"
	local out = (AlecLightTest_convert #(a) 1)[1]
	AlecLightTest_check "quad -> VRayLight Plane" (classOf out.baseObject == VRayLight and out.type == 0)
	AlecLightTest_check "quad: full size" (AlecLightTest_near out.sizeLength 100 and AlecLightTest_near out.sizeWidth 40)
	AlecLightTest_check "quad: gain = intensity x 2^exposure" (AlecLightTest_near out.multiplier 16)
	AlecLightTest_check "quad: Default units" (out.normalizeColor == 0)
	AlecLightTest_check "quad: Intensity rays off" (not out.intensityRaysOn)
	AlecLightTest_check "quad: name and position kept" (out.name == "t_quad" and AlecLightTest_nearPos out.pos [10, 20, 30])
	AlecLightTest_check "quad: old light deleted" (not isValidNode a)
	local back = (AlecLightTest_convert #(out) 2)[1]
	AlecLightTest_check "plane -> Arnold quad" (classOf back.baseObject == Arnold_Light and back.shapeType == 3)
	AlecLightTest_check "plane: intensity = multiplier, exposure 0" (AlecLightTest_near back.intensity 16 and back.exposure == 0)
	AlecLightTest_clean #(back)
)

fn AlecLightTest_normalize =
(
	local a = Arnold_Light shapeType:3 quadX:100.0 quadY:40.0 intensity:8000.0 exposure:0.0 normalize:true name:"t_norm"
	local out = (AlecLightTest_convert #(a) 1)[1]
	AlecLightTest_check "Normalize on: multiplier = gain / area" (AlecLightTest_near out.multiplier 2)
	AlecLightTest_check "Normalize on: stored in the user property" (((getUserProp out "a2v_normalize") as string) != "off")
	local back = (AlecLightTest_convert #(out) 2)[1]
	AlecLightTest_check "Normalize comes back on" back.normalize
	AlecLightTest_check "intensity comes back" (AlecLightTest_near back.intensity 8000)
	AlecLightTest_clean #(back)

	local i = Arnold_Light shapeType:3 quadX:100.0 quadY:40.0 intensity:5.0 exposure:0.0 normalize:true name:"t_ind"
	local watts = (AlecLightTest_convert #(i) 1 units:2)[1]
	AlecLightTest_check "Independent, Normalize on: Radiant power, multiplier = gain" (watts.normalizeColor == 3 and AlecLightTest_near watts.multiplier 5)
	AlecLightTest_clean #(watts)
)

fn AlecLightTest_spot =
(
	local a = Arnold_Light shapeType:2 cone_angle:60.0 penumbra_angle:10.0 intensity:4.0 exposure:0.0 lightRadius:5.0 normalize:false cast_shadows:false name:"t_spot"
	a.targeted = true
	a.target.pos = [0, 0, -200]
	local out = (AlecLightTest_convert #(a) 1)[1]
	AlecLightTest_check "targeted spot -> targetSpot" (classOf out.baseObject == targetSpot)
	AlecLightTest_check "spot: falloff and hotspot" (AlecLightTest_near out.falloff 60 and AlecLightTest_near out.hotspot 40)
	AlecLightTest_check "spot: Inverse Square from the radius" (out.attenDecay == 3 and AlecLightTest_near out.decayRadius 5 and AlecLightTest_near out.multiplier 4)
	AlecLightTest_check "spot: VRayShadow" (classOf out.shadowGenerator == VRayShadow)
	AlecLightTest_check "spot: shadows always on, even from a light with them off" out.baseObject.castShadows
	AlecLightTest_check "spot: target at the same point" (out.target != undefined and AlecLightTest_nearPos out.target.pos [0, 0, -200])
	local back = (AlecLightTest_convert #(out) 2)[1]
	AlecLightTest_check "spot comes back: cone and penumbra" (back.shapeType == 2 and AlecLightTest_near back.cone_angle 60 and AlecLightTest_near back.penumbra_angle 10)
	AlecLightTest_check "spot comes back: intensity" (AlecLightTest_near back.intensity 4 and AlecLightTest_near back.lightRadius 5)
	AlecLightTest_check "spot comes back: target" (back.target != undefined and AlecLightTest_nearPos back.target.pos [0, 0, -200])
	AlecLightTest_clean #(back)

	local f = Arnold_Light shapeType:2 aspect_ratio:0.5 lightRadius:0.0 normalize:false name:"t_free"
	local free = (AlecLightTest_convert #(f) 1)[1]
	AlecLightTest_check "free spot -> freeSpot" (classOf free.baseObject == freeSpot)
	AlecLightTest_check "aspect inverted" (AlecLightTest_near free.aspect 2)
	AlecLightTest_check "radius 0, Normalize off: multiplier 0" (free.multiplier == 0)
	AlecLightTest_clean #(free)

	local n = Arnold_Light shapeType:2 intensity:pi exposure:0.0 normalize:true lightRadius:5.0 aspect_ratio:1.0 name:"t_normSpot"
	local normal = (AlecLightTest_convert #(n) 1)[1]
	AlecLightTest_check "Normalize on: multiplier = gain / pi, decay radius 1" (AlecLightTest_near normal.multiplier 1 and AlecLightTest_near normal.decayRadius 1)
	AlecLightTest_clean #(normal)

	local plain = targetSpot name:"t_plainSpot" multiplier:2.0 attenDecay:3 decayRadius:10.0
	plain.target = Targetobject pos:[0, 0, -100]
	local fromMax = (AlecLightTest_convert #(plain) 2)[1]
	AlecLightTest_check "standard spot without area shadow gets a radius, so Arnold emits" (fromMax.lightRadius > 0 and AlecLightTest_near fromMax.intensity 200)
	AlecLightTest_clean #(fromMax)
)

fn AlecLightTest_distant =
(
	local a = Arnold_Light shapeType:1 useKelvin:true useColor:false kelvin:3200.0 intensity:3.0 exposure:0.0 name:"t_dist"
	local out = (AlecLightTest_convert #(a) 1)[1]
	AlecLightTest_check "Distant -> Directionallight" (classOf out.baseObject == Directionallight)
	AlecLightTest_check "Distant: overshoots" out.overShoot
	AlecLightTest_check "Distant: multiplier = gain / pi" (AlecLightTest_near out.multiplier (3.0 / pi))
	AlecLightTest_check "Kelvin on a standard light -> warm RGB" (out.rgb.r > out.rgb.b)
	AlecLightTest_clean #(out)
)

fn AlecLightTest_shapes =
(
	local p = Arnold_Light shapeType:0 lightRadius:0.0 name:"t_point"
	local sphere = (AlecLightTest_convert #(p) 1)[1]
	AlecLightTest_check "Point radius 0 -> Sphere with a surface" (sphere.type == 2 and sphere.size0 > 0)
	AlecLightTest_clean #(sphere)

	local q = Arnold_Light shapeType:3 quadX:50.0 quadY:50.0 quadRoundness:1.0 name:"t_round"
	local disc = (AlecLightTest_convert #(q) 1)[1]
	AlecLightTest_check "round square quad -> Disc, radius half the side" (disc.type == 4 and AlecLightTest_near disc.size0 25)
	AlecLightTest_clean #(disc)

	local c = Arnold_Light shapeType:5 lightRadius:10.0 height:80.0 pos:[0, 0, 100] name:"t_cyl"
	local mesh = (AlecLightTest_convert #(c) 1)[1]
	AlecLightTest_check "Cylinder -> VRayLight Mesh" (mesh.type == 3 and mesh.mesh_source != undefined)
	AlecLightTest_check "Cylinder: shape does not render" (not mesh.mesh_source.renderable)
	local shape = mesh.mesh_source
	AlecLightTest_check "Cylinder: shape centered on the old light, axis along its Y" (AlecLightTest_nearPos (shape.pos + shape.transform.row3 * 40) [0, 0, 100] and abs shape.transform.row3.y > 0.99)
	local back = (AlecLightTest_convert #(mesh) 2)[1]
	AlecLightTest_check "VRayLight Mesh on a Cylinder -> Arnold cylinder" (back.shapeType == 5 and AlecLightTest_near back.height 80)
	AlecLightTest_check "Arnold cylinder back at the center" (AlecLightTest_nearPos back.pos [0, 0, 100])
	AlecLightTest_check "the shape goes with the conversion back" ((for o in objects where o.name == "t_cyl_shape" collect o).count == 0)
	AlecLightTest_clean #(back)
)

fn AlecLightTest_nearColor a b = distance [a.r, a.g, a.b] [b.r, b.g, b.b] < 1.0

-- a new Arnold_Light starts with the color settings of the last one made
fn AlecLightTest_setColor a c f =
(
	a.useKelvin = false
	a.useColor = true
	a.color = c
	a.filter = f
	a
)

fn AlecLightTest_colors =
(
	local p = AlecLightTest_setColor (Arnold_Light shapeType:0 name:"t_white") white white
	local before = "Arnold " + p.color as string + " x " + p.filter as string + " Kelvin " + p.useKelvin as string
	local sphere = (AlecLightTest_convert #(p) 1)[1]
	AlecLightTest_check ("white stays white: " + before + " became " + sphere.color as string) (AlecLightTest_nearColor sphere.color white)
	AlecLightTest_clean #(sphere)

	local q = AlecLightTest_setColor (Arnold_Light shapeType:3 name:"t_filter") (color 200 100 50) (color 255 128 255)
	before = "Arnold " + q.color as string + " x " + q.filter as string + " Kelvin " + q.useKelvin as string
	local plane = (AlecLightTest_convert #(q) 1)[1]
	AlecLightTest_check ("color x filter: " + before + " became " + plane.color as string) (AlecLightTest_nearColor plane.color (color 200 50.2 50))
	AlecLightTest_clean #(plane)

	local v = VRayLight type:0 color:(color 100 50 25) normalizeColor:4 name:"t_hue"
	local quad = (AlecLightTest_convert #(v) 2)[1]
	AlecLightTest_check "physical units: hue with its brightest channel at 255" (AlecLightTest_nearColor quad.color (color 255 127.5 63.75))
	AlecLightTest_check "a new Arnold light does not keep the last one's filter" (AlecLightTest_nearColor quad.filter white)
	AlecLightTest_clean #(quad)

	local k = Arnold_Light shapeType:3 useKelvin:true useColor:false kelvin:3200.0 intensity:2.0 exposure:0.0 normalize:false name:"t_kelvin"
	local warm = (AlecLightTest_convert #(k) 1)[1]
	AlecLightTest_check "Kelvin -> Temperature mode" (warm.color_mode == 1 and AlecLightTest_near warm.color_temperature 3200)
	AlecLightTest_check "Kelvin: V-Ray multiplier raised by 1 / luminance" (AlecLightTest_near warm.multiplier (2.0 / AlecLight_kelvinLuminance 3200.0))
	local kBack = (AlecLightTest_convert #(warm) 2)[1]
	AlecLightTest_check "Temperature -> Kelvin" (kBack.useKelvin and not kBack.useColor and AlecLightTest_near kBack.kelvin 3200)
	AlecLightTest_check "Kelvin: intensity comes back" (AlecLightTest_near kBack.intensity 2)
	AlecLightTest_clean #(kBack)
)

fn AlecLightTest_doubleSided =
(
	local v = VRayLight type:0 doubleSided:true name:"t_ds"
	local news = AlecLightTest_convert #(v) 2
	AlecLightTest_check "Double-sided -> two Arnold lights" (news.count == 2)
	AlecLightTest_check "Double-sided: opposite normals" (dot news[1].transform.row3 news[2].transform.row3 < -0.99)
	AlecLightTest_clean news
)

fn AlecLightTest_instances =
(
	local a = Arnold_Light shapeType:3 name:"t_inst1"
	local b = instance a name:"t_inst2" pos:[100, 0, 0]
	local news = AlecLightTest_convert #(a, b) 1
	local count = #()
	InstanceMgr.GetInstances news[1] &count
	AlecLightTest_check "instances stay instances" (news.count == 2 and count.count == 2)
	local second = for n in news where n.name == "t_inst2" collect n
	AlecLightTest_check "instances keep their own place" (second.count == 1 and AlecLightTest_nearPos second[1].pos [100, 0, 0])
	AlecLightTest_clean news
)

fn AlecLightTest_decay =
(
	local a = Arnold_Light shapeType:3 name:"t_decay"
	local m = Arnold_Light_Decay()
	addModifier a m
	m.arnold_node_use_far_atten = true
	m.arnold_node_far_end = 500.0
	local out = (AlecLightTest_convert #(a) 1)[1]
	AlecLightTest_check "decay -> VRayLight Far" (out.decay_far_on and AlecLightTest_near out.decay_far_end 500)
	local back = (AlecLightTest_convert #(out) 2)[1]
	AlecLightTest_check "decay comes back as a modifier" (back.modifiers.count == 1 and back.modifiers[1].arnold_node_use_far_atten)
	AlecLightTest_clean #(back)
)

fn AlecLightTest_maps =
(
	local v = VRayLight type:0 texmap:(VRayBitmap HDRIMapName:"C:\\t_light.exr" multiplier:2.0) multiplier:3.0 name:"t_map"
	local out = (AlecLightTest_convert #(v) 2)[1]
	AlecLightTest_check "VRayBitmap -> UberBitmap2 OSL map" (classOf out.texmap == OSLMap and matchPattern out.texmap.OSLPath pattern:"*UberBitmap2.osl")
	AlecLightTest_check "UberBitmap2 has the file" (out.texmap.Filename == "C:\\t_light.exr")
	AlecLightTest_check "map multiplier folded into the intensity" (AlecLightTest_near out.intensity 6)
	local back = (AlecLightTest_convert #(out) 1)[1]
	AlecLightTest_check "UberBitmap2 -> VRayBitmap" (classOf back.texmap == VRayBitmap and back.texmap.HDRIMapName == "C:\\t_light.exr")
	AlecLightTest_clean #(back)

	local s = Arnold_Light shapeType:0 useTexmap:true texmap:(Bitmaptexture()) name:"t_lost"
	local sphere = (AlecLightTest_convert #(s) 1)[1]
	AlecLightTest_check "a map on a Point is lost" (sphere.texmap == undefined)
	AlecLightTest_clean #(sphere)
)

fn AlecLightTest_lightSelect =
(
	local mgr = maxOps.GetCurRenderElementMgr()
	local before = mgr.NumRenderElements()
	local a = Arnold_Light shapeType:3 aov:"t_key" name:"t_aov"
	local out = (AlecLightTest_convert #(a) 1)[1]
	local selects = for e in AlecLight_lightSelects() where e.elementName == "t_key" collect e
	AlecLightTest_check "AOV -> VRayLightSelect with the light" (selects.count == 1 and findItem (selects[1].lights as array) out > 0)
	local back = (AlecLightTest_convert #(out) 2)[1]
	AlecLightTest_check "VRayLightSelect -> AOV" (back.aov == "t_key")
	for e in selects do mgr.RemoveRenderElement e
	AlecLightTest_check "render elements restored" (mgr.NumRenderElements() == before)
	AlecLightTest_clean #(back)
)

fn AlecLightTest_renderer =
(
	local keep = renderers.production
	local job = AlecLight_Job settings:(AlecLight_Settings())
	AlecLight_setRenderer job 1
	format "    V-Ray GPU class: %\n" (classOf renderers.production)
	AlecLightTest_check "To V-Ray: V-Ray GPU is the production renderer" (classOf renderers.production == AlecLight_vrayGpuClass() and classOf renderers.production != VRay)
	AlecLight_setRenderer job 2
	AlecLightTest_check "To Arnold: Arnold is the production renderer" (classOf renderers.production == Arnold)
	AlecLightTest_check "To Arnold: Render Device GPU" (renderers.production.render_device == 1)
	local same = renderers.production
	AlecLight_setRenderer job 2
	AlecLightTest_check "a renderer already in place stays the same one" (renderers.production == same)
	renderers.production = keep
)

fn AlecLightTest_sunSky =
(
	local sun = VRaySun name:"t_sun"
	local news = AlecLightTest_convert #(sun) 2
	AlecLightTest_check "VRaySun left as it is" (isValidNode sun and news.count == 0)
	delete sun
	local d = Arnold_Light shapeType:6 texmap:(ai_physical_sky()) useTexmap:true name:"t_sky"
	news = AlecLightTest_convert #(d) 1
	AlecLightTest_check "Skydome with ai_physical_sky left as it is" (isValidNode d and news.count == 0)
	delete d
)

(
	if Arnold_Light == undefined or VRayLight == undefined then format "lightConverter_test: needs both Arnold and V-Ray\n"
	else
	(
		local keep = selection as array
		local before = objects as array
		AlecLightTest_failures = #()
		with undo off with redraw off
			for test in #(AlecLightTest_quadLook, AlecLightTest_normalize, AlecLightTest_spot, AlecLightTest_distant, AlecLightTest_shapes, AlecLightTest_colors,
				AlecLightTest_doubleSided, AlecLightTest_instances, AlecLightTest_decay, AlecLightTest_maps, AlecLightTest_lightSelect, AlecLightTest_renderer,
				AlecLightTest_sunSky) do test()
		local extra = for o in objects where findItem before o == 0 collect o.name
		AlecLightTest_check ("nothing left in the scene " + extra as string) (extra.count == 0)
		select keep
		format "\nlightConverter_test: % failure(s)\n" AlecLightTest_failures.count
		for label in AlecLightTest_failures do format "  FAILED %\n" label
	)
)
