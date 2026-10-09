# Codex Manager user guide

Codex Manager is an unofficial beta companion for the Windows Codex desktop app. It saves account sessions locally so you can compare usage and switch accounts without repeatedly signing in.

## Install

Requirements:

- Windows 10 or Windows 11.
- Windows PowerShell 5.1 and WPF, provided by supported Windows installations.
- The official `OpenAI.Codex` desktop package installed from the Microsoft Store.
- An internet connection for OpenAI authentication and usage requests.

Download the ZIP asset from the [latest GitHub release](https://github.com/DavitBadishyan/codex-manager/releases/latest), extract the whole archive, and double-click **Install.cmd** inside the extracted folder. Use the **Codex Manager** shortcut after installation. Administrator access is not required.

Run the installer from the extracted folder, not from the ZIP viewer. This release is unsigned. Its launcher starts the bundled PowerShell scripts using a process-scoped `ExecutionPolicy Bypass`; it does not change the permanent system execution policy. If your organization blocks unsigned scripts, contact your administrator about approved use.

## Connect accounts

On first use, an existing desktop login can be imported into the saved list when available. If there is no current login, start with **Add Account**.

1. Click **Add Account**.
2. Complete the browser sign-in for the account you want to add. Check the account shown in the browser before approving sign-in.
3. Return to Codex Manager when sign-in completes.
4. Refresh to retrieve that account's latest usage.

The new login uses an isolated flow. Adding an account does not sign out the currently active desktop account or immediately switch it. Use **Switch to this account** after you finish adding it. If a saved account shows **Reconnect**, use that action and sign in to the same account to replace its expired session.

Only connect accounts you are authorized to use. A session can expire or be revoked by OpenAI; saved tokens do not guarantee permanent access. If an account requests sign-in again, reconnect it through the browser flow.

## Read the dashboard

Refresh fetches usage for saved accounts. Values describe the last successful response; they can change after further use in Codex.

| Display | Meaning |
| --- | --- |
| Five-hour remaining | The remaining share of the account's reported short usage window. |
| Weekly remaining | The remaining share of the reported weekly usage window. |
| Reset date and countdown | The reset timestamp returned for a usage window, shown as a date and time remaining. |
| Credits | The credit information available in the account response. |
| Session status / active-until | Available session or entitlement status and date information. An active-until date is not a guaranteed next billing date. |

An unavailable value means the service did not provide a usable value or the request could not complete. Do not interpret missing data as zero remaining usage or zero credits. Use Refresh again after reconnecting or resolving a network problem.

## Switch the desktop account

Finish or pause ongoing work in Codex first. Select the saved account and use its switch action. Codex Manager saves the outgoing account's latest refresh tokens, requests a graceful desktop shutdown, installs the chosen account session, and restarts the official Codex desktop app.

Confirm the account shown in the restarted desktop app before starting more work. If Codex cannot close gracefully, address the open app state and retry; do not assume a switch completed because you clicked the button.

Refresh tokens can change after use. Keeping the outgoing session synchronized is necessary so the saved account remains usable later. Avoid editing authentication files while either app is running.

## Change the dashboard size

Hold **Ctrl** and scroll the mouse wheel to zoom. You can also use **Ctrl + +** or **Ctrl + −**, and **Ctrl + 0** to reset. Zoom changes the dashboard presentation, not your Codex account or limits.

## Storage and account safety

Codex Manager keeps saved account sessions, profiles, and runtime data in `%LOCALAPPDATA%\CodexManager`. There is no Codex Manager cloud service or telemetry. Authentication and usage calls go to OpenAI over HTTPS.

Token files are plaintext. Windows access permissions restrict the account storage to the current Windows user, SYSTEM, and Administrators; this is not encryption. Another process running as your user can read the files. Do not place this folder in public backups, attach it to issues, or share it with someone helping troubleshoot. See the [security policy](../SECURITY.md).

## Troubleshooting

### The official desktop app cannot be found

Install or repair the official Microsoft Store `OpenAI.Codex` package for your current Windows user, then reopen Codex Manager. A CLI-only installation does not satisfy this desktop requirement.

### Sign-in keeps using the wrong browser account

Check the identity on the sign-in page and use the page's account selection or sign-out controls to choose the intended account. Complete the login before returning to the dashboard. Adding the account uses an isolated login flow and should leave the existing desktop login in place.

### Refresh fails or requests sign-in

Check your internet connection. Reconnect the affected account if its session expired or was revoked, then refresh. A saved account can remain listed even when its session is no longer valid. If the error persists, report the redacted error text and your Codex Manager version; never attach token files.

### Switching does not complete

Finish active Codex work and close blocking dialogs, then retry. Check that the official package still opens normally. If it still fails, include the relevant redacted error and reproduction steps in a bug report. Avoid running multiple copies of Codex Manager during account changes.

### Windows or company policy blocks the scripts

Review the source and obtain an approved release from this repository. On a managed device, ask your administrator whether the tool is allowed. Do not turn off organization security controls or change machine-wide execution policy to work around a block.

### A reset countdown or active-until date looks unexpected

Refresh and check the displayed timestamp. These are service-reported usage or session dates, not a promise about billing. For account or subscription questions, check your account through OpenAI's official channels.

## Update or stop using the tool

Close Codex Manager before installing a newer release with **Install.cmd**. Updates preserve saved accounts and settings.

To uninstall, close Codex Manager and double-click **Uninstall.cmd** from the extracted release folder. Normal uninstall removes the application files and shortcut while preserving saved accounts and settings. It leaves the official Codex app's authentication folder untouched.

For optional deletion of the tool's saved profiles, accounts, and selected settings, run the following from PowerShell in the extracted release folder:

```powershell
.\Uninstall.cmd -RemoveData
```

The script asks you to type **DELETE** before removing the selected local data. This is not secure erasure, and it does not revoke remote sessions or remove the official Codex app's login. Use OpenAI's account controls if session revocation is needed. Saved account data remains sensitive regardless of which release created it.

For technical background, see OpenAI's [Codex App Server documentation](https://learn.chatgpt.com/docs/app-server). For bug reports and improvements, see [CONTRIBUTING.md](../CONTRIBUTING.md).
