macroScript BBox
category:"Alec Tools"
toolTip:"BBox - box cages around the selection. Click: apply with the last settings, Shift+Click or toolbar right click: caddy with preview and OK"
buttonText:"BBox"
iconName:":/Icons/BlendedBoxMap/BoundingBox_24.png"
(
	on execute do
	(
		-- Shift (or a toolbar right click) is read first, before the file loads
		local showCaddy = AlecTools_wantsOptions()
		fileIn (AlecTools_path "tools/bbox.ms")
		execute ("AlecBBox_run showCaddy:" + (showCaddy as string))
	)
)
