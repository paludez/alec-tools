macroScript UniversalConverter
category:"Alec Tools"
toolTip:"UniversalConverter - materials to VRayMtl, OpenPBR or Standard. Click: convert with the last settings, Shift+Click or toolbar right click: caddy"
buttonText:"Converter"
(
	on execute do
	(
		-- Shift (or a toolbar right click) is read first, before the file loads
		local showCaddy = AlecTools_wantsOptions()
		fileIn (AlecTools_path "tools/universalConverter.ms")
		execute ("AlecConv_run showCaddy:" + (showCaddy as string))
	)
)
