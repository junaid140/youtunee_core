import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';
import 'package:youtunee_core/typings.dart';
import 'package:youtunee_core/youtunee_core.dart';

void main() async {
  final youtunee = Youtunee();

  test('Get featured items', () async {
    final featured = await youtunee.getFeatured();
    expect(featured, isNotNull);
    expect(featured, isNotEmpty);
    expect(featured?.first.category, isNotEmpty);
    expect(featured?.first.contents, isNotEmpty);
  });

  test('Get stream data', () async {
    final stream = await youtunee.getPlayableStream('ZSRzCbpIxZo');
    expect(stream, isNotNull);
    expect(stream?.streamUrl, isNotNull);
  });

  test('Get stream data (wrong id)', () async {
    final stream = await youtunee.getPlayableStream('ZSRzCbpIxZg');
    expect(stream, isNull);
  });

  group('Search test ->', () {
    test('Get result', () async {
      final result = await youtunee.search(query: 'Snowman Sia');
      expect(result, isNotNull);
      expect(result, isNotEmpty);
      expect(result?[0].category, isNotEmpty);
      expect(result?[0].contents, isNotEmpty);
      expect(result?[0].next, isNull);
      expect(result?[1].next, isNotNull);
    });

    test('Get next result', () async {
      final result = await youtunee.search(query: 'Snowman Sia');
      expect(result, isNotNull);
      expect(result, isNotEmpty);
      expect(result?[0].category, isNotEmpty);
      expect(result?[0].contents, isNotEmpty);
      expect(result?[0].next, isNull);
      expect(result?[1].next, isNotNull);

      final next = result?[1].next;
      final nextResult = await youtunee.search(
        mode: next?.mode ?? '',
        query: next?.query ?? '',
        browseId: next?.browseId ?? '',
        ctoken: next?.ctoken,
        params: next?.params,
      );
      expect(nextResult, isNotEmpty);
      expect(nextResult?[0].contents, isNotEmpty);
      expect(nextResult?[0].contents, isNotEmpty);
    });
  });

  group('Queue test ->', () {
    test('Get without playlistId', () async {
      final nextQueue = await youtunee.getNextQueue(itemId: 'ZSRzCbpIxZo');
      expect(nextQueue, isNotNull);
      expect(nextQueue?.index, 0);
      expect(nextQueue?.playlistId, isNotEmpty);
      expect(nextQueue?.queue, isNotEmpty);
      expect(nextQueue?.queue.length, 50);
      expect(nextQueue?.queue.first is Content, true);
    });

    test('Get with playlistId', () async {
      final nextQueue = await youtunee.getNextQueue(itemId: 'ZSRzCbpIxZo', playlistId: 'RDAMVMZSRzCbpIxZo');
      expect(nextQueue, isNotNull);
      expect(nextQueue?.index, 0);
      expect(nextQueue?.playlistId, isNotEmpty);
      expect(nextQueue?.queue, isNotEmpty);
      expect(nextQueue?.queue[0] is Content, true);
    });

    test('Get wrong id', () async {
      final nextQueue = await youtunee.getNextQueue(itemId: 'ZSRzCbpIxZg');
      expect(nextQueue, isNull);
    });
  });

  group('Playlist test ->', () {
    test('Get playlist', () async {
      final playlist = await youtunee.getPlaylistItems(playlistId: 'OLAK5uy_lVPnAPfrA51In5DD8TtbdlF4Guv0mY2VE');
      expect(playlist, isNotNull);
      expect(playlist?.nextSearch, isNull);
      expect(playlist?.contents, isNotEmpty);
      expect(playlist?.contents.first is Content, true);
      expect(playlist?.contents.first.thumbnail, isEmpty);
    });

    test('Get playlist with next items', () async {
      final playlist = await youtunee.getPlaylistItems(playlistId: 'OLAK5uy_ngabBGA34oUremHhEFSLbS4Vp_DUVT9wc');
      expect(playlist, isNotNull);
      expect(playlist?.nextSearch, isNotNull);
      expect(playlist?.contents, isNotEmpty);
      expect(playlist?.contents.first is Content, true);
      expect(playlist?.contents.first.thumbnail, isNotEmpty);

      final next = playlist?.nextSearch;
      final nextItem = await youtunee.search(
        query: next!.query,
        mode: next.mode,
        browseId: next.browseId ?? '',
        ctoken: next.ctoken ?? '',
        params: next.params,
      );
      expect(nextItem, isNotNull);
      expect(nextItem, isNotEmpty);
      expect(nextItem?.first.contents, isNotEmpty);
      expect(nextItem?.first.contents.first is Content, true);
      expect(nextItem?.first.contents.first.thumbnail, isNotEmpty);
    });

    test('Get wrong playlist', () async {
      final playlist = await youtunee.getPlaylistItems(playlistId: 'OLAK5uy_lVPnAPfrA51In5DD8TtbdlF4Guv0mY2Vb');
      expect(playlist, isNull);
    });
  });

  group('Profile test ->', () {
    test('Get profile', () async {
      final profile = await youtunee.getProfile('UCaPIRYCKs51kvD4jrbwMH1w');
      expect(profile, isNotNull);
      expect(profile?.contents, isNotEmpty);
      expect(profile?.contents[0].category, 'Lagu');
      expect(profile?.contents[0].contents, isNotEmpty);
      expect(profile?.contents[0].next, isNotNull);
      expect(profile?.contents[1].contents, isNotEmpty);
      expect(profile?.contents[1].next, isNotNull);
    });

    test('Get no public items profile', () async {
      final profile = await youtunee.getProfile('UCGRwLJu9YYvkjhui67T-90A');
      expect(profile, isNull);
    });

    test('Get wrong profile', () async {
      final profile = await youtunee.getProfile('UCaPIRYCKs51kvD4jrbwMH1m');
      expect(profile, isNull);
    });
  });
}
