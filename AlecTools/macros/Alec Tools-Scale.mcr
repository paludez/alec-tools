macroScript Scale
category:"Alec Tools"
toolTip:"Scale - type a scale at the mouse in percent: starts on XYZ, Tab goes to X, Y, Z and back; the selection scales live about Max's Use Center; Enter or a left click in a viewport accepts, a right click or the shortcut again cancels"
buttonText:"Scale"
(
	on execute do AlecTools_switchTool "Scale" "grab.ms" "AlecGrab_run #scale"
)
