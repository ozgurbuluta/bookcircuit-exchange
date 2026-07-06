# Data reset at v1 cutover (decision D3) — EXECUTED 2026-07-06

The reset has been run. This file records what happened and what little
remains manual.

## Done (automated via firebase/gcloud CLI + REST)

- [x] **Backup** exported to `gs://turtle-turning-pages-backups/pre-v1-reset`
      (new us-central1 bucket; the default bucket is us-east1 and can't
      receive Firestore exports)
- [x] **Firestore rules + indexes deployed** (rules compiled clean; 7 stale
      legacy indexes deleted)
- [x] **Cloud Functions deployed** (all Node 20 / v2, us-central1):
      `expirySweep` + `swapReminderSweep` hourly via Cloud Scheduler (ENABLED),
      `pushFanout` on notification create; artifact cleanup policy set
- [x] **Collections wiped**: books, trades, conversations, bookInterests,
      bookRequests, tradeHistory, notifications, ratings, users — all verified
      empty. Auth accounts kept: testers re-onboard and receive the fresh
      200-pt grant automatically.
- [x] **Journal seeded**: 3 `blogPosts` entries (story, reading list, and the
      Moda Park meetup event) so the Journal tab has content
- [x] **Auth providers**: email-link (passwordless) enabled, **Apple enabled**
      (client = bundle ID); authorized domains already include
      turtle-turning-pages.web.app
- [x] **Universal links live**: `https://turtle-turning-pages.web.app/.well-known/apple-app-site-association`
      serves appID `4WXK55P8VB.com.turtleturningpages.turtleTurningPages`,
      paths `/finishSignIn*` (Hosting `appAssociation: NONE` so our file wins);
      plus a small branded landing page

## Remaining manual steps (cannot be automated)

1. **Enable Google sign-in** — Firebase console → Authentication →
   Sign-in method → Google → Enable (pick the support email). This
   auto-provisions the iOS OAuth client. THEN tell Claude — fetching the
   updated `GoogleService-Info.plist` and wiring `REVERSED_CLIENT_ID` into
   `Info.plist` is scripted and ready to run.
2. **Apple Developer portal** (developer.apple.com, team 4WXK55P8VB):
   - App ID `com.turtleturningpages.turtleTurningPages` → enable
     **Sign in with Apple** and **Push Notifications** capabilities
     (Xcode automatic signing usually syncs this on the next archive)
   - Keys → create an **APNs key (.p8)** → upload it in Firebase console →
     Project settings → Cloud Messaging → Apple app configuration
3. **Archive Build 11 and upload to TestFlight** (Xcode: Product → Archive).

## TestFlight release notes (suggested)

> New season, new shell. The club moved to a points economy — every book is a
> flat 50 pts and your first 200 are on us. Sign-in is now Apple, Google, or
> an email link (no passwords). Your old shelf was retired with the redesign;
> scan your books again and they will find new readers. Good books travel
> slowly.
