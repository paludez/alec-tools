-- Settings Transfer: moves the Max shortcuts, toolbars and menus between PCs as a folder.
-- Export puts them in <chosen folder>/AlecSettings.zip. Import takes that zip, backs up this PC's and replaces them with the zip's.
-- Max rewrites its UI files when it exits unless "Save UI configuration on exit" (Customize > Preferences) is off, so the
-- panel (maxSettings.py) asks for that to be off, and the new settings are there at the next start.
--
-- What is moved (nothing else of the workspaces: no ribbon, viewport presets, colors):
--   User Settings/*.hsx *.qmnx *.mnx   shortcuts (hotkey sets), quad menus, menus
--   the active workspace's .cuix       toolbars, plus its .cuix.layout (where they are docked) and .mnxpath (which menu files);
--                                      the active workspace is the one Max saved last (the newest .workspace)
--   MaxStartUI.cuix(.layout)           the copy of the toolbars Max starts with
-- The .mnxpath names the user folder of the PC that wrote it: export swaps it for a token, so the exported folder holds
-- no path of that PC, and staging swaps the token for this PC's user folder.

-- workspace: the active workspace's path without extension (Workspaces\usersave\Workspace1__usersave__), undefined when there is none
struct AlecMaxSettings_dirsStruct (settingsDir, uiDir, workspace, backupDir, pendingDir)

global AlecMaxSettings_userToken = "{USERPROFILE}"

fn AlecMaxSettings_userProfile = (dotNetClass "System.Environment").GetEnvironmentVariable "USERPROFILE"

-- the active workspace: the newest .workspace under Workspaces, as its path without the extension
fn AlecMaxSettings_activeWorkspace uiDir =
(
	local dirIO = dotNetClass "System.IO.Directory"
	local fileIO = dotNetClass "System.IO.File"
	local newest = undefined
	local newestTime = undefined
	if dirIO.Exists (uiDir + "\\Workspaces") do
		for f in (dirIO.GetFiles (uiDir + "\\Workspaces") "*.workspace" (dotNetClass "System.IO.SearchOption").AllDirectories) do
		(
			local time = fileIO.GetLastWriteTimeUtc f
			if newest == undefined or (time.CompareTo newestTime) > 0 do (newest = f; newestTime = time)
		)
	if newest == undefined then undefined else (getFilenamePath newest) + (getFilenameFile newest)
)

-- where this Max keeps its customizations; the language folder (ENU) is the one the user scripts folder is in
fn AlecMaxSettings_defaultDirs =
(
	local enu = (dotNetClass "System.IO.Path").GetFullPath ((getDir #userScripts) + "/..")
	local ui = enu + "\\en-US\\UI"
	AlecMaxSettings_dirsStruct \
		settingsDir:((AlecMaxSettings_userProfile()) + "\\Autodesk\\3ds Max 2027\\User Settings") \
		uiDir:ui \
		workspace:(AlecMaxSettings_activeWorkspace ui) \
		backupDir:(enu + "\\AlecSettings.backup") \
		pendingDir:(enu + "\\AlecSettings.pending")
)

fn AlecMaxSettings_copyFileTo src dst =
(
	(dotNetClass "System.IO.Directory").CreateDirectory (getFilenamePath dst)
	(dotNetClass "System.IO.File").Copy src dst true
)

fn AlecMaxSettings_emptyDir path =
(
	local dirIO = dotNetClass "System.IO.Directory"
	if dirIO.Exists path do dirIO.Delete path true
	dirIO.CreateDirectory path
)

-- copies a folder with everything in it
fn AlecMaxSettings_copyTree srcDir dstDir =
(
	local dirIO = dotNetClass "System.IO.Directory"
	dirIO.CreateDirectory dstDir
	for f in (dirIO.GetFiles srcDir) do AlecMaxSettings_copyFileTo f (dstDir + "\\" + (filenameFromPath f))
	for d in (dirIO.GetDirectories srcDir) do
		AlecMaxSettings_copyTree d (dstDir + "\\" + (filenameFromPath d))
)

-- copies the shortcuts, toolbars and menus of this PC into root/UserSettings and root/UI; returns how many files
fn AlecMaxSettings_collect root dirs =
(
	local n = 0
	for pattern in #("*.hsx", "*.qmnx", "*.mnx") do
		for f in (getFiles (dirs.settingsDir + "\\" + pattern)) do
		(
			AlecMaxSettings_copyFileTo f (root + "\\UserSettings\\" + (filenameFromPath f))
			n += 1
		)
	local ui = root + "\\UI\\"
	local pairs = #(
		#(dirs.uiDir + "\\MaxStartUI.cuix", ui + "MaxStartUI.cuix"),
		#(dirs.uiDir + "\\MaxStartUI.cuix.layout", ui + "MaxStartUI.cuix.layout")
	)
	if dirs.workspace != undefined do
		join pairs #(
			#(dirs.workspace + ".cuix", ui + "Toolbars.cuix"),
			#(dirs.workspace + ".cuix.layout", ui + "Toolbars.cuix.layout"),
			#(dirs.workspace + ".mnxpath", ui + "Menus.mnxpath")
		)
	for p in pairs do
		if doesFileExist p[1] do (AlecMaxSettings_copyFileTo p[1] p[2]; n += 1)
	n
)

-- rewrites the text of every file in root named pattern with fixFn
fn AlecMaxSettings_rewriteFiles root pattern fixFn =
(
	local fileIO = dotNetClass "System.IO.File"
	local utf8Bom = dotNetObject "System.Text.UTF8Encoding" true
	local everywhere = (dotNetClass "System.IO.SearchOption").AllDirectories
	for f in ((dotNetClass "System.IO.Directory").GetFiles root pattern everywhere) do
	(
		local text = fileIO.ReadAllText f
		local fixed = fixFn text
		if fixed != text do fileIO.WriteAllText f fixed utf8Bom
	)
)

fn AlecMaxSettings_neutral text =
(
	(dotNetClass "System.Text.RegularExpressions.Regex").Replace text "(?i)[A-Z]:[/\\\\]Users[/\\\\][^/\\\\\r\n\"<>]+" AlecMaxSettings_userToken
)

fn AlecMaxSettings_local text =
(
	substituteString text AlecMaxSettings_userToken (substituteString (AlecMaxSettings_userProfile()) "\\" "/")
)

-- the .NET zip class; the assembly is named differently in older .NET
fn AlecMaxSettings_zipClass =
(
	try (dotnet.loadAssembly "System.IO.Compression.ZipFile")
	catch (dotnet.loadAssembly "System.IO.Compression.FileSystem")
	dotNetClass "System.IO.Compression.ZipFile"
)

-- returns how many files went into <target>\AlecSettings.zip
fn AlecMaxSettings_exportTo target dirs =
(
	local root = (getDir #temp) + "\\AlecSettingsPack"
	AlecMaxSettings_emptyDir root
	local n = AlecMaxSettings_collect root dirs
	AlecMaxSettings_rewriteFiles root "*.mnxpath" AlecMaxSettings_neutral
	if n == 0 do throw ("Nothing to export: no shortcuts, toolbars or menus found in " + dirs.settingsDir + " and " + dirs.uiDir)
	local zipFile = target + "\\AlecSettings.zip"
	(dotNetClass "System.IO.File").Delete zipFile
	(AlecMaxSettings_zipClass()).CreateFromDirectory root zipFile
	(dotNetClass "System.IO.Directory").Delete root true
	n
)

-- true for the folder inside an Export zip, and for a backup folder (the same layout)
fn AlecMaxSettings_isPack folder =
(
	local dirIO = dotNetClass "System.IO.Directory"
	dirIO.Exists (folder + "\\UserSettings") and dirIO.Exists (folder + "\\UI")
)

-- unpacks an Export zip into the (emptied) folder and returns it
fn AlecMaxSettings_unzipTo zipFile folder =
(
	AlecMaxSettings_emptyDir folder
	(AlecMaxSettings_zipClass()).ExtractToDirectory zipFile folder
	if not (AlecMaxSettings_isPack folder) do throw ("Not an Alec settings file: " + zipFile)
	folder
)

-- the pending folder is a staging copy of the pack with this user's folder in the paths; copies it over the real files.
-- The workspace files go to the workspace this Max has; with none, only the shortcuts, menus and MaxStartUI are replaced.
-- Max is not touched: it keeps what it has until it is restarted
fn AlecMaxSettings_apply dirs =
(
	local pending = dirs.pendingDir
	local pairs = #(
		#(pending + "\\UI\\MaxStartUI.cuix", dirs.uiDir + "\\MaxStartUI.cuix"),
		#(pending + "\\UI\\MaxStartUI.cuix.layout", dirs.uiDir + "\\MaxStartUI.cuix.layout")
	)
	for f in (getFiles (pending + "\\UserSettings\\*")) do
		append pairs #(f, dirs.settingsDir + "\\" + (filenameFromPath f))
	if dirs.workspace != undefined do
		join pairs #(
			#(pending + "\\UI\\Toolbars.cuix", dirs.workspace + ".cuix"),
			#(pending + "\\UI\\Toolbars.cuix.layout", dirs.workspace + ".cuix.layout"),
			#(pending + "\\UI\\Menus.mnxpath", dirs.workspace + ".mnxpath")
		)
	local n = 0
	for p in pairs do
		if doesFileExist p[1] do (AlecMaxSettings_copyFileTo p[1] p[2]; n += 1)
	n
)

-- the Preferences option that makes Max rewrite its UI files when it closes: "1" when on
fn AlecMaxSettings_saveUiOnExit = getINISetting (getMAXIniFile()) "WindowState" "SaveUIonExit"

-- the backups are AlecSettings-backup-<date and time>.zip, in the folder of the zip that was imported; the newest few are kept
global AlecMaxSettings_backupsKept = 3

-- the backups in the folder, oldest first (the names are date and time)
fn AlecMaxSettings_backupsIn folder =
(
	local found = for f in ((dotNetClass "System.IO.Directory").GetFiles folder "AlecSettings-backup-*.zip") collect f
	sort found
)

-- zips what this PC has into dirs.backupDir; the oldest backups beyond AlecMaxSettings_backupsKept are deleted; returns the zip
fn AlecMaxSettings_backup dirs =
(
	local stamp = (dotNetClass "System.DateTime").Now.ToString "yyyyMMdd-HHmmss-fff"
	local tmp = (getDir #temp) + "\\AlecSettingsBackup"
	AlecMaxSettings_emptyDir tmp
	AlecMaxSettings_collect tmp dirs
	(dotNetClass "System.IO.Directory").CreateDirectory dirs.backupDir
	local zipFile = dirs.backupDir + "\\AlecSettings-backup-" + stamp + ".zip"
	(AlecMaxSettings_zipClass()).CreateFromDirectory tmp zipFile
	(dotNetClass "System.IO.Directory").Delete tmp true
	local backups = AlecMaxSettings_backupsIn dirs.backupDir
	for i = 1 to backups.count - AlecMaxSettings_backupsKept do (dotNetClass "System.IO.File").Delete backups[i]
	zipFile
)

-- backs up what this PC has (see AlecMaxSettings_backup), replaces it with the folder's; returns #(files replaced, backup zip)
fn AlecMaxSettings_import root dirs =
(
	local backup = AlecMaxSettings_backup dirs
	AlecMaxSettings_emptyDir dirs.pendingDir
	AlecMaxSettings_copyTree root dirs.pendingDir
	AlecMaxSettings_rewriteFiles dirs.pendingDir "*.mnxpath" AlecMaxSettings_local
	local n = AlecMaxSettings_apply dirs
	(dotNetClass "System.IO.Directory").Delete dirs.pendingDir true
	#(n, backup)
)

-- what the Max Settings panel (tools/maxSettings.py) calls; none of them asks anything, the panel holds the paths.
-- Each returns #(files replaced, backup folder) and throws a message when it cannot go on.

-- imports an Export zip; this PC's files are backed up next to it
fn AlecMaxSettings_importZip zipFile dirs =
(
	if not (doesFileExist zipFile) do throw ("File not found: " + zipFile)
	dirs.backupDir = trimRight (getFilenamePath zipFile) "\\"
	local unzipped = (getDir #temp) + "\\AlecSettingsUnzip"
	local done = AlecMaxSettings_import (AlecMaxSettings_unzipTo zipFile unzipped) dirs
	(dotNetClass "System.IO.Directory").Delete unzipped true
	done
)

-- the backup to restore: the zip itself, or the newest backup in the folder
fn AlecMaxSettings_backupToRestore path =
(
	local newest = undefined
	if (dotNetClass "System.IO.Directory").Exists path then
	(
		local backups = AlecMaxSettings_backupsIn path
		if backups.count > 0 do newest = backups[backups.count]
	)
	else if doesFileExist path do newest = path
	newest
)

-- puts a backup back; the state before is backed up beside it
fn AlecMaxSettings_restoreFrom path dirs =
(
	local zipFile = AlecMaxSettings_backupToRestore path
	if zipFile == undefined do throw ("No backup found in " + path)
	dirs.backupDir = trimRight (getFilenamePath zipFile) "\\"
	local unzipped = (getDir #temp) + "\\AlecSettingsUnzip"
	local done = AlecMaxSettings_import (AlecMaxSettings_unzipTo zipFile unzipped) dirs
	(dotNetClass "System.IO.Directory").Delete unzipped true
	done
)
