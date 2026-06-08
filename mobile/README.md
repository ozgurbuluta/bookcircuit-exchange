# Turtle Turning Pages

A community-driven book exchange app that connects local book lovers to share, trade, and discover books in their neighborhood.

## About

Turtle Turning Pages brings the joy of physical books back to communities. Instead of letting books collect dust on shelves, users can list their books for trade and discover what their neighbors are reading. The app emphasizes local, in-person exchanges — building real connections between readers.

**Why "Turtle"?** Like a turtle carrying its home, readers carry stories with them. And just like the slow, deliberate pace of a turtle, we believe in the unhurried pleasure of physical books and meaningful exchanges.

## Features

### Discover Books Nearby
- **Location-based search**: Find books available within your chosen radius (1-100 km)
- **Map view**: See book locations on an interactive Google Map
- **Genre filtering**: Browse by Fiction, Sci-Fi, Memoir, Historical, and more
- **Search**: Find specific titles or authors

### Your Book Collection
- **Add books**: List books you want to share with cover photos
- **Book details**: Title, author, condition, description, ISBN
- **Condition badges**: New, Like New, Very Good, Good, Acceptable, Poor

### Trading System
- **Request books**: Express interest in books you'd like to read
- **Trade proposals**: Offer your books in exchange
- **Trade status tracking**: Pending, Accepted, Completed, Declined
- **Notifications**: Get notified when someone wants your book

### Messaging
- **In-app chat**: Coordinate exchanges with other users
- **Real-time updates**: Instant message delivery via Firebase

### User Profiles
- **Personalized avatars**: Auto-generated initials or custom photos
- **Location display**: Show your neighborhood
- **Trade history**: Track your exchanges

## Design

### Visual Identity
- **Color palette**: Warm, literary tones inspired by aged paper and leather-bound books
  - Paper cream backgrounds (#F0E6D4, #FBF6EC)
  - Espresso ink tones (#2A211A, #5C4F42)
  - Terracotta rust accents (#B0492A)
  - Sage green highlights (#5E7355)

- **Typography**: San Francisco Pro (iOS system font) for clean, readable text

- **Book covers**: Richly colored placeholder covers when no image is available
  - Oxblood, Olive, Dusty Blue, Ochre, Plum, Terra, Forest, Slate, Sand, Ink

### User Experience
- Pull-to-refresh on all lists
- Smooth animations and transitions
- Glass-morphism cards with subtle shadows
- Intuitive bottom navigation: Home, Discover, Trades, Messages, Profile

## Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Backend**: Firebase (Firestore, Auth, Storage)
- **Maps**: Google Maps Flutter
- **Navigation**: GoRouter

## Setup

### Prerequisites
- Flutter SDK 3.x
- Xcode 15+ (for iOS)
- Firebase project configured
- Google Maps API key

### Installation

```bash
# Clone the repository
git clone https://github.com/ozgurbuluta/bookcircuit-exchange.git
cd bookcircuit-exchange/mobile

# Install dependencies
flutter pub get

# iOS setup
cd ios && pod install && cd ..

# Run the app
flutter run
```

### Environment Configuration

1. **Firebase**: Place `GoogleService-Info.plist` in `ios/Runner/`
2. **Google Maps**: Add your API key to `ios/Runner/Info.plist`:
   ```xml
   <key>GOOGLE_MAPS_API_KEY</key>
   <string>YOUR_API_KEY</string>
   ```

## Building for Release

### iOS (TestFlight)
```bash
flutter build ios --release
```
Then archive and upload via Xcode.

## Screenshots

*Coming soon*

## Contributing

We welcome contributions! Please read our contributing guidelines before submitting PRs.

## License

MIT License - see LICENSE file for details.

---

**Turtle Turning Pages** — *Slow down. Read more. Share the joy.*
