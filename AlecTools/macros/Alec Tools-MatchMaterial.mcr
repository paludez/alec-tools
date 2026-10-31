macroScript MatchMaterial
category:"Alec Tools"
toolTip:"Match Material"
buttonText:"Match Material"
iconName:":/Icons/MaterialEditor/PickMaterialFromObject_24.png"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/matchMaterial.ms")
		execute "AlecMatchMat_execute()"
	)
)
