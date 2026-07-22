import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/presentation/photo_gallery_page.dart';
import 'package:watch_collection/features/collection/presentation/watch_photo_grid.dart';

void main() {
  testWidgets('shows a placeholder when there are no photos', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WatchPhotoGrid(imagePaths: []))),
    );

    expect(find.byIcon(Icons.watch_outlined), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('renders a hero-tagged tile per photo', (tester) async {
    const paths = ['/tmp/a.jpg', '/tmp/b.jpg', '/tmp/c.jpg'];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WatchPhotoGrid(imagePaths: paths)),
      ),
    );

    expect(find.byType(GridView), findsOneWidget);
    // One Hero per photo, each carrying the shared tag used by the viewer.
    for (final path in paths) {
      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == photoHeroTag(path),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('tapping a tile opens the full-screen viewer', (tester) async {
    const paths = ['/tmp/a.jpg', '/tmp/b.jpg'];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WatchPhotoGrid(imagePaths: paths)),
      ),
    );

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.byType(PhotoGalleryPage), findsOneWidget);
    // The viewer labels the current page as "1 / N".
    expect(find.text('1 / 2'), findsOneWidget);
    // Pinch-/pan-zoom is available on the open photo.
    expect(find.byType(InteractiveViewer), findsWidgets);
  });
}
