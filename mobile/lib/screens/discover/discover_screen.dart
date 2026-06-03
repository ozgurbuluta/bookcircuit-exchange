import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  String _selectedGenre = 'All';
  double _radius = 5.0;
  bool _isMapView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearch() {
    ref.read(bookSearchParamsProvider.notifier).state = BookSearchParams(
      query: _searchController.text.isEmpty ? null : _searchController.text,
      genre: _selectedGenre == 'All' ? null : _selectedGenre,
      radius: _radius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final genres = ref.watch(genresProvider);
    final booksAsync = ref.watch(booksProvider);

    return Scaffold(
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
                    onPressed: () {},
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
                        onChanged: (_) => _updateSearch(),
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
                        : _buildListView(books),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ),

            const SizedBox(height: 96), // Tab bar space
          ],
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

  Widget _buildListView(List books) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Container(
          decoration: BoxDecoration(
            border: index > 0
                ? const Border(top: BorderSide(color: AppColors.line2, width: 0.5))
                : null,
          ),
          child: BookCard(
            book: book,
            onTap: () => context.push('/book/${book.id}'),
            trailing: GestureDetector(
              onTap: () => context.push('/book/${book.id}'),
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
    // Simplified map placeholder - would use google_maps_flutter in full implementation
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFE7DFC9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 0.5),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 48, color: AppColors.ink3),
            const SizedBox(height: 12),
            Text(
              'Map view',
              style: AppTypography.serifSemiBold.copyWith(
                fontSize: 17,
                color: AppColors.ink2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${books.length} books nearby',
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
}
