macroScript UseTransformCoordinateCenter
category:"Alec Tools"
toolTip:"Use Transform Coordinate Center"
buttonText:"Use Transform Coordinate Center"
(
	on isChecked do getCoordCenter() == #system
	on execute do setCoordCenter #system
)
