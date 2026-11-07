macroScript MeasureAngle
category:"Alec Tools"
toolTip:"Measure Angle - 4 points for 2 lines (Ctrl: angle in World XY), the angle follows the mouse; right click ends and clears. Shift+Click or toolbar right click: caddy (edges, faces, planes)"
buttonText:"Measure Angle"
iconName:":/Icons/MainUI/Protractor_24.png"
(
	on execute do AlecTools_runCaddyTool "MeasureAngle" "measureAngle.ms" "AlecMeasureAngle_run"
)
