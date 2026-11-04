macroScript Grab
category:"Alec Tools"
toolTip:"Grab - type a move at the mouse: a field per axis, Tab goes to the next one (15+28 works), the selection moves live; Enter or right click accepts, a click elsewhere or the shortcut again cancels"
buttonText:"Grab"
(
	on execute do
	(
		if not (AlecTools_closeIfOpen "Grab") do
		(
			fileIn (AlecTools_path "tools/grab.ms")
			execute "AlecGrab_run #move"
		)
	)
)
