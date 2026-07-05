import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/router.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/book_cover.dart';

/// Map view (mock #1b): pins are books, results as a sheet underneath.
/// Layout follows the mock; pricing is the flat 50 pts everywhere (spec §1).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final booksAsync = ref.watch(booksProvider);
    final countsAsync = ref.watch(languageCountsProvider);
    final params = ref.watch(bookSearchParamsProvider);

    final centroidLat = profile?.centroidLat;
    final centroidLng = profile?.centroidLng;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(profile?.areaLabel ?? 'Nearby'),
      ),
      body: Column(
        children: [
          // Language filter chips with counts (mock #1b)
          SizedBox(
            height: 46,
            child: countsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (counts) {
                final total = counts.values.fold<int>(0, (a, b) => a + b);
                final entries = counts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    _LanguageChip(
                      key: const Key('lang_all'),
                      label: 'All · $total',
                      selected: params.language == null,
                      onTap: () => ref
                          .read(bookSearchParamsProvider.notifier)
                          .update((p) => p.copyWith(clearLanguage: true)),
                    ),
                    ...entries.map((e) => _LanguageChip(
                          key: Key('lang_${e.key}'),
                          label: '${e.key} · ${e.value}',
                          selected: params.language == e.key,
                          onTap: () => ref
                              .read(bookSearchParamsProvider.notifier)
                              .update((p) => p.copyWith(language: e.key)),
                        )),
                  ],
                );
              },
            ),
          ),
          // Map
          Expanded(
            flex: 5,
            child: centroidLat == null || centroidLng == null
                ? Center(
                    child: Text(
                      'Set your neighborhood to see the map.',
                      style: AppTypography.sansRegular
                          .copyWith(color: AppColors.ink2),
                    ),
                  )
                : booksAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Center(
                      child: Text(
                        'Could not load the map.',
                        style: AppTypography.sansRegular
                            .copyWith(color: AppColors.ink2),
                      ),
                    ),
                    data: (books) => GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(centroidLat, centroidLng),
                        zoom: 15,
                      ),
                      onMapCreated: (c) => _mapController = c,
                      myLocationButtonEnabled: false,
                      markers: {
                        for (final book in books)
                          if (book.locationLat != null &&
                              book.locationLng != null)
                            Marker(
                              markerId: MarkerId(book.id),
                              position: LatLng(
                                  book.locationLat!, book.locationLng!),
                              infoWindow: InfoWindow(
                                title: book.title,
                                snippet: '${book.author} · 50 pts',
                                onTap: () => context.push(AppRoutes.bookDetail
                                    .replaceFirst(':id', book.id)),
                              ),
                            ),
                      },
                    ),
                  ),
          ),
          // Results sheet (mock #1b): count + nearest-first list
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.bg,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: booksAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (books) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${books.length} books within ${params.radius == params.radius.roundToDouble() ? params.radius.toInt() : params.radius} km',
                            key: const Key('map_count'),
                            style: AppTypography.sansExtraBold.copyWith(
                              fontSize: 13.5,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'Sort: nearest',
                            style: AppTypography.sansSemiBold.copyWith(
                              fontSize: 11.5,
                              color: AppColors.ink3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: books.isEmpty
                          ? Center(
                              child: Text(
                                'Nothing on nearby shelves yet.',
                                style: AppTypography.sansRegular
                                    .copyWith(color: AppColors.ink2),
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: books.length,
                              itemBuilder: (context, index) =>
                                  _MapResultCard(book: books[index]),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.greenTint : AppColors.surface,
            border: Border.all(
                color: selected ? AppColors.green : AppColors.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: AppTypography.sansBold.copyWith(
              fontSize: 12.5,
              color: selected ? AppColors.green : AppColors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapResultCard extends StatelessWidget {
  final Book book;

  const _MapResultCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.push(AppRoutes.bookDetail.replaceFirst(':id', book.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 58,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 68,
                  height: 98,
                  child: BookCover(
                    title: book.title,
                    author: book.author,
                    coverColorKey: book.coverColorKey,
                    showShadow: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sansBold.copyWith(
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      book.author,
                      if (book.language != null) book.language!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sansRegular.copyWith(
                      fontSize: 12,
                      color: AppColors.ink3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (book.distanceDisplay != null) book.distanceDisplay!,
                      if (book.owner?.displayName != null)
                        book.owner!.displayName.split(' ').first,
                    ].join(' · '),
                    style: AppTypography.sansSemiBold.copyWith(
                      fontSize: 11.5,
                      color: AppColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Request · 50 pts',
                style: AppTypography.sansExtraBold.copyWith(
                  fontSize: 11,
                  color: AppColors.bg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
