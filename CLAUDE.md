# Alec Tools

Personal tools for **3ds Max 2027** (2027.1, scene units in cm). Used through macroScript buttons and shortcuts, category "Alec Tools". Only Max 2027 matters; ignore other versions.

## Layout

```
AlecTools/            payload, what gets installed
  core/               AlecTools_core.ms: AlecTools_root, AlecTools_path, AlecTools_load, AlecTools_reload
  lib/                shared helpers (AlecTools_*), auto-loaded before the macros
  tools/              one file per tool, holds the logic, loaded on demand by its macro
  macros/             thin .mcr/.ms files: buttons and shortcuts only, they call into tools/
installer/            AlecTools_Load.ms (startup loader), AlecTools_install.ms + mzp.run (laptop install)
tests/                *_test.ms, run inside Max, print PASS/FAIL
tools/build_mzp.ps1   builds dist/AlecTools.mzp (build.bat)
```

## How it is deployed

- This PC: live. `<userStartupScripts>\AlecTools_Load.ms` loads from the folder in `<userScripts>\AlecTools.root.txt` (points at `D:/P R O I E C T E/AI/3DS MAX/AlecTools`). After editing, the user presses the "Reload Alec Tools" macro; no Max restart.
- Work laptop (no admin): the user downloads `AlecTools.mzp` from the private GitHub repo (`paludez/alec-tools`, file in the repo root) and drags it into Max.
- **Every commit that goes to GitHub comes with a fresh `AlecTools.mzp`:** commit the code, run `tools/build_mzp.ps1` on the clean tree (it also copies the mzp to the repo root), commit the mzp, then push. Otherwise build the mzp only when the user asks.
- Never copy files into `usermacros`, never hardcode `getDir #userMacros` or `D:` paths in tools. Reach files with `AlecTools_path "tools/x.ms"`.

## Rules for code

- MAXScript for macros and anything that touches the scene. Python (pymxs) for files, images, JSON and complex UI.
- Names: `AlecTools_` for shared helpers, `Alec<ToolName>_` for a tool's own functions (e.g. `AlecSmartVis_`).
- Short functions, no unused functions, no dead code, no commented-out code.
- No empty `try ... catch ()`. Let errors reach the Listener, or report `getCurrentException()`.
- Macros stay thin: they call a tool function, nothing more.
- One tool at a time: write it, test it in Max, commit when it works.

## Testing

Test in the real Max through the `3dsmax-mcp` MCP server (skill `3dsmax-mcp-dev`); do not claim a tool works without running it. Test files live in `tests/` and create and delete their own temporary objects. Do not save the user's scene.

## Verified in Max 2027 (add only what has been checked)

- `getDir #userScripts` and `getDir #userStartupScripts` exist.
- A parenthesized block is compiled before a `fileIn` inside it runs, so a function defined by that `fileIn` must be called with `execute "fn()"` from the same block.
- `sort` works on an array of strings.
