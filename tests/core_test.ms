-- Test for the cleanup in core/AlecTools_core.ms. Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\core_test.ms"
-- Creates a fake stale global and a fake saved macro copy, checks that the cleanup removes them and keeps the core, then loads lib and the macros again. Prints PASS/FAIL lines to the Listener.

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)

	global AlecATtest_stale = 1
	AlecTools_purge()
	if not (check "purge: a stale Alec* global is removed" (not (globalVars.isGlobal #AlecATtest_stale))) do failures += 1
	if not (check "purge: the core functions stay" (globalVars.isGlobal #AlecTools_path and globalVars.isGlobal #AlecTools_load and globalVars.isGlobal #AlecTools_removeSavedMacros)) do failures += 1

	local stale = getDir #userMacros + "/Alec Tools-ATtest_stale.mcr"
	local f = createFile stale
	close f
	if not (check "removeSavedMacros: the fake copy was created" (doesFileExist stale)) do failures += 1
	AlecTools_removeSavedMacros()
	if not (check "removeSavedMacros: the stale copy is deleted" (not (doesFileExist stale))) do failures += 1

	-- the purge above removed the lib helpers too, so everything is loaded again for the tests and tools that run after this one
	local errors = AlecTools_load()
	if not (check "load: lib and macros loaded again after the purge" (errors.count == 0 and globalVars.isGlobal #AlecTools_inClosedGroup)) do failures += 1

	format "core_test: % failure(s)\n" failures
)
