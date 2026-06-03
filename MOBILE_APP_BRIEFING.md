# Mobile App Development Briefing: Turtle Turning Pages

## Executive Summary

**Turtle Turning Pages** is a community-driven book trading platform that enables users to exchange physical books with others in their local area. This document provides a comprehensive briefing for LLM agents to assist in developing a native mobile application (iOS/Android) that mirrors and extends the existing web application functionality.

---

## 1. Application Overview

### Purpose
A peer-to-peer book trading platform connecting local readers to exchange physical books, fostering community engagement and sustainable reading habits.

### Core Value Propositions
- **Local Discovery**: Find books available within a configurable geographic radius (1-100km)
- **Direct Trading**: Propose and negotiate book exchanges with other users
- **Real-time Communication**: Built-in messaging system for coordination
- **Community Building**: User profiles, book collections, and engagement features

---

## 2. Current Tech Stack (Web Application)

### Frontend
- **Framework**: React 18.3 with TypeScript
- **Build Tool**: Vite 5.4
- **Styling**: TailwindCSS 3.4 + shadcn/ui components
- **State Management**: React Context (AuthContext) + TanStack React Query
- **Forms**: React Hook Form + Zod validation
- **Routing**: React Router DOM 6.x

### Backend (Supabase)
- **Database**: PostgreSQL with PostGIS extension for geospatial queries
- **Authentication**: Supabase Auth (email/password)
- **Storage**: Supabase Storage (avatar and book cover images)
- **Real-time**: Supabase Realtime subscriptions (PostgreSQL CDC)
- **Functions**: PostgreSQL RPC functions for complex operations

### External APIs
- **Google Maps API**: Postal code autocomplete and geocoding
- **Open Library API**: Book metadata lookup (title, author, cover, ISBN)

---

## 3. Data Models

### Profile
```typescript
interface Profile {
  id: string;                    // UUID, references auth.users
  full_name?: string;
  avatar_url?: string;
  email?: string;
  location?: string;             // Free-text location
  bio?: string;
  website?: string;
  favorite_genre?: string;
  role?: string;                 // 'user' | 'admin'
  created_at?: string;
  updated_at?: string;
}
```

### Book
```typescript
interface Book {
  id: string;                    // UUID
  user_id: string;               // Owner's user ID
  title: string;
  author: string;
  description?: string;
  condition: 'New' | 'Like New' | 'Very Good' | 'Good' | 'Acceptable' | 'Poor';
  isbn?: string;
  cover_img_url?: string;
  publisher?: string;
  publication_year?: number;
  language?: string;
  pages?: number;
  genres?: string[];
  location_text?: string;        // Human-readable location
  postal_code?: string;
  location_lat?: number;         // Latitude for geo queries
  location_lng?: number;         // Longitude for geo queries
  status?: 'available' | 'requested' | 'trading' | 'completed';
  current_trade_id?: string;
  trade_count?: number;
  interest_count?: number;
  distance_km?: number;          // Calculated field from geo search
  created_at: string;
  updated_at: string;
  owner?: Profile;               // Joined relation
}
```

### Trade
```typescript
interface Trade {
  id: string;
  initiator_id: string;          // User who proposed the trade
  recipient_id: string;          // User who receives the proposal
  status: 'request_pending' | 'pending' | 'accepted' | 'rejected' | 'completed' | 'cancelled';
  created_at: string;
  updated_at: string;
  initiator_message?: string;
  recipient_message?: string;
  is_direct_request: boolean;    // Single book request vs multi-book trade
  is_counteroffered: boolean;
  items: TradeItem[];            // Books involved in the trade
}

interface TradeItem {
  id: string;
  trade_id: string;
  book_id: string;
  owner_id: string;
  recipient_id: string;
  item_type: 'book';
  book?: Book;                   // Joined relation
}
```

### Conversation & Messages
```typescript
interface Conversation {
  id: string;
  created_at: string;
  updated_at: string;
  last_message?: string;
  last_message_at?: string;
  last_message_sender_id?: string;
  book_id?: string;              // Optional: conversation about specific book
  unread_count?: number;         // Calculated field
  participants: ConversationParticipant[];
  other_user?: Profile;          // The other participant
}

interface Message {
  id: string;
  conversation_id: string;
  user_id: string;
  content: string;
  created_at: string;
  updated_at?: string;
  is_edited?: boolean;
  attachments?: any;             // JSONB for future expansion
}
```

### Book Interest
```typescript
interface BookInterest {
  id: string;
  user_id: string;
  book_id: string;
  status: 'active' | 'inactive';
  note?: string;
  created_at: string;
}
```

---

## 4. Core Features

### 4.1 Authentication
- **Sign Up**: Email + password registration
- **Sign In**: Email + password authentication
- **Session Persistence**: Auto-refresh tokens, persistent sessions
- **Profile Auto-Creation**: Default profile created on first sign-up

### 4.2 Book Management
- **Add Book**: Manual entry or Open Library API lookup
- **Edit Book**: Update book details and location
- **Delete Book**: Remove from collection
- **Book Conditions**: 6-level condition scale
- **Location Association**: Postal code with geocoding for proximity search

### 4.3 Book Discovery
- **Quick Search**: Search by title OR author (combined)
- **Advanced Search**: Filter by title, author, postal code, radius
- **Geographic Search**: PostGIS-powered proximity queries (ST_DWithin)
- **Distance Display**: Show distance to each book in search results
- **Radius Slider**: 1-100km with smart step increments

### 4.4 Trading System
- **Direct Request**: Request a single book from another user
- **Trade Proposal**: Offer your books in exchange for theirs
- **Trade Negotiation**: Accept, reject, or counter-offer
- **Trade Status Tracking**: Full lifecycle management
- **Trade History**: Audit trail of all trade actions

### 4.5 Messaging
- **Real-time Chat**: Instant messaging between users
- **Conversation List**: Sorted by most recent activity
- **Unread Counts**: Badge indicators for unread messages
- **Message History**: Paginated loading of older messages
- **Book Context**: Conversations can be associated with specific books

### 4.6 User Profile
- **Profile Editing**: Name, bio, location, website, favorite genre
- **Avatar Upload**: Image upload to Supabase Storage
- **Public Visibility**: All profiles are publicly viewable

### 4.7 Notifications (Implicit)
- Real-time updates via Supabase subscriptions for:
  - New messages
  - Trade status changes
  - Book requests

---

## 5. Key Database Functions (RPC)

### Geographic Search
```sql
-- Find books within distance
books_within_distance(search_lat, search_lng, max_distance_meters)
-- Returns: books with calculated_distance_meters field, sorted by distance
```

### Trade Operations
```sql
-- Get all trades for current user
get_user_trades(p_status_filter)

-- Create a new trade
create_trade(p_partner_id, p_my_book_ids, p_their_book_ids, p_message)

-- Update trade status
update_trade_status(p_trade_id, p_new_status)

-- Get available books for user
get_user_available_books(p_user_id)
```

### Conversation Operations
```sql
-- Start or get existing conversation
start_conversation(other_user_id, initial_message, book_id)
```

---

## 6. Authentication Flow

```
1. User enters email/password
2. Supabase Auth validates credentials
3. On success: Session token returned, stored in secure storage
4. Auth state change triggers profile fetch
5. If no profile exists: auto-create default profile
6. User redirected to Dashboard/Home
```

### Session Management
- Tokens auto-refresh before expiry
- Session persists across app restarts
- Logout clears local session and navigates to landing page

---

## 7. Real-time Subscriptions

### Currently Implemented
1. **Messages**: New messages in active conversation
2. **Trades**: INSERT/UPDATE/DELETE on trades table (filtered by user)
3. **Conversations**: New conversation participants

### Subscription Pattern
```javascript
supabase.channel('channel-name')
  .on('postgres_changes', {
    event: 'INSERT' | 'UPDATE' | 'DELETE',
    schema: 'public',
    table: 'table_name',
    filter: `column=eq.${value}`
  }, callback)
  .subscribe()
```

---

## 8. Mobile-Specific Considerations

### 8.1 Must-Have Mobile Features
- **Push Notifications**: New messages, trade updates, book requests
- **Camera Integration**: Scan ISBN barcodes, capture book photos
- **Location Services**: Current location for proximity search
- **Offline Support**: Cache recent data, queue actions when offline
- **Deep Linking**: Open specific books, trades, or conversations from links

### 8.2 UI/UX Adaptations
- **Bottom Navigation**: Dashboard, Search, Add Book, Messages, Profile
- **Pull-to-Refresh**: On all list views
- **Swipe Actions**: Delete books, dismiss notifications
- **Native Image Picker**: For avatars and book covers
- **Native Maps**: For location selection and visualization

### 8.3 Performance Considerations
- **Image Optimization**: Lazy loading, thumbnail generation
- **Pagination**: Already implemented, maintain for mobile
- **Connection Handling**: Graceful degradation on poor connectivity
- **Background Sync**: Sync data when app returns to foreground

---

## 9. Recommended Mobile Tech Stack

### Option A: React Native (Recommended for code sharing)
```
Framework: React Native 0.73+
Navigation: React Navigation 6
State: TanStack Query + Zustand/Context
Forms: React Hook Form
Storage: @react-native-async-storage/async-storage
Maps: react-native-maps
Camera: expo-camera or react-native-camera
Notifications: expo-notifications or @notifee/react-native
Supabase: @supabase/supabase-js (same as web)
```

### Option B: Flutter (For optimal native feel)
```
Framework: Flutter 3.x
State: Riverpod or BLoC
Storage: shared_preferences + sqflite
Maps: google_maps_flutter
Camera: camera + image_picker
Notifications: firebase_messaging + flutter_local_notifications
Supabase: supabase_flutter
```

### Option C: Native (Maximum platform integration)
```
iOS: SwiftUI + Combine
Android: Kotlin + Jetpack Compose
Both: Supabase client libraries available
```

---

## 10. Implementation Priorities

### Phase 1: Core MVP
1. Authentication (sign up, sign in, sign out)
2. Profile management
3. Book CRUD operations
4. Basic search (title/author)
5. Book detail view

### Phase 2: Discovery & Trading
1. Geographic search with radius
2. Direct book requests
3. Trade proposals
4. Trade management (accept/reject/cancel)

### Phase 3: Communication
1. Conversation list
2. Real-time messaging
3. Push notifications
4. Unread indicators

### Phase 4: Enhanced Features
1. ISBN barcode scanning
2. Camera capture for book photos
3. Offline support
4. Deep linking
5. Share functionality

---

## 11. API Endpoints Reference

### Supabase Tables (via REST or client)
| Table | Operations |
|-------|------------|
| `profiles` | SELECT, INSERT, UPDATE |
| `books` | SELECT, INSERT, UPDATE, DELETE |
| `trades` | SELECT (via RPC) |
| `trade_items` | SELECT (via join) |
| `conversations` | SELECT |
| `messages` | SELECT, INSERT |
| `conversation_participants` | SELECT, UPDATE |
| `book_interests` | SELECT, INSERT, UPDATE, DELETE |

### External APIs
| API | Purpose | Endpoint Pattern |
|-----|---------|-----------------|
| Open Library | Book search | `https://openlibrary.org/search.json?q={query}` |
| Open Library | Book details | `https://openlibrary.org/works/{key}.json` |
| Open Library | Covers | `https://covers.openlibrary.org/b/id/{id}-{size}.jpg` |
| Google Maps | Geocoding | Via Google Maps SDK |

---

## 12. Environment Variables Required

```env
SUPABASE_URL=your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GOOGLE_MAPS_API_KEY=your-google-maps-key
```

---

## 13. Row Level Security (RLS) Policies

### Books
- **SELECT**: Public (anyone can view)
- **INSERT**: Own user_id only
- **UPDATE**: Own user_id only
- **DELETE**: Own user_id only

### Profiles
- **SELECT**: Public
- **INSERT**: Own id only
- **UPDATE**: Own id only

### Messages
- **SELECT**: Conversation participants only
- **INSERT**: Conversation participants only, own user_id

### Conversations
- **SELECT**: Participants only

---

## 14. Key UI Components to Implement

### Reusable Components
- `BookCard` - Book display with cover, title, author, condition badge
- `RequestableBookCard` - BookCard + request/cancel actions
- `TradeItemCard` - Compact book display for trade lists
- `ConversationListItem` - Avatar, name, last message, timestamp, unread badge
- `MessageBubble` - Sent/received message with timestamp
- `PostalCodeAutocomplete` - Location input with suggestions
- `RadiusSlider` - Distance selection with smart increments

### Screens
- Landing/Onboarding
- Sign In / Sign Up
- Dashboard (home)
- Search/Discover
- Add/Edit Book
- Book Detail
- Trades List
- Trade Detail
- Conversations List
- Chat
- Profile View/Edit

---

## 15. Testing Considerations

### Critical Paths to Test
1. Full authentication flow
2. Book creation with location
3. Geographic search accuracy
4. Trade lifecycle (request -> accept -> complete)
5. Real-time message delivery
6. Offline -> online sync

### Edge Cases
- No books in search radius
- Trade with user who deleted their book
- Conversation with deleted user
- Network interruption during trade submission

---

## 16. Known Technical Debt / Considerations

1. **Mixed JS/TS**: Some chat components are `.jsx`, rest is TypeScript
2. **Profile Schema Variations**: Some queries select different profile fields
3. **Book Request Legacy**: `book_requests` table exists alongside trades
4. **Timeout Handling**: Custom fetch timeouts (1.5-2s) in Supabase clients

---

## 17. Getting Started Checklist

For the LLM agent building the mobile app:

- [ ] Set up mobile development environment
- [ ] Configure Supabase client with credentials
- [ ] Implement authentication flow first
- [ ] Create data models matching TypeScript interfaces
- [ ] Set up navigation structure
- [ ] Implement real-time subscriptions early
- [ ] Test geographic search with PostGIS
- [ ] Configure push notification infrastructure
- [ ] Set up deep linking scheme
- [ ] Implement image upload to Supabase Storage

---

## 18. Contact & Resources

- **Web App Repo**: Current working directory
- **Supabase Dashboard**: Access via project URL
- **Migrations**: See `supabase/migrations/` for schema details

---

*This briefing document was generated from analysis of the Turtle Turning Pages web application codebase. All data models, features, and technical specifications are derived from the existing implementation.*
