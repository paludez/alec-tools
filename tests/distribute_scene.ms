-- Scene for trying Distribute by hand. Run in Max (in a scene you do not mind changing, it does not save anything):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\distribute_scene.ms"
-- Every set sits on its own layer "ATdist_*": select a layer's objects, press Distribute.
-- Running it again replaces the old set. To remove everything:
--   delete $ATdist_*; for n in #("ATdist_1 row", "ATdist_2 local", "ATdist_3 blend", "ATdist_4 mixed") do LayerManager.deleteLayerByName n

(
	delete (for o in objects where matchPattern o.name pattern:"ATdist_*" collect o)

	fn onLayer nm nodes =
	(
		local lay = LayerManager.getLayerFromName nm
		if lay == undefined do lay = LayerManager.newLayerFromName nm
		for n in nodes do lay.addNode n
	)

	-- 1. a row along X: different widths, uneven spacing, scattered in Y and Z (Positions, Gaps, references, align on Y/Z)
	local row = #(
		box name:"ATdist_row_a" width:20 length:20 height:20 pos:[0,0,0] wirecolor:red,
		box name:"ATdist_row_b" width:60 length:20 height:40 pos:[45,30,15] wirecolor:orange,
		cylinder name:"ATdist_row_c" radius:15 height:50 pos:[150,-25,0] wirecolor:yellow,
		box name:"ATdist_row_d" width:10 length:40 height:10 pos:[190,10,30] wirecolor:green,
		sphere name:"ATdist_row_e" radius:25 pos:[320,-10,25] wirecolor:blue)
	onLayer "ATdist_1 row" row

	-- 2. a row turned 30 degrees around Z, plus a box turned 45 to pick as anchor (Local: pick a box of the row or the 45 one as anchor; without one Local uses the world)
	local turned = #()
	for i = 0 to 4 do
	(
		local b = box name:("ATdist_local_" + (i + 1) as string) width:(15 + i * 8) length:15 height:15 wirecolor:(color 120 (60 + i * 40) 220)
		b.transform = (rotateZMatrix 30) * (transMatrix ([i * 40 + i * i * 6, 0, 0] * (rotateZMatrix 30) + [0, 250, 0]))
		append turned b
	)
	local anchorBox = box name:"ATdist_local_anchor45" width:30 length:30 height:30 wirecolor:white
	anchorBox.transform = (rotateZMatrix 45) * (transMatrix [100, 340, 0])
	append turned anchorBox
	onLayer "ATdist_2 local" turned

	-- 3. rotations: the first straight, the last turned 90 on Z and tipped 30 on X, the ones between at random angles, one scaled (Blend, anchor = the first or the middle)
	local blendSet = #()
	for i = 0 to 5 do
	(
		local t = teapot name:("ATdist_blend_" + (i + 1) as string) radius:10 wirecolor:(color (40 * i) 200 (240 - 40 * i))
		t.pos = [i * 50 + random -10 10, 500, 0]
		if i > 0 and i < 5 do rotate t (eulerAngles (random -40 40) (random -40 40) (random -90 90))
		append blendSet t
	)
	rotate blendSet[6] (eulerAngles 30 0 90)
	blendSet[3].scale = [1.5, 1, 1]
	onLayer "ATdist_3 blend" blendSet

	-- 4. mixed: a closed group, a bent box (bounds from the modifier), a parent with a child, a point helper, an omni light, a target camera (target skipped)
	local g1 = box name:"ATdist_mix_grpA" width:20 length:20 height:20 pos:[0,750,0] wirecolor:brown
	local g2 = box name:"ATdist_mix_grpB" width:20 length:20 height:40 pos:[40,750,0] wirecolor:brown
	local grp = group #(g1, g2) name:"ATdist_mix_group"
	local bent = box name:"ATdist_mix_bent" width:10 length:10 height:80 heightsegs:20 pos:[130,760,0] wirecolor:gray
	addModifier bent (Bend angle:90 direction:0)
	local parent = box name:"ATdist_mix_parent" width:20 length:20 height:20 pos:[220,740,0] wirecolor:green
	local child = sphere name:"ATdist_mix_child" radius:8 pos:[220,740,40] wirecolor:green
	child.parent = parent
	local pt = Point name:"ATdist_mix_point" size:20 pos:[300,770,10] wirecolor:yellow
	local lt = Omnilight name:"ATdist_mix_light" pos:[350,730,50]
	local cam = Targetcamera name:"ATdist_mix_camera" pos:[420,700,60] target:(Targetobject name:"ATdist_mix_camera_target" pos:[420,800,0])
	onLayer "ATdist_4 mixed" #(grp, g1, g2, bent, parent, child, pt, lt, cam, cam.target)

	clearSelection()
	max tool zoomextents all
	format "distribute scene: 4 sets on the ATdist_* layers\n"
)
