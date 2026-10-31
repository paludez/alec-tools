macroScript MeasureClearance
category:"Alec Tools"
toolTip:"Measure Clearance - move over a surface to see the distance to the next one along its normal; right click ends and clears"
buttonText:"Measure Clearance"
iconName:":/Icons/MainUI/NormalAlign_24.png"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/measureClearance.ms")
		execute "AlecClear_run()"
	)
)
