-- Test for tools/settingsTransfer.ms. Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\settingsTransfer_test.ms"
-- Works on temporary folders only (a fake "PC A" and "PC B"); the real Max settings are not touched, no .cmd is started.
-- Prints PASS/FAIL lines, then the number of failures and one FAIL line per failed check as the last lines.

fileIn (AlecTools_path "tools/settingsTransfer.ms")

(
	local failed = #()
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)

	local fileIO = dotNetClass "System.IO.File"
	local dirIO = dotNetClass "System.IO.Directory"
	local base = (getDir #temp) + "\\AlecSettingsTest"
	AlecSettings_emptyDir base

	fn writeFile path text =
	(
		dirIO.CreateDirectory (getFilenamePath path)
		fileIO.WriteAllText path text
	)

	fn makePc base name tag user =
	(
		local pc = base + "\\" + name
		writeFile (pc + "\\us\\keys.hsx") ("keys-" + tag)
		writeFile (pc + "\\us\\quads.qmnx") ("quads-" + tag)
		writeFile (pc + "\\us\\menus.mnx") ("menus-" + tag)
		writeFile (pc + "\\us\\GlobalSearch.ini") ("not-moved-" + tag)
		writeFile (pc + "\\ui\\MaxStartUI.cuix") ("start-" + tag)
		writeFile (pc + "\\ui\\Workspaces\\Workspace1.cuix") ("ws-" + tag)
		writeFile (pc + "\\ui\\Workspaces\\usersave\\W__usersave__.cuix") ("us-" + tag)
		writeFile (pc + "\\ui\\Workspaces\\usersave\\W__usersave__.mnxpath") ("C:/Users/" + user + "/Autodesk/3ds Max 2027/User Settings/menus.mnx\r\nC:/Program Files/Autodesk/3ds Max 2027/UI_LN/CUI/3dsmaxMenus.mnx")
		AlecSettings_dirsStruct settingsDir:(pc + "\\us") uiDir:(pc + "\\ui") backupDir:(pc + "\\backup") pendingDir:(pc + "\\pending")
	)

	local a = makePc base "pcA" "A" "someoneelse"
	local b = makePc base "pcB" "B" "laptopuser"
	writeFile (b.uiDir + "\\Workspaces\\OnlyOnB.cuix") "only-b"

	local exported = AlecSettings_exportTo base a
	if not (check "export: counts the files" (exported == 7)) do append failed "export: counts the files"
	if not (check "export: packRoot finds the folder" (AlecSettings_packRoot (base + "\\AlecSettings") != undefined)) do append failed "export: packRoot finds the folder"
	if not (check "export: packRoot finds it from the parent" (AlecSettings_packRoot base != undefined)) do append failed "export: packRoot finds it from the parent"
	if not (check "export: other user settings not moved" (not (doesFileExist (base + "\\AlecSettings\\UserSettings\\GlobalSearch.ini")))) do append failed "export: other user settings not moved"
	if not (check "export: nothing to export throws" (try (AlecSettings_exportTo (base + "\\empty") (AlecSettings_dirsStruct settingsDir:(base + "\\none1") uiDir:(base + "\\none2")); false) catch true)) do append failed "export: nothing to export throws"

	local root = AlecSettings_packRoot base
	local backup = AlecSettings_stage root b
	local pending = b.pendingDir
	if not (check "stage: shortcuts staged" (fileIO.ReadAllText (pending + "\\UserSettings\\keys.hsx") == "keys-A")) do append failed "stage: shortcuts staged"
	if not (check "stage: workspace staged" (fileIO.ReadAllText (pending + "\\UI\\Workspaces\\usersave\\W__usersave__.cuix") == "us-A")) do append failed "stage: workspace staged"
	if not (check "stage: this PC untouched until the cmd runs" (fileIO.ReadAllText (b.settingsDir + "\\keys.hsx") == "keys-B")) do append failed "stage: this PC untouched until the cmd runs"
	if not (check "stage: backup holds the old settings" (fileIO.ReadAllText (backup + "\\UserSettings\\keys.hsx") == "keys-B")) do append failed "stage: backup holds the old settings"
	if not (check "stage: backup holds the old workspaces" (doesFileExist (backup + "\\UI\\Workspaces\\OnlyOnB.cuix"))) do append failed "stage: backup holds the old workspaces"

	local paths = (fileIO.ReadAllText (pending + "\\UI\\Workspaces\\usersave\\W__usersave__.mnxpath")) as string
	local userHome = (substituteString (AlecSettings_userProfile()) "\\" "/") + "/"
	if not (check "stage: mnxpath points to this user" ((findString paths (userHome + "Autodesk/3ds Max 2027/User Settings/menus.mnx")) != undefined)) do append failed "stage: mnxpath points to this user"
	if not (check "stage: mnxpath keeps the Program Files path" ((findString paths "C:/Program Files/Autodesk/3ds Max 2027/UI_LN/CUI/3dsmaxMenus.mnx") != undefined)) do append failed "stage: mnxpath keeps the Program Files path"

	local cmdText = AlecSettings_cmdText 1234 b "C:\\Max\\3dsmax.exe"
	if not (check "cmd: waits for the Max process" ((findString cmdText "PID eq 1234") != undefined)) do append failed "cmd: waits for the Max process"
	if not (check "cmd: copies from the pending folder" ((findString cmdText (b.pendingDir + "\\UserSettings")) != undefined)) do append failed "cmd: copies from the pending folder"
	if not (check "cmd: opens Max again" ((findString cmdText "start \"\" \"C:\\Max\\3dsmax.exe\"") != undefined)) do append failed "cmd: opens Max again"

	if not (check "defaultDirs: settings and ui folders are set" (local d = AlecSettings_defaultDirs(); d.settingsDir != undefined and d.uiDir != undefined)) do append failed "defaultDirs: settings and ui folders are set"

	dirIO.Delete base true
	format "settingsTransfer_test: % failure(s)\n" failed.count
	for l in failed do format "FAIL %\n" l
)
