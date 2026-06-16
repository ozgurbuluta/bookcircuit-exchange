# Turtle Turning Pages

A community platform for book trading and connecting readers in your local area.

![Logo](mobile/assets/images/logo.png)

## Project Status

| Platform | Version | Status |
|----------|---------|--------|
| iOS App | 1.0.0 (Build 3) | TestFlight Ready |
| Web App | 1.0.0 | Production Ready |
| Android | - | Planned |

## Overview

Turtle Turning Pages helps users exchange books with others nearby. List your books, discover what neighbors are reading, and arrange trades through in-app messaging.

### Key Features

- **Book Discovery** - Find books by title, author, or location radius
- **Smart Add** - Search Google Books to auto-fill book details
- **Scan a Shelf** - Photograph a bookshelf and AI bulk-adds the books (iOS)
- **Map View** - See available books on an interactive map
- **Trading System** - Request, accept, or decline book trades
- **Real-time Chat** - Coordinate exchanges with other users
- **User Profiles** - Track your library and trade history

## Tech Stack

### Shared Backend (Firebase)
- **Authentication**: Email/password
- **Database**: Firestore
- **Storage**: Firebase Storage (book covers, avatars)
- **Project ID**: `turtle-turning-pages`

### Web App (`/src`)
| Technology | Purpose |
|------------|---------|
| React 18 | UI framework |
| TypeScript | Type safety |
| Vite | Build tool |
| TailwindCSS | Styling |
| shadcn/ui | Component library |
| React Router | Navigation |
| React Query | Data fetching |

### Mobile App (`/mobile`)
| Technology | Purpose |
|------------|---------|
| Flutter 3.35 | Cross-platform framework |
| Dart 3.9 | Language |
| Riverpod | State management |
| GoRouter | Navigation |
| Google Maps Flutter | Map display |
| Google Books API | Book search |
| Firebase AI Logic | Gemini Flash vision (shelf scan) |

## Quick Start

### Prerequisites
- Node.js 18+ (web)
- Flutter 3.35+ (mobile)
- Firebase CLI
- Xcode 15+ (iOS)

### Firebase Setup

1. The project uses Firebase project `turtle-turning-pages`
2. Services enabled: Auth, Firestore, Storage
3. Configuration files:
   - Web: `src/lib/firebase.ts`
   - iOS: `mobile/ios/Runner/GoogleService-Info.plist`

### Web App

```bash
npm install
npm run dev
# Visit http://localhost:8080
```

### Mobile App (iOS)

```bash
cd mobile
flutter pub get
cd ios && pod install && cd ..
flutter run

# Or open in Xcode
open ios/Runner.xcworkspace
```

## Project Structure

```
bookcircuit-exchange/
├── src/                          # Web app (React)
│   ├── components/
│   │   ├── chat/                 # Chat UI
│   │   ├── trading/              # Trade components
│   │   ├── ui/                   # shadcn components
│   │   └── ui-custom/            # Custom components
│   ├── context/
│   │   └── AuthContext.tsx
│   ├── lib/
│   │   ├── firebase.ts           # Firebase init
│   │   ├── bookService.ts        # Book operations
│   │   ├── tradeService.ts       # Trade operations
│   │   └── types.ts              # TypeScript types
│   └── pages/                    # Route pages
│
├── mobile/                       # Mobile app (Flutter)
│   ├── lib/
│   │   ├── config/               # Theme, router, Firebase
│   │   ├── models/               # Data models
│   │   ├── providers/            # Riverpod state
│   │   ├── screens/              # UI screens
│   │   ├── services/             # Firebase, Google Books
│   │   └── widgets/              # Reusable widgets
│   ├── assets/images/            # Logo, images
│   └── ios/                      # iOS native code
│
├── public/                       # Web static assets
│   ├── favicon-32.png
│   ├── logo-192.png
│   └── og-image.png
│
├── firestore.rules               # Database security
├── storage.rules                 # Storage security
└── firestore-structure.md        # Schema docs
```

## Database Schema

### Collections
- `users` - User profiles (name, location, avatar)
- `books` - Book listings (title, author, condition, location)
- `trades` - Trade requests with status tracking
- `conversations` - Chat threads between users
- `bookInterests` - Wishlist/interest markers
- `notifications` - User notifications

See `firestore-structure.md` for complete schema.

## Development Workflow

### Adding a Feature

1. **Models**: Define data structures in `models/`
2. **Services**: Add Firebase operations in `services/`
3. **Providers** (mobile): Create Riverpod providers
4. **UI**: Build screens/components
5. **Routes**: Register in router

### Deployment

**Web App**:
```bash
npm run build
# Deploy to your hosting provider
```

**iOS App**:
```bash
cd mobile
flutter build ios --release
# Archive in Xcode → Distribute to App Store Connect
```

## What's Next

### Immediate (v1.1)
- [ ] Push notifications
- [ ] ISBN barcode scanner
- [ ] Onboarding flow polish
- [ ] Android build

### Short-term (v1.2)
- [ ] Book wishlists
- [ ] User ratings
- [ ] Trade analytics
- [ ] Dark mode

### Long-term (v2.0)
- [ ] Book clubs
- [ ] Reading challenges
- [ ] Library integration

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## API Keys Required

| Service | Environment Variable | Notes |
|---------|---------------------|-------|
| Firebase | Configured in code | See firebase_options.dart |
| Google Maps | `GOOGLE_MAPS_API_KEY` | Maps SDK for iOS enabled |
| Google Books | None | Public API, no key needed |
| Firebase AI Logic | None (in-app) | Enable the API in Firebase console for shelf scan |

## Troubleshooting

### Firebase "No app configured"
Ensure `GoogleService-Info.plist` is added to the Xcode project, not just the folder.

### Routing errors
Check auth state loading - the router waits for auth before redirecting.

### Slow loading
Firestore persistence is enabled. Pull-to-refresh fetches fresh data.

## License

MIT

---

**Turtle Turning Pages** — *Slow down. Read more. Share the joy.*
