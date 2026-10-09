# Launch drafts and directory candidates

Prepared **10 October 2026**. These are ready-to-review drafts. **Nothing here has been submitted, posted, or sent.** Obtain the repository owner's authorization before posting to another community or opening a submission pull request. Check the destination's current rules, audience, and contribution requirements first.

Use the repository as the main destination: <https://github.com/DavitBadishyan/codex-manager>. Link to [Releases](https://github.com/DavitBadishyan/codex-manager/releases/latest) when someone specifically asks where to download. Do not send credentials, account screenshots, or runtime folders.

## Developer-community draft

**Title:** Codex Manager: a local Windows account switcher and usage dashboard

I built Codex Manager for people who use more than one authorized account in the Windows Codex desktop app and want to see their remaining usage in one place.

It shows remaining five-hour and weekly usage, reset countdowns, and available credits. You can add an account through browser sign-in and choose a saved account to switch the official desktop app to. Switching restarts Codex, so finish or pause work first.

Installation is: download the release ZIP, extract it, and double-click `Install.cmd`. It uses Windows PowerShell and WPF and requires the official Microsoft Store Codex desktop package.

It is open source under MIT, unofficial, and currently beta. Account data stays on your PC; authentication and usage requests go to OpenAI. There is no project-owned cloud service or telemetry. Current token storage is plaintext with restricted Windows permissions, not encryption. Sessions may expire and need reconnection.

Repository, screenshots, download, and instructions: https://github.com/DavitBadishyan/codex-manager

I'd appreciate feedback on installation and whether the usage display is easy to understand. Please report bugs with redacted details, never authentication files.

## Short social draft

Codex Manager is an open-source Windows dashboard for locally saved Codex accounts: remaining five-hour/weekly usage, reset countdowns, and desktop account switching. Extract ZIP → Install.cmd. Unofficial beta; requires the Store Codex app. Plaintext tokens with restricted Windows permissions.

https://github.com/DavitBadishyan/codex-manager

Shorten for the destination's limit without removing important compatibility or security details; a linked screenshot can show the workflow. Do not describe it as an official OpenAI product or a way to bypass usage limits.

## Curated-list submission copy

```markdown
- [Codex Manager](https://github.com/DavitBadishyan/codex-manager) — Unofficial Windows desktop companion for locally saved Codex accounts, remaining five-hour/weekly usage, reset countdowns, and account switching. PowerShell/WPF; requires the Microsoft Store Codex app.
```

Adapt the entry's formatting and length to the list's rules. Disclose maintainer affiliation in a submission message:

> I maintain Codex Manager and would like to propose it for your account-management or usage-monitoring section. It is a Windows desktop companion, not a CLI replacement. The repository includes a tested ZIP release, installation instructions, fictional screenshots, and a security policy explaining local plaintext credential storage. Please let me know if desktop companions are outside the list's scope.

## Candidate destinations

These candidates were checked for relevance, not approval. Inclusion is discretionary and must be earned by meeting each destination's rules.

| Candidate | Why it may fit | Before any submission |
| --- | --- | --- |
| [milisp/awesome-codex-cli](https://github.com/milisp/awesome-codex-cli) | Has account-switcher and usage-monitoring categories, including desktop companions | Read its [contribution guide](https://github.com/milisp/awesome-codex-cli/blob/main/contributing.md); check desktop scope and avoid duplicate entries in multiple categories. |
| [RoggeOhta/awesome-codex-cli](https://github.com/RoggeOhta/awesome-codex-cli) | Includes account/auth tools and GUI projects | Re-read repository contribution rules and existing entries; propose only the best-fitting category. |
| [r/codex](https://www.reddit.com/r/codex/) | Community search results include account-switcher discussions | Review the current sidebar and self-promotion rules. Post once only if allowed, disclose that you made it, and answer real questions. |
| [r/OpenaiCodex](https://www.reddit.com/r/OpenaiCodex/) | Community search results include Codex usage and Windows-tool discussions | Review current community rules and recent related posts. Do not cross-post duplicates indiscriminately. |

GitHub's relevant [codex-account-switcher topic](https://github.com/topics/codex-account-switcher) is a discovery surface, not a directory requiring an outreach message. Use accurate repository topics; no submission or invented endorsement is needed.

The broad [sindresorhus/awesome](https://github.com/sindresorhus/awesome) repository is an index of curated lists, not the right place to submit this individual application. Start with a relevant list above instead.

## Launch checklist

- Verify that the current release installs from an extracted ZIP and that the download link works.
- Verify screenshots and demo media use only fictional identities and usage.
- Check every claim against the released version and current documentation.
- Have the owner approve the specific draft and destination before posting or submitting.
- Follow the destination's rules, disclose affiliation, and avoid unsolicited messages to individual users.
- Record the authorized launch date privately for the [measurement routine](DISCOVERY.md#a-manual-measurement-routine).
- Answer questions and reproducible bugs; do not repeatedly repost a launch or solicit manufactured stars.

No paid links, purchased stars, automated promotional comments, or claims of guaranteed search placement are part of this launch.
