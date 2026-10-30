macroScript ReloadAlecTools
category:"Alec Tools"
toolTip:"Reload Alec Tools"
buttonText:"Reload Alec Tools"
(
	on execute do
	(
		fileIn (AlecTools_root + "/core/AlecTools_core.ms")
		execute "AlecTools_reload()"
	)
)
