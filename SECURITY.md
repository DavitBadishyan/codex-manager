# Security policy

Codex Manager is an unofficial beta application that handles account sessions. Use it only on a Windows account and computer you trust.

## Credential storage and threat model

Saved account tokens, profiles, and runtime files live under `%LOCALAPPDATA%\CodexManager`. **Tokens are plaintext, not encrypted.** The account directory is intended to have restricted Windows access permissions for the current user, SYSTEM, and Administrators.

Those permissions do not protect tokens from software running as your user, administrators, malware, unrestricted backups, or someone with equivalent access to your files. This is not a hardware-backed credential vault. Keep the folder out of shared storage and public archives, and do not copy it into the repository or a release ZIP.

Codex Manager has no separate cloud service and no telemetry. It makes HTTPS requests to OpenAI for authentication and usage; browser sign-in also interacts with OpenAI. Local storage does not mean the application operates offline.

Sessions can expire or be revoked. Deleting a saved token removes a local copy; it does not revoke that session at OpenAI. Use the official account controls when revocation is needed.

## Unsigned scripts

The distributed PowerShell scripts are unsigned. The launcher uses process-scoped `ExecutionPolicy Bypass` for bundled scripts, without changing permanent system policy. Enterprise controls may still prevent execution. Follow your organization's approval process instead of disabling managed controls.

Review downloaded code and obtain releases from this project's GitHub repository. Administrator access is not needed for normal installation.

## Report a vulnerability

Please use [GitHub private vulnerability reporting](https://github.com/DavitBadishyan/codex-manager/security/advisories/new) when it is available. If private reporting is unavailable, open a minimal issue asking the maintainer for a private reporting channel without posting exploit details or credentials publicly.

Include the affected release, Windows version, a description of the impact, and reproduction steps using synthetic data. Never send live access or refresh tokens, authentication files, personal account identities, or an unredacted local data directory.

The latest release is the primary target for fixes. There is no guaranteed response time or long-term support commitment. Do not assume a previously fixed vulnerability is also fixed in an older release.
