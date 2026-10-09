# GitHub discovery and measurement

Audit date: **10 October 2026**. This is a maintainer guide for discovering Codex Manager through its GitHub repository. It does not require a website, app telemetry, or a marketing service.

## What the search audit found

The following searches were checked through a web search tool:

- `Codex account switcher Windows GitHub`
- `Codex usage dashboard multiple accounts GitHub Windows`
- `github awesome codex tools account switcher list`

The returned results include several Windows switchers, multi-platform command-line tools, usage dashboards, and community discussions. This is evidence that the terms describe an existing category, not a measurement of search volume, Google position, or user demand. Results change with date, region, and search engine. No ranking or search-volume baseline was measured for Codex Manager.

### Search intent to address

| Search phrase | What the visitor likely needs | Repository content that should answer it |
| --- | --- | --- |
| Codex account switcher Windows | Download and switch the official desktop app | README opening, release ZIP, installation steps |
| Codex account manager | Understand which Codex product is supported | Windows desktop requirement and unofficial-project notice |
| Codex usage dashboard | See remaining usage and reset times | Dashboard screenshot, usage guide, refresh explanation |
| Codex five-hour weekly limits | Interpret remaining percentages and resets | Usage guide and FAQs; distinguish missing data from zero |
| Manage multiple Codex accounts locally | Understand account storage and sign-in | Add Account guide, security policy, explicit plaintext-storage disclosure |
| Codex switch accounts without signing in again | Reuse saved sessions | Switching guide, alongside the honest session-expiry/reconnect limitation |

These are editorial targets, not verified high-volume keywords. Use the natural phrase where it helps a reader. Avoid repeated keyword paragraphs and unsupported claims such as "best," "most secure," or "never expires."

### Relevant alternatives

The descriptions below summarize the linked projects' own README claims as checked on the audit date. They were not installed or independently security-audited. Features and compatibility can change.

| Project | Reported focus | Lesson for Codex Manager |
| --- | --- | --- |
| [ZOONGG/codex-swap-account](https://github.com/ZOONGG/codex-swap-account) | Windows overlay, tray controls, hotkeys, local switching and usage indicators | Explain our dashboard workflow clearly; do not claim one-click switching or local storage is unique. |
| [Chisiki1/codex-account-switcher-windows](https://github.com/Chisiki1/codex-account-switcher-windows) | Windows WPF companion, isolated browser sign-in, usage windows and DPAPI-encrypted credentials | Be explicit that our current credential files use restricted Windows permissions and are not encrypted. |
| [Sawmills/codexctl](https://github.com/Sawmills/codexctl) | Codex CLI profiles, a rate-limit dashboard and shell completions | Put the official Windows desktop requirement near the download link so CLI users do not assume the wrong compatibility. |

Our useful positioning is concrete: **a Windows dashboard for locally saved Codex accounts, remaining five-hour and weekly usage, reset countdowns, and deliberate desktop switching**. Installation is an extracted ZIP and `Install.cmd`; browser sign-in is still required when adding or reconnecting an account. Avoid claiming superiority without comparative tests.

## Keep the repository easy to find and use

1. Keep the README title descriptive and the repository About description concise. Use "Windows," "Codex account switcher," and "usage dashboard" where they describe the product accurately.
2. Keep relevant GitHub topics, such as `codex`, `openai-codex`, `codex-desktop`, `codex-account-switcher`, `account-switcher`, `multi-account`, `usage-dashboard`, `windows`, `powershell`, and `wpf`. Do not add unrelated popular topics. [GitHub explains topic discovery](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics).
3. Put the download, requirements, screenshot, and brief installation path before lengthy implementation details.
4. Link focused how-to guides from the README. Each should solve a distinct problem, rather than repeat the opening text.
5. Use fictional identities for screenshots and demos. Include useful alternative text and mark illustrative values as samples.
6. Keep the latest-release link functional. Publish release notes that state requirements, meaningful changes, and known limitations.
7. Answer reproducible issues, remove stale instructions, and keep the security policy accurate. Recommendations should come from a useful, maintained project.

GitHub controls the page's HTML metadata and crawling behavior. Without a separate site, we cannot add a custom sitemap or control the repository page's search metadata. Repository edits do not guarantee indexing, first-page visibility, or first place on Google. Do not buy stars, manufacture reviews, or buy bulk backlinks.

## Shared-link preview

The ready-made [social preview image](../media/social-preview.png) is 1280 × 640 pixels and under 1 MB. A repository file alone does not activate GitHub's custom social preview. In this repository's **Settings → General → Social preview → Edit → Upload an image**, select that PNG and save the preview when prompted. The automated upload was blocked by the browser extension's local-file access setting; the custom preview has not been activated. [GitHub's instructions](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview).

Use the [illustrated MP4 walkthrough](../media/walkthrough.mp4) or [animated quick start](../media/quickstart.gif) when sharing. Both use fictional sample data, not a recorded login or evidence of a live account switch.

## A manual measurement routine

Keep a private spreadsheet or Markdown note outside the public repository. Store aggregate project statistics only; no account identifiers, visitor identifiers, tokens, or application usage data are needed. No scheduled collection or analytics code is required.

### Every week or two

Open [repository Traffic](https://github.com/DavitBadishyan/codex-manager/graphs/traffic) under **Insights → Traffic** using a maintainer account. Record the date range, views, unique visitors, clones, and referring sites that GitHub makes available. GitHub's traffic history covers the past 14 days and reports in UTC; search engines and GitHub itself are excluded from the referring-sites links. Capture short-window totals before they roll away. [GitHub traffic documentation](https://docs.github.com/en/repositories/viewing-activity-and-data-for-your-repository/viewing-traffic-to-a-repository).

Do not add overlapping ranges together. Unique visitors across ranges are not a unique-person count for the month. Traffic does not reveal the Google queries that brought people to the repository, so do not infer keyword rankings from it.

### Once a month

1. Record each release ZIP's cumulative download count and calculate the increase since the previous snapshot of **that same asset**. Counts are available as `download_count` through GitHub's [release asset API](https://docs.github.com/en/rest/releases/assets?apiVersion=2022-11-28). Download counts are not unique installations; repeated downloads and automated requests may be included. An asset that is deleted/replaced needs a new baseline.
2. Review aggregate installation issues and common questions. An increase in downloads with repeated setup failures means the next priority is clearer setup or a fix, not more promotion.
3. Record which guide or README change was published and which authorized announcement was made. Compare the next period, while acknowledging that other events can explain a change.
4. Re-check the target searches manually if desired. Record the engine, date, locale and observed results, and label it a spot check, not a stable ranking measurement.

With GitHub CLI installed and authenticated, this read-only command lists release asset counts:

```powershell
gh api --paginate repos/DavitBadishyan/codex-manager/releases --jq '.[] | .tag_name as $tag | .assets[] | {release: $tag, asset: .name, downloads: .download_count}'
```

Suggested private record:

| Snapshot date (UTC) | Traffic range | Views / visitors / clones | Release ZIP and cumulative downloads | Download increase | Changes or authorized launches | Setup problems |
| --- | --- | --- | --- | --- | --- | --- |
| Fill after taking a real snapshot | Preserve the actual range | Do not invent a baseline | Record exact asset name | Compare the same asset | Link to changes | Summarize redacted issues |

Review at 30, 60, and 90 days. Success means more relevant visitors, fewer setup problems, and users who find the tool useful. Stars and raw clicks alone do not establish successful adoption.

See [announcement drafts and directory candidates](ANNOUNCEMENTS.md) for the next outreach steps. They are drafts, not posts already sent.
