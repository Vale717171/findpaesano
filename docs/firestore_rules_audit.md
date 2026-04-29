# Firestore Rules Audit

This PR tightens the current Firestore rules without changing the Flutter data model or breaking the flows that already ship in the client.

## What Was Tightened

- `users`
  - owner-only create/update/delete
  - authenticated read only
  - field whitelist enforced:
    - `nickname`
    - `countryCode`
    - `countryName`
    - `countryFlag`
    - `travelStatus`
    - `destination`
    - `createdAt`
    - `location`
    - `locationUpdatedAt`
  - `nickname` constrained to 1..20 chars
  - `travelStatus` constrained to `planning | here`
  - `createdAt` locked on update
  - no extra fields

- `users/{uid}/blockedUsers`
  - owner-only read/write
  - `blockedUid != request.auth.uid`
  - schema restricted to `blockedAt`

- `messages`
  - authenticated read only
  - create restricted to the author
  - schema whitelist enforced:
    - `text`
    - `category`
    - `location`
    - `locationKey`
    - `authorUid`
    - `authorNickname`
    - `authorFlag`
    - `createdAt`
    - `reportCount`
  - `category` constrained to:
    - `Food`
    - `Places`
    - `Transport`
    - `Warning`
    - `Other`
  - `reportCount` can only be absent or `0` on create
  - update restricted to `reportCount + 1` only
  - delete remains author-only

- `reports`
  - client read narrowed to `reportedBy == request.auth.uid`
  - create restricted to the authenticated reporter
  - report schema validated
  - report of own message rejected with `get()` on `/messages/{messageId}`
  - update/delete denied

- `chatRequests`
  - read restricted to sender/recipient
  - create restricted to authenticated sender
  - create must start as `pending`
  - immutable sender/recipient profile fields on update
  - update restricted to recipient only
  - status transition restricted to:
    - `pending -> accepted` with `chatId`
    - `pending -> declined` without `chatId`

- `chats`
  - read restricted to participants
  - create restricted to 2 distinct participants
  - immutable on update:
    - `participants`
    - `participantFlags`
    - `participantNicknames`
    - `createdAt`
  - update restricted to:
    - `lastMessage + lastMessageAt`
    - `closedBy + closedAt`

- `chats/{chatId}/messages`
  - read/create restricted to participants of the parent chat
  - strict schema validation for:
    - `text`
    - `senderUid`
    - `createdAt`
  - update denied

## What Stays Intentionally Open For Compatibility

- `chats` delete is still open to participants.
- `chats/{chatId}/messages` delete is still open to participants.

Reason: the current account-deletion flow in the Flutter client deletes shared chats and chat messages directly from the device before deleting the auth account. Closing those deletes in this PR would break account deletion.

The rules contain explicit TODO comments for both cases.

## Residual Risks

- Chat and chat-message deletion is still broader than ideal because of the current account-deletion implementation.
- `messages.reportCount` is still incremented client-side. Rules now restrict the update shape, but they still cannot fully guarantee one real report per increment.
- `reports` still use random top-level document IDs. That keeps compatibility with the client, but it prevents stronger uniqueness guarantees in rules alone.
- `users` remains readable by any authenticated user because Nearby and chat-related flows depend on public profile data and fuzzy location.
- Firestore Security Rules are not a reliable rate-limiting system for spam, flood, or abuse controls.

## Recommended Follow-Up PRs

1. Move account-deletion cleanup to a Cloud Function / callable or other privileged backend path, then close client-side delete on shared chats and chat messages.
2. Refactor reports to a deterministic path or a callable report flow so `reportCount` can be derived or updated server-side.
3. Split public profile data from private profile/location data if privacy requirements get stricter.
4. Add automated rules tests with the Firebase emulator.
