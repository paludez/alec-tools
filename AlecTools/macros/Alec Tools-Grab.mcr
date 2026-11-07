macroScript Grab
category:"Alec Tools"
toolTip:"Grab - type a move at the mouse: a field per axis, Tab goes to the next one (15+28 works), the selection moves live; Enter or a left click in a viewport accepts, a right click or the shortcut again cancels"
buttonText:"Grab"
(
	on execute do AlecTools_switchTool "Grab" "grab.ms" "AlecGrab_run #move"
)
