macroScript Distribute
category:"Alec Tools"
toolTip:"Distribute - spread the selection along an axis, caddy with preview and OK"
buttonText:"Distribute"
iconName:":/Icons/MainUI/SpacingTool_24.png"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/distribute.ms")
		execute "AlecDist_run()"
	)
)
