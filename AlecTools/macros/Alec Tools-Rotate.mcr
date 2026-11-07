macroScript Rotate
category:"Alec Tools"
toolTip:"Rotate - type a rotation at the mouse: a field per axis in degrees, Tab goes to the next one (15+30 works), the selection turns live about Max's Use Center; Enter or a left click in a viewport accepts, a right click or the shortcut again cancels"
buttonText:"Rotate"
(
	on execute do AlecTools_switchTool "Rotate" "grab.ms" "AlecGrab_run #rotate"
)
