macroScript UsePivotPointCenter
category:"Alec Tools"
toolTip:"Use Pivot Point Center"
buttonText:"Use Pivot Point Center"
iconName:":/Icons/MainUI/UsePivotPointCenter_24.png"
(
	on isChecked do getCoordCenter() == #local
	on execute do setCoordCenter #local
)
