# Firestore Database Structure

This document describes the Firestore collections used in Turtle Turning Pages.

## Collections

### `users` (profiles)
```
users/{userId}
├── id: string (same as document ID)
├── email: string
├── fullName: string
├── avatarUrl: string (optional)
├── bio: string (optional)
├── website: string (optional)
├── university: string (optional)
├── locationCity: string (optional)
├── locationState: string (optional)
├── locationCountry: string (optional)
├── locationLat: number (optional)
├── locationLng: number (optional)
├── createdAt: timestamp
└── updatedAt: timestamp
```

### `books`
```
books/{bookId}
├── id: string
├── userId: string (owner)
├── title: string
├── author: string
├── description: string (optional)
├── condition: string ('New' | 'Like New' | 'Very Good' | 'Good' | 'Acceptable' | 'Poor')
├── isbn: string (optional)
├── coverImgUrl: string (optional)
├── publisher: string (optional)
├── publicationYear: number (optional)
├── language: string (optional)
├── pages: number (optional)
├── genres: string[] (optional)
├── locationText: string (optional)
├── postalCode: string (optional)
├── locationLat: number (optional)
├── locationLng: number (optional)
├── status: string ('available' | 'requested' | 'trading' | 'completed')
├── currentTradeId: string (optional)
├── tradeCount: number (default: 0)
├── interestCount: number (default: 0)
├── createdAt: timestamp
└── updatedAt: timestamp
```

### `bookInterests`
```
bookInterests/{interestId}
├── id: string
├── userId: string
├── bookId: string
├── status: string ('active' | 'inactive')
├── note: string (optional)
├── createdAt: timestamp
└── updatedAt: timestamp
```

### `trades`
```
trades/{tradeId}
├── id: string
├── initiatorId: string
├── recipientId: string
├── status: string ('request_pending' | 'pending' | 'accepted' | 'rejected' | 'completed' | 'cancelled')
├── initiatorMessage: string (optional)
├── recipientMessage: string (optional)
├── isDirectRequest: boolean
├── isCounteroffered: boolean
├── createdAt: timestamp
└── updatedAt: timestamp

  └── tradeItems (subcollection)
      └── tradeItems/{itemId}
          ├── id: string
          ├── tradeId: string
          ├── bookId: string
          ├── ownerId: string
          ├── recipientId: string
          ├── itemType: string ('book')
          ├── interestId: string (optional)
          └── createdAt: timestamp
```

### `tradeHistory`
```
tradeHistory/{historyId}
├── id: string
├── tradeId: string
├── action: string ('created' | 'accepted' | 'rejected' | 'completed' | 'cancelled' | 'counteroffered' | 'updated')
├── actorId: string
├── details: string (optional)
└── createdAt: timestamp
```

### `conversations`
```
conversations/{conversationId}
├── id: string
├── participantIds: string[] (array of user IDs for querying)
├── lastMessage: string (optional)
├── lastMessageAt: timestamp (optional)
├── lastMessageSenderId: string (optional)
├── bookId: string (optional, if conversation is about a specific book)
├── createdAt: timestamp
└── updatedAt: timestamp

  └── participants (subcollection)
      └── participants/{participantId}
          ├── userId: string
          ├── unreadCount: number
          └── createdAt: timestamp

  └── messages (subcollection)
      └── messages/{messageId}
          ├── id: string
          ├── userId: string
          ├── content: string
          ├── relatedBookId: string (optional)
          ├── createdAt: timestamp
          └── updatedAt: timestamp
```

### `blogPosts`
```
blogPosts/{postId}
├── id: string
├── title: string
├── slug: string
├── summary: string
├── content: string
├── featuredImageUrl: string (optional)
├── author: string
├── authorId: string (optional)
├── publishedAt: timestamp
├── createdAt: timestamp
└── updatedAt: timestamp
```

## Indexes Required

Create these composite indexes in Firebase Console -> Firestore -> Indexes:

1. **books** - For geographic search and filtering:
   - Collection: `books`
   - Fields: `status` (Ascending), `createdAt` (Descending)

2. **books** - For user's books:
   - Collection: `books`
   - Fields: `userId` (Ascending), `createdAt` (Descending)

3. **trades** - For user's trades:
   - Collection: `trades`
   - Fields: `initiatorId` (Ascending), `createdAt` (Descending)
   - Collection: `trades`
   - Fields: `recipientId` (Ascending), `createdAt` (Descending)

4. **conversations** - For user's conversations:
   - Collection: `conversations`
   - Fields: `participantIds` (Array contains), `lastMessageAt` (Descending)

5. **bookInterests** - For user's interests:
   - Collection: `bookInterests`
   - Fields: `userId` (Ascending), `status` (Ascending)

## Security Rules

See `firestore.rules` for security rules configuration.
