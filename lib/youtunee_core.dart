import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yed;
import 'package:youtunee_core/str.dart';
import 'package:youtunee_core/typings.dart';

class Youtunee {
  Youtunee({this.thumbnailSize = 512});

  final int thumbnailSize;
  final _ytExplode = yed.YoutubeExplode();
  final Map<String, String> _headers = {
    'accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'accept-language': 'id-ID,id;q=0.9',
    'cache-control': 'no-cache',
    'pragma': 'no-cache',
    'priority': 'u=0, i',
    'upgrade-insecure-requests': '1',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  };
  final RegExp _initialDataRegExp = RegExp(
    r"initialData\.push\({path: '\\\/browse', params: JSON\.parse\('([^']+)'\), data: '([^']+)'}\);",
  );
  final RegExp _innertubeContextRegExp = RegExp(
    r'"INNERTUBE_CONTEXT":{(.+)},"INNERTUBE_CONTEXT_CLIENT_NAME"',
  );
  Map<String, dynamic> _innertubeContext = {};

  Future<Map<String, dynamic>> getOrSetContext() async {
    if (_innertubeContext['client'] != null) return _innertubeContext;

    final client = http.Client();
    final response = await client.get(
      Uri.https('music.youtube.com'),
      headers: _headers,
    );
    if (response.statusCode != 200) return {};

    final matched = _innertubeContextRegExp.firstMatch(response.body);
    if (matched == null) return {};

    final rawStringData = matched.group(1);
    if (rawStringData == null) return {};

    _innertubeContext = jsonDecode("{$rawStringData}");
    return _innertubeContext;
  }

  String _getThumbnail(dynamic thumbnails) {
    final tmpThumbnail = (thumbnails as List).last['url'] as String;
    final thumbnail = tmpThumbnail.startsWith('https://i.ytimg.com')
        ? tmpThumbnail
        : tmpThumbnail
            .replaceFirst(RegExp(r"=w\d+-h\d+"), '=w$thumbnailSize-h$thumbnailSize')
            .replaceFirst(RegExp(r"=w\d+-c-h\d+"), '=w$thumbnailSize-c-h$thumbnailSize');
    return thumbnail;
  }

  Content parseContent(dynamic item) {
    final tmpRuns = (item['flexColumns'] as List<dynamic>)
        .map(
          (fc) => fc['musicResponsiveListItemFlexColumnRenderer']['text']['runs'],
        )
        .where((r) => r != null)
        .expand((i) => i)
        .map((runs) => runs as Map<String, dynamic>)
        .toList();
    final runs = TextComponentDetail.create(tmpRuns);
    final title = runs.first;
    final subtitle = runs.sublist(1);
    final thumbnail = _getThumbnail(
      item['thumbnail']['musicThumbnailRenderer']['thumbnail']['thumbnails'],
    );

    if (item['navigationEndpoint'] != null) {
      final browserEndpoint = item['navigationEndpoint']['browseEndpoint'];
      title.id = ((title.id ?? browserEndpoint['browseId']) as String).replaceFirst('VL', '').replaceFirst('MPSP', '');
      title.type = (browserEndpoint['browseEndpointContextSupportedConfigs']['browseEndpointContextMusicConfig']['pageType'] as String)
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
      headers: _headers,
    );
    if (response.statusCode != 200) return null;

    final matched = _initialDataRegExp.firstMatch(response.body);
    if (matched == null) return null;

    final rawStringData = matched.group(2);
    if (rawStringData == null) return null;

    final stringData = unescape(rawStringData);
    final jsonData = jsonDecode(stringData);

    List<CategorizedContent> contents = [];
    final carouselShelfsData =
        jsonData['contents']['singleColumnBrowseResultsRenderer']['tabs'][0]['tabRenderer']['content']['sectionListRenderer']['contents'];

    if (carouselShelfsData.length > 1) {
      for (var i = 0; i < carouselShelfsData.length - 1; i++) {
        CategorizedContent content = CategorizedContent(
          category: '',
          contents: [],
        );

        final musicCarousel = carouselShelfsData[i]['musicCarouselShelfRenderer'];
        if (musicCarousel == null) continue;

        content.category = musicCarousel['header']['musicCarouselShelfBasicHeaderRenderer']['title']['runs'][0]['text'];

        for (var i = 0; i < (musicCarousel['contents'] as List<dynamic>).length; i++) {
          final item = musicCarousel['contents'][i];
          final mrlir = item['musicResponsiveListItemRenderer'];
          final mtrir = item['musicTwoRowItemRenderer'];

          if (mrlir != null) {
            content.contents.add(parseContent(mrlir));
          }

          if (mtrir != null) {
            final title = TextComponentDetail.create(
              (mtrir['title']['runs'] as List).where((r) => r != null).map((runs) => runs as Map<String, dynamic>).toList(),
            ).first;
            final subtitle = TextComponentDetail.create(
              (mtrir['subtitle']['runs'] as List).where((r) => r != null).map((runs) => runs as Map<String, dynamic>).toList(),
            );
            final thumbnail = _getThumbnail(
              mtrir['thumbnailRenderer']['musicThumbnailRenderer']['thumbnail']['thumbnails'],
            );

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
    String mode = 'search',
    String browseId = '',
    String? ctoken,
    String? params,
  }) async {
    final context = await getOrSetContext();

    Map<String, dynamic> queryParams = {'prettyPrint': 'false'};
    Map<String, dynamic> requestBody = {'context': context};

    if (ctoken != null && ctoken.isNotEmpty && params != null && params.isNotEmpty) {
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
      if (mode == 'browse' && browseId.isNotEmpty) {
        requestBody['browseId'] = browseId;
      }
    }

    final url = Uri.https(
      'music.youtube.com',
      '/youtubei/v1/$mode',
      queryParams,
    );
    final client = http.Client();
    final response = await client.post(
      url,
      headers: _headers,
      body: jsonEncode(requestBody),
    );
    if (response.statusCode != 200) return null;

    final jsonData = jsonDecode(response.body);
    if (jsonData['contents'] != null) {
      final slr = jsonData['contents']['tabbedSearchResultsRenderer'] != null
          ? jsonData['contents']['tabbedSearchResultsRenderer']['tabs'][0]['tabRenderer']['content']['sectionListRenderer']['contents']
          : jsonData['contents']['singleColumnBrowseResultsRenderer'] != null
              ? jsonData['contents']['singleColumnBrowseResultsRenderer']['tabs'][0]['tabRenderer']['content']['sectionListRenderer']['contents']
              : null;
      if (slr == null) return null;

      List<CategorizedContent> result = [];

      for (var i = 0; i < (slr as List<dynamic>).length; i++) {
        final mpsr = slr[i]['musicPlaylistShelfRenderer'];
        final mcsr = slr[i]['musicCardShelfRenderer'];
        final msr = slr[i]['musicShelfRenderer'];

        if (mcsr != null) {
          final category = mcsr['header']['musicCardShelfHeaderBasicRenderer']['title']['runs'][0]['text'];
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
          NextSearch next = NextSearch(query: '', mode: mode);

          if (msr['bottomEndpoint'] != null && msr['bottomEndpoint']['searchEndpoint'] != null) {
            next.query = msr['bottomEndpoint']['searchEndpoint']['query'];
            next.params = msr['bottomEndpoint']['searchEndpoint']['params'];
          }

          if (msr['continuations'] != null) {
            next.params = msr['continuations'][0]['nextContinuationData']['clickTrackingParams'];
            next.ctoken = msr['continuations'][0]['nextContinuationData']['continuation'];
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

        if (mpsr != null) {
          List<Content> contents = [];
          NextSearch next = NextSearch(query: '', mode: mode);

          if (mpsr['bottomEndpoint'] != null && mpsr['bottomEndpoint']['searchEndpoint'] != null) {
            next.query = mpsr['bottomEndpoint']['searchEndpoint']['query'];
            next.params = mpsr['bottomEndpoint']['searchEndpoint']['params'];
          }

          if (mpsr['continuations'] != null) {
            next.params = mpsr['continuations'][0]['nextContinuationData']['clickTrackingParams'];
            next.ctoken = mpsr['continuations'][0]['nextContinuationData']['continuation'];
          }

          for (var j = 0; j < mpsr['contents'].length; j++) {
            final item = mpsr['contents'][j];
            final mrlir = item['musicResponsiveListItemRenderer'];

            contents.add(parseContent(mrlir));
          }
          result.add(
            CategorizedContent(
              category: '',
              contents: contents,
              next: next,
            ),
          );
        }
      }

      return result;
    }

    if (jsonData['continuationContents'] != null) {
      var msc = jsonData['continuationContents']['musicShelfContinuation'] ?? jsonData['continuationContents']['musicPlaylistShelfContinuation'];
      if (msc == null) return null;

      List<Content> contents = [];
      NextSearch next = NextSearch(query: query, mode: mode);

      if (msc['continuations'] != null) {
        next.params = msc['continuations'][0]['nextContinuationData']['clickTrackingParams'];
        next.ctoken = msc['continuations'][0]['nextContinuationData']['continuation'];
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

  Future<Playlist?> getPlaylistItems({
    required String playlistId,
    String mode = 'playlist',
  }) async {
    final client = http.Client();
    final url = mode == 'playlist'
        ? Uri.https(
            'music.youtube.com',
            '/playlist',
            {'list': playlistId},
          )
        : Uri.https(
            'music.youtube.com',
            '/browse/$playlistId',
          );
    final response = await client.get(
      url,
      headers: _headers,
    );
    if (response.statusCode != 200) return null;

    final matched = _initialDataRegExp.firstMatch(response.body);
    if (matched == null) return null;

    final rawStringData = matched.group(2);
    if (rawStringData == null) return null;

    final stringData = unescape(rawStringData);
    final jsonData = jsonDecode(stringData);
    final mrhr = jsonData['contents']['twoColumnBrowseResultsRenderer']['tabs'][0]['tabRenderer']['content']['sectionListRenderer']['contents'][0]
        ['musicResponsiveHeaderRenderer'];
    final slr = jsonData['contents']['twoColumnBrowseResultsRenderer']['secondaryContents']['sectionListRenderer']['contents'][0];
    final mslr = slr['musicShelfRenderer'] ?? slr['musicPlaylistShelfRenderer'];
    final slrc = mslr['contents'] as List<dynamic>;
    NextSearch? nextSearch;

    if (mslr['continuations'] != null) {
      final continuationData = mslr['continuations'][0]['nextContinuationData'];
      nextSearch = NextSearch(
        mode: 'browse',
        query: '',
        browseId: '',
        params: continuationData['clickTrackingParams'],
        ctoken: continuationData['continuation'],
      );
    }

    final title = TextComponentDetail.create(
      (mrhr['title']['runs'] as List).map((c) => c as Map<String, dynamic>).toList(),
    ).first;
    final List<TextComponentDetail> subtitle = (mrhr['subtitle'] == null || mrhr['subtitle']['runs'] == null)
        ? []
        : TextComponentDetail.create(
            (mrhr['subtitle']['runs'] as List).map((c) => c as Map<String, dynamic>).toList(),
          );
    final List<TextComponentDetail> secondSubtitle = (mrhr['secondSubtitle'] == null || mrhr['secondSubtitle']['runs'] == null)
        ? []
        : TextComponentDetail.create(
            (mrhr['secondSubtitle']['runs'] as List).map((c) => c as Map<String, dynamic>).toList(),
          );
    final List<TextComponentDetail> description = mrhr['description'] == null
        ? []
        : TextComponentDetail.create(
            ((mrhr['description']['musicDescriptionShelfRenderer']['description']['runs'] ?? []) as List)
                .map(
                  (c) => c as Map<String, dynamic>,
                )
                .toList(),
          );
    final thumbnail = _getThumbnail(
      mrhr['thumbnail']['musicThumbnailRenderer']['thumbnail']['thumbnails'],
    );
    List<Content> contents = [];

    for (var i = 0; i < slrc.length; i++) {
      final mrir = slrc[i]['musicResponsiveListItemRenderer'];
      final mmrlir = slrc[i]['musicMultiRowListItemRenderer'];

      if (mrir != null) {
        final tmpRuns1 = (mrir['flexColumns'] as List<dynamic>)
            .map(
              (fc) => fc['musicResponsiveListItemFlexColumnRenderer']['text']['runs'],
            )
            .where((r) => r != null)
            .expand((i) => i)
            .toList();
        final tmpRuns2 = (mrir['fixedColumns'] as List<dynamic>)
            .map(
              (fc) => fc['musicResponsiveListItemFixedColumnRenderer']['text']['runs'],
            )
            .where((r) => r != null)
            .expand((i) => i)
            .toList();
        final runs = TextComponentDetail.create([...tmpRuns1, ...tmpRuns2]);
        final title = runs.first;
        final subtitle = runs.sublist(1);
        final thumbnail = mrir['thumbnail'] == null
            ? ''
            : _getThumbnail(
                mrir['thumbnail']['musicThumbnailRenderer']['thumbnail']['thumbnails'],
              );

        contents.add(
          Content(
            id: title.id ?? '',
            type: 'watch',
            thumbnail: thumbnail,
            title: title,
            subtitle: subtitle,
          ),
        );
      }

      if (mmrlir != null) {
        final id = mmrlir['onTap']['watchEndpoint']['videoId'];
        final title = TextComponentDetail.create(mmrlir['title']['runs']).first;
        final subtitle = TextComponentDetail.create(mmrlir['subtitle']['runs']);
        final description = TextComponentDetail.create(
          mmrlir['description']['runs'],
        );
        final thumbnail = _getThumbnail(
          mmrlir['thumbnail']['musicThumbnailRenderer']['thumbnail']['thumbnails'],
        );

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
      nextSearch: nextSearch,
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
      headers: _headers,
      body: jsonEncode(requestBody),
    );
    if (response.statusCode != 200) return null;

    final jsonData = jsonDecode(response.body);
    final wntrrTabs = jsonData['contents']['singleColumnMusicWatchNextResultsRenderer']['tabbedRenderer']['watchNextTabbedResultsRenderer']['tabs'];
    if (wntrrTabs[0]['tabRenderer']['content']['musicQueueRenderer']['content'] == null) return null;

    final playlist = wntrrTabs[0]['tabRenderer']['content']['musicQueueRenderer']['content']['playlistPanelRenderer']['contents'] as List<dynamic>;
    final pid = playlistId.isNotEmpty
        ? playlistId
        : playlist.last['automixPreviewVideoRenderer']['content']['automixPlaylistVideoRenderer']['navigationEndpoint']['watchPlaylistEndpoint']
            ['playlistId'];

    if (playlist.length < 3 && playlistId.isEmpty) {
      return await getNextQueue(itemId: itemId, playlistId: pid);
    }

    List<Content> queue = [];
    for (var i = 0; i < playlist.length; i++) {
      final item = playlist[i]['playlistPanelVideoRenderer'];
      if (item == null) continue;
      final tmpRuns = [
        ...item['title']['runs'],
        ...item['shortBylineText']['runs'],
        ...item['lengthText']['runs'],
      ].map((runs) => runs as Map<String, dynamic>).toList();
      final runs = TextComponentDetail.create(tmpRuns);
      final id = item['navigationEndpoint']['watchEndpoint']['videoId'];
      final title = runs.first;
      final subtitle = runs.sublist(1);
      final thumbnail = _getThumbnail(item['thumbnail']['thumbnails']);

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
      playlistId: pid ?? '',
      queue: queue,
    );
  }

  Future<Lyrics?> _getLyricsWithBrowse(String browseId) async {
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
      headers: _headers,
      body: jsonEncode(requestBody),
    );
    if (response.statusCode != 200) return null;

    final jsonData = jsonDecode(response.body);
    if (jsonData['contents']['sectionListRenderer'] == null) return null;

    final mdsr = jsonData['contents']['sectionListRenderer']['contents'][0]['musicDescriptionShelfRenderer'];
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
      headers: _headers,
      body: jsonEncode(requestBody),
    );
    if (response.statusCode != 200) return null;

    final jsonData = jsonDecode(response.body);
    final wntrrTabs = jsonData['contents']['singleColumnMusicWatchNextResultsRenderer']['tabbedRenderer']['watchNextTabbedResultsRenderer']['tabs'][1]
        ['tabRenderer'];

    final hasLyrics = wntrrTabs['unselectable'];
    if (hasLyrics != null && !(hasLyrics as bool)) return null;

    String lyricsBrowseId = wntrrTabs['endpoint']['browseEndpoint']['browseId'];
    return await _getLyricsWithBrowse(lyricsBrowseId);
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
      headers: _headers,
      body: jsonEncode(requestBody),
    );
    if (response.statusCode != 200) return null;

    final jsonData = jsonDecode(response.body);
    final vd = jsonData['videoDetails'];
    if (vd == null) return null;

    final title = TextComponentDetail(text: vd['title']);
    final author = TextComponentDetail(text: vd['author'], id: vd['channelId'], type: 'user_channel');
    final thumbnail = _getThumbnail(vd['thumbnail']['thumbnails']);
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

    final manifest = await _ytExplode.videos.streams.getManifest(
      itemId,
      ytClients: [
        yed.YoutubeApiClient.tv,
        yed.YoutubeApiClient.mweb,
      ],
    );
    final audio = manifest.audioOnly;
    item.streamUrl = audio.first.url;

    return item;
  }

  Future<Profile?> getProfile(String profileId) async {
    final context = await getOrSetContext();
    final responseBody = {
      'context': context,
      'browseId': profileId,
    };

    final client = http.Client();
    final response = await client.post(
      Uri.https(
        'music.youtube.com',
        '/youtubei/v1/browse',
        {'prettyPrint': 'false'},
      ),
      headers: _headers,
      body: jsonEncode(responseBody),
    );
    if (response.statusCode != 200) return null;

    final jsonData = jsonDecode(response.body);
    final header = jsonData['header']['musicImmersiveHeaderRenderer'];
    final contentsz =
        jsonData['contents']['singleColumnBrowseResultsRenderer']['tabs'][0]['tabRenderer']['content']['sectionListRenderer']['contents'];

    if (header == null) return null;

    final name = header['title']['runs'][0]['text'];
    final about = TextComponentDetail.create(
      (header['description']['runs'] as List)
          .map(
            (c) => c as Map<String, dynamic>,
          )
          .toList(),
    );
    final image = (header['thumbnail']['musicThumbnailRenderer']['thumbnail']['thumbnails'] as List).last['url'];

    List<CategorizedContent> contents = [];
    for (var i = 0; i < (contentsz as List).length; i++) {
      final msr = contentsz[i]['musicShelfRenderer'];
      final mcsr = contentsz[i]['musicCarouselShelfRenderer'];

      if (msr != null) {
        final category = msr['title']['runs'][0]['text'];
        NextSearch next = NextSearch(
          query: '',
          mode: 'browse',
          browseId: msr['bottomEndpoint']['browseEndpoint']['browseId'],
          params: msr['bottomEndpoint']['browseEndpoint']['params'],
        );
        List<Content> ct = [];

        for (var j = 0; j < (msr['contents'] as List).length; j++) {
          final item = msr['contents'][j]['musicResponsiveListItemRenderer'];
          ct.add(parseContent(item));
        }

        contents.add(
          CategorizedContent(
            category: category,
            contents: ct,
            next: next,
          ),
        );
      }

      if (mcsr != null) {
        final header = mcsr['header']['musicCarouselShelfBasicHeaderRenderer'];
        final category = header['title']['runs'][0]['text'];

        final moreButton = header['moreContentButton'];
        NextSearch next = NextSearch(
          query: '',
          mode: 'browse',
          browseId: moreButton == null ? null : moreButton['buttonRenderer']['navigationEndpoint']['browseEndpoint']['browseId'],
          params: moreButton == null ? '' : moreButton['buttonRenderer']['navigationEndpoint']['browseEndpoint']['params'],
        );
        List<Content> ct = [];

        for (var j = 0; j < (mcsr['contents'] as List).length; j++) {
          final mtrir = mcsr['contents'][j]['musicTwoRowItemRenderer'];
          final title = TextComponentDetail.create(
            (mtrir['title']['runs'] as List).where((r) => r != null).map((runs) => runs as Map<String, dynamic>).toList(),
          ).first;
          final subtitle = TextComponentDetail.create(
            (mtrir['subtitle']['runs'] as List).where((r) => r != null).map((runs) => runs as Map<String, dynamic>).toList(),
          );
          final thumbnail = _getThumbnail(
            mtrir['thumbnailRenderer']['musicThumbnailRenderer']['thumbnail']['thumbnails'],
          );

          ct.add(
            Content(
              id: title.id ?? '',
              type: title.type ?? '',
              thumbnail: thumbnail,
              title: title,
              subtitle: subtitle,
            ),
          );
        }

        contents.add(
          CategorizedContent(
            category: category,
            contents: ct,
            next: next,
          ),
        );
      }
    }

    return Profile(
      id: profileId,
      name: name,
      about: about,
      image: image,
      contents: contents,
    );
  }
}
