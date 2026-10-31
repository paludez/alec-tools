macroScript Measure
category:"Alec Tools"
toolTip:"Measure - click points with snaps, see each length and the total; right click ends and clears"
buttonText:"Measure"
iconName:":/Icons/Extras/MeasureDistance_24.png"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/measure.ms")
		execute "AlecMeasure_run()"
	)
)
