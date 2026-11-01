macroScript MeasureAngle
category:"Alec Tools"
toolTip:"Measure Angle - 4 points for 2 lines (Ctrl: angle in World XY), the angle follows the mouse; right click ends and clears. Shift + click or toolbar right click: caddy (edges, faces, planes)"
buttonText:"Measure Angle"
iconName:":/Icons/MainUI/Protractor_24.png"
(
	on execute do
	(
		-- Shift (or a toolbar right click) is read first, before the files load
		if AlecTools_wantsOptions() then python.ExecuteFile (AlecTools_path "tools/measureAngleCaddy.py")
		else
		(
			fileIn (AlecTools_path "tools/measureAngle.ms")
			execute "AlecAngle_run()"
		)
	)
)
