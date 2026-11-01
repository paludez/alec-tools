-- Scene for comparing LightConverter by eye. Run in Max, in a new scene (it does not save anything):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\lightConverter_scene.ms"
-- 15 walled cells, seen from above, each with one Arnold light and a grey sphere; a label on the floor of each says what it is.
-- It makes a camera, sets the renderer to Arnold GPU and turns exposure control off, so the two renders are compared as they are.
-- Render with Arnold, convert with LightConverter (Scene, To V-Ray, Set renderer: V-Ray GPU), render again, compare.
-- ATlight_distant and ATlight_skydome are off because they light every cell: turn one on, with the others off, to test it.
-- Running it again replaces the old set.

(
	delete (for o in objects where matchPattern o.name pattern:"ATlight_*" collect o)

	local cell = 400.0
	local wallHeight = 250.0
	local lightHeight = 200.0
	local columns = 5
	local rows = 3

	local grey = OpenPBR_Material name:"ATlight_grey" base_color:(color 128 128 128) specular_weight:0.0
	local dark = OpenPBR_Material name:"ATlight_dark" base_color:(color 15 15 15) specular_weight:0.0

	fn onLayer nm nodes =
	(
		local lay = LayerManager.getLayerFromName nm
		if lay == undefined do lay = LayerManager.newLayerFromName nm
		for n in nodes do lay.addNode n
	)

	-- the middle of a cell, counted from 1
	fn cellCenter index cell columns =
	(
		local i = index - 1
		[(mod i columns) * cell, -(floor (i / columns)) * cell, 0]
	)

	fn makeWall nm size center mat =
	(
		local w = Box name:nm width:size.x length:size.y height:size.z material:mat
		w.pos = center
		w
	)

	fn buildRoom cell wallHeight columns rows mat =
	(
		local width = columns * cell
		local depth = rows * cell
		local center = [(columns - 1) * cell / 2.0, -(rows - 1) * cell / 2.0, 0]
		local parts = #(makeWall "ATlight_floor" [width, depth, 1.0] (center - [0, 0, 1]) mat)
		for i = 0 to columns do
			append parts (makeWall ("ATlight_wallX" + i as string) [4, depth, wallHeight] [(i - 0.5) * cell, center.y, 0] mat)
		for i = 0 to rows do
			append parts (makeWall ("ATlight_wallY" + i as string) [width, 4, wallHeight] [center.x, 0.5 * cell - i * cell, 0] mat)
		parts
	)

	fn buildLabel title center cell mat =
	(
		local t = Text text:title size:26 name:("ATlight_label_" + title) pos:(center + [-cell * 0.45, -cell * 0.45, 0.5])
		addModifier t (Extrude amount:0.5)
		t.material = mat
		t
	)

	-- a new Arnold_Light starts with the values of the last one made, so everything the cells rely on is set
	fn newLight title kind center height gainStops =
	(
		local a = Arnold_Light shapeType:kind name:("ATlight_" + title) pos:(center + [0, 0, height])
		a.targeted = false
		a.useKelvin = false
		a.useColor = true
		a.usePreset = false
		a.useTexmap = false
		a.texmap = undefined
		a.color = white
		a.filter = white
		a.intensity = 1.0
		a.exposure = gainStops
		a.normalize = false
		a.portal = false
		a.spread = 1.0
		a.soft_edge = 0.0
		a.quadRoundness = 0.0
		a.lightShapeVisible = false
		a.camera = 0.0
		a
	)

	fn newQuad title center height gainStops x y =
	(
		local a = newLight title 3 center height gainStops
		a.quadX = x
		a.quadY = y
		a
	)

	fn newSpot title center height gainStops cone penumbra =
	(
		local a = newLight title 2 center height gainStops
		a.cone_angle = cone
		a.penumbra_angle = penumbra
		a.lightRadius = 5.0
		a
	)

	local titles = #("point r5", "point r5 normalize", "spot target", "spot free aspect", "quad 100x100", "quad normalize", "quad 150x40", "quad round",
		"disc", "cylinder", "color x filter", "quad 3200K", "spot 3200K", "mesh", "quad far decay")
	local h = lightHeight
	local c = for i = 1 to titles.count collect cellCenter i cell columns
	local allLights = #()

	local p1 = newLight "point r5" 0 c[1] h 11.0
	p1.lightRadius = 5.0
	local p2 = newLight "point normalize" 0 c[2] h 19.0
	p2.lightRadius = 5.0
	p2.normalize = true
	join allLights #(p1, p2)

	local s1 = newSpot "spot target" c[3] h 11.0 40.0 5.0
	s1.targeted = true
	s1.target.pos = c[3]
	local s2 = newSpot "spot free" c[4] h 11.0 40.0 5.0
	s2.aspect_ratio = 0.5
	join allLights #(s1, s2)

	local q1 = newQuad "quad" c[5] h 4.0 100.0 100.0
	local q2 = newQuad "quad normalize" c[6] h 17.0 100.0 100.0
	q2.normalize = true
	local q3 = newQuad "quad 150x40" c[7] h 5.0 150.0 40.0
	local q4 = newQuad "quad round" c[8] h 4.0 100.0 100.0
	q4.quadRoundness = 1.0
	join allLights #(q1, q2, q3, q4)

	local d1 = newLight "disc" 4 c[9] h 4.0
	d1.lightRadius = 50.0
	local y1 = newLight "cylinder" 5 c[10] h 6.0
	y1.lightRadius = 8.0
	y1.height = 80.0
	join allLights #(d1, y1)

	local f1 = newQuad "color x filter" c[11] h 5.0 100.0 100.0
	f1.color = color 200 100 50
	f1.filter = color 255 128 255
	local k1 = newQuad "quad 3200K" c[12] h 5.0 100.0 100.0
	k1.useColor = false
	k1.useKelvin = true
	k1.kelvin = 3200.0
	local k2 = newSpot "spot 3200K" c[13] h 12.0 40.0 5.0
	k2.useColor = false
	k2.useKelvin = true
	k2.kelvin = 3200.0
	join allLights #(f1, k1, k2)

	local emitter = Box name:"ATlight_mesh_box" width:60 length:60 height:6 pos:(c[14] + [0, 0, h]) material:grey
	local m1 = newLight "mesh" 8 c[14] h 6.0
	m1.lightMesh = emitter
	local e1 = newQuad "quad far decay" c[15] h 5.0 100.0 100.0
	local decay = Arnold_Light_Decay()
	addModifier e1 decay
	decay.arnold_node_use_far_atten = true
	decay.arnold_node_far_start = 50.0
	decay.arnold_node_far_end = 250.0
	join allLights #(m1, e1)

	local middle = [(columns - 1) * cell / 2.0, -(rows - 1) * cell / 2.0, 0]
	local d2 = newLight "distant" 1 middle 1500.0 2.0
	d2.on = false
	local d3 = newLight "skydome" 6 middle 1500.0 1.0
	d3.on = false
	join allLights #(d2, d3)

	local roomParts = buildRoom cell wallHeight columns rows grey
	for i = 1 to titles.count do
	(
		append roomParts (Sphere name:("ATlight_sphere" + i as string) radius:30 pos:(c[i] + [60, 60, 30]) material:grey)
		append roomParts (buildLabel titles[i] c[i] cell dark)
	)
	append roomParts emitter

	local cam = Targetcamera name:"ATlight_camera" fov:45 pos:(middle + [0, -1, 2600]) target:(Targetobject name:"ATlight_camera_target" pos:middle)
	onLayer "ATlight lights" allLights
	onLayer "ATlight geometry" roomParts
	onLayer "ATlight camera" #(cam, cam.target)

	renderWidth = 1500
	renderHeight = 900
	viewport.setCamera cam
	SceneExposureControl.exposureControl = undefined
	renderers.production = Arnold()
	renderers.production.render_device = 1
	redrawViews()
	format "LightConverter scene: % lights in % cells. Renderer %, exposure control off.\n" allLights.count titles.count (classOf renderers.production)
)
