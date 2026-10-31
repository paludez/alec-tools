macroScript MidBetween
category:"Alec Tools"
toolTip:"Mid Between - pick points, right click to finish. Click: apply, Shift+Click: caddy with settings and OK"
buttonText:"Mid Between"
iconName:":/Icons/SnapTools/MaxSDK/Xmesh/Midpoint_24.png"
(
	on execute do
	(
		-- Shift is read first, before anything else runs; Ctrl and Alt never reach a toolbar button
		local showCaddy = keyboard.shiftPressed
		fileIn (AlecTools_path "tools/midBetween.ms")
		execute ("AlecMid_execute showCaddy:" + (showCaddy as string))
	)
)
