---
name: release
description: Commit the Alec Tools changes, build a fresh AlecTools.mzp, commit it and push to GitHub (paludez/alec-tools).
disable-model-invocation: true
---

# Release Alec Tools

The user typed `/release`: that is the approval to commit and push. Do all steps without asking, stop only on a real problem.

Repo: `D:\P R O I E C T E\AI\3DS MAX`. Local branch `master` goes to `main` on GitHub.

GitHub only receives: the local repo is the truth, nothing is ever pulled from GitHub.

1. **Look.** `git status` and `git diff`. Skip junk: `__pycache__`, `AlecSettings-backup-*.zip`, scratch files. If there is nothing to commit and nothing to push, say so and stop.
2. **Build.** `powershell -ExecutionPolicy Bypass -File tools/build_mzp.ps1`. It writes `AlecTools.mzp` in the repo root and prints the version (build date and time).
3. **Commit.** `git add` the real changes and `AlecTools.mzp`, one commit with a short English message saying what changed, by tool. End the message with the attribution line from the system reminder.
4. **Push** once: `git push --force-with-lease origin master:main` (GitHub may hold commits made elsewhere; local wins).
5. **Report** in 2 lines: the commit, pushed. Nothing else.
