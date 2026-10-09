# Check remaining Codex usage and reset times

Codex Manager puts the usage information available for your saved accounts in one Windows dashboard. Use it to compare remaining usage before choosing an account for your next task.

[Download Codex Manager](https://github.com/DavitBadishyan/codex-manager/releases/latest) · [Project overview](../README.md) · [Full user guide](USER_GUIDE.md)

## Fetch the current information

Open **Codex Manager** and wait for its initial refresh. Click **Refresh usage** whenever you want updated values for your saved accounts. Refreshing does not switch the active desktop account.

The displayed percentages come from the last successful account response. They can change when you use Codex elsewhere. A running countdown updates the presentation of a reported reset time; it does not fetch new usage by itself.

## Read an account card

| Item | How to read it |
| --- | --- |
| Account email | Check this to identify the account before switching. |
| Active account | The account associated with the current desktop authentication session. |
| Five-hour remaining | The remaining share of the reported short usage window. |
| Weekly remaining | The remaining share of the reported weekly usage window. |
| Reset date and countdown | The service-reported reset time, displayed using your computer's local time zone. |
| Credits | Credit information exposed by the account response, when available. |
| Subscription date | Available subscription or session information; its label tells you how to interpret it. |

For example, **80% remaining** means the reported window has 80% of its allowance left. It is not a count of prompts or a guarantee that a particular task will fit. If the five-hour and weekly values differ, read both before choosing an account.

When a countdown reaches its reset time, click **Refresh usage** to retrieve updated values. If a date looks wrong, check your computer's date, time, and time zone as well as refreshing.

## Missing usage is not zero usage

**Usage unavailable**, **Could not refresh**, and **Sign-in required** do not mean the account has exhausted its allowance. A network problem, an expired session, or a response that does not expose the requested information can make values unavailable.

1. Check the account's status and your internet connection.
2. Retry **Refresh usage** after the current operation finishes.
3. If the account offers **Reconnect**, reconnect that account through the browser, then refresh.

Do not enter another account's credentials into a reconnect flow for the selected card. The manager verifies the identity before replacing the saved session. See [Troubleshooting](TROUBLESHOOTING.md) if the problem persists.

## Subscription dates and billing

A date labelled **Subscription active until (session claim)** is information carried by the saved session. It is not a confirmed next charge date. A date labelled **Next renewal** or **Subscription ends** is shown only when that information is returned by the subscription service. Some sessions cannot access that service, so a subscription date may be unavailable or fall back to the session claim.

For payment decisions, invoices, or cancellation, check your subscription using OpenAI's official account controls. Codex Manager cannot guarantee future billing dates from a session claim.

## Make the dashboard easier to read

Use **Ctrl + mouse wheel**, **Ctrl + +**, or **Ctrl + −** to zoom. Use **Ctrl + 0** to return to the default size. Larger or smaller text does not change your allowance.

Choose **Switch to this account** only when you are ready for the desktop app to restart. Follow the [account switching guide](SWITCH_ACCOUNTS.md) for the complete sequence.
