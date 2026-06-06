# Turtle Turning Pages

A community platform for book trading and connecting readers in your local area.

## Project Overview

Turtle Turning Pages helps users exchange books with others nearby. The platform enables users to:

- Add books to their personal collection
- Find books by title, author, or location
- Chat with other users to arrange exchanges
- Build a reader profile
- Discover books within a specific geographic radius

## Tech Stack

### Web App
- **Frontend**: React, TypeScript, Vite, TailwindCSS, shadcn/ui
- **Backend**: Firebase (Firestore, Auth, Storage)
- **Map & Location**: Google Maps API

### Mobile App (iOS/Android)
- **Framework**: Flutter 3.35+
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **Backend**: Firebase (Firestore, Auth, Storage)

## Getting Started

### Prerequisites

- Node.js & npm (for web app)
- Flutter SDK (for mobile app)
- A Firebase account and project
- Google Maps API key (optional, for map features)

### Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project named `turtle-turning-pages`
3. Enable the following services:
   - **Authentication** (Email/Password)
   - **Firestore Database** (Start in test mode)
   - **Storage** (Start in test mode)
4. Register your apps:
   - **Web app**: Copy the config to `.env`
   - **iOS app**: Download `GoogleService-Info.plist` to `mobile/ios/Runner/`
   - **Android app**: Download `google-services.json` to `mobile/android/app/`

### Web App Setup

1. Clone the repository
2. Copy `.env.example` to `.env` and add your Firebase config:
   ```
   VITE_FIREBASE_API_KEY=your-api-key
   VITE_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
   VITE_FIREBASE_PROJECT_ID=your-project-id
   VITE_FIREBASE_STORAGE_BUCKET=your-project.appspot.com
   VITE_FIREBASE_MESSAGING_SENDER_ID=your-sender-id
   VITE_FIREBASE_APP_ID=your-app-id
   VITE_GOOGLE_MAPS_API_KEY=your-google-maps-api-key
   ```
3. Install dependencies:
   ```bash
   npm install
   ```
4. Run the development server:
   ```bash
   npm run dev
   ```
5. Visit `http://localhost:8080`

### Mobile App Setup

1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Configure Firebase (choose one):
   
   **Option A: Using FlutterFire CLI (recommended)**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   
   **Option B: Manual configuration**
   - Update `lib/config/firebase_options.dart` with your Firebase config
   - Place `GoogleService-Info.plist` in `ios/Runner/`
   
4. Run on iOS simulator:
   ```bash
   flutter run
   ```

## Features

- **User Authentication**: Sign up, sign in, password reset, and profile management
- **Book Management**: Add, edit, and remove books from your collection
- **Book Discovery**: Search by title, author, or location with radius filtering
- **Trading System**: Create and manage book trade requests
- **Chat System**: Real-time messaging between users
- **Blog**: Articles about book trading and community building

## Database Structure

See `firestore-structure.md` for the complete Firestore collections schema.

### Main Collections
- `users` - User profiles
- `books` - Book listings
- `trades` - Trade requests and status
- `conversations` - Chat conversations with messages subcollection
- `bookInterests` - Book wishlists/interests
- `notifications` - User notifications

## Security Rules

- `firestore.rules` - Firestore security rules
- `storage.rules` - Firebase Storage security rules

Deploy rules with:
```bash
firebase deploy --only firestore:rules,storage
```

## Project Structure

```
bookcircuit-exchange/
├── src/                    # Web app source
│   ├── components/         # React components
│   ├── context/           # Context providers (Auth)
│   ├── lib/               # Services and utilities
│   └── pages/             # Page components
├── mobile/                 # Flutter mobile app
│   ├── lib/
│   │   ├── config/        # Theme, router, Firebase options
│   │   ├── models/        # Data models
│   │   ├── providers/     # Riverpod providers
│   │   ├── screens/       # Screen widgets
│   │   ├── services/      # Firebase service
│   │   └── widgets/       # Reusable widgets
│   └── ios/               # iOS-specific files
├── firestore.rules        # Firestore security rules
├── storage.rules          # Storage security rules
└── firestore-structure.md # Database documentation
```

## License

MIT
