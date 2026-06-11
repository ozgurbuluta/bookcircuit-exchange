# BookCircuit — Codebase Review & Improvement Plan

**Date:** June 2026
**Scope:** React/Vite web app (`src/`), Flutter mobile app (`mobile/`), Firebase rules (`firestore.rules`, `storage.rules`), legacy Supabase SQL (repo root, `supabase/`, `src/migrations/`).

---

## 1. Executive Summary

BookCircuit (codebase name "Turtle Turning Pages") is a community book-exchange product with a React web app and a Flutter mobile app. The core flows — auth, book listing, discovery, trade requests, and real-time chat — all exist, and the codebase has a sensible service-layer shape with clear feature boundaries.

**The single biggest root cause of problems is an incomplete Supabase → Firebase migration.** The live backend is Firebase (Auth, Firestore, Storage), but the repo still carries ~40 Supabase SQL files, two unused Supabase clients, snake_case data models in the mobile app, and — most damagingly — a `user.id` vs `user.uid` mismatch that silently breaks chat, profile, requests, and ownership checks across roughly 10 web components.

**Severity counts across all four review tracks:**

| Severity | Count | Examples |
|----------|-------|----------|
| Critical | ~12 | Firestore rules allow reading all chat messages; stored XSS in blog; `user.id` bug breaking core features |
| High | ~15 | No tests; broken mobile chat routing; hardcoded Maps API key; no push/email notifications |
| Medium | ~25 | No pagination; dual toast systems; TS strict mode off; missing iOS privacy strings |
| Low | ~15 | Dead dependencies; debug routes; accessibility gaps |

**Top 5 actions (do these first):**

1. Fix `firestore.rules` — messages, trade items/history, participants, blog writes (Section 3.1)
2. Sanitize blog HTML with DOMPurify and lock blog writes to admins (Section 3.2)
3. Replace all `user.id` with `user.uid` via a normalized auth helper (Section 2.1)
4. Fix broken routes on web and chat routing on mobile (Sections 2.2, 7.1)
5. Rotate/restrict the committed Google Maps API key and enable Firebase App Check (Section 3.3)

---

## 2. Critical Bug Fixes (P0)

### 2.1 `user.id` vs `user.uid` — broken features across the web app

**Severity:** Critical · **Why it matters:** Firebase's `User` object exposes `uid`, not `id`. Every component reading `user.id` gets `undefined`, so conversations don't load, profile fetch/update targets the wrong document, request/interest checks fail, and ownership comparisons (`user.id === ownerId`) are always false. TypeScript strict mode is disabled, so this compiled silently.

**Affected files (verified occurrences):**

| File | Lines | Effect |
|------|-------|--------|
| `src/pages/Chat.tsx` | 102 | `<ChatContainer userId={undefined}>` — chat never loads |
| `src/pages/Profile.tsx` | 29, 48, 52, 81, 126 | Profile fetch/update use wrong ID |
| `src/components/ui-custom/Navbar.tsx` | 49 | Avatar/profile load fails |
| `src/components/ui-custom/RequestableBookCard.tsx` | 50, 95, 102, 130, 154, 234, 272 | Request/cancel/ownership all broken |
| `src/components/trading/RequestBookButton.tsx` | 46, 62 | Requests created with `undefined` requester |
| `src/components/trading/InterestButton.tsx` | 44, 55 | Interest check fails |
| `src/components/trading/TradeCreationModal.tsx` | 64 | Loads books for `undefined` user |
| `src/components/trading/RequestResponseModal.tsx` | 65 | Same |
| `src/components/trading/TradeDetailsCard.tsx` | 55 | Initiator detection broken |
| `src/pages/BookDetail.tsx` | 88, 185, 234 | "Own book" detection broken |
| `src/pages/TradesPage.tsx` | 222 | Initiator label wrong |

**How to implement:**

1. Add a normalized helper to `src/context/AuthContext.tsx` so the mistake cannot recur:

```tsx
// In AuthContext value:
const authUser = user ? { ...user, id: user.uid } : null;
// Or better — expose an explicit interface:
interface AppUser { id: string; email: string | null; displayName: string | null; }
```

2. Mechanically replace `user.id` → `user.uid` (or migrate to the normalized `authUser.id`) in the files above. A global grep for `user\??\.id\b` in `src/` finds all sites.
3. Type the context return so the compiler enforces it: `useAuth(): { user: AppUser | null; ... }`.
4. Add a regression test (Section 4.6) that asserts the context's user shape.

### 2.2 Broken internal routes (web)

**Severity:** Critical · **Why it matters:** Primary CTAs dead-end users.

| File | Line | Broken link | Should be |
|------|------|-------------|-----------|
| `src/pages/Dashboard.tsx` | 259, 354 | `navigate('/search')` | `/home` |
| `src/pages/TradesPage.tsx` | 135 | `navigate('/login')` | `/signin` |
| `src/components/trading/TradeDetailsCard.tsx` | 270 | `navigate(\`/messages/${otherUser.id}\`)` | Create/fetch conversation via `getOrCreateConversation`, then `/chat/:conversationId` |

**How to implement:** Fix the three links; for `TradeDetailsCard`, call `conversationService.getOrCreateConversation(user.uid, otherUser.id, bookId)` and navigate to the returned conversation ID. Consider a central `routes.ts` constants file so dead routes can't be typed by hand.

### 2.3 TradesPage maps a non-existent field

**Severity:** High · **File:** `src/pages/TradesPage.tsx` (~line 76)

```ts
is_direct_request: trade.trade_type === 'direct_request', // trade_type doesn't exist
```

`tradeService.docToTrade` already exposes `is_direct_request`. **Fix:** use `trade.is_direct_request` directly.

### 2.4 Base64 cover images stored in Firestore documents

**Severity:** High · **Files:** `src/pages/AddBook.tsx` (~L180–241), `src/pages/EditBook.tsx` (~L243–247)

Custom uploads are converted to `data:` URLs and written into the book document's `coverImgUrl`. Firestore documents are capped at 1MB — large covers will start failing writes, and every book list read downloads the full image payload.

**How to implement:** `src/lib/storageService.ts` already has an unused `uploadBookCover()`. Call it on save, store only the download URL. Migrate existing base64 docs with a one-off script (read doc → upload to Storage → replace field).

### 2.5 Mobile P0 bugs (summary — details in Section 7)

- Chat navigation pushes user IDs into a conversation-ID route (broken).
- Discover's radius filter never receives device location — filtering is a no-op.
- Trade list filters match statuses (`'incoming'`/`'outgoing'`) that don't exist.
- Picked images (book covers, avatars) are never uploaded — silently dropped.

---

## 3. Security Remediation

### 3.1 Firestore rules — critical gaps

**File:** `firestore.rules` · **Severity:** Critical

Current problems (verified against the deployed rules file):

| Lines | Rule | Problem |
|-------|------|---------|
| 93–98 | `conversations/{id}/messages` | `allow read: if isAuthenticated()` — **any logged-in user can read every private message** if they know/guess a conversation ID |
| 87–90 | `conversations/{id}/participants` | `allow write: if isAuthenticated()` — anyone can add/remove participants |
| 65–68 | `trades/{id}/tradeItems` | `allow read, write: if isAuthenticated()` — anyone can read/modify items in any trade |
| 72–76 | `tradeHistory` | Read/create open to all authenticated users — forged audit trail |
| 102–107 | `blogPosts` | `allow write: if isAuthenticated()` — any user can publish/edit blog content (feeds the XSS in 3.2) |
| 19–21 | `users` | `allow read: if true` — profiles **including email** are world-readable without auth |
| — | `bookRequests`, `notifications` | Used by `src/lib/bookService.ts` / `tradeService.ts` but **have no rules at all** — either features are broken by default-deny, or permissive rules were added in the Firebase Console outside version control |

**Replacement rules (drop-in):**

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() { return request.auth != null; }
    function isOwner(userId) { return isAuthenticated() && request.auth.uid == userId; }
    function isAdmin() { return isAuthenticated() && request.auth.token.admin == true; }

    function isConvoParticipant(conversationId) {
      return isAuthenticated() &&
        request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
    }

    function isTradeParticipant(tradeId) {
      let t = get(/databases/$(database)/documents/trades/$(tradeId)).data;
      return isAuthenticated() && (t.initiatorId == request.auth.uid || t.recipientId == request.auth.uid);
    }

    match /users/{userId} {
      // Require auth to read; move email to a private subcollection (see note)
      allow read: if isAuthenticated();
      allow create, update, delete: if isOwner(userId);
    }

    match /books/{bookId} {
      allow read: if true;
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isOwner(resource.data.userId);
    }

    match /bookInterests/{interestId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isOwner(resource.data.userId);
    }

    match /bookRequests/{requestId} {
      allow read: if isAuthenticated() &&
        (resource.data.requesterId == request.auth.uid || resource.data.ownerId == request.auth.uid);
      allow create: if isAuthenticated() && request.resource.data.requesterId == request.auth.uid;
      // Requester may cancel; owner may accept/reject. Lock immutable fields.
      allow update: if isAuthenticated() &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'updatedAt']) &&
        ((resource.data.requesterId == request.auth.uid && request.resource.data.status == 'cancelled') ||
         (resource.data.ownerId == request.auth.uid && request.resource.data.status in ['accepted', 'rejected']));
      allow delete: if false;
    }

    match /notifications/{notificationId} {
      allow read: if isOwner(resource.data.userId);
      allow create: if isAuthenticated(); // or restrict to Cloud Functions
      allow update: if isOwner(resource.data.userId) &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read']);
      allow delete: if isOwner(resource.data.userId);
    }

    match /trades/{tradeId} {
      allow read, update: if isAuthenticated() &&
        (resource.data.initiatorId == request.auth.uid || resource.data.recipientId == request.auth.uid);
      allow create: if isAuthenticated() && request.resource.data.initiatorId == request.auth.uid;
      allow delete: if false;

      match /tradeItems/{itemId} {
        allow read, write: if isTradeParticipant(tradeId);
      }
    }

    match /tradeHistory/{historyId} {
      allow read: if isAuthenticated() &&
        (resource.data.initiatorId == request.auth.uid || resource.data.recipientId == request.auth.uid);
      allow create: if isAuthenticated() && request.resource.data.actorId == request.auth.uid;
      allow update, delete: if false;
    }

    match /conversations/{conversationId} {
      allow read, update: if isAuthenticated() && request.auth.uid in resource.data.participantIds;
      allow create: if isAuthenticated() && request.auth.uid in request.resource.data.participantIds;
      allow delete: if false;

      match /participants/{participantId} {
        allow read, write: if isConvoParticipant(conversationId);
      }

      match /messages/{messageId} {
        allow read: if isConvoParticipant(conversationId);
        allow create: if isConvoParticipant(conversationId) &&
          request.resource.data.userId == request.auth.uid;
        allow update: if isOwner(resource.data.userId);
        allow delete: if false;
      }
    }

    match /blogPosts/{postId} {
      allow read: if true;
      allow write: if isAdmin();
    }
  }
}
```

**Implementation notes:**

- `get()` calls inside rules cost one read each; for hot paths (messages), consider denormalizing `participantIds` onto each message at write time instead.
- The `tradeHistory` read rule requires `initiatorId`/`recipientId` denormalized onto history docs — add these at write time in `tradeService.ts`.
- Admin via **custom claims**: set with the Admin SDK (`admin.auth().setCustomUserClaims(uid, { admin: true })`) from a one-off script or Cloud Function. Never use a client-writable field for admin.
- Email privacy: move `email` out of `users/{uid}` into `users/{uid}/private/contact` readable only by the owner, or stop storing it (it's already in Firebase Auth).
- **Deploy rules from the repo via CI** (`firebase deploy --only firestore:rules`) so Console edits can't drift.
- Mirror the trade-status state machine in rules if feasible (e.g. `pending → accepted|rejected|cancelled`), or move status transitions into a Cloud Function.

### 3.2 Stored XSS in blog rendering

**Severity:** Critical · **Files:** `src/lib/blogService.ts` (`markdownToHtml`, ~L121–139), `src/pages/BlogPost.tsx` (L119)

`markdownToHtml` is a naive regex converter that passes raw HTML through and allows `javascript:` URLs in links; the result is injected with `dangerouslySetInnerHTML`. Combined with the open `blogPosts` write rule, **any authenticated user can XSS every visitor**.

**How to implement:**

```bash
npm install dompurify react-markdown
```

Preferred: replace the regex converter entirely.

```tsx
// BlogPost.tsx
import ReactMarkdown from 'react-markdown';
<div className="prose prose-lg max-w-none">
  <ReactMarkdown>{post.content}</ReactMarkdown>
</div>
```

`react-markdown` does not render raw HTML by default and sanitizes URL schemes. If you must keep HTML output, wrap it: `DOMPurify.sanitize(htmlContent, { ALLOWED_TAGS: [...] })`. Also fix the blog write rule (3.1) — sanitization and authorization are both required.

### 3.3 Committed API keys and App Check

**Severity:** High

| File | Issue | Action |
|------|-------|--------|
| `mobile/ios/Runner/Info.plist` L48–49 | `GOOGLE_MAPS_API_KEY` committed in plaintext | **Rotate the key now** (it's in git history). Inject the new one via `--dart-define=GOOGLE_MAPS_API_KEY=...` / xcconfig; restrict it in Google Cloud Console to the iOS bundle ID and only the Maps/Places APIs; set quota alerts |
| `mobile/lib/config/firebase_options.dart` | Firebase config keys committed | Firebase client keys are public identifiers by design — acceptable, **but only if rules are tight (3.1) and App Check is on**. Also note L54–60 uses a placeholder Android app ID — run `flutterfire configure` per platform |
| `.env` (local) | Live Firebase key, correctly gitignored | Verify it was never committed: `git log --all --oneline -- .env`. Rotate if it was. Add the missing `VITE_SUPABASE_*` placeholders to `.env.example` or (better) delete them with the Supabase code |

**Enable Firebase App Check** for Firestore, Auth, and Storage (reCAPTCHA Enterprise on web, App Attest on iOS, Play Integrity on Android). This blocks the abuse vector that committed client keys otherwise open.

### 3.4 Storage rules

**File:** `storage.rules` · `blog/` images are writable by any authenticated user (L35–39). Restrict to admin custom claim, matching 3.1. Avatar/cover rules (owner-scoped, `isValidImage()`, 5MB cap) are a good baseline — keep them.

### 3.5 Supabase: decommission or patch (decision required)

The web and mobile apps do **not** use Supabase at runtime (the only imports are the two orphaned clients in `src/lib/supabase.ts` / `src/lib/supabaseClient.ts`). **Recommended: decommission.**

- **If decommissioning (recommended):** delete the Supabase project (or at least disable the anon key), remove `@supabase/supabase-js`, both client files, and all SQL (Section 4.1).
- **If the Supabase Postgres is still live for anything**, these are exploitable today and must be patched:
  - **Role self-escalation** (`supabase/migrations/profiles_table.sql` L25–28 + L57): the self-update RLS policy lets users set `role = 'admin'` on their own row. Add `WITH CHECK (role = (SELECT role FROM profiles WHERE id = auth.uid()))` or a trigger blocking non-admin role changes.
  - **`get_user_email()`** (`supabase/migrations/user_email_function.sql`): any authenticated user can look up any user's email by UUID. Drop it or restrict to trade/conversation counterparties.
  - **`fix_all_locations()`** (`supabase/migrations/debug_spatial_functions.sql`): SECURITY DEFINER mass-UPDATE callable by PUBLIC. Drop in production.
  - **SECURITY DEFINER functions** (`create_trade`, `accept_trade`, `start_conversation`, etc.): add `REVOKE EXECUTE ... FROM PUBLIC; GRANT EXECUTE ... TO authenticated;` for each.
  - **Hardcoded admin email** in `profiles_table.sql` L69–70: remove; provision admin via dashboard.

### 3.6 Other security items

- **Debug logging of auth state:** `src/components/auth/ProtectedRoute.tsx` (L12, 26, 30), `src/context/AuthContext.tsx` (8+ logs), `src/pages/EditBook.tsx` (L267–268). Remove or gate with `if (import.meta.env.DEV)`.
- **`GoogleMapsDebugger.tsx`** renders env keys in the UI — add `if (!import.meta.env.DEV) return null;`.
- **Third-party script:** `index.html` L22 loads `https://cdn.gpteng.co/gptengineer.js` (Lovable artifact) — remove before production; it's arbitrary third-party JS on every page.
- **Ownership check on edit (defense-in-depth):** `src/pages/EditBook.tsx` and `mobile/lib/screens/books/edit_book_screen.dart` load any book by ID without checking `book.userId === user.uid`. Firestore rules enforce this server-side, but add the client guard for UX (redirect with an error toast).
- **Password policy:** enforce 8–12+ characters with a strength meter on `GetStarted.tsx` and mobile sign-up; optionally enable Firebase Identity Platform password policy.
- **Email verification:** send verification on signup; show a banner for unverified users; optionally gate trading on verification.
- **Dependencies:** enable Dependabot; run `npm audit` and `dart pub outdated` in CI; remove `lovable-tagger` from production builds.

---

## 4. Code Quality Improvements

### 4.1 Remove the dead Supabase layer

**Severity:** High (root cause of confusion and bugs)

Delete or relocate:

- `src/lib/supabase.ts`, `src/lib/supabaseClient.ts` (duplicate, both unused)
- `@supabase/supabase-js` from `package.json`
- `src/migrations/` (SQL inside the frontend source tree — 11 files, one of which, `01_user_notifications_table.sql`, is broken with a duplicate `user_id` column)
- Root-level SQL files (`trades_table.sql`, `book_interests_table.sql`, `trade_management_functions.sql`, etc. — ~15 files)
- `supabase/` directory — **after** the decommission decision in 3.5. If keeping for reference, move everything to `archive/supabase/` with a README stating it is not deployed.
- Update `MOBILE_APP_BRIEFING.md` / `firestore-structure.md` so docs describe the actual (Firebase) backend.

### 4.2 TypeScript strict mode

**Severity:** High · **Files:** `tsconfig.json` (L12–17), `tsconfig.app.json` (L18–22)

`noImplicitAny: false` and `strictNullChecks: false` are what let the `user.id` bug ship. Migration path:

1. Turn on `"strict": true` in `tsconfig.app.json`; run `tsc --noEmit` to get the error inventory.
2. Fix in this order: `src/context/AuthContext.tsx` and auth types → `src/lib/*Service.ts` → pages/components.
3. For an incremental path, enable `strictNullChecks` first (catches the worst class of bugs), then `noImplicitAny`.
4. Migrate the untyped chat module: `src/components/chat/*.jsx` (5 files) and `src/lib/dateUtils.js` → `.tsx`/`.ts` with typed props.
5. Add a typed `ImportMetaEnv` interface in `src/vite-env.d.ts` for `VITE_FIREBASE_*` and the Maps key.
6. Re-enable `@typescript-eslint/no-unused-vars` in `eslint.config.js` (L26) with the `argsIgnorePattern: '^_'` convention.

### 4.3 Adopt React Query (it's already installed)

`QueryClientProvider` wraps the app (`src/App.tsx` L27–30) but zero `useQuery`/`useMutation` calls exist. Every page hand-rolls `useEffect` + `useState` + loading flags.

**How to implement:** Create hooks per domain and migrate page by page:

```ts
// src/hooks/useBooks.ts
export const useUserBooks = (uid: string) =>
  useQuery({ queryKey: ['books', 'user', uid], queryFn: () => getUserBooks(uid), enabled: !!uid });

export const useRequestBook = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ bookId, uid }: { bookId: string; uid: string }) => requestBook(bookId, uid),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['requests'] }),
  });
};
```

Migrate in order of duplication pain: `Dashboard` → `Home` → `TradesPage` → `BookDetail`. This eliminates duplicated loading/error logic and gives caching + refetch-on-focus for free. (Real-time chat stays on `onSnapshot`.)

### 4.4 Fix N+1 queries and add pagination

| Location | Problem | Fix |
|----------|---------|-----|
| `src/lib/tradeService.ts` `docToTrade` (L20–49) | Per trade: 2 profile reads + N item reads + N book reads | Batch profile fetches with `where(documentId(), 'in', ids)` (chunked by 10); denormalize book title/cover onto trade items at creation |
| `src/components/ui-custom/RequestableBookCard.tsx` (L42–68) | Each card runs its own `bookRequests` query — 8 cards = 8 queries | Lift to parent: one `getUserPendingRequests(uid)` call, pass a `Set<bookId>` down |
| `src/lib/bookService.ts` geo search (L402–408) | Fetches 100 books, filters distance client-side — misses everything outside the slice | Add geohash fields (`geofire-common`), query by geohash bounds, refine distance client-side |
| `getUserNotifications` (`tradeService.ts` L336–345) | Fetches all, then `.slice(0, n)` | Use Firestore `limit(n)` + `orderBy` |
| All list queries (`getUserBooks`, `getUserTrades`, `getUserConversations`, `getAllBlogPosts`) | Unbounded | `limit()` + `startAfter()` cursor pagination; with React Query use `useInfiniteQuery` |

### 4.5 Split god files

| File | Lines | Split into |
|------|-------|-----------|
| `src/lib/bookService.ts` | ~751 | `bookRepository.ts` (CRUD), `bookSearch.ts` (search/geo), `bookRequests.ts` (request/interest) |
| `src/pages/AddBook.tsx` / `EditBook.tsx` | ~579 / ~517 | Shared `<BookForm>` + `<OpenLibrarySearch>` components; kills the duplicated-and-divergent condition enums (`AddBook` L49 vs `EditBook` L47 — define one shared Zod enum in `src/lib/types.ts`) |
| `src/pages/Home.tsx` | ~471 | `<QuickSearch>`, `<AdvancedSearch>`, `<ResultsGrid>` |
| `src/context/AuthContext.tsx` | ~318 | Keep auth state; move profile CRUD into `profileService.ts` (and delete the duplicate `fetchUserProfile` in `bookService.ts` L83–100) |
| `mobile/lib/services/firebase_service.dart` | ~547 | `AuthRepository`, `BooksRepository`, `TradesRepository`, `ChatRepository` |
| `mobile/lib/screens/discover/discover_screen.dart` | ~717 | Extract `FilterSheet`, `BookMapView`, `BookListView` widgets |

### 4.6 Testing (currently zero on both platforms)

**Web:** `npm i -D vitest @testing-library/react @testing-library/jest-dom jsdom` and add `"test": "vitest"`. Priority order:

1. Auth user-shape regression test (locks in the `uid` fix)
2. `tradeService.docToTrade` mapping (locks in the `is_direct_request` fix)
3. Route-link integrity (render nav components, assert hrefs exist in the route table)
4. **Firestore rules tests** with `@firebase/rules-unit-testing` — assert a non-participant cannot read messages/trade items (locks in Section 3.1)

**Mobile:** Replace the placeholder `test/widget_test.dart` with provider unit tests using `fake_cloud_firestore`, widget tests for auth forms, and a trade-status serialization round-trip test (locks in 7.4).

**CI:** GitHub Actions running lint + typecheck + tests + `firebase deploy --only firestore:rules` on main.

### 4.7 Cleanup checklist

- Remove dual toast systems — standardize on Sonner (already used in trading flows); delete the Radix `Toaster` from `App.tsx` and migrate `use-toast` call sites. (Also fixes `TOAST_REMOVE_DELAY = 1000000` in `src/hooks/use-toast.ts`.)
- Remove dead routes/components: `/simple-test` + `SimpleTest.tsx`, `GoogleMapsDebugger` (or dev-gate), `testGeographyColumn` in `bookService.ts`, unimported `App.css`.
- Consolidate Google Maps loading on `src/lib/googleMapsLoader.ts` (remove the inline loader in `PostalCodeAutocomplete.tsx`).
- Remove unused npm deps: `recharts`, `cmdk`, `vaul`, `embla-carousel-react`, `react-day-picker`, `input-otp`, `react-resizable-panels` (+ their shadcn component files if unused), `@supabase/supabase-js`.
- Merge duplicate Button components (`ui/button.tsx` vs `ui-custom/Button.tsx`) by extending `buttonVariants` with brand variants.
- Either add a `ThemeProvider` (next-themes) or remove `useTheme()` from `src/components/ui/sonner.tsx`.
- `EditBook.tsx` (L82–91): replace the parallel `onAuthStateChanged` listener with `useAuth()`.
- Align naming: `package.json` name, `index.html` title, and UI all say different things ("turtle-turning-pages" vs "BookCircuit").

---

## 5. UX Improvements

### 5.1 Onboarding & activation (highest-leverage UX work)

**Current:** signup collects only email/password (`GetStarted.tsx` never passes `fullName` even though `signUp` supports it), then drops users on an empty Dashboard. No location is collected, so the core "books near you" value prop is broken from minute one.

**How to implement:**

1. Add a name field to `GetStarted.tsx` and pass it through `signUp`.
2. Create `/welcome` (protected): step 1 — location via the existing `PostalCodeAutocomplete`; step 2 — "Add your first book" (reuse `<BookForm>` from 4.5) with a skip option.
3. Persist `onboardingCompleted` on the profile; `ProtectedRoute` redirects to `/welcome` until set.
4. Unify post-auth destination: signup currently goes to `/dashboard`, sign-in defaults to `/home`. Pick `/home` (discovery-first) for both.

### 5.2 Empty states & CTAs

| Location | Current | Improvement |
|----------|---------|-------------|
| `Dashboard.tsx` | "No books yet" + CTA; "Find Books to Request" points at broken `/search` | Fix link to `/home`; add a 3-step checklist ("Add a book → Set your location → Browse nearby") |
| `Home.tsx` | "No books available yet", no action | Add "Be the first — add a book" → `/add-book` |
| `ChatContainer.jsx` | Text only, no link | Button → `/home` ("Find a book and message its owner") |
| `TradesPage.tsx` | Decent empty card, but the page has **no Navbar/Footer** | Wrap in the standard layout like every other page |
| `TradeNotificationDropdown.tsx` | "No notifications" | One line explaining what triggers them + link to `/home` |

### 5.3 Feedback, loading, and error consistency

- **Silent failures:** `Home.tsx` search catches (L103, 133, 160, 197) and `ChatContainer.jsx` send errors only `console.error`. Add toasts ("Search failed — please try again") and disable the send button while in flight.
- **Loading states:** standardize on skeleton grids for lists (already in `Home`/`Blog`/`TradesPage`) and button spinners for actions; replace full-page spinners in `Dashboard`/`Profile`/`BookDetail`.
- **Optimistic updates:** with React Query mutations (4.3), make request/cancel and interest toggles optimistic with rollback; chat send can append locally before the snapshot confirms.
- **Password reset:** `SignIn.tsx` (~L114) uses `alert()` — use the toast system.

### 5.4 Forms & validation

- `Profile.tsx` has no validation (unlike `AddBook`) — add zod + react-hook-form (URL format for website, bio max length). Also: `favorite_genre` is rendered but never persisted by `updateProfile` — wire it into the Firestore profile or remove the field.
- Require `author` in `bookFormSchema` (currently optional; hurts marketplace quality) and default it from the Open Library selection.
- Advanced search: show "Enter at least one search field" instead of silently setting empty results.
- Social login buttons on `SignIn.tsx` have no handlers — remove them or wire Firebase Google auth (`signInWithPopup(new GoogleAuthProvider())`). A dead "Continue with Google" button is a trust-killer. Same for the inert "Remember me" checkbox (implement via `browserLocalPersistence` vs `browserSessionPersistence`, or delete).

### 5.5 Responsive chat (P0)

`ChatContainer.jsx` (L164, 173) uses fixed `w-1/3` / `w-2/3` panes at all viewports — unusable on phones.

```jsx
// List pane: full width on mobile, hidden when a conversation is open
<div className={`${selectedId ? 'hidden md:block' : 'block'} w-full md:w-1/3 ...`}>
// Thread pane: full width on mobile with a back button
<div className={`${selectedId ? 'flex' : 'hidden md:flex'} w-full md:w-2/3 flex-col ...`}>
```

Also: `TradesPage.tsx` `grid-cols-5` tab bar is cramped on small screens — make it horizontally scrollable below `md`.

### 5.6 Accessibility

- `aria-label` on icon-only buttons: password visibility toggles (`GetStarted.tsx`, `SignIn.tsx`), notification bell (`TradeNotificationDropdown.tsx`).
- `ConversationList.jsx`: clickable `<li>` → `<button>` (keyboard + screen reader support), with `aria-selected`.
- Audit low-contrast text (`text-book-dark/60`, gray timestamps in `MessageItem.jsx`) against WCAG AA.
- Flutter: no `Semantics`/`semanticLabel` anywhere in `mobile/lib` — add to tab items, FAB, icon buttons; test with VoiceOver.

### 5.7 Trust & honesty on the landing page

- `Index.tsx` claims "10,000+ Active Users" / "50,000+ Books Traded" — fabricated. Replace with real Firestore counts (a scheduled Cloud Function writing to a `stats/global` doc) or qualitative copy.
- Landing promises "genre, condition, and distance" filters that `Home.tsx` doesn't have — implement (Section 6.3) or soften the copy.
- `Hero.tsx` "app preview" is a stock Unsplash photo with a fake play button — replace with a real screenshot or short demo video.

---

## 6. Engagement Improvements

### 6.1 Unread message badge + live notifications

- `conversationService.ts` already has `getUnreadMessagesCount()` — **it's never used**. Subscribe in `Navbar.tsx` and render a badge on the Messages link.
- `TradeNotificationDropdown.tsx` fetches once on mount. Replace with `onSnapshot` on `notifications` (ordered, limited) so the bell updates live.
- Web read receipts (`MessageItem.jsx` `CheckCheck`) are decorative — store per-participant `lastReadAt` on the conversation's `participants` subdoc, set on open, and style the checks when `lastReadAt > message.createdAt`. The same data powers unread counts on both platforms (mobile currently hardcodes `unreadCount: 0`).

### 6.2 Push and email notifications

- **Web push (FCM):** add `firebase/messaging`, a `public/firebase-messaging-sw.js` service worker, and store FCM tokens on `users/{uid}/private/fcmTokens`. Prompt for permission contextually (after the first trade request or message, not on load).
- **Cloud Functions** (the missing server layer): Firestore triggers on `bookRequests` create, `trades` status change, and new messages → send FCM push + transactional email (Trigger Email extension or Resend/Postmark). Add a weekly "new books within X km of you" digest (scheduled function) — the single best re-engagement hook for this product.
- Notification preferences on the profile page (per-channel toggles) to stay deliverable and compliant.

### 6.3 Discovery & recommendations

- Implement the promised filters on `Home.tsx`: genre and condition are simple Firestore `where` clauses; distance comes with the geohash work (4.4).
- "Near you" section using profile location; "More in <genre>" based on the user's shelf genres. Both are cheap queries, no ML needed.
- Surface `InterestButton` on `RequestableBookCard` (currently only on detail pages) and add a "My interests" section to the Dashboard; notify owners when someone marks interest ("2 people want this book").

### 6.4 PWA

No manifest or service worker exists. Add `vite-plugin-pwa`:

```ts
// vite.config.ts
import { VitePWA } from 'vite-plugin-pwa';
plugins: [react(), VitePWA({
  registerType: 'autoUpdate',
  manifest: {
    name: 'BookCircuit', short_name: 'BookCircuit',
    theme_color: '#D17A42', // align with brand accent; index.html currently says #B0492A
    icons: [/* 192/512 icons already in public/ */],
  },
})]
```

Gives installability + offline shell, and the service worker doubles as the FCM receiver.

### 6.5 Social proof & profile depth

- Lightweight activity strip on `/home`: "N books added near you this week" (aggregate query, no privacy leak).
- Show real trade counts and member-since on profiles (mobile currently hardcodes `'0'`/`'-'`); optional post-trade ratings later — trust signals matter most in a meet-a-stranger exchange product.
- Tease the latest blog post on `/home` for return visits.

---

## 7. Mobile (Flutter) Improvements

### 7.1 Fix chat routing (P0)

**Files:** `mobile/lib/screens/books/book_detail_screen.dart` (~L313), `mobile/lib/screens/trades/trade_detail_screen.dart` (~L240), `mobile/lib/config/router.dart`

Book detail pushes `/chat/${book.userId}` (a **user** ID into the conversation-ID route); trade detail pushes `/chat/new?userId=...` which doesn't exist in the router.

**Fix:** create/fetch the conversation first, then navigate:

```dart
final convo = await ref.read(conversationActionsProvider.notifier)
    .startConversation(otherUserId: book.userId, bookId: book.id);
if (context.mounted) context.push('/chat/${convo.id}');
```

Add a route helper class (`AppRoutes.chat(conversationId)`) so hand-typed paths can't drift.

### 7.2 Wire up geolocation (P0)

`geolocator` is in `pubspec.yaml` but imported nowhere; Discover's radius slider filters nothing because `BookSearchParams.lat/lng` are never set, and `add_book_screen.dart` saves books without coordinates (so they can never appear in radius results or on the map).

**Fix:** on Discover init, request permission and call `Geolocator.getCurrentPosition()` (fallback to profile location), feed coords into `bookSearchParamsProvider`; on book create, copy the user's profile lat/lng/postal code onto the book.

### 7.3 Implement image uploads (P0)

`add_book_screen.dart` (L185–206) and `edit_profile_screen.dart` (L115–130) pick images that are then silently dropped. Add to the Firebase service:

```dart
Future<String> uploadImage(File file, String path) async {
  final ref = FirebaseStorage.instance.ref(path);
  await ref.putFile(file);
  return ref.getDownloadURL();
}
```

Call before saving; store the download URL in `coverUrl`/`avatarUrl`. **Prerequisite:** add the missing iOS privacy strings to `mobile/ios/Runner/Info.plist` — `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` are absent while `image_picker` uses both; iOS will hard-crash the app on access without them. (Also remove `NSLocationAlwaysAndWhenInUseUsageDescription` since only when-in-use is needed — App Review flags unjustified "always" strings.)

### 7.4 Fix trade filters and status serialization

- `trades_provider.dart` (L13–24): `TradeFilter.incoming/outgoing` set `statusFilter` to `'incoming'`/`'outgoing'`, which match no status — those tabs are always empty. Use the initiator/recipient client-side filter only.
- `firebase_service.dart` (L486–488): status is written as raw strings but parsed with `e.name ==` — snake_case data from the web client deserializes wrong. Add a single `TradeStatus.fromString` / `.value` mapping used for both read and write, and standardize the wire format with the web app's `tradeService.ts`.
- Use `FieldValue.serverTimestamp()` for trade timestamps instead of client `DateTime.now()`.

### 7.5 Finish or hide half-built features

| Feature | State | Action |
|---------|-------|--------|
| Favorites/interest | UI-only `setState` + SnackBar; provider returns `false` (TODO) | Implement against `bookInterests` (shared with web) or remove the heart |
| Unread badges | Hardcoded `unreadCount: 0` | Implement via per-participant `lastReadAt` (shared design with 6.1) |
| Password reset | `resetPassword` exists; UI says "coming soon" | Wire the "Forgot password?" button to an email prompt dialog |
| Onboarding screens | Built but unreachable | Add the `onboardingCompletedProvider` check to the router redirect |
| Chat camera button, "Active now" label, generic "Chat" title | Decorative | Remove camera button; load the counterpart's profile for the title |
| Profile stats | Hardcoded | Wire to `tradesProvider` or hide |

### 7.6 Mobile code quality

- Surface errors: `ChatState.error` and the action providers (`bookActionsProvider`, `tradeActionsProvider`) set error states no screen displays — `ref.listen` and show a SnackBar with retry. `OpenLibraryService` swallows all exceptions and returns `[]` — show "Search unavailable".
- `router.dart` recreates GoRouter on every auth change (`ref.watch(authProvider)` inside the provider) — use `refreshListenable` with a `GoRouterRefreshStream`; set `debugLogDiagnostics: kDebugMode`.
- N+1 patterns mirror the web: `_docToTrade` loads profiles + books per trade; `subscribeToMessages` re-fetches the author profile per message on every snapshot. Cache profiles in-memory and denormalize sender name/avatar onto messages.
- Add pagination (`startAfterDocument`) to books/trades/conversations/messages; add `RefreshIndicator` to Discover and Profile (other tabs have it).
- Fix the `ConversationParticipant.odroid` field name (→ `userId`); reconcile snake_case `fromJson` models with camelCase Firestore data via one canonical mapper.
- Cap Firestore cache (`main.dart` uses `CACHE_SIZE_UNLIMITED`) at ~100MB.
- Remove unused deps: `flutter_hooks`, `hooks_riverpod`, `riverpod_annotation`/`riverpod_generator` (+ `build_runner` — no codegen exists), `flutter_secure_storage`, `shimmer`, `flutter_svg`, `uuid`, `url_launcher`.

---

## 8. Prioritized Roadmap

### Phase 1 — Security & P0 bugs (Week 1)

| # | Task | Section |
|---|------|---------|
| 1 | Deploy fixed `firestore.rules` (messages, tradeItems, tradeHistory, participants, blogPosts, users, + bookRequests/notifications) | 3.1 |
| 2 | Blog: `react-markdown`/DOMPurify + admin-only writes | 3.2 |
| 3 | Rotate + restrict the Maps API key; enable App Check | 3.3 |
| 4 | Fix `user.id` → `user.uid` with normalized auth helper | 2.1 |
| 5 | Fix broken web routes and mobile chat routing | 2.2, 7.1 |
| 6 | Decide Supabase decommission; patch the SQL criticals if it stays live | 3.5 |
| 7 | Remove debug logs, gptengineer script, `/simple-test` | 3.6, 4.7 |

### Phase 2 — Activation & correctness (Weeks 2–3)

| # | Task | Section |
|---|------|---------|
| 8 | Post-signup onboarding (name, location, first book); unify auth redirects | 5.1 |
| 9 | Cover uploads to Storage (web base64 fix + mobile pickers + iOS privacy strings) | 2.4, 7.3 |
| 10 | Mobile: geolocation wiring, trade filter/status fixes, password reset, onboarding routing | 7.2, 7.4, 7.5 |
| 11 | Responsive chat layout; TradesPage layout/tabs | 5.5 |
| 12 | Unread badge + live notification listener; surface silent errors | 6.1, 5.3 |
| 13 | Remove Supabase dead code + SQL sprawl; single toast system; dead deps | 4.1, 4.7 |
| 14 | Test foundation: Vitest + rules tests + first Flutter tests; CI | 4.6 |

### Phase 3 — Engagement & scale (Weeks 4–6)

| # | Task | Section |
|---|------|---------|
| 15 | Cloud Functions: push (FCM) + transactional email + weekly nearby-books digest | 6.2 |
| 16 | Genre/condition/distance filters (geohash); "Near you" recommendations | 6.3, 4.4 |
| 17 | React Query adoption + pagination on all lists (web and mobile) | 4.3, 4.4 |
| 18 | PWA (manifest + service worker) | 6.4 |
| 19 | Real landing-page stats; hero screenshot; honest copy | 5.7 |
| 20 | Read receipts; interest notifications; profile trade stats | 6.1, 6.5 |

### Phase 4 — Long-term health (ongoing)

| # | Task | Section |
|---|------|---------|
| 21 | TypeScript strict mode migration; chat `.jsx` → `.tsx` | 4.2 |
| 22 | Split god files (web services/pages, `FirebaseService`, `discover_screen`) | 4.5 |
| 23 | Accessibility pass (web aria/keyboard, Flutter Semantics) | 5.6 |
| 24 | Dependabot + audit in CI; align branding/naming | 3.6, 4.7 |

---

*Findings consolidated from four review tracks: web code quality, security audit, Flutter mobile review, and UX/engagement review. File paths and line numbers were spot-verified against the working tree at the time of writing; line numbers may drift as fixes land.*
