macroScript BBox
category:"Alec Tools"
toolTip:"BBox - box cages around the selection. opens a caddy with a live preview; Enter or left click = OK, right click = Cancel"
buttonText:"BBox"
iconName:":/Icons/BlendedBoxMap/BoundingBox_24.png"
(
	on execute do AlecTools_toggleTool "BBox" "bbox.ms" "AlecBBox_run()"
)
