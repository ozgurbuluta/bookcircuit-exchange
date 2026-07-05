import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';

/// Firebase service for database operations
class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;

  // ============ STORAGE ============

  /// Upload an image file to the given storage [path] and return its download URL.
  static Future<String> uploadImage(File file, String path) async {
    final ref = storage.ref(path);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Upload a book cover for the current user. Stored under
  /// `book-covers/{uid}/...` to satisfy the storage security rules.
  static Future<String> uploadBookCover(File file) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    final fileName = 'cover-${DateTime.now().millisecondsSinceEpoch}.jpg';
    return uploadImage(file, 'book-covers/$uid/$fileName');
  }

  /// Upload an avatar for the current user. Stored under `avatars/{uid}/...`.
  static Future<String> uploadAvatar(File file) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    final fileName = 'avatar-${DateTime.now().millisecondsSinceEpoch}.jpg';
    return uploadImage(file, 'avatars/$uid/$fileName');
  }

  // ============ AUTH ============

  /// Get current user
  static User? get currentUser => auth.currentUser;

  /// Check if user is logged in
  static bool get isLoggedIn => currentUser != null;

  /// Sign out
  static Future<void> signOut() async {
    await auth.signOut();
  }

  /// Listen to auth state changes
  static Stream<User?> get authStateChanges => auth.authStateChanges();

  // ============ PROFILES ============

  /// Get profile by ID
  static Future<Profile?> getProfile(String userId) async {
    final doc = await db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return _docToProfile(doc);
  }

  /// Get current user's profile
  static Future<Profile?> getCurrentProfile() async {
    if (currentUser == null) return null;
    return getProfile(currentUser!.uid);
  }

  /// Update profile
  static Future<Profile?> updateProfile(Profile profile) async {
    await db.collection('users').doc(profile.id).update({
      'fullName': profile.fullName,
      'name': profile.fullName,
      'avatarInitials': profile.avatarInitials,
      'avatarUrl': profile.avatarUrl,
      'postalCode': profile.postalCode,
      'areaLabel': profile.areaLabel,
      'languages': profile.languages,
      'notifyNewBookNearby': profile.notifyNewBookNearby,
      'notifyJournal': profile.notifyJournal,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return getProfile(profile.id);
  }

  // ============ BOOKS ============

  /// Get books with optional filters
  static Future<List<Book>> getBooks({
    String? query,
    String? genre,
    String? userId,
    int limit = 30,
  }) async {
    Query<Map<String, dynamic>> ref = db
        .collection('books')
        .where('status', isEqualTo: 'on_shelf')
        .where('visible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (userId != null) {
      ref = db
          .collection('books')
          .where('ownerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);
    }

    final snapshot = await ref.get();
    List<Book> books = snapshot.docs.map((doc) => _docToBook(doc)).toList();

    // Apply client-side filtering for text search
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      books = books.where((b) =>
          b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q)).toList();
    }

    return books;
  }

  /// Get book by ID
  static Future<Book?> getBook(String bookId) async {
    final doc = await db.collection('books').doc(bookId).get();
    if (!doc.exists) return null;

    var book = _docToBook(doc);

    // Fetch owner profile
    if (book.ownerId.isNotEmpty) {
      final owner = await getProfile(book.ownerId);
      book = book.copyWith(owner: owner);
    }

    return book;
  }

  /// Get user's books
  static Future<List<Book>> getUserBooks(String userId) async {
    final snapshot = await db
        .collection('books')
        .where('ownerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => _docToBook(doc)).toList();
  }

  /// Get current user's books
  static Future<List<Book>> getMyBooks() async {
    if (currentUser == null) return [];
    return getUserBooks(currentUser!.uid);
  }

  /// Create book
  static Future<Book> createBook(Book book) async {
    final data = book.toFirestore()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    final docRef = await db.collection('books').add(data);
    final newDoc = await docRef.get();
    return _docToBook(newDoc);
  }

  /// Create several books in a single atomic batch (used by the shelf scanner).
  ///
  /// Returns the number of books written. Firestore batches are capped at 500
  /// writes, which is far above the scanner's per-scan limit.
  static Future<int> createBooks(List<Book> books) async {
    if (books.isEmpty) return 0;

    final batch = db.batch();
    for (final book in books) {
      final docRef = db.collection('books').doc();
      final data = book.toFirestore()
        ..['createdAt'] = FieldValue.serverTimestamp()
        ..['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(docRef, data);
    }

    await batch.commit();
    return books.length;
  }

  /// Update book
  static Future<Book?> updateBook(Book book) async {
    final data = book.toFirestore()
      ..remove('createdAt')
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await db.collection('books').doc(book.id).update(data);
    return getBook(book.id);
  }

  /// Delete book
  static Future<void> deleteBook(String bookId) async {
    await db.collection('books').doc(bookId).delete();
  }

  // ============ TRADES ============

  /// Get user's trades
  static Future<List<Trade>> getUserTrades({String? statusFilter}) async {
    if (currentUser == null) return [];

    // Get trades where user is initiator
    final initiatorSnapshot = await db
        .collection('trades')
        .where('requesterId', isEqualTo: currentUser!.uid)
        .orderBy('requestedAt', descending: true)
        .get();

    // Get trades where user is the book owner
    final recipientSnapshot = await db
        .collection('trades')
        .where('ownerId', isEqualTo: currentUser!.uid)
        .orderBy('requestedAt', descending: true)
        .get();

    // Combine and deduplicate
    final Map<String, DocumentSnapshot> tradeMap = {};
    for (final doc in initiatorSnapshot.docs) {
      tradeMap[doc.id] = doc;
    }
    for (final doc in recipientSnapshot.docs) {
      tradeMap[doc.id] = doc;
    }

    List<Trade> trades = await Future.wait(
      tradeMap.values.map((doc) => _docToTrade(doc)),
    );

    // Apply status filter
    if (statusFilter != null) {
      trades = trades.where((t) => t.status.value == statusFilter).toList();
    }

    // Sort by date
    trades.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    return trades;
  }

  /// Get trade by ID
  static Future<Trade?> getTrade(String tradeId) async {
    final doc = await db.collection('trades').doc(tradeId).get();
    if (!doc.exists) return null;
    return _docToTrade(doc);
  }

  /// Update trade status
  static Future<void> updateTradeStatus({
    required String tradeId,
    required String newStatus,
  }) async {
    await db.collection('trades').doc(tradeId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ CONVERSATIONS ============

  /// Get user's conversations
  static Future<List<Conversation>> getConversations() async {
    if (currentUser == null) return [];

    final snapshot = await db
        .collection('conversations')
        .where('participantIds', arrayContains: currentUser!.uid)
        .orderBy('lastMessageAt', descending: true)
        .get();

    return Future.wait(
      snapshot.docs.map((doc) => _docToConversation(doc)),
    );
  }

  /// Get messages for a conversation
  static Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    final snapshot = await db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final messages = await Future.wait(
      snapshot.docs.map((doc) => _docToMessage(doc, conversationId)),
    );

    // Return in chronological order
    return messages.reversed.toList();
  }

  /// Send message
  static Future<Message> sendMessage({
    required String conversationId,
    required String content,
    String? relatedBookId,
  }) async {
    if (currentUser == null) throw Exception('Not authenticated');

    final docRef = await db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
      'userId': currentUser!.uid,
      'content': content,
      'relatedBookId': relatedBookId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update conversation
    await db.collection('conversations').doc(conversationId).update({
      'lastMessage': content,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final newDoc = await docRef.get();
    return _docToMessage(newDoc, conversationId);
  }

  /// Subscribe to messages
  static Stream<List<Message>> subscribeToMessages(String conversationId) {
    return db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .asyncMap((snapshot) async {
      return Future.wait(
        snapshot.docs.map((doc) => _docToMessage(doc, conversationId)),
      );
    });
  }

  // ============ HELPERS ============

  static Profile _docToProfile(DocumentSnapshot doc) {
    return Profile.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
  }

  static Book _docToBook(DocumentSnapshot doc) {
    return Book.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
  }

  static Future<Trade> _docToTrade(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    var trade = Trade.fromFirestore(data, doc.id);

    // Hydrate participants and books for display.
    final requester =
        trade.requesterId.isNotEmpty ? await getProfile(trade.requesterId) : null;
    final owner =
        trade.ownerId.isNotEmpty ? await getProfile(trade.ownerId) : null;
    final book = trade.bookId.isNotEmpty ? await getBook(trade.bookId) : null;
    final offeredBook = trade.offeredBookId?.isNotEmpty == true
        ? await getBook(trade.offeredBookId!)
        : null;

    return trade.copyWith(
      requester: requester,
      owner: owner,
      book: book,
      offeredBook: offeredBook,
    );
  }

  static Future<Conversation> _docToConversation(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    // Find other user
    final participantIds =
        (data['participantIds'] as List<dynamic>?)?.cast<String>() ?? [];
    final otherUserId = participantIds.firstWhere(
      (id) => id != currentUser?.uid,
      orElse: () => '',
    );

    final otherUser =
        otherUserId.isNotEmpty ? await getProfile(otherUserId) : null;

    return Conversation(
      id: doc.id,
      lastMessage: data['lastMessage'],
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCount: 0, // TODO: Calculate from subcollection
      otherUser: otherUser,
      bookId: data['bookId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static Future<Message> _docToMessage(
      DocumentSnapshot doc, String conversationId) async {
    final data = doc.data() as Map<String, dynamic>;
    final senderId =
        data['senderId'] as String? ?? data['userId'] as String? ?? '';
    final sender = senderId.isNotEmpty ? await getProfile(senderId) : null;

    return Message(
      id: doc.id,
      senderId: senderId,
      text: data['text'] as String? ?? data['content'] as String? ?? '',
      type: MessageType.fromString(data['type'] as String?),
      createdAt: dateFromFirestore(data['createdAt']) ?? DateTime.now(),
      sender: sender,
      // ignore: deprecated_member_use_from_same_package
      conversationId: conversationId,
      // ignore: deprecated_member_use_from_same_package
      relatedBookId: data['relatedBookId'] as String?,
    );
  }
}
