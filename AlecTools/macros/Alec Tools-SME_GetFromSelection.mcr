macroScript SME_GetFromSelection
category:"Alec Tools"
toolTip:"Get Materials"
buttonText:"Get Materials"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/getMaterials.ms")
		execute "AlecGetMaterials_execute()"
	)
)
