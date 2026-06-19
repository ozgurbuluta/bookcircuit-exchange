# Turtle Turning Pages - Mobile App

A community-driven book exchange iOS app connecting local book lovers to share, trade, and discover books.

## Current Status (v1.0.0 Build 5)

**Stage**: TestFlight Ready  
**Last Updated**: June 2026

> **Build 4 highlight:** "Scan a Shelf" — photograph a bookcase and AI bulk-adds
> the books (see the section below). Requires Firebase AI Logic enabled.
>
> **Build 5 improvements:** Language + per-book location (current GPS or manual)
> on Add Book; full (uncropped) cover on book detail with distance-to-book;
> working share button; Discover "Request" now sends a real request and is
> hidden for your own books.

### What's Working

| Feature | Status | Notes |
|---------|--------|-------|
| Authentication | ✅ Done | Email/password sign in & sign up |
| Home Screen | ✅ Done | Book carousel, search, FAB for adding books |
| Book Search (Add) | ✅ Done | Google Books API integration |
| Add Book | ✅ Done | Auto-fill from search, camera/gallery upload |
| Scan a Shelf | ✅ Done | Photo → Gemini detects books → review/edit → bulk add |
| Book Details | ✅ Done | Full book info, owner details, condition |
| Profile | ✅ Done | Edit profile, location, settings |
| Discover/Map | ✅ Done | Google Maps with book markers |
| Trades | ✅ Done | Trade requests, accept/decline |
| Messages | ✅ Done | Real-time chat with Firebase |
| Pull-to-refresh | ✅ Done | All list screens |
| Offline Caching | ✅ Done | Firestore persistence enabled |

### Scan a Shelf (AI bulk add)

Photograph a bookshelf and the app recognizes every book it can read, then lets
you review, edit, and add them all at once.

- **Entry**: Home → **+** FAB → "Scan a shelf"
- **Detection**: Gemini Flash (via Firebase AI Logic) returns a structured list
  of `{title, author}` from the photo (`bookshelf_scanner_service.dart`)
- **Enrichment**: each detection is matched against Google Books for cover,
  ISBN, year, and description
- **Review**: edit title/author/condition per book, set condition in bulk,
  drop wrong detections, toggle which to include; duplicates already in your
  library are flagged
- **Bulk add**: written in a single Firestore batch (`FirebaseService.createBooks`)

> **Setup required:** enable **Firebase AI Logic** in the Firebase console for
> the `turtle-turning-pages` project (Gemini Developer API backend, which has a
> free tier). App Check is recommended to protect the endpoint. Until enabled,
> scanning will return an error.

### Known Issues

- Onboarding flow temporarily disabled (routing conflicts)
- Book cover upload needs Storage rules configured
- Location permissions prompt needed on first map view

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.35+ / Dart 3.9 |
| State Management | Riverpod 2.x |
| Navigation | GoRouter 14.x |
| Backend | Firebase (Firestore, Auth, Storage) |
| Maps | Google Maps Flutter |
| AI Vision | Firebase AI Logic (Gemini Flash) |
| Book Search | Google Books API |
| Image Caching | cached_network_image |
| HTTP | http package |

## Project Structure

```
mobile/
├── lib/
│   ├── config/
│   │   ├── firebase_options.dart   # Firebase config
│   │   ├── router.dart             # GoRouter setup
│   │   ├── theme.dart              # Colors, typography
│   │   └── env.dart                # Environment constants
│   ├── models/
│   │   ├── book.dart
│   │   ├── profile.dart
│   │   ├── trade.dart
│   │   ├── conversation.dart
│   │   └── message.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── books_provider.dart
│   │   ├── trades_provider.dart
│   │   ├── conversations_provider.dart
│   │   └── location_provider.dart
│   ├── screens/
│   │   ├── auth/                   # Sign in, Sign up
│   │   ├── home/                   # Home screen
│   │   ├── discover/               # Map view
│   │   ├── books/                  # Add, Edit, Detail
│   │   ├── trades/                 # Trade list, details
│   │   ├── messages/               # Chat screens
│   │   ├── profile/                # Profile, edit
│   │   └── onboarding/             # First-time flow
│   ├── services/
│   │   ├── firebase_service.dart   # All Firebase ops
│   │   └── google_books_service.dart
│   └── widgets/                    # Reusable UI components
├── assets/
│   └── images/
│       └── logo.png                # App logo
└── ios/
    └── Runner/
        ├── Assets.xcassets/        # App icons
        └── GoogleService-Info.plist # Firebase config
```

## Setup

### Prerequisites
- Flutter SDK 3.35+
- Xcode 15+
- CocoaPods
- Firebase project with iOS app registered
- Google Maps API key

### Installation

```bash
cd mobile
flutter pub get
cd ios && pod install && cd ..
```

### Configuration

1. **Firebase**: Ensure `GoogleService-Info.plist` is in `ios/Runner/` AND added to Xcode project
2. **Google Maps**: Add API key to `ios/Runner/Info.plist`:
   ```xml
   <key>GOOGLE_MAPS_API_KEY</key>
   <string>YOUR_KEY</string>
   ```

### Running

```bash
# Debug
flutter run

# Or open in Xcode
open ios/Runner.xcworkspace
```

### Building for TestFlight

```bash
flutter build ios --release
```
Then in Xcode: Product → Archive → Distribute App → App Store Connect

## Design System

### Colors
- **Paper** (backgrounds): `#F0E6D4`, `#FBF6EC`, `#F6EEDF`
- **Ink** (text): `#2A211A`, `#5C4F42`, `#92816E`
- **Rust** (accent): `#B0492A`
- **Sage** (secondary): `#5E7355`

### Typography
San Francisco Pro (iOS system font) - no custom fonts needed

### Logo
Turtle with books on shell, circular green frame
- Location: `assets/images/logo.png`
- App icons: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## Roadmap

### v1.1 (Next)
- [ ] Re-enable onboarding flow for new users
- [ ] Push notifications for trades/messages
- [ ] Book barcode/ISBN scanner
- [ ] Image compression before upload
- [ ] Android support

### v1.2 (Future)
- [ ] Book wishlists
- [ ] User ratings/reviews
- [ ] Trade history stats
- [ ] Social sharing
- [ ] Dark mode

### v2.0 (Long-term)
- [ ] Book clubs/groups
- [ ] Reading challenges
- [ ] Local library integration
- [ ] Audiobook support

## API Dependencies

| Service | Purpose | Auth Required |
|---------|---------|---------------|
| Firebase Auth | User authentication | Yes (configured) |
| Firestore | Database | Yes (configured) |
| Firebase Storage | Image uploads | Yes (configured) |
| Google Maps | Map display | API key |
| Google Books | Book search/autofill | No (public API) |

## Troubleshooting

### "Page not found" errors
- Check router.dart redirect logic
- Ensure auth state is not stuck loading

### Firebase not working
- Verify GoogleService-Info.plist is added to Xcode project (not just folder)
- Check bundle ID matches Firebase console

### Slow book loading
- Firestore persistence is enabled (100MB cache)
- Pull-to-refresh fetches fresh data

### Maps not showing
- Verify Google Maps API key in Info.plist
- Check API key has Maps SDK for iOS enabled

---

**Turtle Turning Pages** — *Slow down. Read more. Share the joy.*
