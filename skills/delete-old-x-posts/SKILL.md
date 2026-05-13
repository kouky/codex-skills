---
name: delete-old-x-posts
description: Delete older X.com/Twitter posts and account-visible activity from the user's logged-in account by manually browsing X in Chrome and using the per-post X delete or undo-repost UI. Use when Codex is asked to prune, purge, remove, or delete X posts, replies, quote posts, reposts, or everything older than a retention age, with a hard batch limit of 500 actions per run. This skill requires the user to be logged into X.com in Chrome and must not use X APIs, local account data, cookies, exports, bulk-deletion services, or non-UI deletion endpoints.
---

# Delete Old X Posts

## Outcome

Delete or undo up to 500 eligible account-visible items from the user's logged-in X account, one item at a time, through the visible X web UI in Chrome. Stop after the batch limit or the first safety blocker, then report exactly what happened.

## Required Job Ticket

Collect or infer these before deleting:

- `Retention`: number of months to keep. Compute a cutoff date as current date minus this many months.
- `Account`: logged-in X handle. Infer from the Profile nav link or account menu, then verify search results match it.
- `Scope`: default to original posts and quote posts only, excluding replies with `-filter:replies`. If the user says "everything", include authored posts, quote posts, replies, and undoing reposts.
- `Batch limit`: default and maximum is 500 manual actions per run. A post deletion and a repost undo each count as one action. Use a smaller limit if the user asks.
- `Stop rule`: stop when 500 actions succeed, no eligible items remain in the searched range, a login/CAPTCHA/rate-limit appears, the UI changes unexpectedly, or eligibility cannot be verified.

Ask one concise clarification only when retention months or scope is missing or risky. If the user has already clearly requested deletion for a specific account and retention, prepare the run, then ask for one final confirmation before the first destructive click.

## Chrome Requirement

Use the OpenAI Chrome plugin against the user's logged-in Chrome session. If Chrome or the Codex Chrome Extension is unavailable, follow the Chrome skill's setup/recovery instructions. Do not switch to X APIs, direct HTTP requests, local profile files, cookie inspection, local storage inspection, archive exports, bulk-delete extensions, or third-party deletion services.

If the user is not logged into X, leave the X tab ready for login and stop for user handoff. Never ask for or handle credentials.

## Efficient Discovery

Prefer X search over scrolling the whole profile timeline:

```text
from:<handle> until:<YYYY-MM-DD> -filter:replies
```

Open it as:

```text
https://x.com/search?q=<url-encoded-query>&src=typed_query&f=live
```

Notes:

- `until:<cutoff>` jumps directly into the deletion set instead of traversing recent retained posts.
- `f=live` selects the Latest tab. Results are newest-to-older within the deletion set, which is usually the most efficient reliable order.
- X does not expose a reliable oldest-first sort in the normal UI. If the user explicitly wants oldest-first, approximate it with monthly or yearly windows using `since:<start> until:<end>`, but still delete manually within each result set.
- If search is incomplete or unavailable, fall back to the profile timeline only after noting the efficiency tradeoff. On profile fallback, skip anything on or after the cutoff and stop if dates become ambiguous.

Scope query variants for authored posts:

- Original posts and quote posts: `from:<handle> until:<cutoff> -filter:replies`
- Replies only: `from:<handle> until:<cutoff> filter:replies`
- All authored posts including replies: `from:<handle> until:<cutoff>`
- Everything authored by the account: `from:<handle> until:<cutoff>`

For "everything" mode, run at least two passes:

1. Delete authored posts, quote posts, and replies with `from:<handle> until:<cutoff>`.
2. Undo reposts from the profile timeline. X search does not reliably return reposts from the target account, because repost articles belong to the original author rather than `from:<handle>`. Use `https://x.com/<handle>` and scan articles whose text begins with or visibly contains `You reposted`.

Repost age warning: X usually displays the original post's date, not the account's repost action date. For date-limited jobs, use the visible original-post `time[datetime]` as the best available cutoff signal unless the user says to undo all reposts regardless of date. Report this assumption.

## Eligibility Check

Before opening a post menu, verify all of these from the visible article:

- The author handle is exactly the target handle.
- The article's own status URL is `/handle/status/<id>`. Ignore quoted/nested post URLs from other authors.
- The article's own timestamp is older than the cutoff date. Prefer the `time[datetime]` attribute when accessible; otherwise use the visible date. If the year is omitted or ambiguous, open the status page or skip and record it.
- The post is not a pinned/profile-control item unless the user explicitly allowed deleting pinned posts.

For repost undoing, verify the visible article is attached to the target account's profile activity, not merely an unrelated post in search results. Undo only the target account's repost action; never delete or report another user's original post as deleted.

Do not delete ads, search suggestions, other users' quoted posts, likes, bookmarks, analytics links, nested quoted content, or original posts from other accounts.

## Repost Pass

Use this pass only when the user asks for reposts or "everything":

1. Navigate to `https://x.com/<handle>`.
2. Inspect visible `article` elements and select only those with visible `You reposted`.
3. Read the article's original status URL and `time[datetime]`. Because the account's repost date is not exposed in the normal UI, treat this as the original post date and apply the cutoff to it unless the user explicitly requested all reposts.
4. Skip reposts whose visible original-post date is not older than the cutoff.
5. Click the article's reposted control, usually `button[data-testid="unretweet"]` or a button with an aria label ending in `Reposted`.
6. X opens a small menu with `Undo repost` and `Quote`. Click only `Undo repost`.
7. Count the action only after the article disappears, the repost control changes away from `Reposted`, or the next fresh profile view no longer shows that repost in the same position.

Do not require the original author to be the target handle during this pass. The eligibility signal is `You reposted` plus the reposted control/menu, not the article author.

## Observed X UI Pattern

The X delete flow observed in Chrome is:

1. Open the article's `More` button.
2. Click menu item `Delete`.
3. X opens an `alertdialog` titled `Delete post?`, not always a generic `dialog`.
4. Click the `Delete` button inside that `alertdialog`.
5. Count the action only after the deleted status id disappears from the visible DOM or the result list refreshes without it.

Before clicking the menu item, store a pending record with status id, URL, and date. If waiting for the confirmation times out, inspect the DOM snapshot for `alertdialog "Delete post?"` before treating it as failure. If the alertdialog is present, continue with the pending record; do not open another post menu.

When visible dates omit the year, use the article's `time[datetime]` attribute for eligibility and reporting. Current-year dates such as `Feb 25` are normal in X search results.

## Batch Operating Notes

Prefer small browser-call batches even when the user asks for a large cap:

- Run 5-8 successful delete actions per browser tool call. Larger batches can complete but exceed the tool timeout, which makes accounting harder.
- After any timeout or interruption, do not assume the in-memory log is complete. Open a fresh search tab with the same query and inspect the first visible status ids/dates to reconcile progress.
- Search-result advancement is a useful reconciliation signal: if a fresh `from:<handle> until:<cutoff>` search starts at older posts than before, the missing newer visible posts were likely deleted. Mark those as inferred only when their previous status ids were known.
- If an owned post unexpectedly has no visible `Delete` menu, treat it as transient first. Open a fresh search tab and retry that status once before recording a skip.
- Avoid relying on one long-lived X tab after a timeout. Fresh search tabs are usually more reliable than reloading a stuck tab.

## Deletion Loop

1. Prepare the query, open the results, verify the account handle, and read the first eligible article.
2. Before the first destructive action, tell the user the account, cutoff date, scope, and maximum count, then obtain confirmation to proceed.
3. For each eligible article:
   - Capture `status_id`, post URL, and date for the run log.
   - Click that article's `More` button.
   - Choose menu item `Delete`. If no `Delete` item appears, close the menu, skip the item, and record why.
   - X should show `alertdialog "Delete post?"`. Click the final `Delete` button only inside that alertdialog.
   - If the alertdialog wait times out, inspect the DOM for `Delete post?` before retrying or skipping.
   - Wait for the dialog to close and the article to disappear or the search results to refresh.
   - Increment the deleted count only after the UI indicates success.
4. For each eligible repost:
   - Capture the original post URL/status id when visible and note that the action is `undo_repost`.
   - Work from the profile timeline article that says `You reposted`; do not use `from:<handle>` search for repost discovery.
   - Click the reposted control, usually `button[data-testid="unretweet"]`, then the menu item `Undo repost`.
   - Confirm only if X shows an explicit additional confirmation for undoing the repost. In the observed UI, `Undo repost` is the final action.
   - Increment the action count only after the UI indicates the repost was undone.
5. Continue down visible results. When visible eligible articles are exhausted, scroll to load more.
6. If deletion causes the virtualized list to jump, reload the same search URL and continue from the top; deleted posts should no longer appear.
7. Stop immediately at 500 successful actions, even if more eligible items remain.

Keep the process visibly manual: one item control/menu, one X confirmation dialog when present, one successful action count at a time. Do not batch-click, run hidden deletion requests, or bypass X's confirmation UI.

## Failure Handling

Stop and report instead of improvising when:

- X shows login, CAPTCHA, suspicious activity, rate limit, or permission prompts.
- The active account or result handle does not match the intended account.
- The menu or confirmation alertdialog labels differ from the expected delete flow.
- A post's date cannot be verified as older than the cutoff.
- More than three consecutive deletion attempts fail.
- The user sends a newer instruction to pause, stop, or change scope.

For transient loading issues, one reload of the same search URL is acceptable. For repeated stale handles or virtualized-list confusion, stop with the last verified post URL.

After a tool timeout or user interruption, stop destructive work and reconcile with a fresh search tab before continuing or reporting. Mention when counts include inferred deletions based on search-result advancement rather than an in-memory success log.

## Reporting

Final report:

- Account handle, retention months, cutoff date, scope query or timeline pass, and batch limit.
- Number of posts deleted, reposts undone, and items skipped.
- Stop reason.
- Last successful action, date when verified, and URL/status id, if any.
- Any blockers or UI changes encountered.

Do not quote deleted post text unless the user explicitly asks. A short list of status IDs and dates is enough for auditability.
