macroScript SmartHide
category:"Alec Tools"
toolTip:"Smart Hide"
buttonText:"Smart Hide"
iconName:":/Icons/Common/Toggle/Visible_off_24.png"
(
	on execute do
	(
		AlecTools_runTool "smartVisibility.ms" "AlecSmartVis_run #hide"
	)
)

macroScript SmartHideUnselected
category:"Alec Tools"
toolTip:"Smart Hide Unsel"
buttonText:"Smart Hide Unsel"
iconName:":/Icons/MainUI/HideNonselectedCurves_24.png"
(
	on execute do
	(
		AlecTools_runTool "smartVisibility.ms" "AlecSmartVis_run #hideUnselected"
	)
)

macroScript SmartUnhideAll
category:"Alec Tools"
toolTip:"Smart Unhide"
buttonText:"Smart Unhide"
iconName:":/Icons/Common/Toggle/Visible_on_24.png"
(
	on execute do
	(
		AlecTools_runTool "smartVisibility.ms" "AlecSmartVis_run #unhideAll"
	)
)
