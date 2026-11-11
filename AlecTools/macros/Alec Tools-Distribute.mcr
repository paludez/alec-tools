macroScript Distribute
category:"Alec Tools"
toolTip:"Distribute - spread the selection along an axis. opens a caddy with a live preview; Enter or left click = OK, right click or Esc = Cancel"
buttonText:"Distribute"
iconName:":/Icons/MainUI/SpacingTool_24.png"
(
	on execute do AlecTools_toggleTool "Distribute" "distribute.ms" "AlecDistribute_run()"
)
