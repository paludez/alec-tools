macroScript MidBetween
category:"Alec Tools"
toolTip:"Mid Between - move the selection's center to the middle of picked points (object pivots or snap points). Left click picks, Enter moves, right click or this button again cancels"
buttonText:"Mid Between"
iconName:":/Icons/SnapTools/MaxSDK/Xmesh/Midpoint_24.png"
(
	on execute do AlecTools_toggleTool "MidBetween" "midBetween.ms" "AlecMidBetween_run()"
)