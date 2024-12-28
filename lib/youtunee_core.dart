import 'dart:convert';
import 'dart:ffi';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yed;
import 'package:youtunee_core/str.dart';
import 'package:youtunee_core/typings.dart';

class Youtunee {
  Map<String, String> headers = {
    'accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'accept-language': 'id-ID,id;q=0.9',
    'cache-control': 'no-cache',
    'pragma': 'no-cache',
    'priority': 'u=0, i',
    'upgrade-insecure-requests': '1',
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  };

  RegExp initialDataRegExp = RegExp(
    r"initialData\.push\({path: '\\\/browse', params: JSON\.parse\('([^']+)'\), data: '([^']+)'}\);",
  );
  RegExp innertubeContextRegExp = RegExp(
    r'"INNERTUBE_CONTEXT":{(.+)},"INNERTUBE_CONTEXT_CLIENT_NAME"',
  );

  Map<String, dynamic> innertubeContext = {};

  Future<Map<String, dynamic>> getOrSetContext() async {
    if (innertubeContext['client'] != null) return innertubeContext;

    final client = http.Client();
    final response = await client.get(
      Uri.https('music.youtube.com'),
      headers: headers,
    );
    if (response.statusCode != 200) return {};

    final matched = innertubeContextRegExp.firstMatch(response.body);
    if (matched == null) return {};

    final rawStringData = matched.group(1);
    if (rawStringData == null) return {};

    innertubeContext = jsonDecode("{$rawStringData}");
    return innertubeContext;
  }

  Content parseContent(dynamic item) {
    final tmpRuns = (item['flexColumns'] as List<dynamic>)
        .map((fc) =>
            fc['musicResponsiveListItemFlexColumnRenderer']['text']['runs'])
        .where((r) => r != null)
        .expand((i) => i)
        .toList();
    final runs = TextComponentDetail.create(tmpRuns);
    final title = runs.first;
    final subtitle = runs.sublist(1);
    final tmpThumbnail = (item['thumbnail']['musicThumbnailRenderer']
            ['thumbnail']['thumbnails'] as List)
        .last['url'] as String;
    final thumbnail = tmpThumbnail.startsWith('https://i.ytimg.com')
        ? tmpThumbnail
        : tmpThumbnail.replaceFirst(RegExp(r"=w\d+-h\d+"), '=w512-h512');

    if (item['navigationEndpoint'] != null) {
      final browserEndpoint = item['navigationEndpoint']['browseEndpoint'];
      title.id = ((title.id ?? browserEndpoint['browseId']) as String)
          .replaceFirst('VL', '')
          .replaceFirst('MPSP', '');
      title.type = (browserEndpoint['browseEndpointContextSupportedConfigs']
              ['browseEndpointContextMusicConfig']['pageType'] as String)
          .replaceAll("MUSIC_PAGE_TYPE_", "")
          .toLowerCase();
    }

    return Content(
      id: title.id ?? '',
      type: title.type ?? '',
      thumbnail: thumbnail,
      title: title,
      subtitle: subtitle,
    );
  }

  Future<List<CategorizedContent>?> getFeatured() async {
    final client = http.Client();
    final response = await client.get(
      Uri.https('music.youtube.com'),
      headers: headers,
    );
    if (response.statusCode != 200) return null;

    final matched = initialDataRegExp.firstMatch(response.body);
    if (matched == null) return null;

    final rawStringData = matched.group(2);
    if (rawStringData == null) return null;

    final stringData = unescape(rawStringData);
    final jsonData = jsonDecode(stringData);

    List<CategorizedContent> contents = [];
    final carouselShelfsData = jsonData['contents']
            ['singleColumnBrowseResultsRenderer']['tabs'][0]['tabRenderer']
        ['content']['sectionListRenderer']['contents'];

    if (carouselShelfsData.length > 1) {
      for (var i = 0; i < carouselShelfsData.length - 1; i++) {
        CategorizedContent content = CategorizedContent(
          category: '',
          contents: [],
        );

        final musicCarousel =
            carouselShelfsData[i]['musicCarouselShelfRenderer'];
        if (musicCarousel == null) continue;
        content.category = musicCarousel['header']
                ['musicCarouselShelfBasicHeaderRenderer']['title']['runs'][0]
            ['text'];

        for (var i = 0;
            i < (musicCarousel['contents'] as List<dynamic>).length;
            i++) {
          final item = musicCarousel['contents'][i];
          final mrlir = item['musicResponsiveListItemRenderer'];
          final mtrir = item['musicTwoRowItemRenderer'];

          if (mrlir != null) {
            content.contents.add(parseContent(mrlir));
          }

          if (mtrir != null) {
            final title = TextComponentDetail.create(
              (mtrir['title']['runs'] as List).where((r) => r != null).toList(),
            ).first;
            final subtitle = TextComponentDetail.create(
              (mtrir['subtitle']['runs'] as List)
                  .where((r) => r != null)
                  .toList(),
            );
            final tmpThumbnail = (mtrir['thumbnailRenderer']
                        ['musicThumbnailRenderer']['thumbnail']['thumbnails']
                    as List)
                .last['url'] as String;
            final thumbnail = tmpThumbnail.startsWith('https://i.ytimg.com')
                ? tmpThumbnail
                : tmpThumbnail.replaceFirst(
                    RegExp(r"=w\d+-h\d+"), '=w512-h512');

            content.contents.add(
              Content(
                id: title.id ?? '',
                type: title.type ?? 'watch',
                thumbnail: thumbnail,
                title: title,
                subtitle: subtitle,
              ),
            );
          }
        }

        contents.add(content);
      }
    }

    return contents;
  }

  Future<List<CategorizedContent>?> search({
    required String query,
    String? ctoken,
    String? params,
  }) async {
    final context = await getOrSetContext();

    Map<String, dynamic> queryParams = {'prettyPrint': 'false'};
    Map<String, dynamic> requestBody = {'context': context};

    if (ctoken != null &&
        ctoken.isNotEmpty &&
        params != null &&
        params.isNotEmpty) {
      queryParams['ctoken'] = ctoken;
      queryParams['continuation'] = ctoken;
      queryParams['type'] = 'next';
      queryParams['itct'] = params;
    }

    if ((ctoken == null || ctoken.isEmpty)) {
      requestBody['query'] = query;
      if (params != null && params.isNotEmpty) {
        requestBody['params'] = params;
      }
    }

    final url = Uri.https(
      'music.youtube.com',
      '/youtubei/v1/search',
      queryParams,
    );
    final client = http.Client();
    final response = await client.post(
      url,
      headers: headers,
      body: jsonEncode(requestBody),
    );
    if (response.statusCode != 200) return null;

    final jsonData = jsonDecode(response.body);
    if (jsonData['contents'] != null) {
      final slr = jsonData['contents']['tabbedSearchResultsRenderer']['tabs'][0]
          ['tabRenderer']['content']['sectionListRenderer']['contents'];
      List<CategorizedContent> result = [];

      for (var i = 0; i < (slr as List<dynamic>).length; i++) {
        final mcsr = slr[i]['musicCardShelfRenderer'];
        final msr = slr[i]['musicShelfRenderer'];

        if (mcsr != null) {
          final category = mcsr['header']['musicCardShelfHeaderBasicRenderer']
              ['title']['runs'][0]['text'];
          List<Content> contents = [];

          for (var j = 0; j < mcsr['contents'].length; j++) {
            final item = mcsr['contents'][j];
            final mrlir = item['musicResponsiveListItemRenderer'];
            if (mrlir != null) {
              contents.add(parseContent(mrlir));
            }
          }

          result.add(
            CategorizedContent(
              category: category,
              contents: contents,
            ),
          );
        }

        if (msr != null) {
          final category = msr['title']['runs'][0]['text'];
          List<Content> contents = [];
          NextSearch next = NextSearch(query: '');

          if (msr['bottomEndpoint'] != null &&
              msr['bottomEndpoint']['searchEndpoint'] != null) {
            next.query = msr['bottomEndpoint']['searchEndpoint']['query'];
            next.params = msr['bottomEndpoint']['searchEndpoint']['params'];
          }

          if (msr['continuations'] != null) {
            next.params = msr['continuations'][0]['nextContinuationData']
                ['clickTrackingParams'];
            next.ctoken =
                msr['continuations'][0]['nextContinuationData']['continuation'];
          }

          for (var j = 0; j < msr['contents'].length; j++) {
            final item = msr['contents'][j];
            final mrlir = item['musicResponsiveListItemRenderer'];

            contents.add(parseContent(mrlir));
          }
          result.add(
            CategorizedContent(
              category: category,
              contents: contents,
              next: next,
            ),
          );
        }
      }
      return result;
    }

    if (jsonData['continuationContents'] != null) {
      final msc = jsonData['continuationContents']['musicShelfContinuation'];
      List<Content> contents = [];
      NextSearch next = NextSearch(query: query);

      if (msc['continuations'] != null) {
        next.params = msc['continuations'][0]['nextContinuationData']
            ['clickTrackingParams'];
        next.ctoken =
            msc['continuations'][0]['nextContinuationData']['continuation'];
      }

      for (var j = 0; j < msc['contents'].length; j++) {
        final item = msc['contents'][j];
        final mrlir = item['musicResponsiveListItemRenderer'];

        contents.add(parseContent(mrlir));
      }

      return [
        CategorizedContent(
          category: '',
          contents: contents,
          next: next,
        ),
      ];
    }

    return null;
  }

  Future<Playlist?> getPlaylistItems(String playlistId) async {
    final client = http.Client();
    final response = await client.get(
      Uri.https(
        'music.youtube.com',
        '/playlist',
        {'list': playlistId},
      ),
      headers: headers,
    );
    if (response.statusCode != 200) return null;

    final matched = initialDataRegExp.firstMatch(response.body);
    if (matched == null) return null;

    final rawStringData = matched.group(2);
    if (rawStringData == null) return null;

    final stringData = unescape(rawStringData);
    final jsonData = jsonDecode(stringData);
    final mrhr = jsonData['contents']['twoColumnBrowseResultsRenderer']['tabs']
            [0]['tabRenderer']['content']['sectionListRenderer']['contents'][0]
        ['musicResponsiveHeaderRenderer'];
    final slrc = jsonData['contents']['twoColumnBrowseResultsRenderer']
            ['secondaryContents']['sectionListRenderer']['contents'][0]
        ['musicShelfRenderer']['contents'] as List<dynamic>;

    final title = TextComponentDetail.create(mrhr['title']['runs']).first;
    final List<TextComponentDetail> subtitle =
        (mrhr['subtitle'] == null || mrhr['subtitle']['runs'] == null)
            ? []
            : TextComponentDetail.create(mrhr['subtitle']['runs']);
    final List<TextComponentDetail> secondSubtitle =
        (mrhr['secondSubtitle'] == null ||
                mrhr['secondSubtitle']['runs'] == null)
            ? []
            : TextComponentDetail.create(mrhr['secondSubtitle']['runs']);
    final List<TextComponentDetail> description = mrhr['description'] == null
        ? []
        : TextComponentDetail.create(mrhr['description']
                ['musicDescriptionShelfRenderer']['description']['runs'] ??
            []);
    final tmpThumbnail = (mrhr['thumbnail']['musicThumbnailRenderer']
            ['thumbnail']['thumbnails'] as List)
        .last['url'] as String;
    final thumbnail = tmpThumbnail.startsWith('https://i.ytimg.com')
        ? tmpThumbnail
        : tmpThumbnail.replaceFirst(RegExp(r"=w\d+-h\d+"), '=w512-h512');
    List<Content> contents = [];

    for (var i = 0; i < slrc.length; i++) {
      if (slrc[i]['musicResponsiveListItemRenderer'] != null) {
        final item = slrc[i]['musicResponsiveListItemRenderer'];
        final tmpRuns1 = (item['flexColumns'] as List<dynamic>)
            .map((fc) =>
                fc['musicResponsiveListItemFlexColumnRenderer']['text']['runs'])
            .where((r) => r != null)
            .expand((i) => i)
            .toList();
        final tmpRuns2 = (item['fixedColumns'] as List<dynamic>)
            .map((fc) => fc['musicResponsiveListItemFixedColumnRenderer']
                ['text']['runs'])
            .where((r) => r != null)
            .expand((i) => i)
            .toList();
        final runs = TextComponentDetail.create([...tmpRuns1, ...tmpRuns2]);
        final title = runs.first;
        final subtitle = runs.sublist(1);

        contents.add(
          Content(
            id: title.id ?? '',
            type: 'watch',
            thumbnail: '',
            title: title,
            subtitle: subtitle,
          ),
        );
      }

      if (slrc[i]['musicMultiRowListItemRenderer'] != null) {
        final item = slrc[i]['musicMultiRowListItemRenderer'];
        final id = item['onTap']['watchEndpoint']['videoId'];
        final title = TextComponentDetail.create(item['title']['runs']).first;
        final subtitle = TextComponentDetail.create(item['subtitle']['runs']);
        final description = TextComponentDetail.create(
          item['description']['runs'],
        );
        final tmpThumbnail = (item['thumbnail']['musicThumbnailRenderer']
                ['thumbnail']['thumbnails'] as List)
            .last['url'] as String;
        final thumbnail = tmpThumbnail.startsWith('https://i.ytimg.com')
            ? tmpThumbnail
            : tmpThumbnail.replaceFirst(RegExp(r"=w\d+-h\d+"), '=w512-h512');

        title.id = id;

        contents.add(
          Content(
            id: id,
            type: 'watch',
            thumbnail: thumbnail,
            title: title,
            subtitle: subtitle,
            description: description,
          ),
        );
      }
    }

    return Playlist(
      id: playlistId,
      title: title,
      subtitle: subtitle,
      secondSubtitle: secondSubtitle,
      description: description,
      thumbnail: thumbnail,
      contents: contents,
    );
  }

  Future<Queue?> getNextQueue({
    required String itemId,
    String playlistId = '',
  }) async {
    final context = await getOrSetContext();
    Map<String, dynamic> requestBody = {
      'context': context,
      'isAudioOnly': true,
      'tunerSettingValue': 'AUTOMIX_SETTING_NORMAL',
      'videoId': itemId,
    };
    if (playlistId.isNotEmpty) {
      requestBody['playlistId'] = playlistId;
    }

    final client = http.Client();
    final response = await client.post(
      Uri.https(
        'music.youtube.com',
        '/youtubei/v1/next',
        {'prettyPrint': 'false'},
      ),
      headers: headers,
      body: jsonEncode(requestBody),
    );
    if (response.statusCode != 200) return null;

    final jsonData = jsonDecode(response.body);
    final wntrrTabs = jsonData['contents']
            ['singleColumnMusicWatchNextResultsRenderer']['tabbedRenderer']
        ['watchNextTabbedResultsRenderer']['tabs'];
    final playlist = wntrrTabs[0]['tabRenderer']['content']
            ['musicQueueRenderer']['content']['playlistPanelRenderer']
        ['contents'] as List<dynamic>;
    final pid = playlistId.isNotEmpty
        ? playlistId
        : playlist.last['automixPreviewVideoRenderer']['content']
                ['automixPlaylistVideoRenderer']['navigationEndpoint']
            ['watchPlaylistEndpoint']['playlistId'];

    if (playlist.length < 3 && playlistId.isEmpty) {
      return await getNextQueue(itemId: itemId, playlistId: pid);
    }

    final hasLyrics = wntrrTabs[1]['tabRenderer']['unselectable'] == null;
    String? lyricsBrowseId;
    if (hasLyrics) {
      lyricsBrowseId =
          wntrrTabs[1]['tabRenderer']['endpoint']['browseEndpoint']['browseId'];
    }

    List<Content> queue = [];
    for (var i = 0; i < playlist.length; i++) {
      final item = playlist[i]['playlistPanelVideoRenderer'];
      if (item == null) continue;
      final tmpRuns = [
        ...item['title']['runs'],
        ...item['shortBylineText']['runs'],
        ...item['lengthText']['runs'],
      ];
      final runs = TextComponentDetail.create(tmpRuns);
      final id = item['navigationEndpoint']['watchEndpoint']['videoId'];
      final title = runs.first;
      final subtitle = runs.sublist(1);
      final tmpThumbnail =
          (item['thumbnail']['thumbnails'] as List).last['url'] as String;
      final thumbnail = tmpThumbnail.startsWith('https://i.ytimg.com')
          ? tmpThumbnail
          : tmpThumbnail.replaceFirst(RegExp(r"=w\d+-h\d+"), '=w512-h512');

      queue.add(
        Content(
          id: id,
          type: 'watch',
          thumbnail: thumbnail,
          title: title,
          subtitle: subtitle,
        ),
      );
    }

    return Queue(
      index: queue.indexWhere((q) => q.id == itemId),
      lyrics: CurrentLyrics(
        available: hasLyrics,
        browseId: lyricsBrowseId,
      ),
      playlistId: pid ?? '',
      queue: queue,
    );
  }

  Future<Lyrics?> getLyricsWithBrowse(String browseId) async {
    final context = await getOrSetContext();
    Map<String, dynamic> requestBody = {
      'context': context,
      'browseId': browseId,
    };

    final client = http.Client();
    final response = await client.post(
      Uri.parse(
        'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false',
      ),
      headers: headers,
      body: jsonEncode(requestBody),
    );
    if (response.statusCode != 200) return null;

    final jsonData = jsonDecode(response.body);
    if (jsonData['contents']['sectionListRenderer'] == null) return null;

    final mdsr = jsonData['contents']['sectionListRenderer']['contents'][0]
        ['musicDescriptionShelfRenderer'];
    final lyrics = mdsr['description']['runs'][0]['text'];
    final footer = mdsr['footer']['runs'][0]['text'];

    return Lyrics(lyrics: lyrics, footer: footer);
  }

  Future<Lyrics?> getLyrics(String itemId) async {
    final context = await getOrSetContext();
    Map<String, dynamic> requestBody = {
      'context': context,
      'isAudioOnly': true,
      'tunerSettingValue': 'AUTOMIX_SETTING_NORMAL',
      'videoId': itemId,
    };

    final client = http.Client();
    final response = await client.post(
      Uri.https(
        'music.youtube.com',
        '/youtubei/v1/next',
        {'prettyPrint': 'false'},
      ),
      headers: headers,
      body: jsonEncode(requestBody),
    );
    if (response.statusCode != 200) return null;

    final jsonData = jsonDecode(response.body);
    final wntrrTabs = jsonData['contents']
            ['singleColumnMusicWatchNextResultsRenderer']['tabbedRenderer']
        ['watchNextTabbedResultsRenderer']['tabs'][1]['tabRenderer'];

    final hasLyrics = wntrrTabs['unselectable'];
    if (hasLyrics != null && !(hasLyrics as bool)) return null;

    String lyricsBrowseId = wntrrTabs['endpoint']['browseEndpoint']['browseId'];
    return await getLyricsWithBrowse(lyricsBrowseId);
  }

  Future<PlayableItem?> getContent(String itemId) async {
    final context = await getOrSetContext();
    Map<String, dynamic> requestBody = {
      'context': context,
      'videoId': itemId,
    };

    final client = http.Client();
    final response = await client.post(
      Uri.https(
        'music.youtube.com',
        '/youtubei/v1/player',
        {'prettyPrint': 'false'},
      ),
      headers: headers,
      body: jsonEncode(requestBody),
    );
    if (response.statusCode != 200) return null;

    final jsonData = jsonDecode(response.body);
    final vd = jsonData['videoDetails'];
    if (vd == null) return null;

    final title = TextComponentDetail(text: vd['title']);
    final author = TextComponentDetail(
        text: vd['author'], id: vd['channelId'], type: 'user_channel');
    final tmpThumbnail =
        (vd['thumbnail']['thumbnails'] as List).last['url'] as String;
    final thumbnail = tmpThumbnail.startsWith('https://i.ytimg.com')
        ? tmpThumbnail
        : tmpThumbnail.replaceFirst(RegExp(r"=w\d+-h\d+"), '=w512-h512');
    final duration = int.parse((vd['lengthSeconds'] as String));

    return PlayableItem(
      id: vd['videoId'],
      title: title,
      author: author,
      thumbnail: thumbnail,
      duration: duration,
    );
  }

  Future<PlayableItem?> getPlayableStream(String itemId) async {
    final item = await getContent(itemId);
    if (item == null) return null;

    final yt = yed.YoutubeExplode();
    final manifest = await yt.videos.streams.getManifest(itemId);
    final audio = manifest.audioOnly;
    yt.close();

    item.streamUrl = audio.first.url;
    return item;
  }
}
