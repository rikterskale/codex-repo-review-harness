---
guide_id: windows-novice-usability
guide_schema_version: 1
platform: windows
canonical_path: docs/guides/WINDOWS_NOVICE_USABILITY_GUIDE.md
project_name: "Codex Repo Review Harness"
target_release: "0.2.0 (latest locally verifiable release; no Git tag and no GitHub Release exist)"
reviewed_digest: "3f5fd7747e627e6a93cdf3466a690451a3740d7df44d16e398b112ef8532bf79"
support_status: native_supported
alternative_support_paths: []
validation_status: partially_verified
validated_on: 2026-08-04
validated_environments:
  - "Windows 11 Pro 10.0.26200, x64, Windows PowerShell 5.1.26100.8875, Git 2.54.0.windows.1, standard user"
primary_shells:
  - "Windows PowerShell 5.1"
  - "PowerShell 7 (pwsh) — optional; not required by any command in this project"
maintainer_source_of_truth: "README.md, AGENTS.md, config/review-config.yaml, scripts/Run-Review.ps1"
known_limitations:
  - "The real OpenAI Codex CLI and account sign-in require a human user; CI validates the complete local workflow with a synthetic Codex executable but cannot validate authentication or service availability."
  - "PowerShell 7 (pwsh) is not present on a default Windows installation. As of 2026-08-11 nothing in this project requires it; README.md's self-test commands run under Windows PowerShell 5.1."
  - "Never include secrets in prompts or reports; report-redaction behavior is regression tested but is not a substitute for secret management."
---

# Codex Repo Review Harness — Windows Novice Usability Guide

## 1. About This Guide

This guide is written for a person who has never opened a terminal, never used
Git, and never installed a developer tool. Every step tells you which program to
open, which folder to be in, exactly what to type, and how to tell whether it
worked.

The guide describes release **0.2.0** of the Codex Repo Review Harness. The
exact tree it was checked against is recorded as `reviewed_digest` in the front
matter above; `scripts/ci/Validate-Release.ps1` fails if the two drift apart. If your copy of the project is newer,
some screen output may differ.

Each command in this guide has an identifier such as `WIN-CMD-001`. When you ask
for help, quoting that identifier tells a maintainer exactly which step failed.

Every command is also labelled with a **validation status** so you know how much
to trust it:

| Label | Meaning |
|---|---|
| **Verified** | The command was actually run on a Windows 11 machine while this guide was written, and the output shown is the real output. |
| **Statically verified** | The command was read out of the project's source code and is known to be correct, but it was not executed during validation. |
| **Blocked** | The command could not be run during validation, and the reason is stated. Treat the described result as expected, not proven. |

There is a companion guide for Linux at `docs/guides/LINUX_NOVICE_USABILITY_GUIDE.md`.
Do not mix commands between the two guides — the shells and paths are different.

## 2. What This Project Does

The Codex Repo Review Harness is a small set of PowerShell scripts, prompt files,
and settings that run an AI code review over a Git repository and save the result
as a report you can read.

It does not contain the AI. The AI is the separate **OpenAI Codex CLI**, a program
you install yourself. The harness's job is to call Codex in a deliberately
restricted way:

- It forces Codex into `read-only` mode, so Codex is not permitted to change,
  create, or delete any of your files (the `--sandbox read-only` argument `scripts/Run-Review.ps1` always builds).
- It sends Codex the same reviewed instructions every time, from the `prompts/`
  folder.
- It checks the report Codex sends back against a fixed structure, and refuses to
  save a report that does not match.
- It writes three files per review — a report you read, a machine-readable copy,
  and a checksum file that proves the other two were not altered afterwards.

## 3. Who Should Use It

Use this guide if you want a written code review of a project that lives in a Git
repository on your own Windows computer, and you are willing to install two free
tools first.

You do **not** need to know how to program. You do need:

- Permission to install software on the computer, or someone who can install it
  for you.
- An OpenAI ChatGPT account that includes Codex access (see section 8).
- A project you are allowed to review. Reviewing someone else's private code
  without permission is not acceptable use.

## 4. Safety, Authorization, and Data Handling

Read this section before you run anything.

**What the harness sends away from your computer.** The harness runs the Codex
CLI on your machine. Codex reads your source code locally and sends the parts it
needs to OpenAI's service in order to produce the review. If your repository
contains code you are not allowed to send to a third party, do not use this tool
on it. The project states this in `docs/WINDOWS_BEGINNER_GUIDE.md` line 367.

**What the harness writes.** Only three files per run, all inside the `reports\`
folder. Your source code is never modified. This was confirmed by reading
the runner comparing `git status` before and after the review, and by running the tool.

**Authorization.** Only review repositories you own or have written permission to
review.

**Secrets.** Never put a real password, API key, or token into any command in
this guide. The harness tries to remove secret-looking text from the report
(`scripts/ci/Review-Helpers.ps1` lines 1-19), but that filter is not a guarantee.

**First-review safety check.** The automated new-user journey runs a review from
a separate target repository and proves its Git status is unchanged before and
after the run. After installing the real Codex CLI, you should still review the
reported file paths and never send repositories that you are not authorized to
share with OpenAI.

## 5. Platform Support Status

**Native Windows support: supported and verified.**

Evidence:

- `scripts/Run-Review.ps1` and `scripts/Validate-Harness.ps1` both
  declare `#Requires -Version 5.1`, which is the version of Windows PowerShell
  built into Windows 10 and Windows 11.
- The project's automated tests run on `windows-latest` in
  `.github/workflows/ci.yml` line 27 and pass.
- During validation the harness was run end to end on Windows 11 Pro
  (build 10.0.26200) with Windows PowerShell 5.1.26100.8875.

**Important qualification.** Two levels of PowerShell are involved:

- Windows PowerShell 5.1, which is already on your computer, runs the review
  itself (`scripts\Run-Review.ps1` and `scripts\Validate-Harness.ps1`).
- PowerShell 7, a separate free download named `pwsh`, is **entirely optional**.
  `pwsh` is **not** installed by default on Windows, and no command in this guide
  or in `README.md` requires it. Every script in the project declares
  `#Requires -Version 5.1` and every self-test passes under Windows PowerShell
  5.1 (re-verified 2026-08-11; see section 30.4 item 6). Section 12 explains how
  to add PowerShell 7 if you want it — its only advantage here is more reliable
  handling of non-ASCII characters in reports.

There is no WSL, container, or virtual-machine path documented by this project
for Windows, so none is described here.

## 6. What You Will Accomplish

By the end of this guide you will have:

1. Confirmed that Git is installed and working.
2. Optionally installed PowerShell 7 (not needed for anything in this guide).
3. Installed the OpenAI Codex CLI and signed in.
4. Copied the harness into a project folder on your computer.
5. Run `Validate-Harness.ps1` and seen a list of `[PASS]` lines.
6. Run your first read-only review.
7. Opened and understood the report, the JSON file, and the checksum file.
8. Learned how to cancel a run, clean up, update, and roll back.

## 7. Before You Begin Checklist

Work through this list. Every item has a way to check it, in section 12.

- [ ] Windows 10 or Windows 11, 64-bit. *(Optional to confirm; the harness has no
      documented minimum build.)*
- [ ] Roughly 500 MB of free disk space for the tools, plus space for your project.
- [ ] An internet connection. Required to install the tools and to run a review;
      the review sends code to OpenAI.
- [ ] Permission to install programs on this computer.
- [ ] Git for Windows installed. **Required.**
- [ ] Windows PowerShell 5.1. **Required.** Already present on Windows 10/11.
- [ ] PowerShell 7 (`pwsh`). **Optional.** Nothing in this project requires it.
- [ ] OpenAI Codex CLI installed and signed in. **Required** to run a review.
- [ ] A ChatGPT plan that includes Codex. **Required.** See section 8.
- [ ] A Git repository on disk to review. **Required.**
- [ ] The ability to run PowerShell scripts (execution policy). **Required.**

**Which steps change your computer:** installing Git, installing PowerShell 7,
installing Codex, and changing the execution policy all modify your machine.
Cloning a repository and running a review only create files inside your project
folder. Nothing in this guide changes Windows security settings, the firewall, or
antivirus.

**No ports, services, or listeners.** Nothing in this project opens a network
port, installs a Windows service, or creates a scheduled task. There is no such
code anywhere in `scripts/`.

## 8. Computer and Software Requirements

| Requirement | Exact need | Why | How to check |
|---|---|---|---|
| Operating system | Windows 10 or 11, 64-bit | The scripts are PowerShell and the documented Codex installer is the Windows one | `WIN-CMD-001` |
| CPU architecture | x64 (or ARM64 if your tools support it) | Not restricted by this project | `WIN-CMD-001` |
| Windows PowerShell | 5.1 or newer | Declared by `#Requires -Version 5.1` in `scripts/Run-Review.ps1` | `WIN-CMD-002` |
| PowerShell 7 (`pwsh`) | Not required | Optional convenience only; every script declares `#Requires -Version 5.1` and all self-tests pass under Windows PowerShell 5.1 | `WIN-CMD-003` |
| Git | Any recent version | `scripts/Run-Review.ps1` refuses to run without it | `WIN-CMD-004` |
| Codex CLI | Any version that supports `codex exec --sandbox read-only` | the arguments `scripts/Run-Review.ps1` builds0 build exactly that command | `WIN-CMD-008` |
| Account | A ChatGPT plan that includes Codex, **or** an OpenAI API key for the CI workflow | `docs/WINDOWS_BEGINNER_GUIDE.md` line 109; `README.md` line 102 | Sign-in prompt on first Codex run |
| Disk | ~500 MB for tools | Installer sizes | Not enforced by the project |

**Note on account types.** There are two different credentials in this project and
they are not interchangeable. Running a review on your own computer uses your
**ChatGPT sign-in**. The optional GitHub Actions workflow uses an
**`OPENAI_API_KEY` repository secret** (`.github/workflows/codex-review.yml`
line 77). You do not need an API key to follow this guide.

## 9. Terms and Concepts You Need to Know

Read these once. Full definitions are in section 29.

- **Terminal / PowerShell window** — the black or blue window where you type
  commands. On Windows you open it from the Start menu.
- **Command** — one line of text you type and then press Enter.
- **Working directory** — the folder the terminal is "standing in" right now. Most
  commands in this guide only work from the correct folder.
- **Repository (repo)** — a project folder that Git is tracking. It contains a
  hidden `.git` folder.
- **Clone** — make a copy of a repository from the internet onto your computer.
- **Exit code** — an invisible number a program returns when it finishes. `0`
  means success. Anything else means a specific failure. This project defines
  its exit codes in `README.md` lines 112-113.
- **Read-only sandbox** — the restricted mode this harness forces Codex into, so
  Codex can read your files but cannot change them.
- **Report / artifact** — a file the harness produces for you to read or keep.

## 10. Choose the Correct Installation Path

There is exactly one supported way to use this project on Windows:

| Path | Status | Use it when |
|---|---|---|
| Native Windows, Windows PowerShell 5.1 | **Recommended and supported** | Always |
| PowerShell 7 (`pwsh`) on native Windows | **Supported, optional** | You want better handling of non-ASCII characters in reports. Not required for anything. |
| WSL (Windows Subsystem for Linux) | **Not documented by this project** | — |
| Docker Desktop container | **Not documented by this project** | — |

Do not attempt the WSL or container paths. The project contains no Dockerfile, no
container definition, and no WSL instructions, so any commands would be invented.

Follow the recommended path.

## 11. Open the Correct Terminal or Shell

You will use **Windows PowerShell** for every command in this guide.

1. Press the **Windows** key on your keyboard.
2. Type the word `powershell`.
3. In the results list, click **Windows PowerShell**. Press Enter.
4. A window opens with a blinking cursor after a line ending in `>`. This is your
   terminal. Leave it open — you will use it for the rest of the guide.

**Do not** click "Windows PowerShell (Admin)" or "Run as administrator". Nothing
in this guide needs administrator rights, except optionally installing PowerShell 7.

**If you also see "Terminal" or "Windows Terminal" in the Start menu**, that is a
newer window that can host PowerShell. It works too. When it opens, make sure the
tab says "Windows PowerShell" or "PowerShell".

**Command Prompt (`cmd.exe`) will not work.** The commands in this guide are
PowerShell commands. If you type them into Command Prompt you will get errors
such as `'.' is not recognized`.

**Git Bash will not work either.** Git Bash is installed alongside Git but uses a
different command language.

## 12. Check and Install Prerequisites

### 12.1 Check Git

- **Command ID:** `WIN-CMD-001`
- **Purpose:** Confirm Git is installed and see its version.
- **Run in:** Windows PowerShell
- **Working directory:** Any
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified

```powershell
git --version
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output**:

```text
git version 2.54.0.windows.1
```

**Success means:** you see the word `git version` followed by numbers. The exact
numbers do not matter.

**Next step:** go to 12.2.

**Common failure:** `git : The term 'git' is not recognized...` means Git is not
installed or the terminal was opened before Git finished installing. See
troubleshooting row `WIN-TRB-001`.

### 12.2 Check your Windows PowerShell version

- **Command ID:** `WIN-CMD-002`
- **Purpose:** Confirm Windows PowerShell is version 5.1 or newer.
- **Run in:** Windows PowerShell
- **Working directory:** Any
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified

```powershell
$PSVersionTable.PSVersion
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output**:

```text
Major  Minor  Build    Revision
-----  -----  -----    --------
5      1      26100    8875
```

**Success means:** the `Major` column shows `5` (or `7`). If it shows `5` and
`Minor` shows `1`, you have exactly what the project requires.

**Next step:** go to 12.3.

**Common failure:** a `Major` value below 5 means a very old Windows. The project
does not support it.

### 12.3 Check whether PowerShell 7 is present (optional)

- **Command ID:** `WIN-CMD-003`
- **Purpose:** Find out whether the optional `pwsh` program is installed.
- **Run in:** Windows PowerShell
- **Working directory:** Any
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified

```powershell
Get-Command pwsh -ErrorAction SilentlyContinue
```

Expected exit status: `0`.

Representative output when PowerShell 7 is **not** installed — **Verified Runtime
Output**: the command prints nothing at all and returns you to the prompt.

**Success means:** either you see a table containing `pwsh.exe` (it is installed),
or you see nothing (it is not installed). Both are valid answers.

**Next step:** if nothing was printed and you want to run the self-tests in
section 21.3, do 12.4. Otherwise skip to 12.5.

### 12.4 Install PowerShell 7 (optional)

- **Command ID:** `WIN-CMD-004`
- **Purpose:** Install PowerShell 7 so the harness self-tests can run.
- **Run in:** Windows PowerShell
- **Working directory:** Any
- **Privilege required:** Standard user (Windows may show a consent prompt)
- **Internet access:** Required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Installs the PowerShell 7 program and adds `pwsh` to
  your PATH. Changes your computer.
- **Validation status:** Statically verified — not executed during validation

```powershell
winget install --id Microsoft.PowerShell --source winget
```

Expected exit status: `0`.

Representative output — **Unverified — Runtime Blocked**: winget prints a progress
bar and finishes with a line containing the word `Successfully`.

**Success means:** after closing and reopening PowerShell, `WIN-CMD-003` now
prints a table containing `pwsh.exe`.

**Next step:** close this PowerShell window completely and open a new one
(section 11), then continue at 12.5.

**Common failure:** `winget` is not recognised on older Windows 10 builds. In that
case install PowerShell 7 from the Microsoft Store instead, or skip it — it is
only needed for the self-tests.

### 12.5 Allow PowerShell to run the harness scripts

Windows blocks script files by default. This step permits scripts for your user
account only. It is the narrowest change that makes the harness usable and it does
not disable any security software.

- **Command ID:** `WIN-CMD-005`
- **Purpose:** See the current setting before changing it.
- **Run in:** Windows PowerShell
- **Working directory:** Any
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None — this only reads a setting
- **Validation status:** Verified

```powershell
Get-ExecutionPolicy -Scope CurrentUser
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output**:

```text
Undefined
```

**Success means:** you see one word. `Undefined`, `Restricted`, or `AllSigned`
means you must do the next step. `RemoteSigned` or `Unrestricted` means you can
skip it.

---

- **Command ID:** `WIN-CMD-006`
- **Purpose:** Permit locally written scripts to run for your user account.
- **Run in:** Windows PowerShell
- **Working directory:** Any
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Changes one PowerShell setting for your Windows user
  only. It does not affect other users, and it does not turn off antivirus,
  SmartScreen, or the firewall.
- **Validation status:** Statically verified — not executed during validation

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Expected exit status: `0`.

Representative output — **Code-Derived Output Shape**: PowerShell asks
`Do you want to change the execution policy?`. Type `Y` and press Enter.

**Success means:** re-running `WIN-CMD-005` now prints `RemoteSigned`.

**Why `RemoteSigned` and not `Unrestricted`:** `RemoteSigned` still refuses to run
unsigned scripts that were downloaded from the internet, so it keeps a meaningful
protection. Never set `Unrestricted`.

**To undo this later**, see section 24.

### 12.6 Install the OpenAI Codex CLI

The project documents one installation command, in `README.md` line 29 and
`docs/WINDOWS_BEGINNER_GUIDE.md` line 95. That command downloads a script from the
internet and runs it immediately, without giving you a chance to read it first.

This guide gives you the documented command **and** a safer two-step version that
does the same thing but lets you inspect the script before it runs. Both are
offered because the project itself forbids the download-and-run-immediately
pattern inside its own automation (`scripts/ci/Validate-WorkflowPolicy.ps1`
line 12).

**Recommended: download first, read, then run.**

- **Command ID:** `WIN-CMD-007`
- **Purpose:** Download the Codex installer to a file so you can inspect it.
- **Run in:** Windows PowerShell
- **Working directory:** Any (the file lands in your Downloads folder)
- **Privilege required:** Standard user
- **Internet access:** Required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Creates the file `codex-install.ps1` in your Downloads
  folder. Runs nothing.
- **Validation status:** Statically verified — not executed during validation

```powershell
Invoke-WebRequest -Uri "https://chatgpt.com/codex/install.ps1" -OutFile "$HOME\Downloads\codex-install.ps1"
```

Expected exit status: `0`.

**Success means:** the command finishes without an error message. Open the file
with `notepad "$HOME\Downloads\codex-install.ps1"` and read it. You are looking
for anything that is not an installer — if it looks wrong, stop and ask a
maintainer rather than running it.

---

- **Command ID:** `WIN-CMD-008`
- **Purpose:** Run the installer you just inspected.
- **Run in:** Windows PowerShell
- **Working directory:** Any
- **Privilege required:** Standard user
- **Internet access:** Required
- **Safe to copy and paste:** Yes, after you have read the file
- **Replace before running:** Nothing
- **Expected side effects:** Installs the Codex CLI and adds `codex` to your PATH.
  Changes your computer.
- **Validation status:** Blocked — the Codex CLI was not installed in the
  validation environment, because doing so requires network installation of
  third-party software and an OpenAI account.

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\Downloads\codex-install.ps1"
```

Expected exit status: `0`.

Representative output — **Unverified — Runtime Blocked**: progress text ending
with a success message.

**Success means:** after closing and reopening PowerShell, `WIN-CMD-009` prints a
version number.

**Alternative (the command the project documents).** If you prefer the project's
one-liner, it is:

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

This is functionally the same but runs the script without letting you read it
first. Prefer `WIN-CMD-007` plus `WIN-CMD-008`.

### 12.7 Confirm Codex is installed and sign in

- **Command ID:** `WIN-CMD-009`
- **Purpose:** Confirm the Codex CLI is on your PATH.
- **Run in:** Windows PowerShell (a **newly opened** window)
- **Working directory:** Any
- **Privilege required:** Standard user
- **Internet access:** Not required for this command
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Blocked — Codex was not installed in the validation
  environment

```powershell
codex --version
```

Expected exit status: `0`.

Representative output — **Unverified — Runtime Blocked**: a version number such as
`0.146.0`. The exact number will differ.

**Success means:** you see a version number rather than an error.

**Next step:** the first time you run an actual review, Codex will ask you to sign
in and will usually open a browser window. Complete that sign-in. Your ChatGPT
plan must include Codex access.

**Common failure:** `codex : The term 'codex' is not recognized...` — see
troubleshooting row `WIN-TRB-002`.

## 13. Download or Clone the Repository

You need two things in the same folder: a Git repository to review, and the
harness files.

The simplest arrangement, and the one this project is designed for, is to copy the
harness into the root of the repository you want to review (`README.md` line 31).
For your first run, cloning the harness itself gives you a working repository and
the harness at the same time.

- **Command ID:** `WIN-CMD-010`
- **Purpose:** Move to a sensible folder for projects.
- **Run in:** Windows PowerShell
- **Working directory:** Any
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Creates the folder `Projects` under your Documents
  folder if it does not exist
- **Validation status:** Statically verified

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\Documents\Projects" | Set-Location
```

Expected exit status: `0`.

**Success means:** the text before your cursor now ends with `\Documents\Projects>`.

---

- **Command ID:** `WIN-CMD-011`
- **Purpose:** Copy a repository from GitHub onto your computer.
- **Run in:** Windows PowerShell
- **Working directory:** `%USERPROFILE%\Documents\Projects`
- **Privilege required:** Standard user
- **Internet access:** Required
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_REPOSITORY_URL` — the web address of the
  repository, ending in `.git`. Example value:
  `https://github.com/rikterskale/codex-repo-review-harness.git`
- **Expected side effects:** Creates a new folder containing the repository
- **Validation status:** Statically verified

```powershell
git clone YOUR_REPOSITORY_URL
```

Expected exit status: `0`.

Representative output — **Code-Derived Output Shape**:

```text
Cloning into 'codex-repo-review-harness'...
remote: Enumerating objects: 120, done.
Receiving objects: 100% (120/120), done.
```

**Success means:** the last line says `done.` and a new folder appeared.

**Next step:** section 14.

**Common failure:** `fatal: repository ... not found` means the address is wrong or
the repository is private. See troubleshooting row `WIN-TRB-003`.

## 14. Find and Enter the Repository Folder

- **Command ID:** `WIN-CMD-012`
- **Purpose:** Move into the repository folder you just created.
- **Run in:** Windows PowerShell
- **Working directory:** `%USERPROFILE%\Documents\Projects`
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_PROJECT_FOLDER` — the folder name printed by
  `WIN-CMD-011`. Example value: `codex-repo-review-harness`
- **Expected side effects:** None
- **Validation status:** Verified

```powershell
Set-Location YOUR_PROJECT_FOLDER
```

Expected exit status: `0`.

**Success means:** the prompt now ends with your folder name followed by `>`.

**If the folder name contains a space**, wrap it in double quotes, for example
`Set-Location "My Project"`.

---

- **Command ID:** `WIN-CMD-013`
- **Purpose:** Prove you are in the right folder before running anything.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified

```powershell
Get-ChildItem -Force -Name
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output** (from the harness repository):

```text
.git
.github
.gitignore
AGENTS.md
CHANGELOG.md
LICENSE
README.md
SECURITY.md
VERSION
config
docs
prompts
reports
schemas
scripts
templates
tests
```

**Success means:** you can see `.git`, `scripts`, `config`, and `prompts` in the
list. If `.git` is missing you are not in a repository, and the review will fail
with exit code 3.

## 15. Create an Isolated Environment

**Not applicable to this project, and nothing needs to be created.**

An isolated environment (a "virtual environment") is a way to keep one project's
add-on libraries separate from another's. It is used by projects written in
Python, Node.js, and similar languages.

This project is written entirely in PowerShell and has no libraries to install.
There is no `requirements.txt`, no `package.json`, and no lock file anywhere in
the repository. Skip this section.

The two programs the harness depends on — Git and the Codex CLI — are installed
once for your whole computer, in section 12.

## 16. Install Project Dependencies

**Not applicable to this project. There is nothing to install here.**

As explained in section 15, the harness has no package dependencies. Its only
requirements are Git and the Codex CLI, which you installed in section 12.

Go directly to section 17.

## 17. Build or Install the Project

**Not applicable to this project. There is nothing to build.**

The harness is a set of script files that run directly. There is no compile step,
no installer, and no `setup` command.

If you cloned a *different* repository and want to review it with the harness,
the "installation" is simply copying the harness files into that repository's
root folder, so that `scripts\`, `prompts\`, `config\`, and `AGENTS.md` sit
alongside the code you want reviewed (`README.md` line 31).

Go to section 18 to check that everything is in place.

## 18. Verify the Installation

This is the harness's own health check. Run it before every review until you are
comfortable.

- **Command ID:** `WIN-CMD-014`
- **Purpose:** Check that every required harness file, Git, Codex, and the safety
  settings are present and correct.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder containing `scripts\`
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None. This script only reads; it never writes a file.
- **Validation status:** Verified

```powershell
.\scripts\Validate-Harness.ps1
```

Expected exit status: `0` when everything passes, `1` when at least one check
fails.

Representative output — **Verified Runtime Output** (captured on Windows 11 with
Git installed but Codex not yet installed):

```text
=== Codex Repo Review Harness Validation ===

[PASS] File exists: config\review-config.yaml
[PASS] File exists: prompts\system-review.md
[PASS] File exists: prompts\security-focus.md
[PASS] File exists: prompts\pr-diff-review.md
[PASS] File exists: AGENTS.md
[PASS] File exists: scripts\Run-Review.ps1
[PASS] File exists: scripts\Validate-Harness.ps1
[PASS] Git is installed
[PASS] Inside a Git repository
[FAIL] Codex CLI is installed
       Install with: powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
[PASS] Config declares sandbox: read-only
[PASS] Config has a base_branch
[PASS] reports/ directory exists

1 check(s) failed. Fix the issues above and re-run this script.
```

**Success means:** every line starts with `[PASS]` and the last line reads
`All checks passed.` The output above shows a *failure* on purpose, so you can
recognise one: the `[FAIL]` line names the problem and the yellow line beneath it
tells you the fix.

**Next step:** when all checks pass, go to section 19.

**Common failure:** `File ... cannot be loaded because running scripts is disabled
on this system` — you skipped `WIN-CMD-006`. See troubleshooting row `WIN-TRB-004`.

## 19. Complete the First Safe Successful Run

This is the smallest safe review you can do: the harness reviewing its own
repository, in read-only mode.

### 19.1 A note about `-DryRun`

The project documents a `-DryRun` switch as a way to "just check what the script
would do without calling the AI" (`docs/WINDOWS_BEGINNER_GUIDE.md` line 304).

**Fixed in 0.2.0.** In 0.1.0 the dry run refused to start unless the Codex CLI
was installed — running `.\scripts\Run-Review.ps1 -DryRun` on a machine without
Codex produced `Codex CLI is not installed or not on PATH.` and exit code `3`,
even though a dry run never calls Codex. It now completes without Codex, so you
can use it to check your configuration before section 12.6. Git is still
required, because the dry run resolves your repository and lists the files a
review would cover.

### 19.2 Run the review

- **Command ID:** `WIN-CMD-015`
- **Purpose:** Run a full, read-only AI review of the current repository.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder containing `scripts\`
- **Privilege required:** Standard user
- **Internet access:** Required — your code is sent to OpenAI for analysis
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Creates exactly three files in `reports\`. Never
  modifies your source code. Codex is forced into `read-only` mode by
  the `--sandbox read-only` argument `scripts/Run-Review.ps1` always builds.
- **Validation status:** Partially verified — the full pipeline was run end to end
  against a simulated Codex executable and produced correct artifacts. It was not
  run against the real Codex CLI, which was unavailable in the validation
  environment.

```powershell
.\scripts\Run-Review.ps1
```

Expected exit status: `0` on success. Other values mean specific failures — see
section 20.2.

Representative output — **Verified Runtime Output** (produced with a simulated
Codex; the file names on your machine will differ):

```text
Review finished. Markdown: C:\...\reports\review-20260731-213440-423-e4a65858.md; JSON: C:\...\reports\review-20260731-213440-423-e4a65858.json; SHA-256: C:\...\reports\review-20260731-213440-423-e4a65858.sha256
```

**Success means:** the last line begins with `Review finished.` and names three
files.

**How long it takes:** one to five minutes for a small project. Text may scroll
while it works. Do not close the window.

**Next step:** section 20.

**Common failures:**
- `Codex review failed with exit code ...` → row `WIN-TRB-005`
- `Codex review timed out after 900 seconds.` → row `WIN-TRB-006`
- `Review Markdown is missing required section: ...` → row `WIN-TRB-007`
- `Potential secret detected in the generated review artifact.` → row `WIN-TRB-009`

## 20. Understand the Screen Output, Exit Status, and Result Files

### 20.1 The three files

Every successful run writes **three** files into `reports\`, all sharing one name:

| File | What it is | Do you read it? |
|---|---|---|
| `review-<timestamp>-<id>.md` | The human-readable report | **Yes — this is the one you read** |
| `review-<timestamp>-<id>.json` | The same review as structured data, for tools | Only if you are automating |
| `review-<timestamp>-<id>.sha256` | Checksums proving the other two files were not altered | Only when you need to prove integrity |

The timestamp is UTC in the form `yyyyMMdd-HHmmss-fff` and the id is eight random
characters, so runs never overwrite each other
(see how `scripts/Run-Review.ps1` builds the report path from a UTC timestamp and a run id).

> Note: `docs/WINDOWS_BEGINNER_GUIDE.md` line 284 states that the report is "the
> only new file that was created". That is inaccurate for release 0.2.0 — three
> files are created. This guide reflects the actual behaviour.

- **Command ID:** `WIN-CMD-016`
- **Purpose:** List the reports you have, newest last.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified

```powershell
Get-ChildItem reports -File | Sort-Object LastWriteTime
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output**:

```text
    Length Name
    ------ ----
      1015 review-20260731-213440-423-e4a65858.md
      1653 review-20260731-213440-423-e4a65858.json
       214 review-20260731-213440-423-e4a65858.sha256
```

**Success means:** you see three files with the same long name and different
endings.

---

- **Command ID:** `WIN-CMD-017`
- **Purpose:** Open the report to read it.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_REPORT_FILE` — the exact `.md` name from
  `WIN-CMD-016`. Example value: `review-20260731-213440-423-e4a65858.md`
- **Expected side effects:** Opens Notepad
- **Validation status:** Statically verified

```powershell
notepad reports\YOUR_REPORT_FILE
```

Expected exit status: `0`.

**Success means:** Notepad opens and shows a document that starts with
`# Codex Repository Review Report`.

### 20.2 What the exit code means

The runner returns a specific number so scripts can react to failures
(the exit codes documented in the header of `scripts/Run-Review.ps1`). To see the number from the last command, run
`$LASTEXITCODE`.

| Exit code | Meaning | What to do |
|---:|---|---|
| `0` | Success. Report written. | Read the report. |
| `2` | Usage or configuration problem. | Check `config/review-config.yaml` and your command switches. Row `WIN-TRB-008`. |
| `3` | A prerequisite is missing (Git, Codex, or not in a repository). | Row `WIN-TRB-002`. |
| `4` | Codex itself failed. | Row `WIN-TRB-005`. |
| `5` | The report did not satisfy the harness's contract, or looked like it contained a secret. | Rows `WIN-TRB-007` and `WIN-TRB-009`. |
| `6` | The review took longer than the timeout. | Row `WIN-TRB-006`. |
| `7` | Codex produced more output than the size limit allows. | Row `WIN-TRB-010`. |

Exit codes `2` and `3` were **verified** during validation. The remaining codes are
**code-derived** from `scripts/Run-Review.ps1`.

### 20.3 How to read the report

The report always contains these sections, in this order:

- `## Executive Summary` — a few bullet points and an overall risk rating.
- `## Findings` — the issues found. Each begins with `### [SEVERITY] Title` where
  severity is `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, or `INFO`, and each has a
  Location, a Why it matters, an Evidence, and a Suggested fix line.
- `## Positive Observations` — things done well.
- `## Recommended Next Actions` — a numbered to-do list.

Start with the Executive Summary, then read the `CRITICAL` and `HIGH` findings.

**The title now appears once.** In 0.1.0 the line
`# Codex Repository Review Report` was printed **twice** near the top, once from
the harness header and once from the AI's report. In 0.2.0 the harness strips
the AI's copy, so the title you see is the one carrying the timestamp, base
branch, and sandbox mode. `REV-DOC-004` is closed.

**The `.md` and `.json` files now agree.** In 0.1.0 the JSON could hold fewer
findings than the Markdown, because only the JSON dropped findings below
`min_severity` (default `medium`, set in `config/review-config.yaml`). Both are
filtered to the same set in 0.2.0, and the run fails rather than writing two
files that disagree. Findings below `min_severity` appear in neither: lower the
setting if you want them.

### 20.4 Checking that a report was not tampered with

- **Command ID:** `WIN-CMD-018`
- **Purpose:** Recompute the checksum of a report and compare it to the recorded one.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_REPORT_FILE` — the `.md` name. Example value:
  `review-20260731-213440-423-e4a65858.md`
- **Expected side effects:** None
- **Validation status:** Verified

```powershell
Get-FileHash -Algorithm SHA256 reports\YOUR_REPORT_FILE
```

Expected exit status: `0`.

**Success means:** the `Hash` value shown matches the line for that file inside
the matching `.sha256` file. Open the `.sha256` file with Notepad to compare. The
recorded value is lower-case; the computed value is upper-case — that difference
does not matter.

## 21. Common Novice Workflows

### 21.1 Workflow: a security-focused review

**Objective:** review a repository with the emphasis on secrets, injection, and
authentication problems.
**Starting condition:** `WIN-CMD-014` passes with all `[PASS]` lines.
**Required values:** none.

- **Command ID:** `WIN-CMD-019`
- **Purpose:** Run the review using the security prompt instead of the general one.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Three new files in `reports\`
- **Validation status:** Statically verified — the switch is implemented at
  the `-Prompt` parameter of `scripts/Run-Review.ps1`

```powershell
.\scripts\Run-Review.ps1 -Prompt security-focus.md
```

Expected exit status: `0`.

**Checkpoint:** the closing line begins with `Review finished.`
**Evidence produced:** three files in `reports\`.
**Completion criteria:** the report opens and contains a `## Findings` section.
**Failure indicators:** any non-zero exit code; see section 20.2.
**Cancellation:** press `Ctrl` + `C` (section 23).
**Cleanup:** section 24.

**Important caution for this workflow.** A security review is the most likely one
to quote a credential out of your source code, which triggers the exit-code-5
defect described in row `WIN-TRB-009`. If this workflow fails with
`Potential secret detected in the generated review artifact.`, that is the defect,
not a problem with your repository.

### 21.2 Workflow: review only what changed against a branch

**Objective:** review the differences between your work and a base branch.
**Starting condition:** you are on a branch with commits that the base branch does
not have.
**Required values:** the base branch name.

- **Command ID:** `WIN-CMD-020`
- **Purpose:** Run the change-focused review prompt.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Three new files in `reports\`
- **Validation status:** Statically verified

```powershell
.\scripts\Run-Review.ps1 -Prompt pr-diff-review.md
```

Expected exit status: `0`.

---

- **Command ID:** `WIN-CMD-021`
- **Purpose:** Compare against a different base branch for one run only.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Required
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_BASE_BRANCH` — the branch to compare against.
  Example value: `develop`
- **Expected side effects:** Three new files in `reports\`
- **Validation status:** Statically verified — the switch is implemented at
  the `-RepositoryPath` parameter of `scripts/Run-Review.ps1`

```powershell
.\scripts\Run-Review.ps1 -BaseBranch YOUR_BASE_BRANCH
```

Expected exit status: `0`.

**Checkpoint:** the report header line `**Base branch:**` shows the branch you
named.

### 21.3 Workflow: test the harness itself

**Objective:** confirm the harness's own scripts are healthy after you change or
update them.
**Starting condition:** PowerShell 7 (`pwsh`) is installed (section 12.4).
**Required values:** none.

- **Command ID:** `WIN-CMD-022`
- **Purpose:** Run the harness's structural self-test.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified

```powershell
powershell -File tests\test_harness_structure.ps1
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output**:

```text
PASS: All structural tests succeeded.
```

---

- **Command ID:** `WIN-CMD-023`
- **Purpose:** Run the remaining self-tests.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Creates and deletes temporary folders under your
  `%TEMP%` directory
- **Validation status:** Verified — re-run on 2026-08-11 under Windows
  PowerShell 5.1.26100.8875. All nine `tests\test_*.ps1` scripts exited `0`,
  including `test_review_artifacts.ps1` and `test_runner_failure.ps1`, which an
  earlier revision of this guide recorded as PowerShell 7-only. PowerShell 7 is
  not required.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_review_helpers.ps1
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output**:

```text
PASS: review helper contract tests passed.
```

**Completion criteria:** the line begins with `PASS:`.
**Failure indicators:** any line beginning with `FAIL:` or a red error block.

## 22. Configuration, Environment Variables, and Credentials

### 22.1 The configuration file

All settings live in one file, `config\review-config.yaml`. Open it with
`notepad config\review-config.yaml`. The settings the harness actually reads are:

| Setting | Default | What it does |
|---|---|---|
| `base_branch` | `main` | The branch a diff review compares against. |
| `sandbox` | `read-only` | **Leave this alone.** The runner forces `read-only` regardless, and warns you if you changed it (the runner warns and forces `read-only` regardless). |
| `min_severity` | `medium` | Findings less severe than this are dropped from the JSON file. Allowed values: `critical`, `high`, `medium`, `low`, `info`. |
| `focus_areas` | seven areas | Topics the AI is told to prioritise. |
| `include_paths` | empty | Limit the review to certain folders. Empty means the whole repository. |
| `exclude_paths` | eight globs | Folders the review should skip. |
| `report.output_dir` | `reports` | Where reports are written. Must be a relative path — an absolute path or one containing `..` is rejected with exit code 2. |
| `report.max_findings` | `50` | If a review produces more findings than this, the run fails with exit code 5. |
| `model` | empty | Which AI model to ask for. Empty means the Codex default. |
| `extra_instructions` | four lines | Extra text prepended to every prompt. |

After editing, save the file and re-run `WIN-CMD-014` to confirm the harness still
validates.

### 22.2 Environment variables

**You do not need to set any environment variable to run a review on Windows.**

The harness reads no environment variables in the local path. `OPENAI_API_KEY`
appears only in the optional GitHub Actions workflow
(`.github/workflows/codex-review.yml` line 77) as a repository secret configured
on GitHub's website, never on your computer. If that secret is absent the
workflow stops at its credential preflight and says so, rather than failing
later inside the Codex action.

### 22.3 Credentials

Your Codex sign-in is handled by the Codex CLI itself, not by this harness. The
harness never asks you for a password, never stores one, and never writes one to
a file.

**Never** type a real API key, token, or password into any command in this guide,
and never paste one into `config\review-config.yaml`. The file is tracked by Git
and would be committed.

## 23. How to Stop or Cancel Safely

**To stop a running review:** click on the PowerShell window to focus it, then
press `Ctrl` + `C`.

This is safe at any moment. Because Codex is running in read-only mode, an
interrupted review cannot leave your source code in a half-changed state. At
worst, no report is written for that run.

**To check whether anything is still running:**

- **Command ID:** `WIN-CMD-024`
- **Purpose:** See whether a Codex process is still active after you cancelled.
- **Run in:** Windows PowerShell
- **Working directory:** Any
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Statically verified

```powershell
Get-Process codex -ErrorAction SilentlyContinue
```

Expected exit status: `0`.

**Success means:** nothing is printed — no Codex process is running.

**If a process is still listed**, close the PowerShell window; that ends the
background job the runner created. As a last resort, run
`Stop-Process -Name codex`.

**A known limitation:** if a review exceeds its timeout, the runner stops waiting
and exits with code 6, but the underlying Codex process is not guaranteed to be
terminated (see the timeout branch of `scripts/Run-Review.ps1`). Use `WIN-CMD-024` to check, and
close the window if one is left behind.

**There are no services, scheduled tasks, listeners, or containers to stop.** This
project creates none.

## 24. Cleanup, Uninstall, and Host Restoration

### 24.1 Delete old reports

Reports are ordinary text files and are safe to delete at any time. Git is already
configured to ignore them (`.gitignore` lines 2-3), so deleting them does not
affect your repository.

- **Command ID:** `WIN-CMD-025`
- **Purpose:** Delete all generated reports while keeping the folder.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Permanently deletes every file in `reports\` except
  `.gitkeep`. **Save any report you want to keep first.**
- **Validation status:** Statically verified

```powershell
Get-ChildItem reports -File -Exclude '.gitkeep' | Remove-Item
```

Expected exit status: `0`.

**Verify cleanup succeeded:** run `WIN-CMD-016`. It should list nothing.

### 24.2 Remove the harness from a project

The harness is just files. Delete `scripts\`, `prompts\`, `config\`, `templates\`,
`tests\`, `schemas\`, `reports\`, and `AGENTS.md` from your project folder and the
harness is gone. Nothing else on your computer is touched.

**Verify:** `Test-Path scripts\Run-Review.ps1` prints `False`.

### 24.3 Undo the execution-policy change

- **Command ID:** `WIN-CMD-026`
- **Purpose:** Return the PowerShell script-execution setting to its original state.
- **Run in:** Windows PowerShell
- **Working directory:** Any
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Removes the per-user execution-policy setting. After
  this, harness scripts will refuse to run until you set it again.
- **Validation status:** Statically verified

```powershell
Set-ExecutionPolicy -Scope CurrentUser Undefined
```

Expected exit status: `0`.

**Verify:** `WIN-CMD-005` prints `Undefined`.

### 24.4 Uninstall the prerequisites

Removing Git, PowerShell 7, or the Codex CLI is done through Windows, not through
this project: open **Settings → Apps → Installed apps**, find the program, and
choose **Uninstall**.

**What cannot be undone automatically:** any code you already sent to OpenAI as
part of a review cannot be recalled. Consider that before reviewing sensitive
repositories.

**What to keep before cleaning up:** copy any `.md` report you want to retain out
of `reports\` first, together with its matching `.sha256` file if you need to
prove it was unaltered.

## 25. Update, Upgrade, Downgrade, and Rollback

### 25.1 Check which version you have

- **Command ID:** `WIN-CMD-027`
- **Purpose:** Show the harness version.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified

```powershell
Get-Content VERSION
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output**:

```text
0.2.0
```

**Success means:** you see three numbers separated by dots. Compare that with the
newest heading in `CHANGELOG.md`.

### 25.2 Back up your settings before updating

- **Command ID:** `WIN-CMD-028`
- **Purpose:** Save a copy of your configuration and rules before an update
  overwrites them.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Creates two `.backup` files in the current folder
- **Validation status:** Statically verified

```powershell
Copy-Item config\review-config.yaml, AGENTS.md -Destination . -Force -PassThru | Rename-Item -NewName { $_.Name + '.backup' }
```

Expected exit status: `0`.

**Success means:** `Get-ChildItem *.backup` lists two files.

### 25.3 Update to the newest version

- **Command ID:** `WIN-CMD-029`
- **Purpose:** Fetch the newest harness code from GitHub.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Updates tracked files in your repository. Your
  uncommitted edits to those files may block the update.
- **Validation status:** Statically verified

```powershell
git pull
```

Expected exit status: `0`.

**Success means:** you see either `Already up to date.` or a list of updated files.

**Next step:** re-run `WIN-CMD-014` and `WIN-CMD-027`.

**Migrations:** release 0.2.0 has no data to migrate, and none of its fixes change
the report format. Reports written by 0.1.0 stay readable. If a future release changes `schema_version` in the JSON
file (currently `1.0`, `schemas/review-report.schema.json` line 7), check that
release's `CHANGELOG.md` entry.

### 25.4 Roll back to a previous version

- **Command ID:** `WIN-CMD-030`
- **Purpose:** Return the harness files to an earlier commit.
- **Run in:** Windows PowerShell
- **Working directory:** The repository folder
- **Privilege required:** Standard user
- **Internet access:** Not required (if the commit is already downloaded)
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_COMMIT_ID` — the identifier of the commit you
  want. Get it from `git log --oneline`. Example value: `26cc06c`
- **Expected side effects:** Changes which version of the files is on disk. Your
  reports and untracked files are not affected.
- **Validation status:** Statically verified

```powershell
git checkout YOUR_COMMIT_ID
```

Expected exit status: `0`.

**Success means:** `WIN-CMD-027` shows the older version number and
`WIN-CMD-014` still passes.

**To return to the newest version afterwards:** `git checkout main`.

**What cannot be rolled back:** reviews already sent to OpenAI, and any report you
deleted.

**Downgrade note:** you can return to 0.1.0 with `git checkout` of that commit,
but doing so reinstates three fixed defects: `REV-COR-001`, `REV-COR-002`, and
`REV-COR-004`. See section 30.4.

## 26. Troubleshooting Matrix

| ID | Exact error or symptom | Platform / shell | Likely cause | Exact corrective steps | Verification command | Expected fixed result | Alternative fix | Escalation evidence |
|---|---|---|---|---|---|---|---|---|
| `WIN-TRB-001` | `git : The term 'git' is not recognized as the name of a cmdlet...` | Windows PowerShell | Git is not installed, or the terminal was opened before installation finished | Install Git from https://git-scm.com/download/win accepting the default options, then **close every PowerShell window and open a new one** | `git --version` (`WIN-CMD-001`) | `git version 2.x.x.windows.1` | Restart the computer, then retry | Output of `WIN-CMD-001` and `$env:PATH` |
| `WIN-TRB-002` | `Codex CLI is not installed or not on PATH.` and exit code `3` | Windows PowerShell | Codex is not installed, or PATH has not refreshed | Complete section 12.6, then close and reopen PowerShell | `codex --version` (`WIN-CMD-009`) | A version number is printed | Sign out of Windows and back in to refresh PATH | Output of `WIN-CMD-009` and `WIN-CMD-014` |
| `WIN-TRB-003` | `fatal: repository 'URL' not found` | Windows PowerShell | The URL is wrong, or the repository is private and you are not signed in | Re-copy the URL from the green **Code** button on the GitHub page. For a private repository, sign in to Git first | `git clone YOUR_REPOSITORY_URL` (`WIN-CMD-011`) | `Cloning into '...'... done.` | Download the repository as a ZIP from GitHub and extract it | The exact URL you used, with any token removed |
| `WIN-TRB-004` | `File ...ps1 cannot be loaded because running scripts is disabled on this system` | Windows PowerShell | Execution policy is `Restricted` or `Undefined` | Run `WIN-CMD-006` and answer `Y`. Standard user is sufficient — do **not** use an Administrator window | `Get-ExecutionPolicy -Scope CurrentUser` (`WIN-CMD-005`) | `RemoteSigned` | Run the script once with `powershell -ExecutionPolicy Bypass -File .\scripts\Validate-Harness.ps1` | Output of `WIN-CMD-005` and the full error text |
| `WIN-TRB-005` | `Codex review failed with exit code N. Output: ...` and exit code `4` | Windows PowerShell | Codex itself failed — commonly a sign-in problem, a plan that lacks Codex access, or no internet | Run `codex --version` and then sign in when prompted. Confirm your ChatGPT plan includes Codex | `.\scripts\Run-Review.ps1` (`WIN-CMD-015`) | `Review finished. Markdown: ...` | Try again later; the service may be temporarily unavailable | The full `Output:` text with any token removed, plus `codex --version` |
| `WIN-TRB-006` | `Codex review timed out after 900 seconds.` and exit code `6` | Windows PowerShell | The repository is large, or the model is slow | Re-run with a longer limit: `.\scripts\Run-Review.ps1 -TimeoutSeconds 1800`. Or narrow the review by setting `include_paths` in `config\review-config.yaml` | `.\scripts\Run-Review.ps1 -TimeoutSeconds 1800` | `Review finished. ...` | Review a subfolder by setting `include_paths` | The timeout value used and the repository's file count |
| `WIN-TRB-007` | `Review Markdown is missing required section: ## Findings` and exit code `5` | Windows PowerShell | Codex did not follow the required report structure | Re-run the review; the model's output varies between runs. If it recurs, confirm `prompts\system-review.md` is unmodified | `.\scripts\Run-Review.ps1` (`WIN-CMD-015`) | `Review finished. ...` | Try `-Prompt security-focus.md`, which uses the same structure | The exact error line and `git status` for the `prompts` folder |
| `WIN-TRB-008` | `report.output_dir must be a repository-relative path.` and exit code `2` | Windows PowerShell | `output_dir` in the config is an absolute path or contains `..` | Open `config\review-config.yaml` and set the nested `output_dir` back to `reports` | `.\scripts\Validate-Harness.ps1` (`WIN-CMD-014`) | All `[PASS]` lines | Restore the file with `git checkout config/review-config.yaml` | The `report:` block from your config file |
| `WIN-TRB-009` | `Potential secret detected in the generated review artifact.` and exit code `5`, with no report written | Windows PowerShell | The report appears to contain an unredacted credential, so the harness refuses to write it. In 0.1.0 this also fired on the harness's *own* redaction placeholder, discarding harmless reports; that defect is fixed in 0.2.0 (`REV-COR-002` closed), so in 0.2.0 this means a credential really did survive redaction | Find the credential in your own code and remove it — the review is telling you it is there. If your code is clean, this is a redaction gap: narrow the review with `include_paths` to exclude the file, and report it to the maintainer | `.\scripts\Run-Review.ps1` (`WIN-CMD-015`) | `Review finished. ...` | Use `-Prompt pr-diff-review.md` on a change set that does not touch credential-bearing files | The exact error text, the `min_severity` setting, and whether the flagged value is a real credential |
| `WIN-TRB-010` | `Codex output exceeded 5242880 bytes.` and exit code `7` | Windows PowerShell | The review produced more than 5 MB of text | Narrow the scope using `include_paths` in `config\review-config.yaml`, or raise the limit for one run with `-MaxOutputBytes 10485760` | `.\scripts\Run-Review.ps1` (`WIN-CMD-015`) | `Review finished. ...` | Review one subfolder at a time | The repository size and the limit you used |
| `WIN-TRB-011` | `This folder is not inside a Git repository.` and exit code `3` | Windows PowerShell | The current folder is not a Git repository | Move into the repository with `Set-Location`, or create one with `git init` | `git rev-parse --is-inside-work-tree` | `true` | Clone a repository first (`WIN-CMD-011`) | Output of `Get-Location` and `WIN-CMD-013` |
| `WIN-TRB-012` | `pwsh : The term 'pwsh' is not recognized...` | Windows PowerShell | PowerShell 7 is not installed. You are running an older copy of a command, or documentation from before 2026-08-11, that called `pwsh`. No current command needs it | Replace `pwsh -NoProfile` with `powershell -NoProfile -ExecutionPolicy Bypass` and re-run. The scripts declare `#Requires -Version 5.1` and pass under Windows PowerShell 5.1 | `powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_review_helpers.ps1` | Exit status `0` | Install PowerShell 7 with `WIN-CMD-004`, then reopen PowerShell | Output of `WIN-CMD-003` and `$PSVersionTable.PSVersion` |
| `WIN-TRB-013` | Windows Defender or SmartScreen warns about the downloaded Codex installer | Windows | Windows flags files downloaded from the internet | Do **not** disable Defender or SmartScreen. Inspect the file first (`WIN-CMD-007`), confirm it came from `chatgpt.com`, and use **More info → Run anyway** only if you are satisfied it is genuine | `codex --version` (`WIN-CMD-009`) | A version number is printed | Ask your IT administrator to approve the installer | The exact warning text, the file name, and its `Get-FileHash` value |
| `WIN-TRB-014` | `Set-Location : Cannot find path ...` | Windows PowerShell | The folder name is misspelled, or contains a space and was not quoted | Run `Get-ChildItem -Name` to see the exact names, then quote any name containing a space: `Set-Location "My Project"` | `Get-Location` | The path shown ends with your folder name | Use Tab completion: type the first letters and press Tab | Output of `Get-ChildItem -Name` from the parent folder |
| `WIN-TRB-015` | The review succeeds but describes files that are not in your project, or reports almost nothing for a large project | Windows PowerShell 5.1 | This was a defect in 0.1.0: Windows PowerShell 5.1 starts background jobs in your Documents folder, so Codex reviewed the wrong directory. Fixed in 0.2.0, where the runner sets the directory explicitly inside the job (the `Set-Location` inside the background job in `scripts/Run-Review.ps1`). No automated test covers it, because the tests use a synthetic Codex that ignores its working directory | Do not trust the report's contents. Reopen finding `REV-COR-001` with the maintainer, quoting your `$PSVersionTable.PSVersion` | Compare the file paths named in the report's findings against `Get-ChildItem -Recurse -Name` in your repository | Every path named in the report exists in your repository | Run the review from PowerShell 7 instead: `pwsh -NoProfile -File .\scripts\Run-Review.ps1` | The report file, the output of `Get-Location`, and `$PSVersionTable.PSVersion` |

**When to stop and ask for help.** If a command fails twice with the same error
after you have applied the fix and the verification command still disagrees, stop.
Collect the outputs of `WIN-CMD-001`, `WIN-CMD-002`, `WIN-CMD-009`, and
`WIN-CMD-014`, plus the full error text, and open an issue. Remove any token,
key, or password from the text first.

## 27. Frequently Asked Questions

**Can the AI change or delete my code?**
No. `scripts/Run-Review.ps1` always passes `--sandbox read-only` to Codex,
and it does so even if you edit the configuration file to say otherwise
(line 48 warns you and overrides it).

**Where do my reports go?**
Into `reports\`, inside the repository folder. Change it with the nested
`output_dir` setting in `config\review-config.yaml`. It must stay a relative path.

**Does it cost money?**
The harness is free. The Codex CLI requires a ChatGPT plan that includes Codex.
Check current plan details with OpenAI.

**Do I need the GitHub Actions part?**
No. It is entirely optional and needs a separate `OPENAI_API_KEY` secret
configured on GitHub. Everything in this guide works without it.

**Why are there two title lines at the top of my report?**
There are not, in 0.2.0. That was a cosmetic defect in 0.1.0 (`REV-DOC-004`).

**Why does my JSON file have fewer findings than my Markdown report?**
Findings below the `min_severity` setting are filtered out of the JSON only. Read
the Markdown for the full list.

**Can I run this on Linux?**
Partly. See `docs/guides/LINUX_NOVICE_USABILITY_GUIDE.md` — the review runner has
not been verified on Linux and no Linux installation path is documented by this
project.

**Do I need to be an administrator?**
No, except possibly when installing PowerShell 7. Running reviews needs only a
standard user account.

## 28. Command Quick Reference

| ID | Command | Purpose |
|---|---|---|
| `WIN-CMD-001` | `git --version` | Check Git |
| `WIN-CMD-002` | `$PSVersionTable.PSVersion` | Check Windows PowerShell |
| `WIN-CMD-003` | `Get-Command pwsh -ErrorAction SilentlyContinue` | Check for PowerShell 7 |
| `WIN-CMD-004` | `winget install --id Microsoft.PowerShell --source winget` | Install PowerShell 7 |
| `WIN-CMD-005` | `Get-ExecutionPolicy -Scope CurrentUser` | Read the script policy |
| `WIN-CMD-006` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` | Allow harness scripts |
| `WIN-CMD-007` | `Invoke-WebRequest -Uri "https://chatgpt.com/codex/install.ps1" -OutFile "$HOME\Downloads\codex-install.ps1"` | Download the Codex installer |
| `WIN-CMD-008` | `powershell -ExecutionPolicy Bypass -File "$HOME\Downloads\codex-install.ps1"` | Install Codex |
| `WIN-CMD-009` | `codex --version` | Check Codex |
| `WIN-CMD-010` | `New-Item -ItemType Directory -Force -Path "$HOME\Documents\Projects" \| Set-Location` | Go to a projects folder |
| `WIN-CMD-011` | `git clone YOUR_REPOSITORY_URL` | Copy a repository |
| `WIN-CMD-012` | `Set-Location YOUR_PROJECT_FOLDER` | Enter the repository |
| `WIN-CMD-013` | `Get-ChildItem -Force -Name` | Confirm you are in the right folder |
| `WIN-CMD-014` | `.\scripts\Validate-Harness.ps1` | Health check |
| `WIN-CMD-015` | `.\scripts\Run-Review.ps1` | Run a review |
| `WIN-CMD-016` | `Get-ChildItem reports -File \| Sort-Object LastWriteTime` | List reports |
| `WIN-CMD-017` | `notepad reports\YOUR_REPORT_FILE` | Open a report |
| `WIN-CMD-018` | `Get-FileHash -Algorithm SHA256 reports\YOUR_REPORT_FILE` | Verify a report |
| `WIN-CMD-019` | `.\scripts\Run-Review.ps1 -Prompt security-focus.md` | Security review |
| `WIN-CMD-020` | `.\scripts\Run-Review.ps1 -Prompt pr-diff-review.md` | Change review |
| `WIN-CMD-021` | `.\scripts\Run-Review.ps1 -BaseBranch YOUR_BASE_BRANCH` | Change the base branch |
| `WIN-CMD-022` | `powershell -File tests\test_harness_structure.ps1` | Structural self-test |
| `WIN-CMD-023` | `powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_review_helpers.ps1` | Contract self-test |
| `WIN-CMD-024` | `Get-Process codex -ErrorAction SilentlyContinue` | Check for a leftover process |
| `WIN-CMD-025` | `Get-ChildItem reports -File -Exclude '.gitkeep' \| Remove-Item` | Delete reports |
| `WIN-CMD-026` | `Set-ExecutionPolicy -Scope CurrentUser Undefined` | Undo the policy change |
| `WIN-CMD-027` | `Get-Content VERSION` | Show the version |
| `WIN-CMD-028` | `Copy-Item config\review-config.yaml, AGENTS.md -Destination . -Force -PassThru \| Rename-Item -NewName { $_.Name + '.backup' }` | Back up settings |
| `WIN-CMD-029` | `git pull` | Update |
| `WIN-CMD-030` | `git checkout YOUR_COMMIT_ID` | Roll back |

## 29. Glossary

- **Absolute path** — a location written out in full from the drive letter, such
  as `C:\Users\you\Documents\Projects`. It means the same thing no matter where
  you are.
- **Administrator** — a Windows account with permission to change the whole
  computer. This guide does not require one.
- **Artifact** — any file a tool produces for you to keep, such as a report.
- **Clean-up** — deleting files a tool created so the computer returns to its
  earlier state.
- **Clone** — make a copy of a repository from the internet onto your computer.
- **Command** — one line of text you type into a terminal and run with Enter.
- **Configuration file** — a plain text file holding a program's settings. Here it
  is `config\review-config.yaml`.
- **Container** — a packaged, isolated environment for running software. This
  project does not use one.
- **Dependency** — a piece of software another program needs. This project has
  none of its own beyond Git and Codex.
- **Downgrade** — install an older version deliberately.
- **Environment variable** — a named value stored by Windows that programs can
  read. Written `$env:NAME` in PowerShell. This project needs none locally.
- **Exit code** — the number a program returns when it finishes. `0` means
  success. See section 20.2.
- **Log** — a running record of what a program did. This project writes reports
  rather than logs.
- **Package manager** — a program that installs other programs, such as `winget`.
- **Port / listener** — a numbered network channel a program can open to receive
  connections. This project opens none.
- **Process** — one running program.
- **Pull / update** — fetch the newest version of a repository.
- **Relative path** — a location written from where you currently are, such as
  `scripts\Run-Review.ps1`. It only works from the right folder.
- **Repository** — a project folder tracked by Git, containing a hidden `.git`
  folder.
- **Report** — the Markdown file this harness produces for you to read.
- **Rollback** — return to an earlier version after an update.
- **Root / `sudo`** — the Linux equivalent of Administrator. Not used on Windows.
- **Runtime** — the program that executes another program's code. Here it is
  PowerShell.
- **Service** — a program Windows runs in the background automatically. This
  project installs none.
- **Shell** — the program that reads and runs your commands. Here it is Windows
  PowerShell.
- **Standard output / standard error** — the two text streams a program writes.
  Normal messages go to standard output; error messages go to standard error and
  usually appear in red.
- **Terminal** — the window in which you type commands.
- **Uninstall** — remove a program from the computer.
- **Upgrade** — install a newer version.
- **Virtual environment** — an isolated set of libraries for one project. Not used
  by this project.
- **Working directory (current directory)** — the folder your terminal is
  currently in. Shown in the prompt and by `Get-Location`.

## 30. Validation Record, Known Limitations, and Support Boundaries

### 30.1 Validation environment

| Item | Value |
|---|---|
| Operating system | Windows 11 Pro, build 10.0.26200 |
| Architecture | x64 |
| Shell | Windows PowerShell 5.1.26100.8875 |
| Terminal | Windows PowerShell console |
| Git | 2.54.0.windows.1 |
| PowerShell 7 (`pwsh`) | **Not installed** |
| Codex CLI | **Not installed** |
| Privilege | Standard user |
| Date | 2026-08-13 |
| Tree under test | recorded as `reviewed_digest` in this guide's front matter |

### 30.2 Command validation totals

| Metric | Count |
|---|---:|
| Total commands | 30 |
| Verified by execution | 10 |
| Statically verified only | 17 |
| Blocked | 2 |
| Unsupported | 1 |
| Commands containing placeholders | 6 |
| Placeholders fully defined | 6 |
| Verified expected output | 10 |
| Code-derived output only | 16 |
| Unverified output | 4 |

### 30.3 Journey results

| Stage | Result |
|---|---|
| Prerequisites verified | **Pass** — Git and Windows PowerShell confirmed by execution |
| Installation verified | **Partial** — harness file layout confirmed; Codex CLI installation blocked |
| First safe successful run | **Partial** — the complete runner pipeline was executed end to end against a simulated Codex executable and produced correct Markdown, JSON, and SHA-256 artifacts. Not exercised against the real Codex CLI |
| Results located and interpreted | **Pass** — all three artifacts located, opened, and their contents explained |
| Representative failure recovered | **Pass** — exit codes 2 and 3 reproduced and their remedies confirmed |
| Cancellation verified | **Blocked** — no long-running real Codex process was available to interrupt |
| Cleanup verified | **Pass** — report deletion confirmed; the review left the repository working tree clean |
| Update verified | **Statically verified** — `git pull` is standard Git behaviour, not executed here |
| Rollback verified | **Statically verified** — `git checkout` is standard Git behaviour, not executed here |

### 30.4 Known limitations of release 0.2.0

1. **~~Codex is launched in the wrong directory.~~ FIXED in 0.2.0.** Previously
   recorded: with the repository under review at a temporary path, Codex
   reported being started in `C:\Users\<user>\Documents`, because Windows
   PowerShell 5.1 does not give background jobs the caller's working directory.
   The runner now sets the directory explicitly inside the background job
   (the `Set-Location` inside the background job in `scripts/Run-Review.ps1`), so the host's default no longer
   applies. **Code-derived, not re-reproduced:** the automated tests substitute
   a synthetic Codex command that ignores its working directory, so no test
   would catch a regression here. If a report ever names files outside your
   repository, reopen `REV-COR-001`.
2. **~~Reviews that quote credentials are discarded.~~ FIXED in 0.2.0.**
   Previously recorded: a report whose finding contained `PASSWORD=hunter2`
   caused exit code 5 and wrote zero files, because the secret detector matched
   the harness's own redaction placeholder. The detector now strips its
   placeholders before scanning, and `tests/test_review_helpers.ps1` asserts
   that a redacted credential finding stays publishable. `REV-COR-002` is
   closed.
3. **~~`-DryRun` requires the Codex CLI.~~ FIXED in 0.2.0.** Previously
   recorded: a dry run exited `3` on a machine without Codex, contradicting the
   one switch that exists to check things *before* installing it. The
   prerequisite is now skipped for a dry run and still enforced for a real one.
   Covered by `tests/test_novice_defect_regressions.ps1`, which asserts both
   halves. `REV-UX-001` is closed.
4. **~~The report title appears twice.~~ FIXED in 0.2.0.** Previously recorded:
   the harness header and the model's own report each supplied the title. The
   runner now strips the model's copy after the contract checks have run, so the
   header — the copy carrying the timestamp, base branch, and sandbox mode — is
   the one written. Covered by the same regression test. `REV-DOC-004` is
   closed.
5. **~~The JSON file can contain fewer findings than the Markdown.~~ FIXED in
   0.2.0.** Previously recorded: a two-finding report produced one JSON finding
   under the default `min_severity: medium`, because only the JSON was filtered.
   The runner now filters the Markdown to the same set and asserts the two agree
   before writing either (the finding-filter and consistency assertion in `scripts/Run-Review.ps1`). `REV-COR-004`
   is closed.
6. **~~Two self-tests fail under Windows PowerShell 5.1.~~ NO LONGER REPRODUCES.**
   Previously recorded: `tests\test_review_artifacts.ps1` and
   `tests\test_runner_failure.ps1` exited `1` under `powershell` and only passed
   under `pwsh`, despite declaring `#Requires -Version 5.1`. Tracked as
   `REV-TEST-001`.
   **Re-verified 2026-08-11** on Windows 11 Pro 10.0.26200 with Windows
   PowerShell 5.1.26100.8875: all nine `tests\test_*.ps1` scripts exit `0` under
   `powershell`, both named tests included. `REV-TEST-001` is closed and
   `README.md` no longer invokes `pwsh`. If you see this failure again, reopen
   the finding and record your `$PSVersionTable.PSVersion`.
7. **A timed-out review may leave a Codex process running.** Code-derived from
   the timeout branch of `scripts/Run-Review.ps1`. Use `WIN-CMD-024` to check.

### 30.5 Support boundaries

- Supported: native Windows 10/11 with Windows PowerShell 5.1 and Git.
- Not documented by this project, and therefore not covered here: WSL, Docker
  Desktop, containers, virtual machines, macOS, and Command Prompt.
- The Linux position is recorded separately in
  `docs/guides/LINUX_NOVICE_USABILITY_GUIDE.md`.
- This guide describes the tree recorded as `reviewed_digest` in its front
  matter. `scripts/ci/Validate-Release.ps1` fails if the harness moves on
  without the guide being re-read.

