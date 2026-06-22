import 'book.dart';

/// A single book detected from a bookshelf photo by the scanner.
///
/// This is intentionally a *mutable* class: the review screen lets the user
/// tweak each field (title, author, condition), toggle whether to include it,
/// or drop it entirely before the batch is written to the library.
class DetectedBook {
  /// Title as read by the vision model (later canonicalised by Google Books).
  String title;

  /// Author as read by the vision model.
  String author;

  String? isbn;
  String? description;
  String? coverUrl;
  int? publishYear;
  String? publisher;
  int? pages;

  /// Condition can't be inferred from a spine photo, so it defaults to "Good"
  /// and is adjustable per book (or in bulk) on the review screen.
  BookCondition condition;

  /// Language of the book - required, set in bulk on the review screen.
  String? language;

  /// Whether this book is selected to be added in the batch.
  bool include;

  /// True once a Google Books match was found and metadata was enriched.
  /// When false we keep the raw title/author but have no cover/ISBN.
  bool matched;

  /// True if a book with the same title already exists in the user's library.
  bool isDuplicate;

  DetectedBook({
    required this.title,
    required this.author,
    this.isbn,
    this.description,
    this.coverUrl,
    this.publishYear,
    this.publisher,
    this.pages,
    this.condition = BookCondition.good,
    this.language,
    this.include = true,
    this.matched = false,
    this.isDuplicate = false,
  });

  /// Build a [Book] ready to be persisted, stamping in the owner's identity and
  /// location (mirrors the single add-book flow).
  ///
  /// Location parameters are required - caller must ensure profile has location
  /// or provide explicit coordinates.
  Book toBook({
    required String userId,
    required String locationText,
    required double locationLat,
    required double locationLng,
    required String language,
  }) {
    final now = DateTime.now();
    return Book(
      id: '',
      userId: userId,
      title: title.trim(),
      author: author.trim(),
      description:
          (description == null || description!.trim().isEmpty) ? null : description!.trim(),
      condition: condition,
      isbn: (isbn == null || isbn!.trim().isEmpty) ? null : isbn!.trim(),
      language: language,
      coverImgUrl: coverUrl,
      publisher: publisher,
      publicationYear: publishYear,
      pages: pages,
      locationText: locationText,
      locationLat: locationLat,
      locationLng: locationLng,
      createdAt: now,
      updatedAt: now,
    );
  }
}
