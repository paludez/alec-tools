macroScript BBox
category:"Alec Tools"
toolTip:"BBox - box cages around the selection. Click: apply with the last settings, Shift+Click or toolbar right click: caddy with preview and OK"
buttonText:"BBox"
iconName:":/Icons/BlendedBoxMap/BoundingBox_24.png"
(
	on execute do AlecTools_runCaddyTool "BBox" "bbox.ms" "AlecBBox_run"
)
