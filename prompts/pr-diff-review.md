# Pull-Request Diff Review Prompt (Read-Only)

You are reviewing the **diff** between the current branch (or working tree) and the configured base branch.

## Focus
- Only report issues introduced or made worse by the change.
- Do not re-litigate pre-existing problems unless the change amplifies them.
- Check that tests cover the new behavior.
- Verify documentation was updated when public APIs changed.
- Confirm the change matches any linked issue / task description if present.

## Output
Use the exact same Markdown report structure defined in system-review.md.
In the Executive Summary, explicitly state how many files changed and the overall risk of merging.
