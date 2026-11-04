macroScript Rotate
category:"Alec Tools"
toolTip:"Rotate - type a rotation at the mouse: a field per axis in degrees, Tab goes to the next one (15+30 works), the selection turns live about Max's Use Center; Enter or right click accepts, a click elsewhere or the shortcut again cancels"
buttonText:"Rotate"
(
	on execute do
	(
		if not (AlecTools_closeIfOpen "Rotate") do
		(
			fileIn (AlecTools_path "tools/grab.ms")
			execute "AlecGrab_run #rotate"
		)
	)
)
