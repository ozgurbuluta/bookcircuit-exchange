# Data reset at v1 cutover (decision D3)

Tester data is wiped at the redesign cutover — no migration. Old multi-book
trades cannot map to the single-book model, and everyone restarts with the
200-pt welcome grant.

Run these as a project owner, AFTER deploying the new rules/indexes/functions
and BEFORE releasing Build 11 to TestFlight.

## 1. Backup (for the record)

```bash
gcloud firestore export gs://turtle-turning-pages.firebasestorage.app/backups/pre-v1-reset \
  --project turtle-turning-pages
```

## 2. Deploy the new backend

```bash
cd /path/to/bookcircuit-exchange
firebase deploy --only firestore,functions --project turtle-turning-pages
```

(First functions deploy asks to enable Cloud Build/Artifact Registry — Blaze
plan required, approved in decision D1.)

## 3. Wipe collections

```bash
for c in books trades conversations bookInterests bookRequests tradeHistory notifications ratings users; do
  firebase firestore:delete "/$c" --recursive --force --project turtle-turning-pages
done
```

Optionally also delete the Auth users (Console → Authentication → select all →
delete) so testers re-onboard fully; otherwise existing accounts keep their
uid and just go through neighborhood setup again (the fresh user doc is
created with 0 pts and granted 200 on first sign-in).

Keep `blogPosts` if you want existing journal content to survive; delete it
too if starting the journal fresh.

## 4. Console checklist before the build

- [ ] Auth providers enabled (docs/SETUP_AUTH.md §1–4)
- [ ] APNs key uploaded: Console → Project settings → Cloud Messaging →
      Apple app configuration (needed for FCM push, decision D12)
- [ ] Seed 2–3 `blogPosts` docs with `type: story|list|event` so the Journal
      tab has content

## 5. TestFlight release notes (suggested)

> New season, new shell. The club moved to a points economy — every book is a
> flat 50 pts and your first 200 are on us. Sign-in is now Apple, Google, or
> an email link (no passwords). Your old shelf was retired with the redesign;
> scan your books again and they will find new readers. Good books travel
> slowly.
