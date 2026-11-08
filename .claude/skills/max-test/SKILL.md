---
name: max-test
description: Run an Alec Tools test (tests/*_test.ms) inside 3ds Max through 3dsmax-mcp and get back only the failures. Use whenever a Max test or a quick MAXScript check has to run.
---

# Run a Max test

1. Call `mcp__3dsmax-mcp__execute_maxscript` once with:

   ```maxscript
   fileIn @"D:\P R O I E C T E\AI\3DS MAX\.claude\skills\max-test\run_test.ms"
   (globalVars.get #AlecTest_run) @"<absolute path of the test file>"
   ```

   Pass `quiet: false`. Keep `globalVars.get`: a plain `AlecTest_run` in the same call is compiled before `fileIn` defines it and fails with "got: undefined". Use the real absolute path of this skill folder if the repo lives elsewhere.

2. The result is only what is not a `PASS` line: the failure count, the `FAIL <label>` lines, any other printed text, and `EXCEPTION ...` if the test threw. `AlecTest_run` already calls `AlecTools_reload()` first.

3. Do not write another log reader, do not re-read the whole log, do not print PASS lines.

## Writing a test

- File in `tests/<tool>_test.ms`. It creates and deletes its own objects and never saves the scene.
- Helpers are `global X = fn ...` (MCP runs code in global scope).
- Print `PASS <label>` / `FAIL <label>` per check with `format`.
- Last lines: the failure count, then one `FAIL <label>` per failed check.
- Cover both Editable Poly and Edit Poly (and mesh/spline equivalents) where the tool touches them.

For a quick check without a test file, write the snippet to the scratchpad as a `.ms` file and pass that path to `AlecTest_run`.
