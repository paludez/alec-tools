macroScript Scale
category:"Alec Tools"
toolTip:"Scale - type a scale at the mouse in percent: all three axes, or X, Y or Z for one (the same key again: all three); the selection scales live about Max's Use Center; Enter or right click accepts, Esc cancels"
buttonText:"Scale"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/grab.ms")
		execute "AlecGrab_run #scale"
	)
)
