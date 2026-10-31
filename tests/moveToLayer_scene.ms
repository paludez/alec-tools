-- Scene for trying Move to Layer by hand. Run in Max (in a scene you do not mind changing, it does not save anything):
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\moveToLayer_scene.ms"
-- Builds a layer tree "ATml_*" three levels deep, layers that are hidden / frozen / not renderable / empty,
-- 30 extra layers to scroll through, a closed group and loose boxes "ATml_move_*" in layer 0 to move around.
-- Running it again replaces the old set. Running only the cleanup part (the first two lines in the block) removes everything.

(
	delete (for o in objects where matchPattern o.name pattern:"ATml_*" collect o)
	-- a layer with sublayers or objects cannot be deleted, so the deepest go first: repeat until none is left
	for pass = 1 to 5 do
		for i = LayerManager.count - 1 to 1 by -1 do
		(
			local lay = LayerManager.getLayer i
			if matchPattern lay.name pattern:"ATml_*" do LayerManager.deleteLayerByName lay.name
		)

	fn makeLayer nm parent col =
	(
		local lay = LayerManager.newLayerFromName nm
		lay.wireColor = col
		if parent != undefined do lay.setParent parent
		lay
	)

	fn fill lay nm count x y col =
	(
		for i = 1 to count do lay.addNode (box name:(nm + "_" + i as string) width:20 length:20 height:20 pos:[x + i * 30, y, 0] wirecolor:col)
	)

	-- a tree three levels deep
	local arch = makeLayer "ATml_Arhitectura" undefined (color 200 200 200)
	local walls = makeLayer "ATml_Pereti" arch (color 220 120 60)
	local windows = makeLayer "ATml_Ferestre" arch (color 80 160 230)
	local frames = makeLayer "ATml_Rame" windows (color 60 90 160)
	fill walls "ATml_perete" 3 0 0 (color 220 120 60)
	fill windows "ATml_fereastra" 2 0 40 (color 80 160 230)
	fill frames "ATml_rama" 2 0 80 (color 60 90 160)

	local furniture = makeLayer "ATml_Mobilier" undefined (color 150 100 60)
	local chairs = makeLayer "ATml_Scaune" furniture (color 190 140 80)
	local tables = makeLayer "ATml_Mese" furniture (color 120 70 40)
	fill chairs "ATml_scaun" 4 0 160 (color 190 140 80)
	local legPos = #([200, 160, 0], [260, 160, 0], [200, 200, 0], [260, 200, 0])
	local legs = for i = 1 to 4 collect cylinder name:("ATml_picior_" + i as string) radius:3 height:70 pos:legPos[i] wirecolor:(color 120 70 40)
	local top = box name:"ATml_blat" width:80 length:60 height:4 pos:[230, 180, 70] wirecolor:(color 120 70 40)
	append legs top
	for n in legs do tables.addNode n
	tables.addNode (group legs name:"ATml_masa")

	-- the three states, one layer each, plus an empty layer
	local hiddenLay = makeLayer "ATml_Ascuns" undefined (color 120 120 120)
	fill hiddenLay "ATml_ascuns" 2 0 240 (color 120 120 120)
	hiddenLay.isHidden = true
	local frozenLay = makeLayer "ATml_Inghetat" undefined (color 140 200 240)
	fill frozenLay "ATml_inghetat" 2 0 280 (color 140 200 240)
	frozenLay.isFrozen = true
	local noRenderLay = makeLayer "ATml_NuRandeaza" undefined (color 230 90 90)
	fill noRenderLay "ATml_nurandeaza" 2 0 320 (color 230 90 90)
	noRenderLay.renderable = false
	makeLayer "ATml_Gol" undefined (color 255 255 0)

	-- enough layers to scroll
	for i = 1 to 30 do makeLayer ("ATml_Extra_" + (formattedPrint i format:"02d")) undefined (color (i * 8) 180 (255 - i * 8))

	-- loose boxes in layer 0, to move around
	local layer0 = LayerManager.getLayer 0
	fill layer0 "ATml_move" 5 0 -60 (color 255 255 255)

	layer0.current = true
	select (for o in objects where matchPattern o.name pattern:"ATml_move_*" collect o)
	format "moveToLayer_scene: % layers, % objects; the ATml_move_* boxes are selected\n" \
		(for i = 0 to LayerManager.count - 1 where matchPattern (LayerManager.getLayer i).name pattern:"ATml_*" collect i).count \
		(for o in objects where matchPattern o.name pattern:"ATml_*" collect o).count
)
