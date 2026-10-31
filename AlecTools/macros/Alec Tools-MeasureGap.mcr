macroScript MeasureGap
category:"Alec Tools"
toolTip:"Measure Gap - click a reference object, move over another to see the space between them; right click ends and clears"
buttonText:"Measure Gap"
iconName:":/Icons/UVWUnwrapDialog/SpaceHorizontal_24.png"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/measureGap.ms")
		execute "AlecGap_run()"
	)
)
