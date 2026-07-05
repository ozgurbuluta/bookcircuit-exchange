# Turtle Turning Pages — v1 Redesign Implementation Plan

Implementation plan for the new design system, points economy, and screen set defined in
[APP-SPEC.md](APP-SPEC.md) (spec wins over mocks) and `Turtle Turning Pages.dc.html` (visual truth).

**Scope:** the Flutter app in `mobile/` plus the shared Firebase backend (`firestore.rules`,
indexes, and — new — Cloud Functions or an equivalent). The legacy React web app at the repo
root is **out of scope** (treat as archived; it must not break the shared Firestore rules).

Complexity is rated **Low / Medium / High** (no time estimates). Risk is rated per phase.

---

## 1. Verified current state (audited 2026-07-05)

What actually exists in the codebase today — the plan below is built against this, not assumptions.

| Area | Current reality |
|---|---|
| Auth | Email + password only (`FirebaseService.signUp/signIn`). No Apple, no Google, no OTP/email-link. No packages for them in `pubspec.yaml`. |
| User model | `Profile`: fullName, avatarUrl, email, bio, website, university, locationCity/State/Country, lat/lng. **No** postalCode, areaLabel, languages, points, ratingAvg, tradeCount. |
| Book model | 6 conditions (`New…Poor`), status `available/requested/trading/completed`, has description, genres, coverImgUrl, interestCount, per-book postalCode + lat/lng. **No** visible flag, **no** source field. |
| Trade model | Multi-book trades with `tradeItems` subcollection, initiator/recipient, counteroffer flags. Status `request_pending/pending/accepted/rejected/completed/cancelled`. **No** points, offer type, meetInfo, or transition timestamps. Trade status updates are plain field writes with **no side effects** (books are not locked/transferred). |
| Chat | Standalone person-to-person `conversations` collection with `messages` subcollection, optionally tagged with a bookId. **Not** tied to trades. No system messages, no quick replies. |
| Points | Nothing. No balance, no escrow, no transactions. |
| Ratings | Nothing. |
| Notifications | `notification_service.dart` is a local-notifications shell; `firestore.rules` already contains a `notifications` collection block (unused by the app). No FCM. |
| Journal | `blogPosts` collection exists (public read / admin write) — reusable for the Journal tab. |
| Server code | **None. There is no `functions/` directory and no Cloud Functions.** Everything runs client-side against Firestore. |
| Navigation | 5 tabs (Home, Discover, Trades, Messages, Profile) in `main_shell.dart`; FAB only on Home opens an add/scan sheet. |
| Onboarding | Generic 3-page icon tour → sign-in, gated by a SharedPreferences flag. Runs **before** auth. No neighborhood setup, no welcome gift. |
| Add book | Search (Google Books + Open Library services both exist), AI shelf scanner (`firebase_ai`), cover photo upload. 6-value condition picker. |
| Design tokens | `theme.dart` has a warm paper/ink/rust palette and a 10-color placeholder book-cover palette (`Book.coverColorKey` + `book_cover.dart` widget already exist). Fonts are system SF Pro; `google_fonts` package is installed but unused for the spec fonts. |
| Search | Client-side: fetches up to 30 books, Haversine-filters by device GPS radius. Genre chips. No postal-centroid search, no language chips with counts. |
| Rules leftovers | `bookInterests`, `bookRequests`, `tradeHistory` collections exist in rules; partially or entirely unused by the mobile app (web-app era). |

**Consequence:** this is not a reskin. The data model, trade engine, auth, chat topology, and
navigation all change. The plan sequences the work so the app stays buildable after every phase.

---

## 2. Architecture decisions — RESOLVED (2026-07-05)

All decisions below have been made with the product owner. Summary:

| # | Decision | Outcome |
|---|---|---|
| D1 | Economy architecture | **Hybrid** — Blaze plan approved. Client-side transactions via `TradeEngine`; Cloud Functions for scheduled work (expiry, swap reminders) + FCM push fan-out |
| D2 | "Email OTP" | **Firebase email-link** sign-in, labeled "Continue with email" |
| D3 | Existing data | **Reset at cutover** — no migration script; wipe test data |
| D4 | Chat topology | `trades/{id}/messages`; retire `conversations` |
| D5 | Journal storage | Reuse `blogPosts` with `type` field |
| D6 | Book covers | Generated placeholder covers only (existing system, palette port) |
| D7 | Swap confirmation | **DEVIATION FROM SPEC:** both parties must confirm "Mark as swapped". When the first party confirms, the other gets a push immediately, again +12h, again +24h |
| D8 | Multiple pending requests | As specced — allowed; accept auto-declines the rest |
| D9 | Offered-book locking | As specced — locks at accept, not request |
| D10 | AI shelf scanner | **Keep** in v1, adapted to the new per-book confirm flow |
| D11 | Journal event "Join" | Keep it simple — no RSVP backend (mailto or plain link) |
| D12 | Push notifications | **Yes in v1** — FCM fan-out Cloud Function |

Original analysis kept below for context.

### D1 — Where does the points economy live?

The economy (rules §4) needs: atomic escrow on request, refund on cancel/decline/expiry,
transfer + book-ownership swap on completion, auto-decline of competing requests, and 7-day expiry.

| Option | Pros | Cons |
|---|---|---|
| **A. Cloud Functions (callable) for every trade transition** | Trustworthy: clients can never mint points; expiry via scheduled function; single place for side effects | Requires Blaze plan; new deploy pipeline; Node/TS codebase to maintain |
| **B. Client-side Firestore transactions + strict security rules** | No backend to build; ships fastest | Rules cannot fully validate cross-document invariants (points conservation); a hostile client can corrupt balances; expiry needs a workaround |
| **C. Hybrid (recommended)** — client-side **transactions** for all transitions now, written behind a single `TradeEngine` service with rules tightened as far as rules allow; **one scheduled Cloud Function** for expiry + day-6 warning; move transitions server-side post-TestFlight if abuse appears | Ships fast, one tiny function, clean migration path to full server-side later | Economy is "honest-client" secure only; acceptable for a closed TestFlight, not for public launch |

If Blaze is off the table entirely: expiry can be done **lazily** (any client that reads a
`requested` trade older than 7 days runs the expiry transaction), at the cost of the day-6
warning notification being unreliable.

### D2 — "Email OTP"

Firebase Auth has **email-link (passwordless)** sign-in built in, not 6-digit codes. True OTP
codes require a custom sender (Cloud Function + mail provider).
**Recommendation:** use Firebase email-link sign-in and label it "Continue with email" — matches
"no password flow" with zero backend. Revisit real OTP codes later if the link UX tests badly.

### D3 — Existing data: migrate or reset?

The app is at TestFlight Build 10; the user base is testers.
**Recommendation:** write a one-shot migration script (Section 8) but accept **reset** as the
fallback: old condition/status/trade shapes map lossily anyway (multi-book trades cannot map to
single-book trades cleanly — plan is to cancel all in-flight trades at cutover).

### D4 — Chat topology

Spec §9: threads exist **only per trade + club groups**. 
**Recommendation:** new `trades/{id}/messages` subcollection (user + system messages), and
`clubs/{id}/messages` reserved for v2 groups. The old `conversations` collection is retired
(kept read-only in rules until cleanup). The Chats tab lists trades-with-messages, not
conversations.

### D5 — Journal storage

**Recommendation:** reuse `blogPosts` (public read / admin write already ruled) with new fields
`type ∈ {story, list, event}` and optional event metadata. No new collection, no new rules.

### D6 — Book covers

Spec §6: photos are v2; use generated placeholder covers. The placeholder system
(`Book.coverColorKey`, `widgets/book_cover.dart`) **already exists** — port the palette to the
`components/books/BookCover.jsx` palette from the design package, and remove cover-photo
upload/display from add/edit flows (keep `coverImgUrl` nullable in the schema for v2).

---

## 3. Target data model (Firestore)

### `users/{uid}` — reworked
```
id, email                          (kept for auth)
name                               (from fullName)
avatarInitials                     (derived, stored for query-free display)
postalCode                         NEW (required after onboarding)
areaLabel                          NEW e.g. "Moda, Kadıköy" (geocoded once from postalCode)
languages: string[]                NEW (≥1 required)
points: int                        NEW (200 granted once at signup — guard with pointsGranted flag)
ratingAvg: double, ratingCount:int NEW (denormalized from ratings)
tradeCount: int                    NEW
notificationPrefs: {newBookNearby: bool, journal: bool}   NEW (opt-ins, spec §8)
createdAt, updatedAt
REMOVED: bio, website, university, locationCity/State/Country, locationLat/Lng
```
GPS is **never stored** (spec §5) — the location button only fills the postal field.

### `books/{id}` — reworked
```
ownerId                            (from userId)
title, author, year, pages, publisher, isbn, language (required)
condition: like_new | very_good | good | well_read          (4 values)
visible: bool                      NEW (default true)
status: on_shelf | in_trade | traded_away                   (3 values)
source: scan | manual              NEW
postalCode, locationLat/Lng        (kept — copied from owner's postal centroid, used for radius search)
coverColorKey                      (placeholder cover; coverImgUrl reserved for v2)
requestCount: int                  NEW (denormalized pending-request count; feeds "Most loved")
createdAt, updatedAt
REMOVED from UI (kept nullable in schema): description, genres, interestCount, currentTradeId
```

Condition mapping (migration): New/Like New→like_new · Very Good→very_good ·
Good/Acceptable→good · Poor→well_read.

### `trades/{id}` — replaced (single-book, no subcollection)
```
bookId, requesterId, ownerId
offer: points_50 | book
offeredBookId?                     (required iff offer == book)
note?
status: requested | accepted | swapped | cancelled | declined | expired
meetInfo?                          (free text)
requestedAt, acceptedAt?, swappedAt?, closedAt?             (timestamp per transition)
escrowed: bool                     (true while 50 pts are held)
swapConfirmedBy: string[]          (D7: userIds who tapped "Mark as swapped"; trade completes
                                    when it contains both parties)
firstConfirmAt?                    (drives the +12h / +24h reminder pushes)
  └── messages/{id}: senderId, text, type: user|system, createdAt
```

### `ratings/{id}` — new
```
tradeId, fromId, toId, stars 1–5, tags ⊆ {on_time, as_described, great_pick}, note ≤140, createdAt
```

### `notifications/{id}` — new (rules block already exists)
```
userId, type, refId, read, createdAt
types: request_received, request_accepted, request_declined, trade_cancelled,
       expiry_warning, expired_refunded, marked_swapped, rating_received,
       new_book_nearby (opt-in), journal_event (opt-in)
```

### Trade state machine (spec §4 as amended by D7, binding)

```
requested ──accept──▶ accepted ──1st confirm──▶ accepted (half-confirmed) ──2nd confirm──▶ swapped
    │                     │                          │
    ├─ decline ▶ declined ├─ cancel ▶ cancelled      ├─ cancel (either party) ▶ cancelled
    ├─ cancel  ▶ cancelled│                          └─ reminders to other party:
    └─ 7 days  ▶ expired  └─ (no expiry after accept)   immediate · +12h · +24h
```

Half-confirmed is not a separate status — it is `accepted` with one entry in `swapConfirmedBy`.

Side effects (all inside ONE Firestore transaction each):

| Transition | Side effects |
|---|---|
| create (points offer) | requester points −50, `escrowed=true`; reject if balance <50; reject if requester already has an active request on this book |
| create (book offer) | validate offered book is requester's and `on_shelf`; **no lock yet** (locks at accept, spec §12.3) |
| accept | target book →`in_trade`; offered book (if any) →`in_trade`; **auto-decline all other `requested` trades on this book** (each with refund if escrowed + notification); system message |
| decline / cancel | refund 50 if escrowed; any `in_trade` books →`on_shelf`; system message; confirmation dialog before cancel |
| 1st swap confirm (D7) | add userId to `swapConfirmedBy`, set `firstConfirmAt`; system message "X marked as swapped"; push to the other party immediately; scheduled function re-pushes at +12h and +24h while unconfirmed |
| 2nd swap confirm → swapped | points: owner +50 (if points offer); book ownership: `ownerId` swaps to requester, status →`on_shelf` on new shelf (traded book) — book-for-book transfers both, no points; `tradeCount`+1 both users; system message; both parties get rating sheet |
| expired (day 7) | status →`expired`, refund, notification to requester; warning notification to owner on day 6 |

---

## 4. Phases

Ordered so `flutter build` stays green after each phase. Phases A–B unblock everything else.

---

### Phase A — Design system foundation
**Complexity: Medium · Risk: Low · Blocks: all UI phases**

1. **Fonts:** wire `google_fonts` for **Young Serif** (display) + **Schibsted Grotesk** (UI/body)
   into `AppTypography` (`mobile/lib/config/theme.dart`). Verify Turkish glyph coverage (ı, ğ, ş).
2. **Tokens:** open `Turtle Turning Pages.dc.html` in a browser, extract `tokens/{colors,typography,spacing}.css`
   values, and reconcile `AppColors` (current palette is close but must match exactly — including
   the "honey pill" system-message color and the shell-glyph points styling). Do **not** port
   `ios-frame.jsx` (mock chrome only, spec §10).
3. **Core widgets** (new, in `mobile/lib/widgets/`):
   - `PointsBadge` — "50 pts" + shell glyph; header variant navigates to My trades
   - `RatingStars` (display + input), `RatingTagChip`
   - `SystemMessagePill` (centered honey pill)
   - `StatusChip` for the 6 new trade statuses; "In trade" book overlay
   - Rework `condition_badge.dart` for the 4 new conditions
   - Port `BookCover` palette from the design package's `components/books/BookCover.jsx`
4. **Piri assets:** export turtle illustrations from the design file into `assets/images/`
   (onboarding + empty states **only**, spec §10).
5. **Copy rules file** (`docs/COPY_RULES.md` or lint checklist): sentence case, verbs on buttons,
   no exclamation marks, no emoji in chrome, "50 pts" formatting, named neighbors.

*Risk note:* the `.dc.html` is a 1.4 MB self-unpacking bundle — token extraction must be done
in a browser (or by unpacking the embedded manifest), not by grepping the file.

---

### Phase B — Data model + backend schema
**Complexity: High · Risk: High (everything depends on it) · Blocks: C–K**

1. Rewrite Dart models (`mobile/lib/models/`): `Profile`→spec User (keep class name or rename to
   `AppUser`), `Book` (4 conditions, 3 statuses, visible, source), `Trade` (single-book, offer,
   timestamps; delete `TradeItem`), new `Rating`, new `AppNotification`, rework `Message`
   (senderId, text, type user|system, tradeId parent).
2. Rewrite the Firestore mapping layer in `firebase_service.dart` (all `_docTo*` helpers and
   writes). Recommend splitting the 610-line god-service into `user_service`, `book_service`,
   `trade_engine`, `chat_service`, `notification_service`, `rating_service` while touching it.
3. **`firestore.rules` rewrite:**
   - users: field-level validation (points writable only by owner via transaction — and see D1;
     if hybrid, add rule guards like "points may only change together with a trade doc write" to
     the extent rules allow, and document the residual trust gap)
   - books: only owner mutates; `visible`/`status` constraints
   - trades + `messages` subcollection (participants only; system messages)
   - ratings (one per trade per direction, participants only, only after `swapped`)
   - notifications (recipient-only read/update)
   - retire/lock legacy blocks: `bookInterests`, `bookRequests`, `tradeHistory`, `conversations`
     (read-only until data cleanup), `tradeItems`
4. **Composite indexes** (`firestore.indexes.json`, currently absent — create it):
   books by (status, visible, createdAt), books by (ownerId, createdAt), trades by
   (ownerId/requesterId, status, requestedAt), trades by (bookId, status), notifications by
   (userId, read, createdAt).
5. Update `firestore-structure.md` to match Section 3 of this plan.

*Deliverable:* app compiles with new models; screens may temporarily show reduced data.

---

### Phase C — Auth overhaul (welcome screen `#3a`)
**Complexity: High · Risk: High (App Store + Firebase console work) · Blocks: D**

1. Firebase console: enable Apple, Google, email-link providers (per D2).
2. Xcode: add "Sign in with Apple" capability; associated domains / dynamic-link (or custom
   scheme) handling for email-link completion.
3. Packages: `sign_in_with_apple`, `google_sign_in` (+ `app_links` or Firebase Dynamic Links
   replacement for the email link — **note:** Firebase Dynamic Links is deprecated/shutting down;
   use Hosting-based `firebase_auth` email-link with a custom domain or app links).
4. `auth_provider.dart` + `FirebaseService`: `signInWithApple()`, `signInWithGoogle()`,
   `sendSignInLink()` / `completeSignInWithLink()`; **delete** password sign-up/sign-in/reset.
5. New Welcome screen (`#3a`): logo, three continue buttons, terms footer. Delete
   `sign_in_screen.dart` / `sign_up_screen.dart` forms.
6. First-sign-in bootstrap: create user doc with `points: 200` + `pointsGranted: true`
   **exactly once** (transaction guard — Apple/Google sign-in fires the same code path on every
   login).

*Risks:* Apple review requires Sign in with Apple whenever Google login is offered (satisfied);
email-link deep links are fiddly on iOS — allocate real device testing; existing password
testers lose their login method (they re-auth with the same email via link → same Firebase user
**only if** the email matches; document this for testers).

---

### Phase D — Onboarding flow (`#3b`–`#3f`)
**Complexity: Medium · Risk: Medium · Depends: B, C**

Flow (spec §2): `3a → tour (skip → 3e) → 3e → 3f → tabs`. Runs once; re-entry lands on Home.

1. **Gate change:** onboarding moves **after** auth. Router redirect chain becomes:
   splash → welcome (unauthed) → tour/setup (authed, profile incomplete) → tabs.
   The gate is server-truth (user doc missing postalCode/languages), not just the current
   SharedPreferences flag — reinstalls must not re-prompt completed users, and half-onboarded
   users must resume at `3e`. Keep a local flag only for the tour ("never shown again", spec §5).
2. **Tour (`#3b`–`#3d`):** rebuild the 3 cards with Piri illustrations + spec copy; "Skip the
   tour" at every step jumps to 3e.
3. **Neighborhood setup (`#3e`):** postal code field with geocode validation → `areaLabel`
   (via existing `geocoding` package); language multi-select preseeded from device locale (≥1
   required); "use my location" button **only fills the postal field** — GPS never persisted.
   Privacy copy: neighbors see areaLabel only.
4. **First shelf (`#3f`):** empty-shelf state, welcome-gift banner ("200 pts") shown until first
   book added OR dismissed (persist dismissal); CTAs: add first book / "Browse nearby first" → Home.

*Note:* recent Builds 8–9 added location/language requirements at **book** level — that logic
moves to the user profile here; book postal data is then derived from the owner.

---

### Phase E — Navigation + shell restructure
**Complexity: Low–Medium · Risk: Low · Depends: B (routes exist)**

1. `main_shell.dart`: tabs become **Home · Journal · Add book (center FAB) · Chats · Shelf**.
   Center slot is a raised FAB inside the tab bar that pushes the add-book flow (not a tab with
   state). Remove per-tab FAB logic.
2. `router.dart`: add `/journal`, `/shelf`, `/notifications`, `/setup`, `/first-shelf`,
   `/trade-request/:bookId` (modal sheet route), `/rate/:tradeId`; remove `/discover`,
   `/propose-swap`; rewire redirects per Phase D.
3. Header affordances (spec §2): bell icon → Notifications; `PointsBadge` → My trades.
   My trades becomes a **pushed screen** (from points badge / shelf), no longer a tab.

---

### Phase F — Shelf + add-book flow (`#1h`, `#1d`)
**Complexity: Medium · Risk: Medium · Depends: B, E**

1. **Add a book (`#1d`):** scan cover/ISBN → **Open Library** lookup (service exists; drop the
   Google Books path or keep as silent fallback) → prefilled card; **language and condition are
   required confirmations**; "Enter manually" fallback with same fields; visibility toggle
   default ON; `source` recorded (scan|manual). Remove description/genres/cover-photo fields.
   Decide: keep the AI shelf scanner as a bonus entry point (it must emit the same confirm-card
   flow per book) or shelve it for v1 simplicity.
2. **My shelf / profile (`#1h`):** points display, ratingAvg + tradeCount, books grid with
   per-book visibility toggles and "In trade" overlays, settings/sign-out. Merge current
   profile + edit-profile down to spec fields (name, area, languages).
3. Empty states with Piri.

---

### Phase G — Home, map, search (`#1a`, `#1b`)
**Complexity: Medium–High · Risk: Medium · Depends: B, D (postal centroid), E**

1. **Search model change:** center = **postal-code centroid** (not device GPS), default radius
   **1 km**, sort by distance (spec §7). Rework `books_provider.dart`; current fetch-30-then-
   filter won't survive real data — plan geohash or bounding-box querying now (add geohash field
   to books in Phase B).
2. **Home (`#1a`):** sections = search card · map teaser (count near postal) · "New nearby"
   (latest within radius) · "Most loved this month" (by `requestCount`) · journal teasers.
   **Filter out the user's own books** (already done in Build 8 — preserve).
3. **Map view (`#1b`):** layout per mock; pins/cards show **flat 50 pts** (never the mock's
   150/120); language filter chips **with counts**; tap pin → book card → detail.
4. Insufficient-funds affordance surfaces here and on detail (see H.4).

---

### Phase H — Trade engine + request/manage UI (`#2a`, `#2b`, `#2c`)
**Complexity: HIGH (largest phase) · Risk: High · Depends: B**

1. **`TradeEngine` service:** every transition from the state machine table (Section 3) as a
   single Firestore transaction. Unit-test the transition matrix exhaustively — this is the
   money code. Includes: escrow/refund, multi-request auto-decline,
   one-active-request-per-user-per-book guard, two-sided swap confirmation (D7 — transaction
   re-reads `swapConfirmedBy`, completes on second confirm), ownership transfer, tradeCount
   increments.
2. **Cloud Functions bootstrap (Blaze, per D1):** create `functions/` (TypeScript), deploy
   pipeline, and two scheduled jobs — (a) trade expiry: day-6 warning + day-7 auto-expire with
   refund; (b) swap-confirmation reminders: while a trade sits half-confirmed, push the
   unconfirmed party at +12h and +24h after `firstConfirmAt` (immediate push comes from the
   notification fan-out in Phase J).
3. **Book detail (`#2a`):** owner rating/trade count, condition, "In trade" state, pending
   request count; primary CTA "Trade for 50 pts"; owner view shows visibility toggle instead.
4. **Trade request sheet (`#2b`, modal):** offer selector (50 pts ⇄ one of my on-shelf books via
   book picker), optional note, balance display, escrow warning copy, send → system message +
   notification. Reassurance copy after commitment (spec §10).
5. **Disabled state:** balance <50 **and** no on-shelf books → CTA disabled with hint
   "Shelve a book to earn points" (styled per `#2a`, state not mocked).
6. **My trades (`#2c`):** replaces `trades_screen`; cards show offer type, status chip, expiry
   countdown for `requested`, half-confirmed state ("Waiting for X to confirm"), actions
   Accept / Decline / Chat / Cancel (with confirmation dialog); completed cards link to the
   rating sheet.

---

### Phase I — Chat rework (`#2d`, `#1i`)
**Complexity: Medium–High · Risk: Medium · Depends: H (system messages come from TradeEngine)**

1. Messages move to `trades/{id}/messages` (D4). Chat list (`#1i`) lists trades with threads,
   status pill per row, sorted by last activity. **No price talk in previews** (no negotiation
   in v1 — replace the mock's "200 pts?" line).
2. Trade chat (`#2d`): header trade card with status chip + **Mark as swapped** + Cancel;
   after your own confirm the button becomes "Waiting for X to confirm" (D7); system events as
   centered honey pills (points escrowed / accepted / X marked as swapped / cancelled /
   swapped); quick replies "Share meeting spot" / "Running late"; emoji allowed in user text
   only.
3. Retire `conversations` reads/writes; delete `messages_screen`/`chat_screen` coupling to it.

---

### Phase J — Notifications (`#1k`) + Ratings (`#3g`)
**Complexity: Medium–High · Risk: Medium · Depends: H (triggers), I (chat deep links)**

1. **In-app notifications:** `notifications` collection writes from TradeEngine transitions
   (all 8 mandatory triggers, spec §8) + opt-in types (new book nearby, journal/event) behind
   `notificationPrefs`. Screen `#1k` with inline **Accept / Decline / Chat** on request
   notifications (calls TradeEngine directly). Bell badge = unread count. Copy fixes from spec
   §1: any "200 pts" → 50, "+100" → +50.
2. **Push (FCM — decided yes, D12):** `firebase_messaging` + APNs setup, token storage on user
   doc, tap-routing into trades/chat/notifications. A Firestore-triggered Cloud Function fans
   out a push for every `notifications` doc created (this also delivers the immediate D7
   swap-confirm nudge; the +12h/+24h reminders come from the Phase H scheduled job).
3. **Ratings (`#3g`):** rating sheet auto-opens for **both** parties after swap (skippable),
   also reachable from completed-trade card; stars 1–5, tags, note ≤140; one rating per
   direction per trade (rules-enforced); transactionally update recipient's
   ratingAvg/ratingCount; "rating received" notification.

---

### Phase K — Club journal (`#1l`)
**Complexity: Low · Risk: Low · Depends: B, E**

1. Extend `blogPosts` with `type ∈ {story, list, event}` (+ event date/location, joinable flag).
2. Journal tab: read-only feed (stories, lists, events with **Join** button — decided (D11):
   no RSVP backend, Join opens a mailto/plain link), detail views, journal teasers on Home.
3. No authoring UI (v1 non-goal). Seed content via console/admin claim.

---

### Phase L — Data reset, cleanup, hardening
**Complexity: Medium · Risk: Medium (reset decided, D3) · Depends: everything**

1. **Data reset (decided, D3 — no migration script):**
   - Export a Firestore backup for the record, then wipe: `books`, `trades` (+`tradeItems`),
     `conversations`, `bookInterests`, `bookRequests`, `tradeHistory`, and old-shape `users`
     docs (or delete the Auth users too and let everyone start fresh).
   - Testers re-onboard from scratch and receive the 200 pts welcome grant.
   - Announce the reset in TestFlight release notes alongside the re-auth note (Phase C).
2. **Dead code removal:** discover screen, propose-swap screen, password auth screens,
   bookInterests/bookRequests/tradeHistory code paths, genre system, cover-photo upload,
   `google_books_service` (if dropped), old conversation stack.
3. **Copy pass** against spec §10 rules across every screen (sentence case, no "!", no emoji in
   chrome, Piri only in onboarding/empty states, named neighbors).
4. **Test suite:** unit tests for TradeEngine transition matrix (the critical set: escrow refund
   paths, double-accept race, first-tap-wins swap, auto-decline fan-out, expiry idempotency,
   points-granted-once), model serialization tests, widget tests for request sheet + rating
   sheet, manual test script covering all 16 screens.
5. **TestFlight:** bump build, release notes telling testers about re-auth (Phase C risk).

---

## 5. Dependency graph

```
A (design system) ──────────────┐
B (data model + rules) ──┬──────┼──▶ D (onboarding) ─▶ G (home/map/search)
C (auth) ────────────────┘      │
                                ├──▶ E (nav shell) ──▶ F (shelf/add-book)
                                │
                                └──▶ H (trade engine) ─▶ I (chat) ─▶ J (notifications/ratings)
K (journal): needs only B + E                                   all ─▶ L (migration/cleanup)
```

Parallelizable pairs once B lands: (C+D) ∥ (E+F) ∥ (H) ∥ (K).

---

## 6. Risk register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Points integrity without server-side enforcement (D1-B/C) | Medium | High | Single `TradeEngine` choke point + strict rules now; move transitions to callables before public launch; audit log via system messages |
| R2 | Race conditions in trade transitions (double accept, simultaneous confirms landing as "both confirmed" twice, concurrent auto-declines) | High | High | All transitions are transactions that re-read status/`swapConfirmedBy`; exhaustive unit tests; idempotent expiry and reminders |
| R3 | Email-link auth deep-linking breaks on iOS (Dynamic Links deprecation) | Medium | High | Use Hosting-based auth links / app links; test on physical devices early in Phase C |
| R4 | Existing testers locked out or duplicated after password removal | Medium | Medium | Same-email link sign-in maps to same account; release-note instructions; keep password provider enabled-but-hidden for one build |
| R5 | Reset deletes something worth keeping | Low | Low | Firestore export backup before wipe (D3: reset decided, so no migration risk) |
| R6 | Postal-centroid search doesn't scale (client-side Haversine over 30 docs) | Medium | Medium | Add geohash field in Phase B so Phase G can query server-side |
| R7 | Design tokens extracted wrong from the bundled `.dc.html` | Medium | Medium | Extract in browser, screenshot-compare key screens against mocks (`#1a`, `#2a`, `#2d`) |
| R8 | Trades stuck half-confirmed forever (D7 second party never taps) | Medium | Medium | Reminder pushes (+12h/+24h); cancel remains available to both parties at any time; consider auto-complete after N days as a v1.1 follow-up |
| R9 | Apple sign-in review issues | Low | High | Capability + privacy strings early; TestFlight review before release build |
| R10 | Scope creep from design-exploration mocks | Medium | Medium | Spec §1 canonical list is binding; `#1c/#1e/#1f/#1g/#1j` and any non-50-pts price are ignored |

---

## 7. Spec compliance checklist (acceptance criteria)

The build is done when every line here is demonstrably true:

- [ ] All 16 canonical screens exist and match their mocks (with spec-mandated corrections: flat 50 pts on map, no "200 pts?" chat preview, notification amounts 50/+50)
- [ ] Tab bar: Home · Journal · Add book (center FAB) · Chats · Shelf
- [ ] Onboarding runs once: welcome → skippable tour → postal+language setup (both required) → first shelf with dismissible gift banner
- [ ] New account gets exactly 200 pts, exactly once
- [ ] Every book costs flat 50 pts; no custom price appears anywhere in UI or data
- [ ] Points escrow on request send; full refund on cancel/decline/expiry
- [ ] Book offer: locks only at accept; requester picks exactly one on-shelf book
- [ ] Multiple pending requests per book; accept auto-declines the rest with refunds + notifications; max one active request per requester per book
- [ ] Accepted books show "In trade" overlay, stay visible, aren't requestable
- [ ] "Mark as swapped" requires BOTH parties (D7, deviates from spec §4.7): first confirm notifies the other party immediately and re-notifies at +12h and +24h; second confirm releases points, transfers ownership, and opens the skippable rating sheet for both
- [ ] Requests expire after 7 days with day-6 owner warning
- [ ] <50 pts and no books → request CTA disabled with "Shelve a book to earn points"
- [ ] Auth is Apple / Google / email link only; no password anywhere
- [ ] GPS never stored; neighbors only ever see areaLabel
- [ ] Add-book: Open Library prefill, required language + condition confirm, manual fallback, visibility default ON, placeholder covers only
- [ ] Search: postal centroid, 1 km default, distance sort, language chips with counts; own books excluded from Home
- [ ] All 8 mandatory notification triggers fire; request notifications have inline Accept/Decline/Chat
- [ ] Chat threads exist only per trade (+ club placeholder); system events are honey pills; quick replies present; no emoji in chrome
- [ ] Journal is read-only (stories, lists, events + Join)
- [ ] Piri appears only in onboarding + empty states; copy follows §10 rules
- [ ] Fonts are Young Serif + Schibsted Grotesk; tokens match design package

---

## 8. Decision log (all questions resolved 2026-07-05)

1. Spec §12 sanity checks: multi-request auto-decline ✔ as specced (D8); lock-at-accept ✔ as
   specced (D9); swap confirmation **changed** to two-sided with reminder pushes (D7 —
   documented deviation from spec §4.7 / §12.1).
2. Blaze plan approved → Cloud Functions for scheduled expiry, swap reminders, FCM fan-out (D1).
3. Email-link sign-in accepted as the "email OTP" flow (D2).
4. Reset tester data at cutover; no migration (D3).
5. AI shelf scanner stays in v1, adapted to the per-book confirm flow (D10).
6. Journal event Join: no RSVP backend, keep it simple (D11).
7. Push notifications are in scope for v1 (D12).
