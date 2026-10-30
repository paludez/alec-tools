macroScript ImageMapConverter
category:"Alec Tools"
toolTip:"Img Converter"
buttonText:"Img Converter"
(
    on execute do
    (
		try(destroyDialog roll_ImageConverter) catch()

		rollout roll_ImageConverter "Universal Image Map Converter v4.1" width:360 height:370
		(
			group "1. Conversion Mode"
			(
				label lbl_from "Convert From:" align:#left offset:[0,2]
				dropdownlist ddl_from "" items:#("Bitmaptexture (Standard)", "VRayBitmap", "OSL UberBitmap") selection:2 width:320
				
				label lbl_to "Convert To:" align:#left offset:[0,5]
				dropdownlist ddl_to "" items:#("Bitmaptexture (Standard)", "VRayBitmap", "OSL UberBitmap") selection:3 width:320
			)
			
			group "2. Target Scope"
			(
				radiobuttons rdo_scope "" labels:#("Entire Scene", "Selected Objects", "Selected SME Nodes") default:1 columns:1
			)

			group "3. Action"
			(
				button btn_convert "CONVERT MAPS" width:320 height:45
			)

			label lbl_info "Status: Ready" align:#left offset:[5,5]
			timer tmr_esc "" interval:100 active:false

			on roll_ImageConverter open do tmr_esc.active = true

			on tmr_esc tick do
			(
				if keyboard.escPressed do destroyDialog roll_ImageConverter
			)

			on roll_ImageConverter close do
			(
				tmr_esc.active = false
				gc light:true
			)

			on ddl_from selected idx do lbl_info.text = "Status: Ready"
			on ddl_to selected idx do lbl_info.text = "Status: Ready"
			on rdo_scope changed state do lbl_info.text = "Status: Ready"

			-- Verificare daca o mapa este OSL UberBitmap
			fn isUberBitmap m =
			(
				if m == undefined do return false
				local cName = (classOf m) as string
				if matchPattern cName pattern:"*UberBitmap*" ignoreCase:true do return true
				if isKindOf m OSLMap do
				(
					local p = try(m.OSLPath as string) catch("")
					local fn_str = try(filenameFromPath p) catch("")
					return (matchPattern fn_str pattern:"*UberBitmap*" ignoreCase:true)
				)
				false
			)

			-- Verificare tip de sursa
			fn matchesSource m typeIdx =
			(
				case typeIdx of
				(
					1: (isKindOf m Bitmaptexture)
					2: (isKindOf m VRayBitmap)
					3: (isUberBitmap m)
					default: false
				)
			)

			-- Creare instanta nativa OSL UberBitmap
			fn createUberBitmap =
			(
				local newMap = undefined
				
				-- 1. Incercam clasa wrapper nativa din 3ds Max
				if (try(isKindOf osl_UberBitmap MAXClass) catch(false)) then
				(
					newMap = osl_UberBitmap()
				)
				else if (try(isKindOf osl_UberBitmap2 MAXClass) catch(false)) then
				(
					newMap = osl_UberBitmap2()
				)
				else
				(
					-- 2. Cautam in clasele de texturi inregistrate
					for c in textureMap.classes where (matchPattern (c as string) pattern:"*UberBitmap*" ignoreCase:true) do
					(
						try (newMap = c(); exit) catch()
					)
				)
				
				-- 3. Fallback direct pe OSLMap daca nu a gasit clasa compilata
				if newMap == undefined do
				(
					local oslFile = (getdir #maxroot) + "OSL\\UberBitmap.osl"
					newMap = OSLMap()
					if doesFileExist oslFile then newMap.OSLPath = oslFile
					else newMap.OSLPath = "UberBitmap.osl"
					try(newMap.OSLAutoUpdate = true) catch()
				)
				
				newMap
			)

			-- Extragere si setare cale fisier universal
			fn getMapFilename m =
			(
				if isKindOf m Bitmaptexture then m.filename
				else if isKindOf m VRayBitmap then m.HDRIMapName
				else if isUberBitmap m then
				(
					if isProperty m #Filename then m.Filename
					else if isProperty m #filename then m.filename
					else ""
				)
				else ""
			)

			fn setMapFilename m filePath =
			(
				if filePath == undefined do filePath = ""
				if isKindOf m Bitmaptexture then m.filename = filePath
				else if isKindOf m VRayBitmap then m.HDRIMapName = filePath
				else if isUberBitmap m then
				(
					if isProperty m #Filename then m.Filename = filePath
					else if isProperty m #filename then m.filename = filePath
				)
			)

			-- Colectare recursiva mape
			fn collectMaps node srcType arr vis =
			(
				if node == undefined then return()
				if findItem vis node > 0 then return()
				append vis node
				if matchesSource node srcType do appendIfUnique arr node
				local n = node.numSubs
				if n != undefined and n > 0 do
				(
					for i = 1 to n do
					(
						try
						(
							local sub = node[i]
							if sub != undefined and (isKindOf sub TextureMap or isKindOf sub Mtl) do
								collectMaps sub srcType arr vis
						) catch()
					)
				)
			)

			fn getSMESelectedMaps srcType =
			(
				local selMaps = #()
				if sme.IsOpen() then
				(
					local activeViewIdx = sme.activeView
					if activeViewIdx > 0 do
					(
						local currentView = sme.GetView activeViewIdx
						local selNodes = currentView.GetSelectedNodes()
						for n in selNodes do
						(
							if n.reference != undefined do
							(
								if matchesSource n.reference srcType then
									appendIfUnique selMaps n.reference
								else if isKindOf n.reference Mtl or isKindOf n.reference TextureMap then
									collectMaps n.reference srcType selMaps #()
							)
						)
					)
				)
				selMaps
			)

			fn getTargetMaps srcType scopeMode =
			(
				local rawMaps = #()
				local visited = #()
				
				case scopeMode of
				(
					1:
					(
						for mat in sceneMaterials do
							collectMaps mat srcType rawMaps visited
						if environmentMap != undefined do
							collectMaps environmentMap srcType rawMaps visited
						for lgt in lights do
						(
							for p in (getPropNames lgt) do
							(
								try
								(
									local val = getProperty lgt p
									if val != undefined and (isKindOf val TextureMap or isKindOf val Mtl) do
										collectMaps val srcType rawMaps visited
								) catch()
							)
						)
					)
					2:
					(
						for obj in selection where obj.material != undefined do
							collectMaps obj.material srcType rawMaps visited
					)
					3:
					(
						rawMaps = getSMESelectedMaps srcType
					)
				)
				makeUniqueArray rawMaps
			)

			-- Structura pentru extragerea si aplicarea coordonatelor UV
			struct MapCoordsData
			(
				u_tiling = 1.0,
				v_tiling = 1.0,
				u_offset = 0.0,
				v_offset = 0.0,
				w_angle = 0.0,
				mapChannel = 1,
				hasCoords = false
			)

			fn extractCoords m =
			(
				local cd = MapCoordsData()
				if isProperty m #coords and m.coords != undefined then
				(
					cd.hasCoords = true
					cd.u_tiling = try(m.coords.U_Tiling) catch(1.0)
					cd.v_tiling = try(m.coords.V_Tiling) catch(1.0)
					cd.u_offset = try(m.coords.U_Offset) catch(0.0)
					cd.v_offset = try(m.coords.V_Offset) catch(0.0)
					cd.w_angle = try(m.coords.W_Angle) catch(0.0)
					cd.mapChannel = try(m.coords.mapChannel) catch(1)
				)
				else if isUberBitmap m then
				(
					cd.hasCoords = true
					if isProperty m #Tiling then
					(
						local t = m.Tiling
						if isKindOf t Point3 then (cd.u_tiling = t.x; cd.v_tiling = t.y)
					)
					else if isProperty m #Tiling_X do
					(
						cd.u_tiling = m.Tiling_X
						cd.v_tiling = m.Tiling_Y
					)
					
					if isProperty m #Offset then
					(
						local o = m.Offset
						if isKindOf o Point3 then (cd.u_offset = o.x; cd.v_offset = o.y)
					)
					else if isProperty m #Offset_X do
					(
						cd.u_offset = m.Offset_X
						cd.v_offset = m.Offset_Y
					)
					
					if isProperty m #Rotate do cd.w_angle = m.Rotate
					if isProperty m #UVSet do cd.mapChannel = m.UVSet
				)
				cd
			)

			fn applyCoords m cd =
			(
				if not cd.hasCoords do return ()
				if isProperty m #coords and m.coords != undefined then
				(
					try(m.coords.U_Tiling = cd.u_tiling) catch()
					try(m.coords.V_Tiling = cd.v_tiling) catch()
					try(m.coords.U_Offset = cd.u_offset) catch()
					try(m.coords.V_Offset = cd.v_offset) catch()
					try(m.coords.W_Angle = cd.w_angle) catch()
					try(m.coords.mapChannel = cd.mapChannel) catch()
				)
				else if isUberBitmap m then
				(
					try(m.Tiling = [cd.u_tiling, cd.v_tiling, 1.0]) catch
					(
						try(m.Tiling_X = cd.u_tiling; m.Tiling_Y = cd.v_tiling) catch()
					)
					try(m.Offset = [cd.u_offset, cd.v_offset, 0.0]) catch
					(
						try(m.Offset_X = cd.u_offset; m.Offset_Y = cd.v_offset) catch()
					)
					try(m.Rotate = cd.w_angle) catch()
					try(m.UVSet = cd.mapChannel) catch()
				)
			)

			-- Conversia unei singure mape
			fn convertMapInstance srcMap targetType =
			(
				local targetMap = undefined
				case targetType of
				(
					1: targetMap = Bitmaptexture()
					2: 
					(
						try (targetMap = VRayBitmap()) catch
						(
							messageBox "VRayBitmap is not available! Make sure V-Ray is installed." title:"Error"
							return undefined
						)
					)
					3: 
					(
						targetMap = createUberBitmap()
						if targetMap == undefined do
						(
							messageBox "Could not create OSL UberBitmap instance." title:"Error"
							return undefined
						)
					)
				)
				
				if targetMap == undefined do return undefined

				-- 1. Nume
				if isProperty srcMap #name and srcMap.name != undefined do targetMap.name = srcMap.name

				-- 2. Cale fisier
				local fPath = getMapFilename srcMap
				setMapFilename targetMap fPath

				-- 3. Coordonate
				if isProperty srcMap #coords and isProperty targetMap #coords and srcMap.coords != undefined then
				(
					try(targetMap.coords = copy srcMap.coords) catch()
				)
				else
				(
					local cd = extractCoords srcMap
					applyCoords targetMap cd
				)

				-- 4. Output (intre mape cu suport StandardTextureOutput)
				if isProperty srcMap #output and isProperty targetMap #output and srcMap.output != undefined do
				(
					try(targetMap.output = copy srcMap.output) catch()
					try(targetMap.output.invert = srcMap.output.invert) catch()
					try(targetMap.output.output_amount = srcMap.output.output_amount) catch()
					try(targetMap.output.rgb_level = srcMap.output.rgb_level) catch()
					try(targetMap.output.rgb_offset = srcMap.output.rgb_offset) catch()
					try(targetMap.output.clamp = srcMap.output.clamp) catch()
					try(targetMap.output.bump_amount = srcMap.output.bump_amount) catch()
					try(targetMap.output.alphaFromRGB = srcMap.output.alphaFromRGB) catch()
					try(targetMap.output.enableColorMap = srcMap.output.enableColorMap) catch()
				)

				-- 5. Setari specifice Bitmaptexture <--> VRayBitmap
				if isKindOf srcMap Bitmaptexture and isKindOf targetMap VRayBitmap do
				(
					if isProperty targetMap #mapType do targetMap.mapType = 4
					if isProperty srcMap #alphaSource and isProperty targetMap #alphaSource do targetMap.alphaSource = srcMap.alphaSource
					if isProperty srcMap #apply do targetMap.cropplace_on = srcMap.apply
					if isProperty srcMap #cropPlace do targetMap.cropplace_mode = srcMap.cropPlace
					if isProperty srcMap #clipu do targetMap.cropplace_u = srcMap.clipu
					if isProperty srcMap #clipv do targetMap.cropplace_v = srcMap.clipv
					if isProperty srcMap #clipw do targetMap.cropplace_width = srcMap.clipw
					if isProperty srcMap #cliph do targetMap.cropplace_height = srcMap.cliph
				)

				if isKindOf srcMap VRayBitmap and isKindOf targetMap Bitmaptexture do
				(
					if isProperty srcMap #alphaSource and isProperty targetMap #alphaSource do targetMap.alphaSource = srcMap.alphaSource
					if isProperty srcMap #mapType and srcMap.mapType != 4 do
					(
						if targetMap.coords != undefined do
						(
							targetMap.coords.mappingType = 1
							case srcMap.mapType of
							(
								2: targetMap.coords.mapping = 0
								0: targetMap.coords.mapping = 0
								1: targetMap.coords.mapping = 0
								3: targetMap.coords.mapping = 0
								5: targetMap.coords.mapping = 1
								6: targetMap.coords.mapping = 3
								default: targetMap.coords.mapping = 0
							)
						)
					)
					if isProperty srcMap #cropplace_on do targetMap.apply = srcMap.cropplace_on
					if isProperty srcMap #cropplace_mode do targetMap.cropPlace = srcMap.cropplace_mode
					if isProperty srcMap #cropplace_u do targetMap.clipu = srcMap.cropplace_u
					if isProperty srcMap #cropplace_v do targetMap.clipv = srcMap.cropplace_v
					if isProperty srcMap #cropplace_width do targetMap.clipw = srcMap.cropplace_width
					if isProperty srcMap #cropplace_height do targetMap.cliph = srcMap.cropplace_height
				)

				targetMap
			)

			on btn_convert pressed do
			(
				local srcType = ddl_from.selection
				local tgtType = ddl_to.selection
				local scope = rdo_scope.state

				if srcType == tgtType do
				(
					lbl_info.text = "Status: Source and Target are the same!"
					return false
				)

				if scope == 3 and not (sme.IsOpen()) do
				(
					lbl_info.text = "Status: SME not open."
					return false
				)

				lbl_info.text = "Status: Processing..."

				local targetMaps = getTargetMaps srcType scope
				
				if targetMaps.count == 0 then
				(
					lbl_info.text = "Status: No matching maps found."
				)
				else
				(
					undo "Convert Image Maps" on
					(
						local convertedCount = 0
						for oldMap in targetMaps do
						(
							local newMap = convertMapInstance oldMap tgtType
							if newMap != undefined do
							(
								replaceInstances oldMap newMap
								convertedCount += 1
							)
						)
						gc light:true
						lbl_info.text = ("Status: Converted " + (convertedCount as string) + " map(s).")
						format "\nConverted % map(s).\n" convertedCount
					)
				)
			)
		)

		createDialog roll_ImageConverter
	)
)