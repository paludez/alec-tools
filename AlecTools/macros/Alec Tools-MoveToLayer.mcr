macroScript MoveToLayer
category:"Alec Tools"
toolTip:"Move to Layer"
buttonText:"Move to Layer"
iconName:":/Icons/Layers/AddSelectionToCurrentLayer_24.png"
(
	on execute do
	(
		fileIn (AlecTools_path "tools/moveToLayer.ms")
		python.ExecuteFile (AlecTools_path "tools/moveToLayer.py")
	)
)
