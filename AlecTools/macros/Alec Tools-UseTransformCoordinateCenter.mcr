macroScript UseTransformCoordinateCenter
category:"Alec Tools"
toolTip:"Use Transform Coordinate Center"
buttonText:"Use Transform Coordinate Center"
iconName:":/Icons/MainUI/UseTransformCoordinateCenter_24.png"
(
	on isChecked do getCoordCenter() == #system
	on execute do setCoordCenter #system
)
