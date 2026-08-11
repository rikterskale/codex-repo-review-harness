---
guide_id: linux-novice-usability
guide_schema_version: 1
platform: linux
canonical_path: docs/guides/LINUX_NOVICE_USABILITY_GUIDE.md
project_name: "Codex Repo Review Harness"
target_release: "0.1.0 (latest locally verifiable release; no Git tag and no GitHub Release exist)"
target_commit: "b72180d08e739cf404b7f0a62af998bb72af309f"
reviewed_head: "d05159bafabded4135ecb24cb62790b48c7b21b0"
support_status: unverified
alternative_support_paths: []
validation_status: partially_verified
validated_on: 2026-08-04
validated_environments:
  - "Ubuntu 24.04.4 LTS, x64, PowerShell 7 (/usr/bin/pwsh), GitHub Actions hosted runner image ubuntu-24.04 20260720.247.2 — evidence from workflow run 30662430133, job 91261545707"
primary_shells:
  - "PowerShell 7 (pwsh)"
  - "Bash (only to install prerequisites and to start pwsh)"
maintainer_source_of_truth: "README.md, AGENTS.md, config/review-config.yaml, scripts/Run-Review.ps1, .github/workflows/ci.yml"
known_limitations:
  - "This project documents no Linux installation path for the OpenAI Codex CLI. Every command that installs or runs Codex is Blocked in this guide rather than invented."
  - "scripts/Run-Review.ps1 and scripts/Validate-Harness.ps1 have never been executed on Linux by the project's CI or by this review."
  - "Three of the project's own test scripts fail on Linux because they invoke the Windows-only 'powershell' executable, and the CI job nevertheless reports success."
---

# Codex Repo Review Harness — Linux Novice Usability Guide

## 1. About This Guide

This guide is written for a person who has never opened a terminal, never used
Git, and never installed a developer tool on Linux. Every step tells you which
program to open, which folder to be in, exactly what to type, and how to tell
whether it worked.

The guide describes release **0.1.0** of the Codex Repo Review Harness at commit
`26cc06cf96cd2a854fe1f3fc9bc3c461b45f73c9`.

Each command has an identifier such as `LNX-CMD-001`. Quoting that identifier
tells a maintainer exactly which step failed.

**Please read section 5 before anything else.** This project's Linux support is
*unverified*, and this guide is deliberately honest about which parts are proven
to work and which are not. It does not invent commands to fill the gaps.

Validation labels used throughout:

| Label | Meaning |
|---|---|
| **Verified** | Proven to work on Linux by the project's own automated test run (GitHub Actions run 30662430133, job 91261545707, Ubuntu 24.04). |
| **Statically verified** | Read out of the project's source and believed correct, but never executed on Linux. |
| **Blocked** | Could not be validated, with the reason stated. |
| **Unsupported** | The project provides no Linux path for this, and none is invented here. |

The companion Windows guide is `docs/guides/WINDOWS_NOVICE_USABILITY_GUIDE.md`.
Do not mix commands between the two — the shells and path separators differ.

## 2. What This Project Does

The Codex Repo Review Harness is a small set of PowerShell scripts, prompt files,
and settings that ask an AI to review a Git repository and save the result as a
report you can read.

It does not contain the AI. The AI is the separate **OpenAI Codex CLI**, a program
you install yourself. The harness's job is to call Codex in a restricted way:

- It forces Codex into `read-only` mode so Codex cannot change, create, or delete
  your files (`scripts/Run-Review.ps1` line 79).
- It sends the same reviewed instructions every time, from `prompts/`.
- It checks the returned report against a fixed structure and refuses to save one
  that does not match.
- It writes three files per review: a report, a machine-readable copy, and a
  checksum file.

The scripts are written in PowerShell, which is a Microsoft language that also
runs on Linux. On Linux the program is called `pwsh`.

## 3. Who Should Use It

Use this guide if you run Linux and want a written AI code review of a Git
repository.

You do not need to know how to program. You do need:

- A Linux system where you can install software (usually via `sudo`).
- An OpenAI ChatGPT account that includes Codex access.
- A repository you are allowed to review.
- Tolerance for an unverified path — see section 5. If you need a proven path
  today, use the Windows guide instead.

## 4. Safety, Authorization, and Data Handling

**What leaves your computer.** The Codex CLI reads your source code locally and
sends what it needs to OpenAI to produce the review. Do not use this tool on code
you are not allowed to send to a third party.

**What the harness writes.** Three files per run, inside the `reports/` folder.
Your source code is never modified (`scripts/Run-Review.ps1` lines 111, 123, 124).

**Privileges.** Nothing in this project needs `sudo` or a root shell. `sudo` is
needed only to *install* prerequisites such as PowerShell and Git, and each such
step says so explicitly. Never run the review itself with `sudo`.

**File permissions.** This project does not require you to change file ownership
or permission bits, and this guide never tells you to run `chmod 777`. PowerShell
scripts on Linux are executed by passing them to `pwsh`, so they do not need an
executable bit.

**Ports, services, containers.** This project opens no network port, installs no
`systemd` service, and uses no container. There is nothing to clean up in those
areas.

**Secrets.** Never type a real password, API key, or token into any command here.

**Known safety-relevant defect.** If the review contains a finding that quotes a
credential — for example `PASSWORD=hunter2` copied from your code — the harness
misidentifies its own redaction placeholder as a real secret, aborts with exit
code 5, and writes no report. Reproduced on Windows; the same code path is used on
Linux. See troubleshooting row `LNX-TRB-008`.

## 5. Platform Support Status

**This repository does not currently document native Linux execution, and the
review runner has never been verified on Linux. Support status: `unverified`.**

This is not a formatting technicality. Here is precisely what is and is not known.

**What is proven to work on Linux.** The project's continuous-integration
workflow runs on `ubuntu-latest` (`.github/workflows/ci.yml` line 27). In workflow
run 30662430133, job 91261545707, on Ubuntu 24.04 with PowerShell 7, these
scripts ran and printed a `PASS` line:

- `tests/test_harness_structure.ps1`
- `scripts/ci/Test-ReportContract.ps1`
- `tests/test_security_regressions.ps1`
- `tests/test_review_helpers.ps1`
- `scripts/ci/Validate-Release.ps1`
- `scripts/ci/Validate-WorkflowPolicy.ps1`
- `scripts/ci/Test-PowerShellSyntax.ps1`

So the harness's file layout, configuration parser, report contract, and secret
redaction all work under PowerShell 7 on Linux.

**What is proven to fail on Linux.** In the same job, three test scripts failed
with `The term 'powershell' is not recognized`:

- `tests/test_review_artifacts.ps1` (line 28)
- `tests/test_runner_failure.ps1` (line 15)
- `tests/test_clean_room.ps1` (line 10)

They call `powershell`, which is the *Windows* PowerShell executable and does not
exist on Linux. The job still reported success, so this failure is currently
invisible to the maintainers.

**What has never been tried on Linux.** `scripts/Run-Review.ps1` and
`scripts/Validate-Harness.ps1` — the two scripts you actually use — are not
executed by any Linux test. Their behaviour on Linux is therefore inferred from
their source code only.

**What is missing entirely.** The repository contains no Linux installation
instructions for the OpenAI Codex CLI. `README.md` line 29 documents only a
Windows PowerShell installer, and `docs/WINDOWS_BEGINNER_GUIDE.md` is
Windows-only. This guide will **not** invent a Linux Codex installation command.
Section 12.4 tells you where to get the authoritative instructions instead.

**Consequence.** You can install the harness, validate it, and read its
configuration on Linux with reasonable confidence. You cannot rely on this project
for a documented, tested Linux review run. Section 30 records this as a
portability finding.

## 6. What You Will Accomplish

Working through this guide, you will:

1. Confirm which Linux distribution and shell you have.
2. Install Git and PowerShell 7 if they are missing.
3. Obtain the harness repository.
4. Run the harness's own self-tests — the parts proven to work on Linux.
5. Run the health check.
6. Learn what a review would produce, where it lands, and how to interpret it.
7. Learn how to cancel, clean up, update, and roll back.

You will **not** complete a real AI review in this guide, because the Codex CLI
installation step is not documented by this project for Linux. Section 19 explains
exactly where that journey stops and what to do about it.

## 7. Before You Begin Checklist

- [ ] A Linux system you can install software on. **Required.**
- [ ] Knowledge of which distribution you run. **Required.** Check with `LNX-CMD-001`.
- [ ] About 300 MB of free disk space for PowerShell, plus space for your project.
- [ ] An internet connection. Required to install tools and to run a review.
- [ ] `sudo` rights, or an administrator who has them. **Required only to install.**
- [ ] Git. **Required.** Check with `LNX-CMD-003`.
- [ ] PowerShell 7 (`pwsh`). **Required.** Check with `LNX-CMD-004`.
- [ ] OpenAI Codex CLI. **Required for a real review, not documented by this project for Linux.**
- [ ] A ChatGPT plan that includes Codex. **Required for a real review.**
- [ ] A Git repository on disk. **Required.**

**Which steps change your computer:** installing Git and PowerShell modify the
system and need `sudo`. Cloning a repository and running the self-tests only
create files inside your own home directory.

**Case sensitivity.** Linux treats `README.md` and `readme.md` as different files.
Type paths exactly as shown, including capital letters.

## 8. Computer and Software Requirements

| Requirement | Exact need | Why | How to check |
|---|---|---|---|
| Distribution | Ubuntu 24.04 is the only distribution with evidence behind it | The project's CI runs on the `ubuntu-latest` runner image, Ubuntu 24.04.4 LTS | `LNX-CMD-001` |
| Architecture | x64 | The CI runner is x64. No other architecture has evidence | `LNX-CMD-002` |
| Shell for installation | Bash | Standard on Ubuntu | `LNX-CMD-002` |
| Shell for the harness | PowerShell 7 (`pwsh`) | Every harness script is PowerShell | `LNX-CMD-004` |
| Git | Any recent version | `scripts/Run-Review.ps1` line 26 refuses to run without it | `LNX-CMD-003` |
| Codex CLI | A version supporting `codex exec --sandbox read-only` | `scripts/Run-Review.ps1` lines 79-80 | `LNX-CMD-011` |
| Account | A ChatGPT plan including Codex | Codex requires sign-in | Sign-in prompt |
| Privilege | Standard user to run; `sudo` to install | No harness script requires elevation | — |

**Other distributions.** Fedora, RHEL, Arch, SUSE, Alpine, and Debian are *not*
covered. The project has never been tested on them. PowerShell 7 is available for
several of them, but this guide will not print package commands it cannot support
with evidence. If you use one of those distributions, follow Microsoft's official
PowerShell installation page for your distribution, then return to section 13.

**Note on the two credentials.** Running a review locally uses your **ChatGPT
sign-in**. The optional GitHub Actions workflow uses an **`OPENAI_API_KEY`
repository secret** (`.github/workflows/codex-review.yml` line 60). They are not
interchangeable, and you need neither to follow sections 13 through 18.

## 9. Terms and Concepts You Need to Know

Full definitions are in section 29. The essentials:

- **Terminal** — the window where you type commands. Open it with `Ctrl`+`Alt`+`T`
  on most desktop Linux systems.
- **Shell** — the program inside the terminal that reads your commands. Yours is
  probably Bash. This project needs a second shell, PowerShell 7 (`pwsh`).
- **Working directory** — the folder your terminal is currently in.
- **Repository** — a project folder tracked by Git, containing a hidden `.git`
  folder.
- **`sudo`** — a prefix that runs one command with administrator rights. It will
  ask for your password. Use it only where this guide says to.
- **Exit code** — the number a program returns when it finishes; `0` means
  success. See section 20.2.
- **Package manager** — the program that installs software. On Ubuntu it is `apt`.

## 10. Choose the Correct Installation Path

| Path | Status | Use it when |
|---|---|---|
| Ubuntu 24.04, PowerShell 7, native | **Best available — partially verified** | You want the closest thing to a supported Linux path |
| Another Linux distribution with PowerShell 7 | **Unverified** | You accept that nothing has been tested |
| Container | **Not documented by this project** | — |
| Virtual machine running Windows | **Alternative** | You need the proven path; follow the Windows guide inside the VM |

Follow the Ubuntu path below. If a proven end-to-end review matters more to you
than running on Linux, use a Windows machine or a Windows virtual machine and
follow `docs/guides/WINDOWS_NOVICE_USABILITY_GUIDE.md` instead.

## 11. Open the Correct Terminal or Shell

You will use **two** shells in this guide, and it matters which one you are in.

**Bash** — for installing software. This is the shell you get by default.

1. Press `Ctrl` + `Alt` + `T`, or open your applications menu and choose
   **Terminal**.
2. A window opens with a prompt that usually ends in `$`.

**PowerShell 7 (`pwsh`)** — for everything to do with the harness itself. You start
it *from* Bash by typing `pwsh` and pressing Enter. The prompt changes to `PS`
followed by your current folder.

To leave PowerShell and return to Bash, type `exit` and press Enter.

Throughout this guide each command block is labelled **Run in: Bash** or
**Run in: PowerShell 7 (pwsh)**. Getting this wrong is the most common beginner
mistake on Linux with this project — Bash does not understand PowerShell commands
and will answer `command not found`.

## 12. Check and Install Prerequisites

### 12.1 Identify your distribution

- **Command ID:** `LNX-CMD-001`
- **Purpose:** Show which Linux distribution and version you are running.
- **Run in:** Bash
- **Working directory:** Any
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Statically verified — standard Linux command, not
  executed during this review

```bash
cat /etc/os-release
```

Expected exit status: `0`.

Representative output — **Code-Derived Output Shape**:

```text
PRETTY_NAME="Ubuntu 24.04.4 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
```

**Success means:** you can read a `PRETTY_NAME` line. If it says Ubuntu 24.04, you
are on the one configuration with evidence behind it. Anything else is unverified
— re-read section 8.

**Next step:** 12.2.

### 12.2 Identify your shell and architecture

- **Command ID:** `LNX-CMD-002`
- **Purpose:** Confirm you are in Bash and see your CPU architecture.
- **Run in:** Bash
- **Working directory:** Any
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Statically verified

```bash
echo "$SHELL" && uname -m
```

Expected exit status: `0`.

Representative output — **Code-Derived Output Shape**:

```text
/bin/bash
x86_64
```

**Success means:** the first line contains `bash` and the second says `x86_64`.

**Common failure:** if the second line says `aarch64` you are on ARM. Nothing in
this project forbids ARM, but no evidence supports it either.

### 12.3 Check for Git

- **Command ID:** `LNX-CMD-003`
- **Purpose:** Confirm Git is installed.
- **Run in:** Bash
- **Working directory:** Any
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Statically verified

```bash
git --version
```

Expected exit status: `0`.

Representative output — **Code-Derived Output Shape**:

```text
git version 2.54.0
```

**Success means:** you see `git version` and some numbers.

**If Git is missing**, install it with `sudo apt update && sudo apt install git`.
`sudo` is required because installing software changes the whole system; it will
ask for your login password. Then re-run this command.

### 12.4 Check for PowerShell 7

- **Command ID:** `LNX-CMD-004`
- **Purpose:** Confirm PowerShell 7 is installed and see its version.
- **Run in:** Bash
- **Working directory:** Any
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified — `pwsh` is present and runs every harness test
  script in the project's Ubuntu CI job

```bash
pwsh --version
```

Expected exit status: `0`.

Representative output — **Code-Derived Output Shape**:

```text
PowerShell 7.4.6
```

**Success means:** the output begins with `PowerShell 7`.

**If you see `pwsh: command not found`**, PowerShell is not installed. This
project does not document how to install it. Use Microsoft's official
installation instructions for your exact distribution, which are the authoritative
source, then re-run this command. This guide will not print an `apt` repository
command it has not verified, because an incorrect package-source command can leave
your system in a broken state.

**Verification after installing:** re-run `LNX-CMD-004` and confirm the version
begins with `7`.

### 12.5 Install the OpenAI Codex CLI

- **Command ID:** `LNX-CMD-005`
- **Purpose:** Install the Codex CLI on Linux.
- **Run in:** Bash
- **Working directory:** —
- **Privilege required:** —
- **Internet access:** Required
- **Safe to copy and paste:** —
- **Replace before running:** —
- **Expected side effects:** —
- **Validation status:** **Unsupported — this repository documents no Linux
  installation command for the Codex CLI, and none is invented here.**

There is no command block for this step, deliberately.

`README.md` line 29 and `docs/WINDOWS_BEGINNER_GUIDE.md` line 95 give only a
Windows PowerShell installer. No Linux equivalent appears anywhere in the
repository. Printing a guessed command here would violate this guide's rule
against inventing steps, and a wrong installation command is a real risk to your
system.

**What to do instead:**

1. Consult the official OpenAI Codex CLI documentation and its release page for
   the current Linux installation method.
2. After installing, verify with `LNX-CMD-011`.
3. Ask the harness maintainer to add a documented and tested Linux installation
   path. This gap is recorded as finding `REV-LNX-GUIDE-001`.

**Stop condition.** If you cannot install the Codex CLI, you can still complete
sections 13 through 18 and 21.3 — the harness installs and self-tests fine
without Codex. You cannot complete section 19, the actual review.

## 13. Download or Clone the Repository

- **Command ID:** `LNX-CMD-006`
- **Purpose:** Create and enter a folder for your projects.
- **Run in:** Bash
- **Working directory:** Any
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Creates `~/projects` if it does not exist
- **Validation status:** Statically verified

```bash
mkdir -p ~/projects && cd ~/projects
```

Expected exit status: `0`.

**Success means:** the prompt now shows `~/projects`.

---

- **Command ID:** `LNX-CMD-007`
- **Purpose:** Copy a repository from GitHub onto your computer.
- **Run in:** Bash
- **Working directory:** `~/projects`
- **Privilege required:** Ordinary user
- **Internet access:** Required
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_REPOSITORY_URL` — the repository web address
  ending in `.git`. Example value:
  `https://github.com/rikterskale/codex-repo-review-harness.git`
- **Expected side effects:** Creates a new folder containing the repository
- **Validation status:** Statically verified

```bash
git clone YOUR_REPOSITORY_URL
```

Expected exit status: `0`.

Representative output — **Code-Derived Output Shape**:

```text
Cloning into 'codex-repo-review-harness'...
Receiving objects: 100% (120/120), done.
```

**Success means:** the last line says `done.`

**Common failure:** `fatal: repository ... not found` — see row `LNX-TRB-002`.

## 14. Find and Enter the Repository Folder

- **Command ID:** `LNX-CMD-008`
- **Purpose:** Move into the repository folder.
- **Run in:** Bash
- **Working directory:** `~/projects`
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_PROJECT_FOLDER` — the folder name printed by
  `LNX-CMD-007`. Example value: `codex-repo-review-harness`
- **Expected side effects:** None
- **Validation status:** Statically verified

```bash
cd YOUR_PROJECT_FOLDER
```

Expected exit status: `0`.

**Success means:** the prompt ends with your folder name.

**If the folder name contains a space**, wrap it in quotes: `cd "My Project"`.

**Remember Linux is case-sensitive** — `cd codex-repo-review-harness` works,
`cd Codex-Repo-Review-Harness` does not.

---

- **Command ID:** `LNX-CMD-009`
- **Purpose:** Prove you are in the right folder.
- **Run in:** Bash
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Statically verified

```bash
pwd && ls -a
```

Expected exit status: `0`.

Representative output — **Code-Derived Output Shape**:

```text
/home/you/projects/codex-repo-review-harness
.  ..  .git  .github  .gitignore  AGENTS.md  CHANGELOG.md  LICENSE  README.md
SECURITY.md  VERSION  config  docs  prompts  reports  schemas  scripts
templates  tests
```

**Success means:** you can see `.git`, `scripts`, `config`, and `prompts`. If
`.git` is missing you are not in a repository and the review will fail with exit
code 3.

## 15. Create an Isolated Environment

**Not applicable to this project, and nothing needs to be created.**

An isolated environment keeps one project's add-on libraries separate from
another's. It is used by Python, Node.js, and similar projects.

This project is written entirely in PowerShell and has no libraries to install.
There is no `requirements.txt`, `package.json`, or lock file anywhere in the
repository. Skip this section.

The two programs the harness depends on — Git and PowerShell 7 — are installed
once for the whole system, in section 12.

## 16. Install Project Dependencies

**Not applicable to this project. There is nothing to install here.**

As explained in section 15, the harness has no package dependencies. Its only
requirements are Git, PowerShell 7, and (for a real review) the Codex CLI.

Go directly to section 17.

## 17. Build or Install the Project

**Not applicable to this project. There is nothing to build.**

The harness is a set of script files that run directly through `pwsh`. There is no
compile step and no installer.

On Linux you do **not** need to make the `.ps1` files executable with `chmod`,
because you always run them by handing them to `pwsh`, as shown in section 18.

If you want to review a *different* repository, copy the harness folders
(`scripts/`, `prompts/`, `config/`, `templates/`, `tests/`, `schemas/`,
`reports/`) and `AGENTS.md` into that repository's root, alongside the code you
want reviewed (`README.md` line 31).

## 18. Verify the Installation

### 18.1 Start PowerShell

- **Command ID:** `LNX-CMD-010`
- **Purpose:** Switch from Bash into PowerShell 7.
- **Run in:** Bash
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Starts a new shell. Type `exit` to return to Bash.
- **Validation status:** Verified — `pwsh` runs on the project's Ubuntu CI job

```bash
pwsh
```

Expected exit status: `0`.

Representative output — **Code-Derived Output Shape**:

```text
PowerShell 7.4.6
PS /home/you/projects/codex-repo-review-harness>
```

**Success means:** your prompt now begins with `PS`. Every remaining command in
sections 18 to 21 is typed here, not in Bash.

### 18.2 Confirm Codex is available (optional)

- **Command ID:** `LNX-CMD-011`
- **Purpose:** Check whether the Codex CLI is installed.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Blocked — the Codex CLI has no documented Linux
  installation path in this repository, so it could not be installed or tested

```powershell
codex --version
```

Expected exit status: `0`.

Representative output — **Unverified — Runtime Blocked**: a version number.

**Success means:** a version number rather than an error.

**If it fails**, that is expected — see section 12.5. You can still complete 18.3.

### 18.3 Run the harness health check

- **Command ID:** `LNX-CMD-012`
- **Purpose:** Check that every required harness file, Git, Codex, and the safety
  defaults are present.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None — the script only reads
- **Validation status:** Statically verified — this script is not run by the
  project's Linux CI and has never been executed on Linux. Its cmdlets are
  cross-platform, so it is expected to work, but that expectation is unproven.

```powershell
./scripts/Validate-Harness.ps1
```

Expected exit status: `0` when everything passes, `1` when a check fails.

Representative output — **Code-Derived Output Shape** (this is the Windows-verified
output; the Linux output should be identical apart from path separators):

```text
=== Codex Repo Review Harness Validation ===

[PASS] File exists: config\review-config.yaml
[PASS] File exists: prompts\system-review.md
...
[FAIL] Codex CLI is installed
       Install with: powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
[PASS] Config declares sandbox: read-only
[PASS] Config has a base_branch
[PASS] reports/ directory exists

1 check(s) failed. Fix the issues above and re-run this script.
```

**Success means:** every line reads `[PASS]` and the closing line says
`All checks passed.`

**Expected failure on Linux:** the `Codex CLI is installed` check will fail unless
you installed Codex yourself, and its suggested fix is a Windows command. That
mismatch is a documentation defect in release 0.1.0 (finding `REV-DOC-005`), not a
problem with your system.

**Common failure:** `./scripts/Validate-Harness.ps1: The term ... is not
recognized` usually means you are still in Bash. Run `LNX-CMD-010` first. See row
`LNX-TRB-001`.

## 19. Complete the First Safe Successful Run

**On Linux this journey stops here, and it is important to say so plainly rather
than print a command that has never been run.**

- **Command ID:** `LNX-CMD-013`
- **Purpose:** Run a full read-only AI review of the current repository.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user — never use `sudo`
- **Internet access:** Required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Creates exactly three files in `reports/`. Never
  modifies your source code.
- **Validation status:** **Blocked** — requires the Codex CLI, which has no
  documented Linux installation path in this repository. The script has never been
  executed on Linux by the project's CI or by this review.

```powershell
./scripts/Run-Review.ps1
```

Expected exit status: `0` on success; see section 20.2 for other values.

Representative output — **Unverified — Runtime Blocked**. On Windows the verified
output is:

```text
Review finished. Markdown: .../reports/review-20260731-213440-423-e4a65858.md; JSON: .../reports/review-20260731-213440-423-e4a65858.json; SHA-256: .../reports/review-20260731-213440-423-e4a65858.sha256
```

**Success would mean:** a closing line beginning `Review finished.` naming three
files.

**What is genuinely unknown on Linux:**

- Whether `codex exec --sandbox read-only` behaves the same way.
- Whether the background-job mechanism the runner uses
  (`scripts/Run-Review.ps1` lines 86-97) launches Codex in the repository folder.
  On Windows PowerShell 5.1 this was **reproduced as broken** — Codex was launched
  in the user's Documents folder instead of the repository under review
  (finding `REV-COR-001`). PowerShell 7 is documented to behave differently, so
  Linux may be unaffected, but this has not been proven.

**What you should do instead, today:**

1. Complete section 21.3, the self-tests. Those *are* proven on Linux and confirm
   the harness itself is healthy.
2. For a real review, use the Windows path in
   `docs/guides/WINDOWS_NOVICE_USABILITY_GUIDE.md`, on a Windows machine or a
   Windows virtual machine.
3. Ask the maintainer to add a tested Linux path. This is recorded as findings
   `REV-COMPAT-001` and `REV-LNX-GUIDE-001`.

## 20. Understand the Screen Output, Exit Status, and Result Files

This section describes what a review *produces*. It is derived from the code and
was verified on Windows; the file formats are platform-independent.

### 20.1 The three files

Every successful run writes three files into `reports/`, sharing one name:

| File | What it is | Do you read it? |
|---|---|---|
| `review-<timestamp>-<id>.md` | The human-readable report | **Yes** |
| `review-<timestamp>-<id>.json` | The same review as structured data | Only for automation |
| `review-<timestamp>-<id>.sha256` | Checksums proving the other two are unaltered | Only for integrity checks |

The timestamp is UTC in the form `yyyyMMdd-HHmmss-fff` and the id is eight random
characters, so runs never overwrite each other
(`scripts/Run-Review.ps1` lines 57-61).

- **Command ID:** `LNX-CMD-014`
- **Purpose:** List the reports you have.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Statically verified

```powershell
Get-ChildItem reports -File | Sort-Object LastWriteTime
```

Expected exit status: `0`.

**Success means:** three files with the same name and different endings, or
nothing at all if you have not run a review.

---

- **Command ID:** `LNX-CMD-015`
- **Purpose:** Read a report in the terminal.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_REPORT_FILE` — the `.md` name from
  `LNX-CMD-014`. Example value: `review-20260731-213440-423-e4a65858.md`
- **Expected side effects:** None
- **Validation status:** Statically verified

```powershell
Get-Content reports/YOUR_REPORT_FILE
```

Expected exit status: `0`.

**Success means:** text scrolls past beginning with
`# Codex Repository Review Report`.

### 20.2 What the exit code means

To see the exit code of the last command in PowerShell, type `$LASTEXITCODE`.

| Exit code | Meaning | What to do |
|---:|---|---|
| `0` | Success. Report written. | Read the report. |
| `2` | Usage or configuration problem. | Row `LNX-TRB-007`. |
| `3` | A prerequisite is missing (Git, Codex, or not in a repository). | Rows `LNX-TRB-003` and `LNX-TRB-004`. |
| `4` | Codex itself failed. | Row `LNX-TRB-005`. |
| `5` | The report failed the harness's contract, or looked like it held a secret. | Rows `LNX-TRB-006` and `LNX-TRB-008`. |
| `6` | The review exceeded the timeout. | Row `LNX-TRB-009`. |
| `7` | Codex produced more output than allowed. | Row `LNX-TRB-010`. |

Codes `2` and `3` were verified on Windows. All are code-derived from
`scripts/Run-Review.ps1` and none has been observed on Linux.

### 20.3 How to read the report

The report always contains `## Executive Summary`, `## Findings`,
`## Positive Observations`, and `## Recommended Next Actions`, in that order. Each
finding starts with `### [SEVERITY] Title` and carries Location, Why it matters,
Evidence, and Suggested fix lines.

Two known oddities in release 0.1.0, both verified on Windows:

1. The title `# Codex Repository Review Report` appears **twice**. Harmless.
2. The `.json` file may hold **fewer** findings than the `.md`, because findings
   below `min_severity` (default `medium`) are dropped from the JSON only. Trust
   the Markdown.

### 20.4 Verify a report was not altered

- **Command ID:** `LNX-CMD-016`
- **Purpose:** Recompute a report's checksum.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_REPORT_FILE` — the `.md` name. Example value:
  `review-20260731-213440-423-e4a65858.md`
- **Expected side effects:** None
- **Validation status:** Statically verified

```powershell
Get-FileHash -Algorithm SHA256 reports/YOUR_REPORT_FILE
```

Expected exit status: `0`.

**Success means:** the `Hash` value matches the line for that file in the matching
`.sha256` file. Upper- versus lower-case does not matter.

## 21. Common Novice Workflows

### 21.1 Workflow: a security-focused review

**Objective:** review with emphasis on secrets, injection, and authentication.
**Starting condition:** `LNX-CMD-012` passes and Codex is installed.
**Required values:** none.

- **Command ID:** `LNX-CMD-017`
- **Purpose:** Run the review with the security prompt.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Three new files in `reports/`
- **Validation status:** Blocked — depends on the Codex CLI

```powershell
./scripts/Run-Review.ps1 -Prompt security-focus.md
```

Expected exit status: `0`.

**Checkpoint:** a closing line beginning `Review finished.`
**Evidence produced:** three files in `reports/`.
**Completion criteria:** the report opens and has a `## Findings` section.
**Failure indicators:** any non-zero exit code.
**Cancellation:** `Ctrl` + `C` (section 23).
**Cleanup:** section 24.
**Caution:** this is the workflow most likely to trigger the exit-code-5 defect in
row `LNX-TRB-008`.

### 21.2 Workflow: review only what changed

**Objective:** review the difference against a base branch.
**Starting condition:** you are on a branch with commits the base does not have.
**Required values:** the base branch name.

- **Command ID:** `LNX-CMD-018`
- **Purpose:** Run the change-focused prompt against a chosen base branch.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Required
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_BASE_BRANCH` — the branch to compare against.
  Example value: `develop`
- **Expected side effects:** Three new files in `reports/`
- **Validation status:** Blocked — depends on the Codex CLI

```powershell
./scripts/Run-Review.ps1 -Prompt pr-diff-review.md -BaseBranch YOUR_BASE_BRANCH
```

Expected exit status: `0`.

**Checkpoint:** the report header line `**Base branch:**` names your branch.

### 21.3 Workflow: test the harness itself — the proven Linux path

This is the one workflow with real Linux evidence behind it. Every command here
is proven by the project's Ubuntu CI job.

**Objective:** confirm the harness's own scripts are healthy.
**Starting condition:** you are in PowerShell 7 in the repository folder.
**Required values:** none.

- **Command ID:** `LNX-CMD-019`
- **Purpose:** Run the structural self-test.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified on Ubuntu 24.04

```powershell
pwsh -NoProfile -File tests/test_harness_structure.ps1
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output**:

```text
PASS: All structural tests succeeded.
```

---

- **Command ID:** `LNX-CMD-020`
- **Purpose:** Run the report-contract self-test.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified on Ubuntu 24.04

```powershell
pwsh -NoProfile -File scripts/ci/Test-ReportContract.ps1
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output**:

```text
PASS: report contract fixture is valid.
```

---

- **Command ID:** `LNX-CMD-021`
- **Purpose:** Run the secret-redaction and prompt-injection self-test.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified on Ubuntu 24.04

```powershell
pwsh -NoProfile -File tests/test_security_regressions.ps1
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output**:

```text
PASS: secret redaction and prompt-injection fixtures passed.
```

---

- **Command ID:** `LNX-CMD-022`
- **Purpose:** Run the helper contract self-test.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Verified on Ubuntu 24.04

```powershell
pwsh -NoProfile -File tests/test_review_helpers.ps1
```

Expected exit status: `0`.

Representative output — **Verified Runtime Output**:

```text
PASS: review helper contract tests passed.
```

**Completion criteria for this workflow:** all four commands print a line
beginning `PASS:`.

**Three further test scripts exist and will fail on Linux.**
`tests/test_review_artifacts.ps1`, `tests/test_runner_failure.ps1`, and
`tests/test_clean_room.ps1` call the Windows-only `powershell` executable and stop
with `The term 'powershell' is not recognized`. Do not run them on Linux and do
not treat their failure as a problem with your setup. This is finding
`REV-TEST-002`.

## 22. Configuration, Environment Variables, and Credentials

### 22.1 The configuration file

All settings live in `config/review-config.yaml`. Open it with
`Get-Content config/review-config.yaml` in PowerShell, or `nano
config/review-config.yaml` in Bash. The settings the harness reads are:

| Setting | Default | What it does |
|---|---|---|
| `base_branch` | `main` | The branch a diff review compares against. |
| `sandbox` | `read-only` | **Leave this alone.** The runner forces `read-only` regardless and warns if you changed it (`scripts/Run-Review.ps1` line 48). |
| `min_severity` | `medium` | Findings below this are dropped from the JSON file. Values: `critical`, `high`, `medium`, `low`, `info`. |
| `focus_areas` | seven areas | Topics the AI prioritises. |
| `include_paths` | empty | Limit the review to certain folders. Empty means everything. |
| `exclude_paths` | eight globs | Folders to skip. |
| `report.output_dir` | `reports` | Where reports are written. Must be a relative path without `..`, or the run fails with exit code 2. |
| `report.max_findings` | `50` | More findings than this fails the run with exit code 5. |
| `model` | empty | Which AI model to request. |
| `extra_instructions` | four lines | Text prepended to every prompt. |

After editing, re-run `LNX-CMD-012`.

**A Linux-specific caution.** Use forward slashes in `output_dir` (for example
`reports` or `build/reports`). A Windows-style value containing a backslash would
be treated as part of the folder name on Linux.

### 22.2 Environment variables

**You do not need to set any environment variable to run a review on Linux.**

The local path reads none. `OPENAI_API_KEY` appears only in the GitHub Actions
workflow (`.github/workflows/codex-review.yml` line 60) as a repository secret
configured on GitHub's website, never in your shell.

Do not add `export OPENAI_API_KEY=...` to your `~/.bashrc`. It would not be used
by the local runner and would leave a secret in a plain file.

### 22.3 Credentials

Your Codex sign-in is handled by the Codex CLI itself. The harness never asks for,
stores, or writes a credential. Never put a real key into
`config/review-config.yaml` — that file is tracked by Git and would be committed.

## 23. How to Stop or Cancel Safely

**To stop a running review:** click the terminal window and press `Ctrl` + `C`.

This is safe at any point. Because Codex runs read-only, an interrupted review
cannot leave your source code half-changed. At worst no report is written.

- **Command ID:** `LNX-CMD-023`
- **Purpose:** Check whether a Codex process survived the cancellation.
- **Run in:** Bash
- **Working directory:** Any
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Statically verified

```bash
pgrep -a codex
```

Expected exit status: `0` if a process is found, `1` if none is.

**Success means:** no output and exit status `1` — nothing is left running.

**If a process is listed**, close the terminal window, which ends the background
job. As a last resort run `pkill codex`.

**A known limitation:** if a review exceeds its timeout the runner stops waiting
and exits with code 6, but the underlying Codex process is not guaranteed to be
terminated (`scripts/Run-Review.ps1` lines 92-95). Use `LNX-CMD-023` to check.

**There are no services, timers, listeners, or containers to stop.** This project
creates none, so there is nothing for `systemctl` to do here.

## 24. Cleanup, Uninstall, and Host Restoration

### 24.1 Delete old reports

Reports are ordinary text files, safe to delete at any time, and already ignored
by Git (`.gitignore` lines 2-3).

- **Command ID:** `LNX-CMD-024`
- **Purpose:** Delete all generated reports while keeping the folder.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Permanently deletes every file in `reports/` except
  `.gitkeep`. **Save anything you want to keep first.**
- **Validation status:** Statically verified

```powershell
Get-ChildItem reports -File -Exclude '.gitkeep' | Remove-Item
```

Expected exit status: `0`.

**Verify cleanup succeeded:** run `LNX-CMD-014`; it should list nothing.

### 24.2 Remove the harness from a project

The harness is only files. Delete `scripts/`, `prompts/`, `config/`, `templates/`,
`tests/`, `schemas/`, `reports/`, and `AGENTS.md` and it is gone. Nothing outside
the project folder is touched — no system files, no shell profile, no PATH entry.

**Verify:** `test -f scripts/Run-Review.ps1 && echo present || echo removed`
prints `removed`.

### 24.3 Restore the host

This project makes no host changes to undo. It does not modify your PATH, your
`~/.bashrc`, any `systemd` unit, any firewall rule, or any file permission.

The only system-level changes you made were installing Git and PowerShell 7 in
section 12, and they are removed through your package manager if you want them
gone — for example `sudo apt remove powershell` on Ubuntu. `sudo` is required
because removing system software affects all users.

**Verify:** `pwsh --version` reports `command not found` once PowerShell is removed.

**What cannot be undone:** code already sent to OpenAI during a review cannot be
recalled. Consider that before reviewing sensitive repositories.

**What to keep first:** copy any `.md` report you want to retain out of `reports/`
along with its `.sha256` file.

## 25. Update, Upgrade, Downgrade, and Rollback

### 25.1 Check which version you have

- **Command ID:** `LNX-CMD-025`
- **Purpose:** Show the harness version.
- **Run in:** PowerShell 7 (pwsh)
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** None
- **Validation status:** Statically verified

```powershell
Get-Content VERSION
```

Expected exit status: `0`.

Representative output — **Code-Derived Output Shape**:

```text
0.1.0
```

**Success means:** three numbers separated by dots, matching the newest heading in
`CHANGELOG.md`.

### 25.2 Back up your settings before updating

- **Command ID:** `LNX-CMD-026`
- **Purpose:** Save copies of your configuration and rules before an update.
- **Run in:** Bash
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Creates two `.backup` files
- **Validation status:** Statically verified

```bash
cp config/review-config.yaml config/review-config.yaml.backup && cp AGENTS.md AGENTS.md.backup
```

Expected exit status: `0`.

**Success means:** `ls *.backup config/*.backup` lists two files.

### 25.3 Update to the newest version

- **Command ID:** `LNX-CMD-027`
- **Purpose:** Fetch the newest harness code.
- **Run in:** Bash
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Required
- **Safe to copy and paste:** Yes
- **Replace before running:** Nothing
- **Expected side effects:** Updates tracked files. Uncommitted edits may block it.
- **Validation status:** Statically verified

```bash
git pull
```

Expected exit status: `0`.

**Success means:** `Already up to date.` or a list of updated files.

**Next step:** re-run `LNX-CMD-025` and `LNX-CMD-012`.

**Migrations:** release 0.1.0 has no data to migrate. Older reports remain
readable. If a future release changes `schema_version` in the JSON report
(currently `1.0`, `schemas/review-report.schema.json` line 7), read that release's
`CHANGELOG.md` entry.

### 25.4 Roll back to a previous version

- **Command ID:** `LNX-CMD-028`
- **Purpose:** Return the harness files to an earlier commit.
- **Run in:** Bash
- **Working directory:** The repository folder
- **Privilege required:** Ordinary user
- **Internet access:** Not required if the commit is already downloaded
- **Safe to copy and paste:** **No — replace the placeholder first**
- **Replace before running:** `YOUR_COMMIT_ID` — from `git log --oneline`.
  Example value: `26cc06c`
- **Expected side effects:** Changes which version is on disk. Reports and
  untracked files are unaffected.
- **Validation status:** Statically verified

```bash
git checkout YOUR_COMMIT_ID
```

Expected exit status: `0`.

**Success means:** `LNX-CMD-025` shows the older version and `LNX-CMD-012` still
passes.

**To return to the newest version:** `git checkout main`.

**What cannot be rolled back:** reviews already sent to OpenAI, and deleted
reports.

**Downgrade note:** 0.1.0 is the first release, so there is nothing to downgrade
to yet.

## 26. Troubleshooting Matrix

| ID | Exact error or symptom | Platform / shell | Likely cause | Exact corrective steps | Verification command | Expected fixed result | Alternative fix | Escalation evidence |
|---|---|---|---|---|---|---|---|---|
| `LNX-TRB-001` | `./scripts/Validate-Harness.ps1: command not found` | Linux / Bash | You are in Bash, but harness scripts are PowerShell | Type `pwsh` and press Enter to switch shells (`LNX-CMD-010`), then re-run the command | `$PSVersionTable.PSVersion` | A table with `Major` = `7` | Run it in one step from Bash: `pwsh -NoProfile -File ./scripts/Validate-Harness.ps1` | The prompt text and the output of `echo $SHELL` |
| `LNX-TRB-002` | `fatal: repository 'URL' not found` | Linux / Bash | Wrong URL, or a private repository you are not signed in to | Re-copy the address from the green **Code** button on the GitHub page; sign in to Git for private repositories | `git clone YOUR_REPOSITORY_URL` (`LNX-CMD-007`) | `Cloning into '...'... done.` | Download a ZIP from GitHub and unzip it with `unzip` | The URL used, with any token removed |
| `LNX-TRB-003` | `pwsh: command not found` | Linux / Bash | PowerShell 7 is not installed | Install PowerShell 7 using Microsoft's official instructions for your distribution. This project documents none, so do not guess a package command | `pwsh --version` (`LNX-CMD-004`) | Output begins `PowerShell 7` | Use the Windows guide on a Windows machine or VM | Output of `LNX-CMD-001` and `LNX-CMD-004` |
| `LNX-TRB-004` | `Codex CLI is not installed or not on PATH.` and exit code `3` | Linux / pwsh | The Codex CLI is absent. **Expected on Linux** — this project documents no Linux installation path | Follow the official OpenAI Codex CLI documentation. Do not follow the Windows command shown by the validator | `codex --version` (`LNX-CMD-011`) | A version number | Complete only the self-tests in section 21.3, which need no Codex | Output of `LNX-CMD-012`, noting finding `REV-LNX-GUIDE-001` |
| `LNX-TRB-005` | `Codex review failed with exit code N. Output: ...` and exit code `4` | Linux / pwsh | Codex itself failed — commonly sign-in, plan access, or no internet | Run `codex --version` and complete any sign-in prompt. Confirm your ChatGPT plan includes Codex | `./scripts/Run-Review.ps1` (`LNX-CMD-013`) | `Review finished. ...` | Retry later; the service may be unavailable | The full `Output:` text with tokens removed |
| `LNX-TRB-006` | `Review Markdown is missing required section: ## Findings` and exit code `5` | Linux / pwsh | Codex did not follow the required report structure | Re-run; model output varies. If it recurs, confirm `prompts/system-review.md` is unmodified with `git status` | `./scripts/Run-Review.ps1` (`LNX-CMD-013`) | `Review finished. ...` | Try `-Prompt security-focus.md`, same structure | The exact error line and `git status` output |
| `LNX-TRB-007` | `report.output_dir must be a repository-relative path.` and exit code `2` | Linux / pwsh | `output_dir` is absolute or contains `..` | Edit `config/review-config.yaml` and set the nested `output_dir` back to `reports` | `./scripts/Validate-Harness.ps1` (`LNX-CMD-012`) | All `[PASS]` lines | Restore with `git checkout config/review-config.yaml` | The `report:` block of your config |
| `LNX-TRB-008` | `Potential secret detected in the generated review artifact.` and exit code `5`, no report written | Linux / pwsh | **Known defect in release 0.1.0.** The report quoted a credential such as `PASSWORD=...`; the harness redacts it, then its own detector matches the redaction placeholder and discards the whole report | No user-side setting avoids this. Re-run and hope the wording differs, or use `include_paths` to exclude the credential-bearing file. Report it to the maintainer | `./scripts/Run-Review.ps1` (`LNX-CMD-013`) | `Review finished. ...` | Use `-Prompt pr-diff-review.md` on a change set that avoids those files | The exact error text and a note that finding `REV-COR-002` is suspected |
| `LNX-TRB-009` | `Codex review timed out after 900 seconds.` and exit code `6` | Linux / pwsh | Large repository or slow model | Re-run with `./scripts/Run-Review.ps1 -TimeoutSeconds 1800`, or narrow the review with `include_paths` | `./scripts/Run-Review.ps1 -TimeoutSeconds 1800` | `Review finished. ...` | Review one subfolder at a time | The timeout used and the repository's file count |
| `LNX-TRB-010` | `Codex output exceeded 5242880 bytes.` and exit code `7` | Linux / pwsh | The review produced more than 5 MB of text | Narrow the scope with `include_paths`, or raise the limit for one run with `-MaxOutputBytes 10485760` | `./scripts/Run-Review.ps1` (`LNX-CMD-013`) | `Review finished. ...` | Review one subfolder at a time | The repository size and the limit used |
| `LNX-TRB-011` | `This folder is not inside a Git repository.` and exit code `3` | Linux / pwsh | The current folder is not a repository | `cd` into the repository, or create one with `git init` | `git rev-parse --is-inside-work-tree` | `true` | Clone a repository first (`LNX-CMD-007`) | Output of `pwd` and `ls -a` |
| `LNX-TRB-012` | `The term 'powershell' is not recognized` while running a test | Linux / pwsh | **Known defect.** `tests/test_review_artifacts.ps1`, `tests/test_runner_failure.ps1`, and `tests/test_clean_room.ps1` call the Windows-only `powershell` executable | Do not run these three on Linux. Run only the four commands in section 21.3. Nothing is wrong with your system | `pwsh -NoProfile -File tests/test_harness_structure.ps1` (`LNX-CMD-019`) | `PASS: All structural tests succeeded.` | Run the full suite on Windows with PowerShell 7 | The script name and line number, noting finding `REV-TEST-002` |
| `LNX-TRB-013` | `Permission denied` when running a script | Linux / Bash | You tried to execute the `.ps1` file directly | Do not `chmod` the file. Run it through PowerShell: `pwsh -NoProfile -File ./scripts/Validate-Harness.ps1` | `pwsh -NoProfile -File ./scripts/Validate-Harness.ps1` | The validation banner appears | Start `pwsh` first, then use `./scripts/...` | The exact command you typed and `ls -l` of the script |
| `LNX-TRB-014` | `cd: no such file or directory` | Linux / Bash | Wrong capitalisation — Linux paths are case-sensitive — or a space in the name | Run `ls` to see the exact name, then type it exactly. Quote names with spaces: `cd "My Project"` | `pwd` | The path ends with your folder name | Use Tab completion: type a few letters and press Tab | Output of `ls` in the parent folder |

**When to stop and ask for help.** If a command fails twice after you applied the
fix and the verification command still disagrees, stop. Collect the outputs of
`LNX-CMD-001`, `LNX-CMD-004`, `LNX-CMD-011`, and `LNX-CMD-012`, plus the full
error text, and open an issue. Remove any token, key, or password first.

## 27. Frequently Asked Questions

**Does this project officially support Linux?**
No. Support status is `unverified`. Part of the harness is proven to run on Ubuntu
by the project's own CI; the review runner is not. See section 5.

**Can the AI change or delete my code?**
No. `scripts/Run-Review.ps1` line 79 always passes `--sandbox read-only`, even if
you edit the configuration file to say otherwise.

**Do I need `sudo`?**
Only to install Git and PowerShell. Never run a review with `sudo`.

**Do I need to `chmod +x` the scripts?**
No. You always run them through `pwsh`, so no executable bit is required.

**Where do reports go?**
Into `reports/` inside the repository folder. Change it with the nested
`output_dir` setting; it must stay a relative path.

**Why do three of the tests fail on my machine?**
They call the Windows-only `powershell` program. It is a defect in the project,
not in your system. See row `LNX-TRB-012`.

**Why are there two title lines in the report?**
A known cosmetic defect in release 0.1.0.

**Can I use Docker instead?**
The project provides no container definition, so this guide does not describe one.

**Which distribution should I use?**
Ubuntu 24.04 is the only one with evidence behind it, because that is what the
project's CI runs.

## 28. Command Quick Reference

| ID | Shell | Command | Purpose |
|---|---|---|---|
| `LNX-CMD-001` | Bash | `cat /etc/os-release` | Identify the distribution |
| `LNX-CMD-002` | Bash | `echo "$SHELL" && uname -m` | Identify shell and architecture |
| `LNX-CMD-003` | Bash | `git --version` | Check Git |
| `LNX-CMD-004` | Bash | `pwsh --version` | Check PowerShell 7 |
| `LNX-CMD-005` | — | *(no command — Codex CLI has no documented Linux path)* | See section 12.5 |
| `LNX-CMD-006` | Bash | `mkdir -p ~/projects && cd ~/projects` | Create a projects folder |
| `LNX-CMD-007` | Bash | `git clone YOUR_REPOSITORY_URL` | Copy a repository |
| `LNX-CMD-008` | Bash | `cd YOUR_PROJECT_FOLDER` | Enter the repository |
| `LNX-CMD-009` | Bash | `pwd && ls -a` | Confirm the folder |
| `LNX-CMD-010` | Bash | `pwsh` | Switch into PowerShell |
| `LNX-CMD-011` | pwsh | `codex --version` | Check Codex |
| `LNX-CMD-012` | pwsh | `./scripts/Validate-Harness.ps1` | Health check |
| `LNX-CMD-013` | pwsh | `./scripts/Run-Review.ps1` | Run a review (blocked) |
| `LNX-CMD-014` | pwsh | `Get-ChildItem reports -File \| Sort-Object LastWriteTime` | List reports |
| `LNX-CMD-015` | pwsh | `Get-Content reports/YOUR_REPORT_FILE` | Read a report |
| `LNX-CMD-016` | pwsh | `Get-FileHash -Algorithm SHA256 reports/YOUR_REPORT_FILE` | Verify a report |
| `LNX-CMD-017` | pwsh | `./scripts/Run-Review.ps1 -Prompt security-focus.md` | Security review |
| `LNX-CMD-018` | pwsh | `./scripts/Run-Review.ps1 -Prompt pr-diff-review.md -BaseBranch YOUR_BASE_BRANCH` | Change review |
| `LNX-CMD-019` | pwsh | `pwsh -NoProfile -File tests/test_harness_structure.ps1` | Structural self-test |
| `LNX-CMD-020` | pwsh | `pwsh -NoProfile -File scripts/ci/Test-ReportContract.ps1` | Contract self-test |
| `LNX-CMD-021` | pwsh | `pwsh -NoProfile -File tests/test_security_regressions.ps1` | Redaction self-test |
| `LNX-CMD-022` | pwsh | `pwsh -NoProfile -File tests/test_review_helpers.ps1` | Helper self-test |
| `LNX-CMD-023` | Bash | `pgrep -a codex` | Check for a leftover process |
| `LNX-CMD-024` | pwsh | `Get-ChildItem reports -File -Exclude '.gitkeep' \| Remove-Item` | Delete reports |
| `LNX-CMD-025` | pwsh | `Get-Content VERSION` | Show the version |
| `LNX-CMD-026` | Bash | `cp config/review-config.yaml config/review-config.yaml.backup && cp AGENTS.md AGENTS.md.backup` | Back up settings |
| `LNX-CMD-027` | Bash | `git pull` | Update |
| `LNX-CMD-028` | Bash | `git checkout YOUR_COMMIT_ID` | Roll back |

## 29. Glossary

- **Absolute path** — a location written from the top of the filesystem, such as
  `/home/you/projects`. It means the same thing from anywhere.
- **Administrator** — on Linux this is the `root` account. See `root` and `sudo`.
- **Artifact** — any file a tool produces for you to keep, such as a report.
- **Bash** — the default shell on most Linux systems.
- **Clean-up** — deleting files a tool created so the system returns to its
  earlier state.
- **Clone** — make a copy of a repository from the internet onto your computer.
- **Command** — one line of text you type and run with Enter.
- **Configuration file** — a plain text file holding settings. Here,
  `config/review-config.yaml`.
- **Container** — a packaged, isolated environment for running software. This
  project does not use one.
- **Dependency** — software another program needs. This project has none of its
  own beyond Git, PowerShell, and Codex.
- **Downgrade** — install an older version deliberately.
- **Environment variable** — a named value the shell stores that programs can
  read. Set with `export NAME=value` in Bash. This project needs none locally.
- **Exit code** — the number a program returns when it finishes; `0` means
  success. See section 20.2.
- **Log** — a running record of what a program did. This project writes reports
  rather than logs.
- **Package manager** — the program that installs software; `apt` on Ubuntu.
- **Port / listener** — a numbered network channel a program can open to receive
  connections. This project opens none.
- **PowerShell 7 (`pwsh`)** — the shell the harness scripts are written for. It is
  a separate program from Bash and must be installed.
- **Process** — one running program.
- **Pull / update** — fetch the newest version of a repository.
- **Relative path** — a location written from where you are, such as
  `scripts/Run-Review.ps1`. It only works from the right folder.
- **Repository** — a project folder tracked by Git, containing a hidden `.git`
  folder.
- **Report** — the Markdown file the harness produces for you to read.
- **Rollback** — return to an earlier version after an update.
- **Root** — the all-powerful Linux administrator account. You should not need it.
- **Runtime** — the program that executes another program's code. Here, PowerShell.
- **Service** — a program the system runs in the background, usually managed by
  `systemd`. This project installs none.
- **Shell** — the program that reads and runs your commands. Bash and PowerShell
  are both shells.
- **Standard output / standard error** — the two text streams a program writes.
  Normal messages go to standard output, errors to standard error.
- **`sudo`** — a prefix that runs one command as the administrator, after asking
  for your password. Needed only to install software here.
- **Terminal** — the window in which you type commands.
- **Uninstall** — remove software from the system.
- **Upgrade** — install a newer version.
- **Virtual environment** — an isolated set of libraries for one project. Not used
  by this project.
- **Working directory (current directory)** — the folder your terminal is in,
  shown by `pwd`.

## 30. Validation Record, Known Limitations, and Support Boundaries

### 30.1 Validation environment

| Item | Value |
|---|---|
| Operating system | Ubuntu 24.04.4 LTS (GitHub Actions runner image ubuntu-24.04, 20260720.247.2) |
| Architecture | x64 |
| Shell | PowerShell 7 at `/usr/bin/pwsh` |
| Terminal | GitHub Actions non-interactive runner |
| Git | 2.54.0 |
| Codex CLI | **Not installed — no documented Linux installation path** |
| Privilege | Ordinary user (`runner`) |
| Date | 2026-07-31 |
| Commit under test | `26cc06cf96cd2a854fe1f3fc9bc3c461b45f73c9` |
| Evidence | GitHub Actions workflow run 30662430133, job 91261545707 |

No interactive Linux desktop was available to this review. All Linux runtime
evidence comes from the project's own CI job log, which is authoritative for the
scripts it executed and silent about the rest.

### 30.2 Command validation totals

| Metric | Count |
|---|---:|
| Total commands | 28 (27 executable, 1 deliberately absent) |
| Verified by execution on Linux | 6 |
| Statically verified only | 17 |
| Blocked | 4 |
| Unsupported | 1 |
| Commands containing placeholders | 5 |
| Placeholders fully defined | 5 |
| Verified expected output | 5 |
| Code-derived output only | 17 |
| Unverified output | 5 |

### 30.3 Journey results

| Stage | Result |
|---|---|
| Prerequisites verified | **Partial** — `pwsh` and Git proven present in the CI environment; not verified on an end-user desktop |
| Installation verified | **Partial** — the harness is only files, and its layout check passes on Linux. The Codex CLI could not be installed |
| First safe successful run | **Blocked** — requires the Codex CLI, which has no documented Linux installation path. `scripts/Run-Review.ps1` has never been executed on Linux |
| Results located and interpreted | **Statically verified** — the artifact format is platform-independent and was verified on Windows |
| Representative failure recovered | **Partial** — the `powershell`-not-found failure was observed in the CI log and its remedy documented |
| Cancellation verified | **Blocked** — no runnable review existed to interrupt |
| Cleanup verified | **Statically verified** — report deletion uses standard cmdlets; not executed on Linux |
| Update verified | **Statically verified** — `git pull` is standard Git behaviour |
| Rollback verified | **Statically verified** — `git checkout` is standard Git behaviour |

### 30.4 Known limitations of release 0.1.0 on Linux

1. **No documented Linux installation path for the Codex CLI.** The repository's
   only installation instruction is Windows PowerShell. Finding
   `REV-LNX-GUIDE-001`.
2. **Three test scripts are hard-broken on Linux.** They invoke the Windows-only
   `powershell` executable. Observed directly in CI job 91261545707. Finding
   `REV-TEST-002`.
3. **Those failures are invisible to CI.** The Ubuntu job reported `success`
   despite three scripts erroring, because the workflow step runs several commands
   in one block and only the last one's exit code is used. Finding `REV-CI-001`.
4. **The review runner has never run on Linux.** `scripts/Run-Review.ps1` and
   `scripts/Validate-Harness.ps1` are excluded from every Linux test. Finding
   `REV-COMPAT-001`.
5. **The validator prints a Windows fix on Linux.** When Codex is missing,
   `scripts/Validate-Harness.ps1` line 49 suggests a Windows PowerShell command
   that cannot work on Linux. Finding `REV-DOC-005`.
6. **Reviews that quote credentials are discarded.** Reproduced on Windows; the
   same code path runs on Linux. Finding `REV-COR-002`.
7. **A working-directory defect exists on Windows PowerShell 5.1** in which Codex
   is launched outside the repository under review (finding `REV-COR-001`).
   PowerShell 7 is documented to behave differently, so Linux is probably
   unaffected — but this has not been proven, and it should be verified before any
   Linux support claim is made.

### 30.5 Support boundaries

- Best available: Ubuntu 24.04 on x64 with PowerShell 7, for the harness
  self-tests and health check only.
- Unverified: every other distribution, every other architecture, and the review
  runner itself on all Linux systems.
- Not documented by this project, and therefore not covered here: containers,
  virtual machines, `systemd` integration, and macOS.
- For a proven end-to-end review today, use
  `docs/guides/WINDOWS_NOVICE_USABILITY_GUIDE.md`.
- This guide describes commit `26cc06cf96cd2a854fe1f3fc9bc3c461b45f73c9`. Re-verify
  after any update.

