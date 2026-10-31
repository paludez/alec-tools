macroScript ReloadAlecTools
category:"Alec Tools"
toolTip:"Reload Alec Tools"
buttonText:"Reload Alec Tools"
iconName:":/Icons/RenderFrameWindow/Reload_24.png"
(
	on execute do
	(
		if AlecTools_root == undefined then
			messageBox "Alec Tools root folder is not set. Restart Max, or check AlecTools.root.txt in the user scripts folder." title:"Alec Tools"
		else
		(
			fileIn (AlecTools_root + "/core/AlecTools_core.ms")
			execute "AlecTools_reload()"
		)
	)
)
