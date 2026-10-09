# How to switch Codex accounts on Windows

Codex Manager lets you save several ChatGPT account sessions and choose which one the official Windows Codex desktop app uses. Adding an account and switching to it are separate actions: you can connect another account while keeping your current desktop login.

[Download Codex Manager](https://github.com/DavitBadishyan/codex-manager/releases/latest) · [Project overview](../README.md) · [Full user guide](USER_GUIDE.md)

## Before you start

You need Windows 10 or 11 and the official **OpenAI.Codex Microsoft Store desktop package** installed for your Windows user. A Codex CLI installation alone is insufficient. This tool manages ChatGPT sign-in sessions; it is not an API key manager.

Download the release ZIP, choose **Extract All**, then double-click **Install.cmd** in the extracted folder. Open the **Codex Manager** desktop shortcut. No administrator access is required.

## Save your first account

If Codex is already signed in with a compatible ChatGPT session, Codex Manager can import that session when its saved list is empty. Check the email shown on the resulting account card.

If the list is empty, click **Add account** and complete the browser sign-in. Return to the dashboard and wait for the operation to finish. The saved account can then be selected for activation.

## Add another account

1. Click **Add account**.
2. Check which account the browser proposes. Select the intended account before completing sign-in.
3. Return to Codex Manager and wait for the new card and usage refresh.
4. Repeat for each account you are authorized to use.

The login runs in a separate temporary session. It does not switch the current desktop account. If you accidentally select the account already active in Codex, the manager reports that it is active and preserves its login. Retry with the intended browser identity.

You can click **Cancel sign-in** in the dashboard to stop an unfinished login. A cancelled or timed-out login does not replace saved accounts. You do not need to copy authentication files manually for normal setup.

## Switch to a saved account

1. Finish or pause ongoing work in Codex.
2. In Codex Manager, find the account by its email and click **Switch to this account**.
3. Wait for Codex to close and restart.
4. Confirm the account shown in the restarted Codex app before starting work.

Switching requires a restart. The manager requests a normal shutdown and may force-close remaining Codex processes after 12 seconds. After shutdown, it saves the outgoing account's latest session, installs the selected session, and restarts the official app. If shutdown fails, read the error and retry after resolving the blocking app state.

Close independent Codex CLI processes before switching. Avoid simultaneous switching tools or manual authentication-file changes; another client may refresh the same session while the manager is working.

## Reconnect an expired account

A saved card can remain visible after its session expires or is revoked. Click **Reconnect** on that card and sign in to **the same account**. A different account is rejected rather than replacing the selected saved identity. Refresh afterward and check its status.

Saved sessions cannot guarantee permanent access. This manager does not increase limits or bypass OpenAI account restrictions.

## Keep the saved sessions private

Account data is stored locally under `%LOCALAPPDATA%\CodexManager`. Tokens are plaintext with restricted Windows permissions, not encrypted. Do not share this folder or put it in a public repository. See [Security](../SECURITY.md).

For failed switches or unexpected sign-in prompts, use the [troubleshooting guide](TROUBLESHOOTING.md). For remaining usage and reset times, see [Understanding Codex usage limits](USAGE_LIMITS.md).
