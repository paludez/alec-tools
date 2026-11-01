macroScript Grab
category:"Alec Tools"
toolTip:"Grab - type a move at the mouse: X, Y or Z for the axis, then the distance (15+28 works), the selection moves live; Enter or right click accepts, Esc cancels"
buttonText:"Grab"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/grab.ms")
		execute "AlecGrab_run #move"
	)
)
