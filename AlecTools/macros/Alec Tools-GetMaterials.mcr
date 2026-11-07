macroScript SME_GetFromSelection
category:"Alec Tools"
toolTip:"Get Materials"
buttonText:"Get Materials"
iconName:":/Icons/MaterialEditor/GetMaterial_24.png"
(
	on execute do
	(
		AlecTools_runTool "getMaterials.ms" "AlecGetMaterials_run()"
	)
)
