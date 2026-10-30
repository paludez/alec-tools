macroScript BmpConverter
	category:"Alec Tools"
	toolTip:"Bmp Converter"
	buttonText:"Bmp Converter"
(
	try(destroyDialog roll_ImageConverter) catch()

	rollout roll_ImageConverter "Universal Image Map Converter v3.8" width:360 height:340
	(
	    group "1. Conversion Mode"
	    (
	        radiobuttons rdo_mode "" labels:#("Bitmaptexture  -->  VRayBitmap", "VRayBitmap  -->  Bitmaptexture") default:1 columns:1
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

	    on rdo_mode changed state do lbl_info.text = "Status: Ready"
	    on rdo_scope changed state do lbl_info.text = "Status: Ready"

	    fn collectMaps node sourceType arr vis =
	    (
	        if node == undefined then return()
	        if findItem vis node > 0 then return()
	        append vis node
	        if isKindOf node sourceType do appendIfUnique arr node
	        local n = node.numSubs
	        if n != undefined and n > 0 do
	        (
	            for i = 1 to n do
	            (
	                try
	                (
	                    local sub = node[i]
	                    if sub != undefined and (isKindOf sub TextureMap or isKindOf sub Mtl) do
	                        collectMaps sub sourceType arr vis
	                ) catch()
	            )
	        )
	    )

	    fn getSMESelectedMaps =
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
	                    if n.reference != undefined and isKindOf n.reference TextureMap do
	                        appendIfUnique selMaps n.reference
	                )
	            )
	        )
	        selMaps
	    )

	    fn getTargetMaps sourceType scopeMode =
	    (
	        local rawMaps = #()
	        local visited = #()
	        
	        case scopeMode of
	        (
	            1:
	            (
	                for mat in sceneMaterials do
	                    collectMaps mat sourceType rawMaps visited
	                if environmentMap != undefined do
	                    collectMaps environmentMap sourceType rawMaps visited
	                for lgt in lights do
	                (
	                    for p in (getPropNames lgt) do
	                    (
	                        try
	                        (
	                            local val = getProperty lgt p
	                            if val != undefined and (isKindOf val TextureMap or isKindOf val Mtl) do
	                                collectMaps val sourceType rawMaps visited
	                        ) catch()
	                    )
	                )
	            )
	            2:
	            (
	                for obj in selection where obj.material != undefined do
	                    collectMaps obj.material sourceType rawMaps visited
	            )
	            3:
	            (
	                local smeMaps = getSMESelectedMaps()
	                for m in smeMaps where isKindOf m sourceType do
	                    appendIfUnique rawMaps m
	            )
	        )
	        
	        makeUniqueArray rawMaps
	    )

	    fn transferCommonParams srcMap tgtMap =
	    (
	        -- Name
	        if isProperty srcMap #name and srcMap.name != undefined do tgtMap.name = srcMap.name
	        
	        -- Coordinates
	        if srcMap.coords != undefined do try(tgtMap.coords = copy srcMap.coords) catch()
	        
	        -- Output: copy pentru curba, apoi explicit pentru restul
	        if srcMap.output != undefined do
	        (
	            try(tgtMap.output = copy srcMap.output) catch()
	            try(tgtMap.output.invert = srcMap.output.invert) catch()
	            try(tgtMap.output.output_amount = srcMap.output.output_amount) catch()
	            try(tgtMap.output.rgb_level = srcMap.output.rgb_level) catch()
	            try(tgtMap.output.rgb_offset = srcMap.output.rgb_offset) catch()
	            try(tgtMap.output.clamp = srcMap.output.clamp) catch()
	            try(tgtMap.output.bump_amount = srcMap.output.bump_amount) catch()
	            try(tgtMap.output.alphaFromRGB = srcMap.output.alphaFromRGB) catch()
	            try(tgtMap.output.enableColorMap = srcMap.output.enableColorMap) catch()
	        )
	    )

	    fn convertStdToVRay srcMap =
	    (
	        local newMap = VRayBitmap()
	        newMap.HDRIMapName = srcMap.filename
	        if isProperty newMap #mapType do newMap.mapType = 4
	        transferCommonParams srcMap newMap
	        if isProperty srcMap #alphaSource and isProperty newMap #alphaSource do newMap.alphaSource = srcMap.alphaSource
	        if isProperty srcMap #apply do newMap.cropplace_on = srcMap.apply
	        if isProperty srcMap #cropPlace do newMap.cropplace_mode = srcMap.cropPlace
	        if isProperty srcMap #clipu do newMap.cropplace_u = srcMap.clipu
	        if isProperty srcMap #clipv do newMap.cropplace_v = srcMap.clipv
	        if isProperty srcMap #clipw do newMap.cropplace_width = srcMap.clipw
	        if isProperty srcMap #cliph do newMap.cropplace_height = srcMap.cliph
	        newMap
	    )

	    fn convertVRayToStd srcMap =
	    (
	        local newMap = Bitmaptexture()
	        newMap.filename = srcMap.HDRIMapName
	        transferCommonParams srcMap newMap
	        if isProperty srcMap #alphaSource and isProperty newMap #alphaSource do newMap.alphaSource = srcMap.alphaSource
	        if isProperty srcMap #mapType do
	        (
	            if srcMap.mapType != 4 do
	            (
	                if newMap.coords != undefined do
	                (
	                    newMap.coords.mappingType = 1
	                    case srcMap.mapType of
	                    (
	                        2: newMap.coords.mapping = 0
	                        0: newMap.coords.mapping = 0
	                        1: newMap.coords.mapping = 0
	                        3: newMap.coords.mapping = 0
	                        5: newMap.coords.mapping = 1
	                        6: newMap.coords.mapping = 3
	                        default: newMap.coords.mapping = 0
	                    )
	                )
	            )
	        )
	        if isProperty srcMap #cropplace_on do newMap.apply = srcMap.cropplace_on
	        if isProperty srcMap #cropplace_mode do newMap.cropPlace = srcMap.cropplace_mode
	        if isProperty srcMap #cropplace_u do newMap.clipu = srcMap.cropplace_u
	        if isProperty srcMap #cropplace_v do newMap.clipv = srcMap.cropplace_v
	        if isProperty srcMap #cropplace_width do newMap.clipw = srcMap.cropplace_width
	        if isProperty srcMap #cropplace_height do newMap.cliph = srcMap.cropplace_height
	        newMap
	    )

	    on btn_convert pressed do
	    (
	        lbl_info.text = "Status: Processing..."
	        local mode = rdo_mode.state
	        local scope = rdo_scope.state
	        local sourceClass = if mode == 1 then Bitmaptexture else VRayBitmap
	        
	        if scope == 3 and not (sme.IsOpen()) do
	        (
	            lbl_info.text = "Status: SME not open."
	            return false
	        )

	        local targetMaps = getTargetMaps sourceClass scope
	        
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
	                    local newMap = if mode == 1 then convertStdToVRay oldMap else convertVRayToStd oldMap
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
