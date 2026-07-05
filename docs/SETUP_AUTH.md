# Auth setup checklist (Phase C — one-time console work)

The app code for Apple / Google / email-link sign-in is complete. These
console steps must be done by a project owner before the flows work on device.

## 1. Firebase console — enable providers
Firebase console → Authentication → Sign-in method:

- [ ] Enable **Apple**
- [ ] Enable **Google** (set the support email)
- [ ] Enable **Email/Password → Email link (passwordless sign-in)** — enable
      the *email link* toggle; the password toggle can stay off
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

- [ ] Firebase console → Authentication → Settings → Authorized domains:
      confirm `turtle-turning-pages.web.app` is listed
- [ ] Host an `apple-app-site-association` file on Firebase Hosting at
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

  (replace `TEAMID` with the Apple team ID; deploy with `firebase deploy --only hosting`)

- [ ] The associated-domains entitlement (`applinks:turtle-turning-pages.web.app`)
      is already in `Runner.entitlements`

## 5. Firestore rules + indexes
- [ ] `firebase deploy --only firestore` (from the repo root; first deploy of
      the new rules/indexes — CLI validates rule syntax here)

## 6. Tester note for the next TestFlight build
Password sign-in is gone. Existing testers sign in with the SAME EMAIL via
any of the three methods; Firebase links them to the same account only for
email link (same provider email). Apple's "Hide My Email" creates a NEW
account — testers who want their old shelf should use email link with their
original address. Data is being reset at cutover anyway (decision D3), so in
practice everyone starts fresh with 200 pts.
