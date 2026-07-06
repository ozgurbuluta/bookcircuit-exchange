# Auth setup checklist (Phase C — one-time console work)

> STATUS 2026-07-06: email-link ENABLED, Apple ENABLED, universal links +
> AASA DEPLOYED, Firestore rules/indexes/functions DEPLOYED. Remaining:
> §2 (Google provider + plist), §3 (Apple Developer portal), APNs key.
> See docs/RESET.md for the full record.

The app code for Apple / Google / email-link sign-in is complete. These
console steps must be done by a project owner before the flows work on device.

## 1. Firebase console — enable providers
Firebase console → Authentication → Sign-in method:

- [x] Enable **Apple** (done via API — client = bundle ID)
- [ ] Enable **Google** (set the support email)
- [x] Email link (passwordless) enabled via API
- [ ] (Cleanup, after testers migrate) Disable plain **Email/Password**

## 2. Google sign-in — iOS OAuth client
After enabling Google, Firebase creates an iOS OAuth client:

- [ ] Re-download `GoogleService-Info.plist` (it now contains `CLIENT_ID` and
      `REVERSED_CLIENT_ID`) and replace `mobile/ios/Runner/GoogleService-Info.plist`
- [ ] Add the `REVERSED_CLIENT_ID` as a URL scheme in
      `mobile/ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>PASTE-REVERSED-CLIENT-ID-HERE</string>
    </array>
  </dict>
</array>
```

## 3. Apple sign-in — Apple Developer portal
- [ ] developer.apple.com → Identifiers → `com.turtleturningpages.turtleTurningPages`
      → enable the **Sign in with Apple** capability
- [ ] Regenerate/refresh the provisioning profile if not using automatic signing

(The Xcode side is already done: `Runner/Runner.entitlements` with
`com.apple.developer.applesignin` is wired into the build settings.)

## 4. Email link — universal links (Dynamic Links is deprecated)
The link lands on `https://turtle-turning-pages.web.app/finishSignIn` and must
open the app via universal links:

- [x] `turtle-turning-pages.web.app` is in the authorized domains
- [x] Hosted and live: `apple-app-site-association` file on Firebase Hosting at
      `/.well-known/apple-app-site-association` (no extension, JSON):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.turtleturningpages.turtleTurningPages",
        "paths": ["/finishSignIn*"]
      }
    ]
  }
}
```

  (deployed with team ID 4WXK55P8VB — verify at https://turtle-turning-pages.web.app/.well-known/apple-app-site-association)

- [ ] The associated-domains entitlement (`applinks:turtle-turning-pages.web.app`)
      is already in `Runner.entitlements`

## 5. Firestore rules + indexes
- [x] Deployed: rules + indexes + functions + hosting

## 6. Tester note for the next TestFlight build
Password sign-in is gone. Existing testers sign in with the SAME EMAIL via
any of the three methods; Firebase links them to the same account only for
email link (same provider email). Apple's "Hide My Email" creates a NEW
account — testers who want their old shelf should use email link with their
original address. Data is being reset at cutover anyway (decision D3), so in
practice everyone starts fresh with 200 pts.
