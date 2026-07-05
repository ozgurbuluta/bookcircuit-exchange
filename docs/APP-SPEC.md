# Turtle Turning Pages — App Spec (v1 build handoff)

Implementation contract for coding agents. Visual truth = `Turtle Turning Pages.dc.html` (anchors like `#2a` below); style rules = `readme.md` + `tokens/*.css` + `components/`. Where a mock and this spec disagree, this spec wins.

## 1. Canonical screens

Build these. Anything not listed is design exploration — do NOT implement.

| Screen | Mock | Notes |
|---|---|---|
| Welcome / sign-in | `#3a` | Apple, Google, email OTP |
| Tour (3 cards, skippable) | `#3b` `#3c` `#3d` | |
| Neighborhood setup | `#3e` | postal code + languages |
| First shelf (empty state) | `#3f` | welcome gift banner |
| Home | `#1a` | "The Shelf" direction |
| Map view | `#1b` | layout only — use flat 50 pts pricing, not the "150/120 pts" shown |
| Add a book (scan) | `#1d` | |
| Book detail | `#2a` | |
| Trade request sheet | `#2b` | |
| My trades | `#2c` | |
| Trade chat | `#2d` | |
| Chat list | `#1i` | replace the "200 pts?" preview line — no negotiation in v1 |
| My shelf / profile | `#1h` | |
| Notifications | `#1k` | "Offering 200 pts" → 50 pts; "+100 pts" → +50 |
| Club journal | `#1l` | read-only v1 (stories, lists, events + Join) |
| Rate the swap | `#3g` | shown after trade completes |

Superseded (ignore): `#1c` `#1e` `#1f` `#1g` `#1j` and any price other than 50 pts.

## 2. Navigation

- Tab bar: Home · Journal · **Add book** (center FAB) · Chats · Shelf.
- Home → book detail → request sheet (modal). Bell icon → Notifications. Points badge → My trades.
- Onboarding: 3a → tour (skip jumps to 3e) → 3e → 3f → tabs. Runs once; re-entry lands on Home.
- Rating sheet (3g) auto-opens for both parties after a trade is marked swapped; also reachable from the completed-trade card.

## 3. Data model (minimum)

- **User**: id, name, avatarInitials, postalCode, areaLabel ("Moda, Kadıköy"), languages[], points, ratingAvg, tradeCount, createdAt.
- **Book**: id, ownerId, title, author, year, pages, publisher, isbn, language, condition ∈ {like_new, very_good, good, well_read}, visible (bool), status ∈ {on_shelf, in_trade, traded_away}, source (scan|manual), createdAt.
- **Trade**: id, bookId, requesterId, ownerId, offer ∈ {points_50, book} (+offeredBookId), note, status ∈ {requested, accepted, swapped, cancelled, declined, expired}, meetInfo (free text), timestamps per transition.
- **Message**: tradeId | clubId, senderId, text, type ∈ {user, system}. System messages: points escrowed, accepted, cancelled, swapped.
- **Rating**: tradeId, fromId, toId, stars 1–5, tags ⊆ {on_time, as_described, great_pick}, note ≤140 chars.
- **Notification**: type, refId, read.

## 4. Points & trade rules (the economy)

1. Every book costs a flat **50 pts**. No negotiation, no custom prices anywhere.
2. New account: **200 pts**, granted once at signup.
3. Requesting with points: 50 pts **escrowed immediately** (balance drops on send). Refunded in full on cancel / decline / expiry.
4. Requesting with a book: requester picks ONE of their on-shelf books. No points move. The offered book locks (`in_trade`) only when the owner **accepts**.
5. A book may hold **multiple pending requests**. Accepting one auto-declines the rest (with refunds + notifications). Max one active request per requester per book.
6. On accept: target book (and offered book, if any) → `in_trade`; still visible with "In trade" overlay (`#1h`), not requestable.
7. **Swapped**: either party taps "Mark as swapped" — first tap completes the trade. Escrowed points release to the owner (+50); book ownership transfers; a book-for-book trade transfers both with no points. Both parties then get the rating sheet (skippable).
8. Cancel: either party, any time before swapped, one tap from `#2c`/`#2d`. Confirmation dialog, then full refund + system message.
9. Expiry: `requested` with no owner response for **7 days** → `expired`, auto-refund. Warning notification to owner on day 6.
10. Insufficient funds (<50 pts) and no books to offer: request button disabled with hint "Shelve a book to earn points" (state not mocked — follow `#2a` styling).

## 5. Onboarding logic

- Auth: Apple / Google / email OTP. No password flow.
- Tour skippable at every step ("Skip the tour" → 3e). Never shown again.
- Setup requires: valid postal code (geocode → areaLabel) + ≥1 language (preselect from device locale). Location button is a convenience filler for the postal field — GPS is never stored.
- Privacy rule (also copy): neighbors see `areaLabel` only, never address or exact location.
- 3f: welcome-gift banner shows until first book added OR dismissed. "Browse nearby first" → Home.

## 6. Add-book flow

- Scan cover/ISBN → Open Library lookup → prefilled card (`#1d`); user confirms **language** (required) and **condition** (required); "Enter manually" fallback with same fields.
- Visibility toggle default ON. Cover images: generated placeholder covers from `components/books/BookCover.jsx` palette until real photos exist (photos are v2).

## 7. Search & home

- Search scope: postal code centroid, default radius 1 km, sort by distance. Language filter chips with counts (`#1b`).
- Home sections (`#1a`): search card, map teaser (count near postal), "New nearby" (latest within radius), "Most loved this month" (request count), journal teasers.

## 8. Notifications (triggers)

new request received · request accepted · request declined · trade cancelled · expiry warning (day 6, owner) · expired + refund (requester) · marked swapped · rating received · new book nearby (opt-in) · journal/event (opt-in). Request notifications carry inline Accept / Decline / Chat (`#1k`).

## 9. Chat

- Threads exist only per trade + club groups. Header trade card carries status chip, Mark as swapped, Cancel (`#2d`).
- Quick replies: "Share meeting spot", "Running late".
- System events render as centered honey pills (see `#2d`).
- Emoji allowed in user text only — never in UI chrome.

## 10. Copy & style (binding)

- Follow `readme.md` fundamentals: sentence case, verbs on buttons, reassurance after commitment, "50 pts" + shell glyph, named neighbors, no exclamation marks, no emoji in chrome.
- Piri (the club turtle) appears ONLY in onboarding + empty states. Speech: short, unhurried, wry ("Spend them slowly — rather my style."). Never in transactional flows.
- Tokens/components: `tokens/{colors,typography,spacing}.css`, `components/core/{Button,Chip,PointsBadge}`, `components/books/BookCover`. Fonts: Google Fonts Young Serif + Schibsted Grotesk.
- `ios-frame.jsx` is mock chrome only — do not ship.

## 11. v1 non-goals

Negotiation/custom pricing · shipping · payments/point purchases · dispute resolution (cancel covers it) · book photos · journal authoring (read-only) · blocking/reporting beyond a mailto — all v2 candidates.

## 12. Assumptions to sanity-check with a human

1. First "Mark as swapped" tap completes the trade (no two-sided confirmation).
2. Multiple pending requests per book, auto-decline on accept.
3. Offered book locks at accept, not at request.
