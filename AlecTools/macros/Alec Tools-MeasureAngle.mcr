macroScript MeasureAngle
category:"Alec Tools"
toolTip:"Measure Angle - 4 points for 2 lines (Ctrl: plane on/off) with a caddy (points, edges, faces, planes); the angle follows the mouse, right click or Enter ends"
buttonText:"Measure Angle"
iconName:":/Icons/MainUI/Protractor_24.png"
(
	on execute do AlecTools_toggleTool "MeasureAngle" "measureAngle.ms" "AlecMeasureAngle_run()"
)
