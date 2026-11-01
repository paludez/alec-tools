macroScript Rotate
category:"Alec Tools"
toolTip:"Rotate - type a rotation at the mouse: X, Y or Z for the axis, then the angle in degrees (15+30 works), the selection turns live about Max's Use Center; Enter or right click accepts, Esc cancels"
buttonText:"Rotate"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/grab.ms")
		execute "AlecGrab_run #rotate"
	)
)
