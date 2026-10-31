macroScript MeasureBBox
category:"Alec Tools"
toolTip:"Measure BBox - move over objects to see their box and sizes, click keeps one; right click ends and clears"
buttonText:"Measure BBox"
iconName:":/Icons/SnapPivot/reorientBoundingBox_24.png"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/measureBBox.ms")
		execute "AlecMBox_run()"
	)
)
