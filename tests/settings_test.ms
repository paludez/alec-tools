-- Test for lib/settings.ms. Run in Max:
--   fileIn @"D:\P R O I E C T E\AI\3DS MAX\tests\settings_test.ms"
-- Remembers settings, reads them back, checks the scene callbacks and that forget clears them. Does not touch the scene. Prints PASS/FAIL lines to the Listener.

(
	local failures = 0
	fn check label ok =
	(
		format "% %\n" (if ok then "PASS" else "FAIL") label
		ok
	)

	AlecTools_forgetSettings()
	if not (check "recall: nothing remembered gives the default" (AlecTools_recallSettings "ATtest" #(1, 1) as string == "#(1, 1)")) do failures += 1

	AlecTools_rememberSettings "ATtest" #(2, 6)
	AlecTools_rememberSettings "ATtest2" "other"
	local back = AlecTools_recallSettings "ATtest" #(1, 1)
	if not (check "remember: read back" (back[1] == 2 and back[2] == 6)) do failures += 1
	if not (check "remember: sections are apart" (AlecTools_recallSettings "ATtest2" undefined == "other")) do failures += 1

	-- the scene is not reset here; the test checks that the callbacks are there and that forget clears everything
	for ev in #(#systemPostNew, #systemPostReset, #filePostOpen) do
		if not (check ("callback on " + ev as string) ((callbacks.show ev id:#AlecTools_settings asArray:true).count == 1)) do failures += 1
	AlecTools_forgetSettings()
	if not (check "forget: the settings are gone" ((AlecTools_recallSettings "ATtest" undefined) == undefined)) do failures += 1

	format "settings_test: % failure(s)\n" failures
)
