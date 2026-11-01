macroScript Distribute
category:"Alec Tools"
toolTip:"Distribute - spread the selection along an axis. Click: apply with the last settings, Shift+Click or toolbar right click: caddy with preview and OK"
buttonText:"Distribute"
iconName:":/Icons/MainUI/SpacingTool_24.png"
(
	on execute do
	(
		-- Shift (or a toolbar right click) is read first, before the file loads
		local showCaddy = AlecTools_wantsOptions()
		fileIn (AlecTools_path "tools/distribute.ms")
		execute ("AlecDist_run showCaddy:" + (showCaddy as string))
	)
)
