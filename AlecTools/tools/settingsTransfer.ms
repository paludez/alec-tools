-- Settings Transfer: moves the Max customizations (shortcuts, quad menus, menus, toolbars) between PCs as a folder.
-- Export copies them into <chosen folder>/AlecSettings. Import backs up this PC's, stages the folder, and a small .cmd
-- (cmd.exe only: no PowerShell, no Python) replaces them once Max has closed, because Max rewrites its UI files when it exits.
--
-- What is moved:
--   User Settings/*.hsx *.qmnx *.mnx   shortcuts (hotkey sets), quad menus, menus
--   UI/Workspaces                      workspaces: toolbars, plus what a workspace keeps (ribbon, viewport presets)
--   UI/MaxStartUI.cuix(.layout)        the toolbars Max starts with
-- The .mnxpath files of the workspaces hold the user folder of the PC that wrote them; staging points them to this user.

struct AlecSettings_dirsStruct (settingsDir, uiDir, backupDir, pendingDir)

fn AlecSettings_userProfile = (dotNetClass "System.Environment").GetEnvironmentVariable "USERPROFILE"

-- where this Max keeps its customizations; the language folder (ENU) is the one the user scripts folder is in
fn AlecSettings_defaultDirs =
(
	local enu = (dotNetClass "System.IO.Path").GetFullPath ((getDir #userScripts) + "/..")
	AlecSettings_dirsStruct \
		settingsDir:((AlecSettings_userProfile()) + "\\Autodesk\\3ds Max 2027\\User Settings") \
		uiDir:(enu + "\\en-US\\UI") \
		backupDir:(enu + "\\AlecSettings.backup") \
		pendingDir:(enu + "\\AlecSettings.pending")
)

fn AlecSettings_copyFile src dstDir =
(
	(dotNetClass "System.IO.Directory").CreateDirectory dstDir
	(dotNetClass "System.IO.File").Copy src (dstDir + "\\" + (filenameFromPath src)) true
)

-- copies a folder with everything in it; returns how many files
fn AlecSettings_copyTree srcDir dstDir =
(
	local dirIO = dotNetClass "System.IO.Directory"
	dirIO.CreateDirectory dstDir
	local n = 0
	for f in (dirIO.GetFiles srcDir) do (AlecSettings_copyFile f dstDir; n += 1)
	for d in (dirIO.GetDirectories srcDir) do
		n += AlecSettings_copyTree d (dstDir + "\\" + (filenameFromPath d))
	n
)

fn AlecSettings_emptyDir path =
(
	local dirIO = dotNetClass "System.IO.Directory"
	if dirIO.Exists path do dirIO.Delete path true
	dirIO.CreateDirectory path
)

-- copies the customizations of this PC into root/UserSettings and root/UI; returns how many files
fn AlecSettings_collect root settingsDir uiDir =
(
	local n = 0
	for pattern in #("*.hsx", "*.qmnx", "*.mnx") do
		for f in (getFiles (settingsDir + "\\" + pattern)) do (AlecSettings_copyFile f (root + "\\UserSettings"); n += 1)
	for name in #("MaxStartUI.cuix", "MaxStartUI.cuix.layout") do
		if doesFileExist (uiDir + "\\" + name) do (AlecSettings_copyFile (uiDir + "\\" + name) (root + "\\UI"); n += 1)
	if (dotNetClass "System.IO.Directory").Exists (uiDir + "\\Workspaces") do
		n += AlecSettings_copyTree (uiDir + "\\Workspaces") (root + "\\UI\\Workspaces")
	n
)

-- the user folder inside the .mnxpath files (C:/Users/<name>/) points to this user
fn AlecSettings_fixMenuPaths workspacesDir =
(
	local fileIO = dotNetClass "System.IO.File"
	local regex = dotNetClass "System.Text.RegularExpressions.Regex"
	local utf8Bom = dotNetObject "System.Text.UTF8Encoding" true
	local userHome = (substituteString (AlecSettings_userProfile()) "\\" "/") + "/"
	local everywhere = (dotNetClass "System.IO.SearchOption").AllDirectories
	for f in ((dotNetClass "System.IO.Directory").GetFiles workspacesDir "*.mnxpath" everywhere) do
	(
		local text = fileIO.ReadAllText f
		local fixed = regex.Replace text "(?i)[A-Z]:/Users/[^/\\r\\n]+/" userHome
		if fixed != text do fileIO.WriteAllText f fixed utf8Bom
	)
)

-- a folder Export made (or one that holds it)
fn AlecSettings_packRoot picked =
(
	local dirIO = dotNetClass "System.IO.Directory"
	local root = undefined
	for candidate in #(picked, picked + "\\AlecSettings") while root == undefined do
		if dirIO.Exists (candidate + "\\UserSettings") and dirIO.Exists (candidate + "\\UI") do root = candidate
	root
)

-- returns how many files went into <target>\AlecSettings
fn AlecSettings_exportTo target dirs =
(
	local root = target + "\\AlecSettings"
	AlecSettings_emptyDir root
	local n = AlecSettings_collect root dirs.settingsDir dirs.uiDir
	if n == 0 do throw ("Nothing to export: no customizations found in " + dirs.settingsDir + " and " + dirs.uiDir)
	n
)

-- backs up what this PC has, then puts the folder in the pending folder with the menu paths fixed; returns the backup folder
fn AlecSettings_stage root dirs =
(
	local stamp = (dotNetClass "System.DateTime").Now.ToString "yyyyMMdd-HHmmss"
	local backup = dirs.backupDir + "\\" + stamp
	AlecSettings_collect backup dirs.settingsDir dirs.uiDir
	AlecSettings_emptyDir dirs.pendingDir
	AlecSettings_copyTree root dirs.pendingDir
	AlecSettings_fixMenuPaths (dirs.pendingDir + "\\UI\\Workspaces")
	backup
)

-- the .cmd that waits for the Max with this id to exit, replaces the files from the pending folder, and opens Max again
fn AlecSettings_cmdText pid dirs maxExe =
(
	local lines = #(
		"@echo off",
		"echo Waiting for 3ds Max to close (save your scene)...",
		":wait",
		"tasklist /FI \"PID eq " + (pid as string) + "\" /NH | find \"3dsmax.exe\" >nul",
		"if not errorlevel 1 (timeout /t 2 /nobreak >nul & goto wait)",
		"copy /y \"" + dirs.pendingDir + "\\UserSettings\\*\" \"" + dirs.settingsDir + "\\\" >nul || goto failed",
		"copy /y \"" + dirs.pendingDir + "\\UI\\MaxStartUI.cuix*\" \"" + dirs.uiDir + "\\\" >nul || goto failed",
		"robocopy \"" + dirs.pendingDir + "\\UI\\Workspaces\" \"" + dirs.uiDir + "\\Workspaces\" /MIR /NFL /NDL /NJH /NJS /NP >nul",
		"if errorlevel 8 goto failed",
		"echo Settings replaced.",
		"start \"\" \"" + maxExe + "\"",
		"exit /b 0",
		":failed",
		"echo Replacing the settings failed. Nothing more was changed; the backup is in " + dirs.backupDir,
		"pause"
	)
	local text = ""
	for l in lines do text += l + "\r\n"
	text
)

fn AlecSettings_export =
(
	local target = getSavePath caption:"Export Max settings: choose where the AlecSettings folder is made"
	if target != undefined do
	(
		local n = undefined
		try (n = AlecSettings_exportTo target (AlecSettings_defaultDirs()))
		catch (messageBox ("Export failed:\n" + (getCurrentException())) title:"Alec Tools")
		if n != undefined do messageBox ("Exported " + (n as string) + " files to\n" + target + "\\AlecSettings") title:"Alec Tools"
	)
)

-- the replacement has to happen with Max closed, so the .cmd waits for this Max to exit
fn AlecSettings_import =
(
	local picked = getSavePath caption:"Import Max settings: choose the AlecSettings folder"
	if picked != undefined do
	(
		local root = AlecSettings_packRoot picked
		if root == undefined then
			messageBox "That is not an AlecSettings folder (it needs UserSettings and UI inside)." title:"Alec Tools"
		else
		(
			local text = "The shortcuts, quad menus, menus and toolbars of this Max will be replaced by the ones in the folder (a backup is kept).\n\nIt happens when Max closes: save your scene and close Max. It opens again by itself.\n\nContinue?"
			if queryBox text title:"Alec Tools" do
			(
				try
				(
					local dirs = AlecSettings_defaultDirs()
					local backup = AlecSettings_stage root dirs
					local cmdFile = dirs.pendingDir + "\\apply.cmd"
					local pid = ((dotNetClass "System.Diagnostics.Process").GetCurrentProcess()).Id
					(dotNetClass "System.IO.File").WriteAllText cmdFile (AlecSettings_cmdText pid dirs ((getDir #maxroot) + "3dsmax.exe"))
					ShellLaunch ((dotNetClass "System.Environment").SystemDirectory + "\\cmd.exe") ("/c \"" + cmdFile + "\"")
					messageBox ("Ready. Close Max now.\nThe current settings are backed up in\n" + backup) title:"Alec Tools"
				)
				catch (messageBox ("Import failed:\n" + (getCurrentException())) title:"Alec Tools")
			)
		)
	)
)
