class TextComponentDetail {
  String text;
  String? type;
  String? id;

  TextComponentDetail({
    required this.text,
    this.id,
    this.type,
  });

  static List<TextComponentDetail> create(List<Map<String, dynamic>> runs) {
    List<TextComponentDetail> tcds = [];

    for (var i = 0; i < runs.length; i++) {
      TextComponentDetail tcd = TextComponentDetail(text: "");
      final run = runs[i];
      tcd.text = run['text'];
      final navigationEndpoint = run['navigationEndpoint'];
      if (navigationEndpoint != null) {
        final watchEndpoint = navigationEndpoint['watchEndpoint'];
        final browseEndpoint = navigationEndpoint['browseEndpoint'];
        if (watchEndpoint != null) {
          tcd.type = 'watch';
        }
        if (browseEndpoint != null) {
          final pageType = browseEndpoint['browseEndpointContextSupportedConfigs']['browseEndpointContextMusicConfig']['pageType'] as String?;
          if (pageType != null) {
            tcd.type = pageType.replaceAll("MUSIC_PAGE_TYPE_", "").toLowerCase();
          }
        }

        tcd.id = watchEndpoint != null
            ? watchEndpoint['videoId']
            : browseEndpoint != null
                ? browseEndpoint['browseId']
                : null;

        if (tcd.type == 'playlist' && tcd.id != null) {
          tcd.id = (tcd.id ?? '').replaceFirst('VL', '').replaceFirst('MPSP', '');
        }
      }

      tcds.add(tcd);
    }

    return tcds;
  }

  Map<String, dynamic> toMap() {
    return {'text': text, 'id': id, 'type': type};
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

class Content {
  String id;
  String type;
  String thumbnail;
  List<TextComponentDetail> description = [];
  TextComponentDetail title;
  List<TextComponentDetail> subtitle;

  Content({
    required this.id,
    required this.type,
    required this.thumbnail,
    required this.title,
    required this.subtitle,
    this.description = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'thumbnail': thumbnail,
      'title': title.toMap(),
      'subtitle': subtitle.map((subtitle) => subtitle.toMap()).toList(),
      'description': description.map((description) => description.toMap()).toList(),
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }

  static Content create(Map<String, dynamic> data) {
    final id = data['id'] ?? '';
    final type = data['type'] ?? '';
    final thumbnail = data['thumbnail'] ?? '';
    final title = TextComponentDetail.create(
      [data['title'] ?? {}].map((d) => d as Map<String, dynamic>).toList(),
    ).first;
    final subtitle = TextComponentDetail.create((data['subtitle'] ?? []));
    final description = TextComponentDetail.create((data['description'] ?? []));

    return Content(
      id: id,
      type: type,
      thumbnail: thumbnail,
      title: title,
      subtitle: subtitle,
      description: description,
    );
  }
}

class NextSearch {
  String query;
  String mode;
  String params;
  String? browseId;
  String? ctoken;

  NextSearch({
    required this.query,
    this.mode = 'search',
    this.params = '',
    this.browseId,
    this.ctoken,
  });

  Map<String, dynamic> toMap() {
    return {
      'query': query,
      'mode': mode,
      'browseId': browseId,
      'params': params,
      'ctoken': ctoken,
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }

  static NextSearch create(Map<String, dynamic> data) {
    final String query = data['query'] ?? '';
    final String mode = data['mode'] ?? '';
    final String params = data['params'] ?? '';
    final String? browseId = data['browseId'];
    final String? ctoken = data['ctoken'];

    return NextSearch(
      query: query,
      mode: mode,
      params: params,
      browseId: browseId,
      ctoken: ctoken,
    );
  }
}

class CategorizedContent {
  String category;
  List<Content> contents;
  NextSearch? next;

  CategorizedContent({
    required this.category,
    required this.contents,
    this.next,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'contents': contents.map((content) => content.toMap()).toList(),
      'next': next?.toMap(),
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }

  static CategorizedContent create(Map<String, dynamic> data) {
    final String category = data['category'] ?? '';
    final NextSearch? next = data['next'] ? NextSearch.create(data['next']) : null;
    final List<Content> contents = ((data['contents'] ?? []) as List<Map<String, dynamic>>)
        .map(
          (content) => Content.create(content),
        )
        .toList();

    return CategorizedContent(
      category: category,
      contents: contents,
      next: next,
    );
  }
}

class Playlist {
  String id;
  TextComponentDetail title;
  List<TextComponentDetail> subtitle;
  List<TextComponentDetail> secondSubtitle;
  List<TextComponentDetail> description;
  String thumbnail;
  List<Content> contents;
  NextSearch? nextSearch;

  Playlist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.secondSubtitle,
    required this.description,
    required this.thumbnail,
    required this.contents,
    this.nextSearch,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle.map((subtitle) => subtitle.toMap()).toList(),
      'secondSubtitle': secondSubtitle.map((secondSubtitle) => secondSubtitle.toMap()).toList(),
      'description': description.map((description) => description.toMap()).toList(),
      'thumbnail': thumbnail,
      'contents': contents.map((content) => content.toMap()).toList(),
      'nextSearch': nextSearch?.toMap(),
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }

  static Playlist create(Map<String, dynamic> data) {
    String id = data['id'] ?? '';
    String thumbnail = data['thumbnail'] ?? '';
    TextComponentDetail title = TextComponentDetail.create(
      [data['title'] ?? {}].map((d) => d as Map<String, dynamic>).toList(),
    ).first;
    List<TextComponentDetail> subtitle = TextComponentDetail.create((data['subtitle'] ?? []));
    List<TextComponentDetail> secondSubtitle = TextComponentDetail.create((data['secondSubtitle'] ?? []));
    List<TextComponentDetail> description = TextComponentDetail.create((data['description'] ?? []));
    List<Content> contents = ((data['contents'] ?? []) as List<Map<String, dynamic>>)
        .map(
          (content) => Content.create(content),
        )
        .toList();

    return Playlist(
      id: id,
      title: title,
      subtitle: subtitle,
      secondSubtitle: secondSubtitle,
      description: description,
      thumbnail: thumbnail,
      contents: contents,
    );
  }
}

class Queue {
  int index;
  String playlistId;
  List<Content> queue;

  Queue({
    required this.index,
    required this.playlistId,
    required this.queue,
  });

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'playlistId': playlistId,
      'queue': queue.map((content) => content.toMap()).toList(),
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }

  static Queue create(Map<String, dynamic> data) {
    final index = data['index'] ?? -1;
    final playlistId = data['playlistId'] ?? '';
    final List<Content> queue = ((data['queue'] ?? []) as List<Map<String, dynamic>>)
        .map(
          (content) => Content.create(content),
        )
        .toList();

    return Queue(
      index: index,
      playlistId: playlistId,
      queue: queue,
    );
  }
}

class Lyrics {
  String lyrics;
  String footer;

  Lyrics({
    required this.lyrics,
    required this.footer,
  });

  Map<String, dynamic> toMap() {
    return {'lyrics': lyrics, 'footer': footer};
  }

  @override
  String toString() {
    return toMap().toString();
  }

  static create(Map<String, dynamic> data) {
    return Lyrics(
      lyrics: data['lyrics'] ?? '',
      footer: data['footer'] ?? '',
    );
  }
}

class PlayableItem {
  String id;
  TextComponentDetail title;
  TextComponentDetail author;
  String thumbnail;
  int duration;
  Uri? streamUrl;

  PlayableItem({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnail,
    required this.duration,
    this.streamUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title.toMap(),
      'author': author.toMap(),
      'thumbnail': thumbnail,
      'duration': duration,
      'streamUrl': streamUrl.toString(),
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }

  static PlayableItem create(Map<String, dynamic> data) {
    final String id = data['id'] ?? '';
    final String thumbnail = data['thumbnail'] ?? '';
    final int duration = data['duration'] ?? 0;
    final Uri? streamUrl = data['streamUrl'] ? Uri.parse(data['streamUrl'] ?? '') : null;
    final TextComponentDetail title = TextComponentDetail.create(
      [data['title'] ?? {}].map((d) => d as Map<String, dynamic>).toList(),
    ).first;
    final TextComponentDetail author = TextComponentDetail.create(
      [data['author'] ?? {}].map((d) => d as Map<String, dynamic>).toList(),
    ).first;

    return PlayableItem(
      id: id,
      title: title,
      author: author,
      thumbnail: thumbnail,
      duration: duration,
      streamUrl: streamUrl,
    );
  }
}

class Profile {
  String id;
  String name;
  List<TextComponentDetail> about;
  String image;
  List<CategorizedContent> contents;

  Profile({
    required this.id,
    required this.name,
    required this.about,
    required this.image,
    required this.contents,
  });

  @override
  String toString() {
    return {
      'id': id,
      'name': name,
      'about': about,
      'image': image,
      'contents': contents,
    }.toString();
  }

  static Profile create(Map<String, dynamic> data) {
    final String id = data['id'] ?? '';
    final String name = data['name'] ?? '';
    final String image = data['image'] ?? '';
    final List<TextComponentDetail> about = TextComponentDetail.create(data['about'] ?? []);
    final List<CategorizedContent> contents = ((data['contents'] ?? []) as List)
        .map((content) => content as Map<String, dynamic>)
        .map(
          (content) => CategorizedContent.create(content),
        )
        .toList();

    return Profile(id: id, name: name, about: about, image: image, contents: contents);
  }
}
