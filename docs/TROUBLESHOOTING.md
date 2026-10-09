# Codex Manager troubleshooting on Windows

Start with the symptom below. For normal setup, see the [user guide](USER_GUIDE.md). Get application updates from [GitHub Releases](https://github.com/DavitBadishyan/codex-manager/releases/latest), and return to the [project overview](../README.md) for requirements and features.

## Install.cmd cannot find Codex

Codex Manager requires the official **OpenAI.Codex Microsoft Store desktop package**, installed for the same Windows user running the manager. A CLI-only installation is insufficient.

Install or repair that desktop package, confirm it opens normally, then run **Install.cmd** again from the fully extracted release folder. Do not run the installer inside the ZIP viewer.

## Windows or company policy blocks the installer

The beta release contains unsigned PowerShell scripts. The launcher uses a process-scoped execution-policy bypass; it does not permanently change your machine's policy, and organization policies may still block execution.

On a managed device, ask your administrator about approved use. Do not disable security controls or change machine-wide policy to bypass an organization block. Review the project source and use releases from this repository.

## The account list is empty

An existing compatible desktop ChatGPT login can be imported automatically when the saved list is empty. If none is available, click **Add account** and complete the browser sign-in. You do not need to create or paste an auth.json file manually.

After adding the first account, choose **Switch to this account** to activate it in the desktop app. Adding alone does not perform a switch.

## The browser keeps choosing the wrong account

Check the identity displayed on the sign-in page before completing sign-in. Use the page's account-selection or sign-out controls to choose the intended account.

If you finish a **Reconnect** flow with a different account, the manager rejects the replacement and preserves the existing saved account. Retry and choose the correct identity. If you select the account already active in Codex while adding another, select a different account on the next attempt.

## Sign-in hangs or was cancelled

Wait for browser sign-in to complete and return to the dashboard. The flow times out after ten minutes. Use **Cancel sign-in** to stop an unfinished attempt, wait for the dashboard to finish cancelling, then retry.

Keep one manager open and avoid changing the desktop login during an add or reconnect operation. If the desktop account changes mid-flow, the manager rejects that operation to protect account identities.

## One saved account requires sign-in again

A saved session can expire or be revoked independently of the other accounts. Click **Reconnect** on the affected card, sign in to that same account, then refresh usage. A listed profile is not a guarantee that its session remains valid.

Do not restore old authentication files over a working saved account. Refresh tokens can change after use, and an old file may no longer provide access.

## Refresh fails or the account store is busy

Check your internet connection and wait for any sign-in or switch operation to finish. Close duplicate copies of Codex Manager, then retry **Refresh usage**. The manager serializes account operations to avoid conflicting writes.

If an account reports **Could not refresh**, retry after resolving connection problems. If it offers **Reconnect**, reconnect that account. Missing data is not zero remaining usage or zero credits.

## Switching leaves Codex on the old account

Finish or pause ongoing work, close blocking Codex dialogs, and close independent Codex CLI processes. Retry the switch and read the dashboard's result.

The manager must stop the desktop app before replacing its session. If it cannot stop the relevant processes, it reports a failure and preserves the active authentication. Confirm the account in the restarted official app before continuing work; clicking the button alone does not prove the switch completed.

Avoid other account-switching utilities or manual edits to authentication files while using Codex Manager. See the [switching guide](SWITCH_ACCOUNTS.md) for the expected sequence.

## A reset date or subscription date looks unexpected

Refresh usage and check your Windows clock and time zone. Reset timestamps describe usage windows. **Subscription active until (session claim)** is not a confirmed next billing date. Use OpenAI's official account controls to check billing. See [Understanding usage limits](USAGE_LIMITS.md).

## Update or reinstall without losing accounts

Close Codex Manager, extract the latest release, and run **Install.cmd**. Updates preserve saved account data. Normal **Uninstall.cmd** also preserves that data; optional data removal is a separate, confirmed action described in the [user guide](USER_GUIDE.md#update-or-stop-using-the-tool).

## Report a problem safely

Open a [bug report](https://github.com/DavitBadishyan/codex-manager/issues/new?template=bug_report.yml) with your Codex Manager version, Windows version, expected result, actual result, and the steps that reproduce the problem. Include only redacted error text or screenshots.

Never attach auth.json, tokens, browser sign-in URLs, or the `%LOCALAPPDATA%\CodexManager` data folder. Redact email addresses and other account details from screenshots. Do not upload raw logs or runtime files without checking their contents. For suspected security vulnerabilities, follow [SECURITY.md](../SECURITY.md) instead of posting sensitive details publicly.
