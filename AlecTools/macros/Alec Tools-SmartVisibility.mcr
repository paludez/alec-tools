macroScript SmartHide
category:"Alec Tools"
toolTip:"Smart Hide"
buttonText:"Smart Hide"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/smartVisibility.ms")
		execute "AlecSmartVis_execute #hide"
	)
)

macroScript SmartHideUnselected
category:"Alec Tools"
toolTip:"Smart Hide Unsel"
buttonText:"Smart Hide Unsel"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/smartVisibility.ms")
		execute "AlecSmartVis_execute #hideUnselected"
	)
)

macroScript SmartUnhideAll
category:"Alec Tools"
toolTip:"Smart Unhide"
buttonText:"Smart Unhide"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/smartVisibility.ms")
		execute "AlecSmartVis_execute #unhideAll"
	)
)
