macroScript MeasureAngle
category:"Alec Tools"
toolTip:"Measure Angle - 4 points for 2 lines (Ctrl: angle in World XY), the angle follows the mouse; right click ends and clears. Shift + click: dialog (edges, faces, planes)"
buttonText:"Measure Angle"
iconName:":/Icons/MainUI/Protractor_24.png"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/measureAngle.ms")
		if keyboard.shiftPressed then
		(
			fileIn (AlecTools_path "tools/measureAngleDialog.ms")
			execute "AlecAngle_openDialog()"
		)
		else execute "AlecAngle_run()"
	)
)
