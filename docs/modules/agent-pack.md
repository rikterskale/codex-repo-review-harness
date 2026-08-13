# Managed agent pack

The managed specialist pack is described by `agents/manifest.json`. Its
installer validates schema version, managed names, permission mode, relative
paths, source-file existence, and SHA-256 checksums before copying files.

Installed paths are constrained below the manifest-defined installation root.
If an installed managed file already exists, installation copies it into a
timestamped backup beneath that root before replacing it. Installation writes a
JSON log beneath the managed root.

Removal computes only manifest-owned paths. `-RestoreLatest` copies the newest
managed backup back into the managed root after removal. Use `-DryRun` before
either operation to list actions without changing files.

`scripts/Validate-Integrations.ps1` checks the lock file, read-only settings,
agent metadata, checksums, and installed files.
