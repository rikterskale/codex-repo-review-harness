# Complete Beginner Guide: Codex Repository Review Harness on Windows

**You do not need to be a programmer.**  
This guide walks you through every single click and command, starting from a fresh Windows PC.

We will install the free tools you need, set up the review harness, and run your first **read-only** code review.  
“Read-only” means the AI looks at your code and writes a report — it **cannot** change, delete, or break any of your files.

---

## Table of Contents

1. What you will have at the end  
2. What the harness is (simple explanation)  
3. Part A – Install the free tools (one-time)  
4. Part B – Create or open a project folder  
5. Part C – Put the harness files into your project  
6. Part D – Customize two small files  
7. Part E – Validate that everything is ready  
8. Part F – Run your first review  
9. Part G – Read the report  
10. Part H – Run different kinds of reviews  
11. Part I – Optional: put the harness on GitHub  
12. Troubleshooting (common problems + exact fixes)  
13. Safety reminders  

---

## 1. What you will have at the end

- A folder on your computer that contains a ready-to-use “review harness”.
- The ability to type one short command and receive a detailed Markdown report about any code repository.
- Everything stays **read-only** by default, so you cannot accidentally damage your project.

---

## 2. What the harness is (simple explanation)

Think of the harness as a **checklist + instruction book + safety fence** for the AI called Codex.

- **Configuration** (`config/review-config.yaml`) = the settings dial (which branch, how strict, etc.).
- **Prompts** (`prompts/*.md`) = the exact instructions we give the AI.
- **AGENTS.md** = permanent rules the AI must always follow (especially “Code Review Rules”).
- **Scripts** (`scripts/*.ps1`) = the “big green button” that starts the review safely.
- **Reports** (`reports/`) = where the finished review is saved as a text file you can open.

Codex itself is an official OpenAI tool that runs on your computer and talks to the AI models.

---

## 3. Part A – Install the free tools (one-time setup)

You need three things: **Git**, **PowerShell** (already on Windows), and **Codex**.

### A.1 Install Git for Windows

1. Open your web browser (Edge, Chrome, etc.).
2. Go to: https://git-scm.com/download/win  
3. The download should start automatically (64-bit Git for Windows Setup).
4. When the installer opens:
   - Click **Next** on every screen.
   - On the “Choosing the default editor” screen you can leave the default (or choose Notepad).
   - On the “Adjusting your PATH environment” screen, leave the recommended option selected.
   - Keep clicking **Next** until you reach **Install**, then click **Install**.
   - When it finishes, click **Finish**.
5. To verify it worked:
   - Press the **Windows key** on your keyboard.
   - Type `powershell` and press Enter. A blue or black window opens.
   - Type exactly this and press Enter:

     ```
     git --version
     ```

   - You should see something like `git version 2.xx.x`.  
     If you see an error, restart the computer and try the command again.

### A.2 Make sure PowerShell can run scripts

1. Still in the PowerShell window, type this and press Enter:

   ```
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

2. If it asks “Do you want to change the execution policy?”, type `Y` and press Enter.

This only allows scripts that you trust (or that are downloaded from the internet with a signature). It is the normal safe setting for developers.

### A.3 Install Codex CLI (the AI tool)

1. In the **same** PowerShell window, copy and paste this entire line and press Enter:

   ```
   powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
   ```

2. Wait while it downloads and installs. You may see progress text.
3. When it finishes, close the PowerShell window completely and open a **new** one (Windows key → type powershell → Enter).
4. Verify the install:

   ```
   codex --version
   ```

   You should see a version number (for example `0.146.0` or similar).

5. The first time you run Codex it will ask you to sign in with your ChatGPT account.  
   You need a ChatGPT Plus, Pro, Business, Edu or Enterprise plan for full access.  
   Follow the on-screen instructions (it usually opens a browser window for you to log in).

**If the install command fails:**  
Go to https://github.com/openai/codex/releases/latest , download the Windows binary if available, or try the npm method later after installing Node.js. For most people the PowerShell one-liner works.

---

## 4. Part B – Create or open a project folder

You have two choices:

### Option 1 – You already have a GitHub repository you want to review

1. Open PowerShell.
2. Go to a place where you keep projects, for example:

   ```
   cd $HOME\Documents
   mkdir MyProjects
   cd MyProjects
   ```

3. Clone your repository (replace the URL with your real one):

   ```
   git clone https://github.com/YOUR-USERNAME/YOUR-REPO-NAME.git
   cd YOUR-REPO-NAME
   ```

### Option 2 – You want to start a brand-new empty project just to try the harness

1. Open PowerShell.
2. Run:

   ```
   cd $HOME\Documents
   mkdir MyFirstReviewProject
   cd MyFirstReviewProject
   git init
   ```

3. Create a tiny sample file so there is something to review:

   ```
   "Hello from my first project" | Out-File -Encoding utf8 README.md
   git add README.md
   git commit -m "Initial commit"
   ```

---

## 5. Part C – Put the harness files into your project

You now need to copy the harness folder structure into the project you just opened.

**Easiest method for beginners:** clone this repository itself, or download it as a ZIP from GitHub and copy the files into your project.

1. Inside your project folder (the one that has a `.git` folder), the structure should end up looking like this after you copy the harness files:

```
YourProject/
├── .git/
├── AGENTS.md
├── config/
│   └── review-config.yaml
├── prompts/
│   ├── system-review.md
│   ├── security-focus.md
│   └── pr-diff-review.md
├── scripts/
│   ├── Run-Review.ps1
│   └── Validate-Harness.ps1
├── reports/          (empty at first)
├── templates/
├── tests/
├── docs/
│   └── WINDOWS_BEGINNER_GUIDE.md   ← you are reading this
└── (your normal project files)
```

(If you obtained this guide as part of the complete repository, simply copy the entire contents into your project root or start by cloning this repo.)

---

## 6. Part D – Customize two small files (optional but recommended)

### D.1 Open the configuration file

1. In PowerShell (still inside your project folder) type:

   ```
   notepad config\review-config.yaml
   ```

2. Change only these lines if needed:

   - `base_branch: main`  
     → change to `master` if your default branch is called master.
   - Leave `sandbox: read-only` exactly as it is. **Never change this to a write mode unless you understand the risk.**

3. Save the file (Ctrl+S) and close Notepad.

### D.2 Look at AGENTS.md

1. Open it:

   ```
   notepad AGENTS.md
   ```

2. You can add extra rules under the `## Code Review Rules` section later.  
   For your first run you can leave it unchanged.  
   Save and close.

---

## 7. Part E – Validate that everything is ready

Still inside your project folder in PowerShell, run:

```
.\scripts\Validate-Harness.ps1
```

You should see a series of green `[PASS]` lines.  
If any line is red `[FAIL]`, read the yellow hint and fix the problem (most often “Codex not found” or “not inside a Git repo”).

When everything passes, you are ready for a real review.

---

## 8. Part F – Run your first review

In the same PowerShell window type:

```
.\scripts\Run-Review.ps1
```

What happens:

1. The script checks that Git and Codex are present.
2. It forces the sandbox to **read-only**.
3. It builds a careful prompt from the files in `prompts/`.
4. It launches Codex. This can take 1–5 minutes depending on the size of your project and the speed of the AI.
5. When finished, a new file appears under the `reports\` folder, for example:

   ```
   reports\review-20260731-143022.md
   ```

You will see a message telling you the exact file name.

**Important:** While Codex is running you may see a lot of text scrolling. That is normal. Do not close the window until it finishes.

---

## 9. Part G – Read the report

Open the report with Notepad or any Markdown viewer:

```
notepad reports\review-XXXXXXXX-XXXXXX.md
```

(Replace the X’s with the actual timestamp you saw.)

The report always contains:

- Executive Summary  
- Findings (grouped by severity: Critical, High, Medium…)  
- Positive Observations  
- Recommended Next Actions  

Because the harness is read-only, the report is the **only** new file that was created. Your source code is untouched.

---

## 10. Part H – Run different kinds of reviews

You can choose different prompts:

**Security-focused review**

```
.\scripts\Run-Review.ps1 -Prompt security-focus.md
```

**Review that concentrates on the changes since the base branch (like a pull-request review)**

```
.\scripts\Run-Review.ps1 -Prompt pr-diff-review.md
```

**Just check what the script would do without calling the AI (dry-run)**

```
.\scripts\Run-Review.ps1 -DryRun
```

**Override the base branch for one run**

```
.\scripts\Run-Review.ps1 -BaseBranch develop
```

---

## 11. Part I – Optional: put the harness on GitHub

Once you are comfortable:

1. Create a new repository on GitHub (or use your existing one).
2. From PowerShell inside your project:

   ```
   git add .
   git status          # look at the files that will be committed
   git commit -m "Add Codex read-only review harness"
   git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO.git   # only if not already set
   git push -u origin main
   ```

Now anyone who clones your repository also gets the harness and can run the same reviews.

There is also an optional GitHub Actions workflow file (`.github/workflows/codex-review.yml`) that can run reviews automatically on pull requests. That is an advanced topic; you can ignore it until you are ready.

---

## 12. Troubleshooting (common problems + exact fixes)

| Problem | What you see | Exact fix |
|---------|--------------|-----------|
| “git is not recognized” | red error | Re-install Git for Windows and **restart** the computer, then open a new PowerShell. |
| “codex is not recognized” | red error | Re-run the install command from section A.3, then open a **new** PowerShell window. |
| “This folder is not inside a Git repository” | red error | Run `git init` or `cd` into a folder that already has a `.git` directory. |
| Execution policy error | “cannot be loaded because running scripts is disabled” | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` and answer Y. |
| Codex asks for login every time | browser window keeps opening | Make sure you finished the ChatGPT sign-in the first time. Check that your plan supports Codex. |
| Report is empty or very short | almost no findings | Your project may be tiny or the base branch has no differences. Try the security prompt or add more code. |
| “Access denied” writing to reports | red error | Make sure the `reports` folder is not read-only. Right-click the folder → Properties → uncheck Read-only if needed. |

If you are still stuck, copy the **entire** error message and the output of these three commands and ask for help:

```
git --version
codex --version
.\scripts\Validate-Harness.ps1
```

---

## 13. Safety reminders (please read)

- The harness **defaults to read-only**. Codex cannot change your source files while the sandbox is set to `read-only`.
- Never change the sandbox setting to `workspace-write` or `danger-full-access` unless you fully understand that the AI will be allowed to edit files.
- Always keep a backup or use Git so you can undo any future write-enabled sessions.
- The reports folder only contains text files. You can delete old reports any time.
- This harness does not send your code to any third-party service beyond the official OpenAI / ChatGPT Codex service you already authenticated with.

---

## You are done!

You now have a tested, read-only-by-default repository review harness with:

- Configuration  
- Prompts  
- Validation  
- Reports  
- A complete Windows beginner guide  

Run `.\scripts\Validate-Harness.ps1` any time you want to double-check that everything is still healthy, then run `.\scripts\Run-Review.ps1` whenever you want a fresh review.

Happy reviewing!
