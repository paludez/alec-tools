macroScript SME_GetFromSelection
category:"Alec Tools"
toolTip:"Get Materials"
buttonText:"Get Materials"
iconName:":/Icons/MaterialEditor/GetMaterial_24.png"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/getMaterials.ms")
		execute "AlecGetMaterials_execute()"
	)
)
