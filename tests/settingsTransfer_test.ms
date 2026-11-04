-- Test for tools/settingsTransfer.ms. Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\settingsTransfer_test.ms"
-- Works on temporary folders only (fake PCs "A", "B" and "C"); the real Max settings are not touched.
-- Prints PASS/FAIL lines, then the number of failures and one FAIL line per failed check as the last lines.

fileIn (AlecTools_path "tools/settingsTransfer.ms")

(
	local failed = #()
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)
	fn expect label ok failed =
	(
		if not (check label ok) do append failed label
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

	fn read path = fileIO.ReadAllText path

	-- a fake PC: shortcuts, quad menus, menus, startup toolbars, two workspaces (the newer is the active one) and things that must not move
	fn makePc base name tag user withWorkspace =
	(
		local pc = base + "\\" + name
		local ws = pc + "\\ui\\Workspaces\\usersave\\W__usersave__"
		writeFile (pc + "\\us\\keys.hsx") ("keys-" + tag)
		writeFile (pc + "\\us\\quads.qmnx") ("quads-" + tag)
		writeFile (pc + "\\us\\menus.mnx") ("menus-" + tag)
		writeFile (pc + "\\us\\GlobalSearch.ini") ("not-moved-" + tag)
		writeFile (pc + "\\ui\\MaxStartUI.cuix") ("start-" + tag)
		writeFile (pc + "\\ui\\MaxStartUI.cuix.layout") ("startlayout-" + tag)
		writeFile (pc + "\\ui\\MaxStartUI.clrx") ("colors-" + tag)
		if withWorkspace do
		(
			writeFile (pc + "\\ui\\Workspaces\\Workspace1.workspace") "old"
			fileIO.SetLastWriteTimeUtc (pc + "\\ui\\Workspaces\\Workspace1.workspace") (dotNetObject "System.DateTime" 2020 1 1)
			writeFile (pc + "\\ui\\Workspaces\\Workspace1.cuix") ("other-workspace-" + tag)
			writeFile (ws + ".workspace") "active"
			writeFile (ws + ".cuix") ("toolbars-" + tag)
			writeFile (ws + ".cuix.layout") ("layout-" + tag)
			writeFile (ws + ".mnxpath") ("C:/Users/" + user + "/Autodesk/3ds Max 2027/User Settings/menus.mnx\r\nC:/Program Files/Autodesk/3ds Max 2027/UI_LN/CUI/3dsmaxMenus.mnx")
			writeFile (ws + ".ribbonconfig.xaml") ("ribbon-" + tag)
		)
		AlecSettings_dirsStruct settingsDir:(pc + "\\us") uiDir:(pc + "\\ui") workspace:(if withWorkspace then ws else undefined) backupDir:(pc + "\\backup") pendingDir:(pc + "\\pending")
	)

	local a = makePc base "pcA" "A" "someoneelse" true
	local b = makePc base "pcB" "B" "laptopuser" true
	local c = makePc base "pcC" "C" "nobody" false

	expect "activeWorkspace: the newest .workspace" ((AlecSettings_activeWorkspace a.uiDir) == (a.uiDir + "\\Workspaces\\usersave\\W__usersave__")) failed
	expect "activeWorkspace: none when there are no workspaces" ((AlecSettings_activeWorkspace c.uiDir) == undefined) failed

	local exported = AlecSettings_exportTo base a
	expect "export: the zip is made" (doesFileExist (base + "\\AlecSettings.zip")) failed
	local pack = AlecSettings_unzipTo (base + "\\AlecSettings.zip") (base + "\\unzipped")
	expect "export: counts the files" (exported == 8) failed
	expect "export: the temporary pack folder is gone" (not (dirIO.Exists ((getDir #temp) + "\\AlecSettingsPack"))) failed
	writeFile (base + "\\notalec\\x.txt") "x"
	(AlecSettings_zipClass()).CreateFromDirectory (base + "\\notalec") (base + "\\notalec.zip")
	expect "unzip: a zip that is not Alec settings throws" (try (AlecSettings_unzipTo (base + "\\notalec.zip") (base + "\\unzipped2"); false) catch true) failed
	expect "export: toolbars are the active workspace's" ((read (pack + "\\UI\\Toolbars.cuix")) == "toolbars-A") failed
	expect "export: layout is the active workspace's" ((read (pack + "\\UI\\Toolbars.cuix.layout")) == "layout-A") failed
	expect "export: other user settings not moved" (not (doesFileExist (pack + "\\UserSettings\\GlobalSearch.ini"))) failed
	expect "export: no workspaces, ribbon or colors" (not (doesFileExist (pack + "\\UI\\Workspaces")) and not (doesFileExist (pack + "\\UI\\MaxStartUI.clrx")) and (getFiles (pack + "\\UI\\*.xaml")).count == 0) failed
	local exportedMenus = read (pack + "\\UI\\Menus.mnxpath")
	expect "export: mnxpath holds no user of the source PC" ((findString exportedMenus "someoneelse") == undefined) failed
	expect "export: mnxpath uses the token" ((findString exportedMenus "{USERPROFILE}/Autodesk/3ds Max 2027/User Settings/menus.mnx") != undefined) failed
	expect "export: the source PC's own file keeps its path" ((findString (read (a.workspace + ".mnxpath")) "someoneelse") != undefined) failed
	expect "export: nothing to export throws" (try (AlecSettings_exportTo (base + "\\empty") (AlecSettings_dirsStruct settingsDir:(base + "\\none1") uiDir:(base + "\\none2")); false) catch true) failed

	local root = pack
	local done = AlecSettings_import root b
	expect "import: counts the files replaced" (done[1] == 8) failed
	expect "import: shortcuts replaced" ((read (b.settingsDir + "\\keys.hsx")) == "keys-A") failed
	expect "import: quads replaced" ((read (b.settingsDir + "\\quads.qmnx")) == "quads-A") failed
	expect "import: menus replaced" ((read (b.settingsDir + "\\menus.mnx")) == "menus-A") failed
	expect "import: other user settings untouched" ((read (b.settingsDir + "\\GlobalSearch.ini")) == "not-moved-B") failed
	expect "import: startup toolbars replaced" ((read (b.uiDir + "\\MaxStartUI.cuix")) == "start-A" and (read (b.uiDir + "\\MaxStartUI.cuix.layout")) == "startlayout-A") failed
	expect "import: workspace toolbars and layout replaced" ((read (b.workspace + ".cuix")) == "toolbars-A" and (read (b.workspace + ".cuix.layout")) == "layout-A") failed
	expect "import: the rest of the workspaces untouched" ((read (b.uiDir + "\\Workspaces\\Workspace1.cuix")) == "other-workspace-B" and (read (b.workspace + ".ribbonconfig.xaml")) == "ribbon-B" and (read (b.uiDir + "\\MaxStartUI.clrx")) == "colors-B") failed
	expect "import: the backup is a zip" (doesFileExist done[2] and (getFilenameType done[2]) == ".zip") failed
	local oldB = AlecSettings_unzipTo done[2] (base + "\\bk1")
	expect "import: backup holds the old shortcuts and toolbars" ((read (oldB + "\\UserSettings\\keys.hsx")) == "keys-B" and (read (oldB + "\\UI\\Toolbars.cuix")) == "toolbars-B") failed
	expect "import: the temporary backup folder is gone" (not (dirIO.Exists ((getDir #temp) + "\\AlecSettingsBackup"))) failed
	expect "import: the staging folder is gone" (not (dirIO.Exists b.pendingDir)) failed

	local paths = read (b.workspace + ".mnxpath")
	local userHome = (substituteString (AlecSettings_userProfile()) "\\" "/") + "/"
	expect "import: mnxpath points to this user" ((findString paths (userHome + "Autodesk/3ds Max 2027/User Settings/menus.mnx")) != undefined) failed
	expect "import: no token left in the mnxpath" ((findString paths "{USERPROFILE}") == undefined) failed
	expect "import: mnxpath keeps the Program Files path" ((findString paths "C:/Program Files/Autodesk/3ds Max 2027/UI_LN/CUI/3dsmaxMenus.mnx") != undefined) failed

	local doneC = AlecSettings_import root c
	expect "import on a PC without a workspace: counts the files replaced" (doneC[1] == 5) failed
	expect "import on a PC without a workspace: shortcuts replaced" ((read (c.settingsDir + "\\keys.hsx")) == "keys-A") failed
	expect "import on a PC without a workspace: no workspace made" (not (dirIO.Exists (c.uiDir + "\\Workspaces"))) failed

	expect "isPack: an ordinary folder is not a pack" (not (AlecSettings_isPack b.settingsDir)) failed
	local restored = AlecSettings_restoreFrom done[2] b
	expect "restore: shortcuts are back" ((read (b.settingsDir + "\\keys.hsx")) == "keys-B") failed
	expect "restore: toolbars are back" ((read (b.workspace + ".cuix")) == "toolbars-B") failed
	local before = AlecSettings_unzipTo restored[2] (base + "\\bk2")
	expect "restore: a backup of the state before is made, apart from the one restored" (restored[2] != done[2] and (read (before + "\\UserSettings\\keys.hsx")) == "keys-A") failed
	expect "restore: the zip restored from is intact" (doesFileExist done[2]) failed

	-- what the Max Settings panel calls
	local pcD = makePc base "pcD" "D" "nobody" true
	local doneD = AlecSettings_importZip (base + "\\AlecSettings.zip") pcD
	expect "importZip: shortcuts replaced" ((read (pcD.settingsDir + "\\keys.hsx")) == "keys-A") failed
	expect "importZip: the backup is a zip next to the imported one" ((getFilenameType doneD[2]) == ".zip" and (getFilenamePath doneD[2]) == (base + "\\") and (findString (filenameFromPath doneD[2]) "AlecSettings-backup-") == 1) failed
	expect "importZip: a missing file throws" (try (AlecSettings_importZip (base + "\\nope.zip") pcD; false) catch true) failed
	expect "backupToRestore: a backup zip is itself" (AlecSettings_backupToRestore doneD[2] == doneD[2]) failed
	expect "backupToRestore: a folder gives its newest backup, not the Export zip" (AlecSettings_backupToRestore base == doneD[2]) failed
	local restoredD = AlecSettings_restoreFrom base pcD
	expect "restoreFrom: the newest backup is back" ((read (pcD.settingsDir + "\\keys.hsx")) == "keys-D") failed
	expect "restoreFrom: the state before is backed up beside it" ((getFilenameType restoredD[2]) == ".zip" and (getFilenamePath restoredD[2]) == (base + "\\")) failed
	pcD.backupDir = base + "\\kept"
	for i = 1 to 5 do (AlecSettings_backup pcD; sleep 20)
	local kept = sort (getFiles (base + "\\kept\\AlecSettings-backup-*.zip"))
	expect "backup: only the last three are kept" (kept.count == AlecSettings_backupsKept and AlecSettings_backupsKept == 3) failed
	AlecSettings_backup pcD
	local keptNow = AlecSettings_backupsIn (base + "\\kept")
	expect "backup: the oldest goes first" (keptNow.count == 3 and (findItem keptNow kept[1]) == 0 and (findItem keptNow kept[3]) != 0) failed
	expect "restoreFrom: a folder with no backup throws" (try (AlecSettings_restoreFrom (base + "\\empty") pcD; false) catch true) failed

	expect "saveUiOnExit: reads the Max ini" (classOf (AlecSettings_saveUiOnExit()) == String) failed
	expect "defaultDirs: the folders are set" (local d = AlecSettings_defaultDirs(); d.settingsDir != undefined and d.uiDir != undefined and classOf d.backupDir == String) failed

	dirIO.Delete base true
	format "settingsTransfer_test: % failure(s)\n" failed.count
	for l in failed do format "FAIL %\n" l
)
