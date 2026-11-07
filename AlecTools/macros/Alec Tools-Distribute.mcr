macroScript Distribute
category:"Alec Tools"
toolTip:"Distribute - spread the selection along an axis. Click: apply with the last settings, Shift+Click or toolbar right click: caddy with preview and OK"
buttonText:"Distribute"
iconName:":/Icons/MainUI/SpacingTool_24.png"
(
	on execute do AlecTools_runCaddyTool "Distribute" "distribute.ms" "AlecDistribute_run"
)
