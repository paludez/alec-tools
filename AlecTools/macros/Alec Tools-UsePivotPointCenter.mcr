macroScript UsePivotPointCenter
category:"Alec Tools"
toolTip:"Use Pivot Point Center"
buttonText:"Use Pivot Point Center"
(
	on isChecked do getCoordCenter() == #local
	on execute do setCoordCenter #local
)
