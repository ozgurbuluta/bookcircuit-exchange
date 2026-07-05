import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/theme.dart';
import '../../config/router.dart';
import '../../models/book.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _selectedGenre = 'All';
  double _radius = 5.0;
  bool _isMapView = false;
  String _sortBy = 'distance';
  LatLngPoint? _location;

  @override
  void initState() {
    super.initState();
    // Resolve the user's location so the radius filter actually applies.
    Future.microtask(_resolveLocation);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation() async {
    final location = await ref.read(currentLocationProvider.future);
    if (!mounted) return;
    setState(() => _location = location);
    _updateSearch();
  }

  void _updateSearch() {
    ref.read(bookSearchParamsProvider.notifier).state = BookSearchParams(
      query: _searchController.text.isEmpty ? null : _searchController.text,
      genre: _selectedGenre == 'All' ? null : _selectedGenre,
      radius: _radius,
      lat: _location?.lat,
      lng: _location?.lng,
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FilterSheet(
        currentRadius: _radius,
        currentGenre: _selectedGenre,
        currentSort: _sortBy,
        onApply: (radius, genre, sort) {
          setState(() {
            _radius = radius;
            _selectedGenre = genre;
            _sortBy = sort;
          });
          _updateSearch();
        },
      ),
    );
  }

  /// Send a trade request for [book], then jump to the Trades tab.
  Future<void> _requestBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Request this book?',
            style: AppTypography.serifSemiBold.copyWith(fontSize: 20, color: AppColors.ink)),
        content: Text(
          'This will send a request to ${book.owner?.displayName ?? 'the owner'} to start a trade.',
          style: AppTypography.sansRegular.copyWith(fontSize: 14, color: AppColors.ink2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: AppTypography.sansSemiBold.copyWith(color: AppColors.ink2)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final trade = await ref.read(tradeActionsProvider.notifier).createTrade(
          ownerId: book.ownerId,
          bookId: book.id,
        );
    if (!mounted) return;

    if (trade != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Request sent to ${book.owner?.displayName ?? 'owner'}',
            style: AppTypography.sansRegular.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.sage,
        ),
      );
      router.go(AppRoutes.trades);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not send request. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final genres = ref.watch(genresProvider);
    final booksAsync = ref.watch(booksProvider);
    final currentUserId = ref.watch(currentUserProvider)?.uid;

    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Discover',
                    style: AppTypography.serifSemiBold.copyWith(
                      fontSize: 32,
                      letterSpacing: -0.4,
                      color: AppColors.ink,
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.tune,
                    onPressed: _showFilterSheet,
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.paper2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 19, color: AppColors.ink3),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (_) => _updateSearch(),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchFocusNode.unfocus(),
                        decoration: InputDecoration(
                          hintText: 'Search titles, authors...',
                          hintStyle: AppTypography.sansRegular.copyWith(
                            fontSize: 15,
                            color: AppColors.ink3,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: AppTypography.sansRegular.copyWith(
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _updateSearch();
                        },
                        child: const Icon(Icons.close, size: 17, color: AppColors.ink3),
                      ),
                  ],
                ),
              ),
            ),

            // Genre chips
            SizedBox(
              height: 54,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                itemCount: genres.length,
                itemBuilder: (context, index) {
                  final genre = genres[index];
                  final isSelected = genre == _selectedGenre;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedGenre = genre);
                        _updateSearch();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.ink : AppColors.paper2,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isSelected ? AppColors.ink : AppColors.line,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          genre,
                          style: AppTypography.sansSemiBold.copyWith(
                            fontSize: 13,
                            color: isSelected ? AppColors.paper : AppColors.ink2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Radius slider and view toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.paper2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line, width: 0.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: AppColors.rust),
                            const SizedBox(width: 6),
                            Text(
                              'Within ${_radius.toInt()} km',
                              style: AppTypography.sansSemiBold.copyWith(
                                fontSize: 13.5,
                                color: AppColors.ink2,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.paper3,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: AppColors.line, width: 0.5),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Row(
                            children: [
                              _buildViewToggle('List', Icons.list, !_isMapView),
                              _buildViewToggle('Map', Icons.map_outlined, _isMapView),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.rust,
                        inactiveTrackColor: AppColors.paper3,
                        thumbColor: AppColors.paper2,
                        overlayColor: AppColors.rust.withValues(alpha: 0.2),
                        trackHeight: 5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 11,
                          elevation: 2,
                        ),
                      ),
                      child: Slider(
                        value: _radius,
                        min: 1,
                        max: 100,
                        onChanged: (value) {
                          setState(() => _radius = value);
                        },
                        onChangeEnd: (_) => _updateSearch(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Results count
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: booksAsync.when(
                  data: (books) => Text(
                    '${books.length} book${books.length != 1 ? 's' : ''} found',
                    style: AppTypography.sansSemiBold.copyWith(
                      fontSize: 13,
                      color: AppColors.ink3,
                      letterSpacing: 0.2,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            // Results
            Expanded(
              child: booksAsync.when(
                data: (books) => books.isEmpty
                    ? _buildEmptyState()
                    : _isMapView
                        ? _buildMapView(books)
                        : _buildListView(books, currentUserId),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ),

            const SizedBox(height: 96), // Tab bar space
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildViewToggle(String label, IconData icon, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _isMapView = label == 'Map'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.paper : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.12),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.sansSemiBold.copyWith(
            fontSize: 12.5,
            color: isActive ? AppColors.ink : AppColors.ink3,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 34, color: AppColors.ink3),
          const SizedBox(height: 12),
          Text(
            'No books in range',
            style: AppTypography.serifSemiBold.copyWith(
              fontSize: 17,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try widening your radius.',
            style: AppTypography.sansRegular.copyWith(
              fontSize: 13.5,
              color: AppColors.ink3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List books, String? currentUserId) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index] as Book;
        final isOwn = book.userId == currentUserId;
        return Container(
          decoration: BoxDecoration(
            border: index > 0
                ? const Border(top: BorderSide(color: AppColors.line2, width: 0.5))
                : null,
          ),
          child: BookCard(
            book: book,
            onTap: () => context.push('/book/${book.id}'),
            // Don't offer to request your own books.
            trailing: isOwn
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Yours',
                      style: AppTypography.sansBold.copyWith(
                        fontSize: 12.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => _requestBook(book),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.rust.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Request',
                        style: AppTypography.sansBold.copyWith(
                          fontSize: 12.5,
                          color: AppColors.rust,
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildMapView(List books) {
    final typedBooks = books.cast<Book>();
    final booksWithLocation = typedBooks.where((b) => b.locationLat != null && b.locationLng != null).toList();

    if (booksWithLocation.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.paper2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line, width: 0.5),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 48, color: AppColors.ink3),
              const SizedBox(height: 12),
              Text(
                'No locations available',
                style: AppTypography.serifSemiBold.copyWith(
                  fontSize: 17,
                  color: AppColors.ink2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Books need location data to appear on map',
                style: AppTypography.sansRegular.copyWith(
                  fontSize: 13.5,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final markers = booksWithLocation.map((book) {
      return Marker(
        markerId: MarkerId(book.id),
        position: LatLng(book.locationLat!, book.locationLng!),
        infoWindow: InfoWindow(
          title: book.title,
          snippet: book.author,
          onTap: () => context.push('/book/${book.id}'),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      );
    }).toSet();

    final centerLat = booksWithLocation.map((b) => b.locationLat!).reduce((a, b) => a + b) / booksWithLocation.length;
    final centerLng = booksWithLocation.map((b) => b.locationLng!).reduce((a, b) => a + b) / booksWithLocation.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 0.5),
      ),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(centerLat, centerLng),
          zoom: 12,
        ),
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final double currentRadius;
  final String currentGenre;
  final String currentSort;
  final void Function(double radius, String genre, String sort) onApply;

  const _FilterSheet({
    required this.currentRadius,
    required this.currentGenre,
    required this.currentSort,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late double _radius;
  late String _genre;
  late String _sort;

  final _sortOptions = ['distance', 'newest', 'title'];
  final _genres = ['All', 'Fiction', 'Non-Fiction', 'Mystery', 'Sci-Fi', 'Romance', 'Biography', 'History', 'Self-Help'];

  @override
  void initState() {
    super.initState();
    _radius = widget.currentRadius;
    _genre = widget.currentGenre;
    _sort = widget.currentSort;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: AppTypography.serifSemiBold.copyWith(
                    fontSize: 22,
                    color: AppColors.ink,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _radius = 5.0;
                      _genre = 'All';
                      _sort = 'distance';
                    });
                  },
                  child: Text(
                    'Reset',
                    style: AppTypography.sansSemiBold.copyWith(
                      fontSize: 14,
                      color: AppColors.rust,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Distance
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Distance',
                      style: AppTypography.sansSemiBold.copyWith(
                        fontSize: 14,
                        color: AppColors.ink2,
                      ),
                    ),
                    Text(
                      '${_radius.toInt()} km',
                      style: AppTypography.sansBold.copyWith(
                        fontSize: 14,
                        color: AppColors.rust,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.rust,
                    inactiveTrackColor: AppColors.paper3,
                    thumbColor: AppColors.paper2,
                    overlayColor: AppColors.rust.withValues(alpha: 0.2),
                    trackHeight: 5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 11,
                      elevation: 2,
                    ),
                  ),
                  child: Slider(
                    value: _radius,
                    min: 1,
                    max: 100,
                    onChanged: (value) => setState(() => _radius = value),
                  ),
                ),
              ],
            ),
          ),

          // Sort by
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sort by',
                  style: AppTypography.sansSemiBold.copyWith(
                    fontSize: 14,
                    color: AppColors.ink2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _sortOptions.map((option) {
                    final isSelected = option == _sort;
                    final label = option[0].toUpperCase() + option.substring(1);
                    return GestureDetector(
                      onTap: () => setState(() => _sort = option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.ink : AppColors.paper2,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isSelected ? AppColors.ink : AppColors.line,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          label,
                          style: AppTypography.sansSemiBold.copyWith(
                            fontSize: 13,
                            color: isSelected ? AppColors.paper : AppColors.ink2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Genre
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Genre',
                  style: AppTypography.sansSemiBold.copyWith(
                    fontSize: 14,
                    color: AppColors.ink2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _genres.map((genre) {
                    final isSelected = genre == _genre;
                    return GestureDetector(
                      onTap: () => setState(() => _genre = genre),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.ink : AppColors.paper2,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isSelected ? AppColors.ink : AppColors.line,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          genre,
                          style: AppTypography.sansSemiBold.copyWith(
                            fontSize: 13,
                            color: isSelected ? AppColors.paper : AppColors.ink2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Apply button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_radius, _genre, _sort);
                  Navigator.pop(context);
                },
                child: const Text('Apply Filters'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
