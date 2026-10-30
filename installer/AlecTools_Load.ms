-- Alec Tools startup loader. The only Alec Tools file that lives in Max's startup folder.
-- Root folder is resolved per machine:
--   1) <userScripts>/AlecTools.root.txt  (dev override: one line = path to the AlecTools folder)
--   2) <userScripts>/AlecTools           (copy installed from AlecTools.mzp)
global AlecTools_root

(
	local scriptsDir = getDir #userScripts
	local root = scriptsDir + "/AlecTools"
	local override = scriptsDir + "/AlecTools.root.txt"

	if doesFileExist override do
	(
		local p = ""
		local f = openFile override
		if f != undefined do (p = readLine f; close f)
		p = substituteString (trimRight (trimLeft p)) "\\" "/"
		if doesFileExist (p + "/core/AlecTools_core.ms") then root = p
		else format "Alec Tools: invalid root override: %\n" p
	)

	if doesFileExist (root + "/core/AlecTools_core.ms") then
	(
		AlecTools_root = root
		try
		(
			fileIn (root + "/core/AlecTools_core.ms")
			-- execute: the block is compiled before fileIn runs, so a direct call would be undefined
			execute "AlecTools_reload()"
		)
		catch (format "Alec Tools: startup failed: %\n" (getCurrentException()))
	)
	else format "Alec Tools: nothing to load, expected %/core/AlecTools_core.ms\n" root
)
