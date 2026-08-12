# Independent review

Run reviews from this harness, not the implementation session. Supply
`-RepositoryPath` to inspect another local Git repository. The runner keeps its
reports under this harness, forces `read-only`, records the target commit and
branch, and compares target Git status before and after review. A changed target
causes the run to fail.
