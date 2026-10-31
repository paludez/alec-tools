macroScript BBox
category:"Alec Tools"
toolTip:"BBox - box cages around the selection, caddy with preview and OK"
buttonText:"BBox"
iconName:":/Icons/BlendedBoxMap/BoundingBox_24.png"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/bbox.ms")
		execute "AlecBBox_run()"
	)
)
