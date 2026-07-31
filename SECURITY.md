# Security Policy

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Contact the repository
maintainer privately through the GitHub security advisory mechanism or the
maintainer listed in `.github/CODEOWNERS`. Include reproduction steps, affected
commit, impact, and a safe disclosure contact.

Do not include real API keys, tokens, credentials, customer data, or target data
in reports. Use synthetic fixtures. The CI review workflow treats pull-request
content as untrusted data and keeps commenting permissions in a separate job.

## Supported versions

Only the latest release listed in `CHANGELOG.md` is currently supported.
