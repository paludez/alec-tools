macroScript Scale
category:"Alec Tools"
toolTip:"Scale - type a scale at the mouse in percent: starts on XYZ, Tab goes to X, Y, Z and back; the selection scales live about Max's Use Center; Enter or right click accepts, a click elsewhere or the shortcut again cancels"
buttonText:"Scale"
(
	on execute do
	(
		if not (AlecTools_closeIfOpen "Scale") do
		(
			fileIn (AlecTools_path "tools/grab.ms")
			execute "AlecGrab_run #scale"
		)
	)
)
