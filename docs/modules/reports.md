# Reports

A successful local review produces three files in a unique directory below the
configured `report.output_dir`:

- `review.md`: the rendered review with a harness header;
- `review.json`: structured status, summary, findings, and metadata; and
- `review.sha256`: SHA-256 hashes for the Markdown and JSON files.

The JSON report follows `schemas/review-report.schema.json`. Its status is
`passed` when there are no findings and `findings` when findings remain after
the configured severity selection.

The runner validates Markdown structure, parses and filters findings, checks
Markdown/JSON consistency, and refuses a generated report that matches its
secret detector before writing artifacts.
