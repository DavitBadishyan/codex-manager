# Contributing to Codex Manager

Thank you for helping improve the Windows account switcher and usage dashboard. This is an unofficial beta project; changes should preserve predictable account handling and honest reporting of service data.

## Report a bug or propose a change

Open a [GitHub issue](https://github.com/DavitBadishyan/codex-manager/issues) with the version, Windows version, what you expected, what happened, and the smallest reproduction you can provide. Check existing issues first. Use fictional identities in screenshots and redact errors before sharing them.

Never attach authentication files, bearer tokens, refresh tokens, local account folders, real account fixtures, or unredacted logs. Report suspected vulnerabilities through the [security policy](SECURITY.md).

## Development

Use Windows 10/11 with Windows PowerShell 5.1 and WPF. The desktop integration requires the official Microsoft Store `OpenAI.Codex` package. Keep compatibility with Windows PowerShell 5.1; do not introduce a PowerShell 7 requirement without agreeing on that change first.

Keep account and runtime data outside the repository. Automated tests should use synthetic credentials and mocked service responses. Login and switching checks require authorized accounts and should be performed locally; do not put credentials into CI secrets merely to run an account integration test.

Run the isolated regression scripts from a Windows PowerShell 5.1 prompt in the repository root:

```powershell
.\tests\Test-Switcher.ps1
.\tests\Test-Isolated-Login.ps1
.\tests\Test-Native-Errors.ps1
```

Read each test before running it and keep tests isolated from your real account store. These scripts exercise synthetic sessions; they do not establish that browser login or live OpenAI responses work for a particular account.

## Pull requests

Keep changes focused on a concrete problem. Link the issue or ticket and explain the observed behavior, the intended behavior, and the approach. State exactly which tests or manual checks you ran and their results. Do not claim authenticated testing when you only tested fixtures or syntax.

Preserve agreed acceptance criteria. If a ticket's criteria appear incorrect or unreachable, discuss them with the maintainer before changing scope. Do not silently rewrite criteria to fit an implementation.

Read the complete cumulative diff and changed-file list before submitting. Check callers and token writers as well as the function you edited. Remove debug output, unused code, placeholder stubs, and accidentally skipped tests. Inspect fixtures, screenshots, and release files for credentials and private information.

For a follow-up review, address every earlier finding and reply with the changed location and supporting evidence. Update the PR description to describe the whole current change, including current test results. Keep criterion text unchanged; update only stale code references as lines move.

## Release validation

Changes to authentication, installation, or switching need relevant checks from this list:

- Parse scripts and run the repository's automated checks under Windows PowerShell 5.1.
- Install from a clean extracted ZIP as a normal Windows user; verify the shortcut starts the dashboard.
- Confirm a missing official desktop package produces a useful error.
- Add another authorized account and verify the active desktop account remains signed in until an explicit switch.
- Refresh multiple accounts and check five-hour/weekly values, reset times, credits, and missing or expired-session states.
- Switch accounts after pausing work; confirm graceful restart and correct desktop identity.
- Switch back and confirm the outgoing account's updated refresh tokens were retained.
- Check restricted account-folder permissions and verify no token values appear in normal output.
- Check zoom and readability, and make screenshots only with fictional demo data.
- Inspect the release ZIP: it must contain distributable application files, never local profiles, account tokens, runtime caches, or developer-specific paths.

Choose checks relevant to your change, then report any checks you could not run and why. Authenticated checks need real authorized sessions, so successful fixture tests alone do not establish end-to-end login or switching compatibility.

Contributions are distributed under this repository's [MIT License](LICENSE).
