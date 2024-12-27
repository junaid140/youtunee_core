class TextComponentDetail {
    String text;
    String? type;
    String? id;

    TextComponentDetail({
        required this.text,
        this.id,
        this.type,
    });

    static List<TextComponentDetail> create(dynamic runs) {
        List<TextComponentDetail> tcds = [];

        for (var i = 0; i < runs.length; i++) {
            TextComponentDetail tcd = TextComponentDetail(text: "");
            final run = runs[i];
            tcd.text = run['text'];
            final navigationEndpoint = run['navigationEndpoint'];
            if(navigationEndpoint != null) {
                final watchEndpoint = navigationEndpoint['watchEndpoint'];
                final browseEndpoint = navigationEndpoint['browseEndpoint'];
                if(watchEndpoint != null) {
                    tcd.type = 'watch';
                }
                if(browseEndpoint != null) {
                    final pageType = browseEndpoint['browseEndpointContextSupportedConfigs']['browseEndpointContextMusicConfig']['pageType'] as String?;
                    if(pageType != null) {
                        tcd.type = pageType.replaceAll("MUSIC_PAGE_TYPE_", "").toLowerCase();
                    }
                }

                tcd.id = watchEndpoint != null 
                    ? watchEndpoint['videoId']
                    : browseEndpoint != null 
                        ? browseEndpoint['browseId']
                        : null;
                
                if(tcd.type == 'playlist' && tcd.id != null) {
                    tcd.id = (tcd.id ?? '').replaceFirst('VL', '').replaceFirst('MPSP', '');
                }
            }

            tcds.add(tcd);
        }

        return tcds;
    }

  @override
  String toString() {
    return {'text': text, 'id': id, 'type': type}.toString();
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

    @override
  String toString() {
    return {'id': id, 'type': type, 'thumbnail': thumbnail, 'title': title, 'subtitle': subtitle, 'description': description}.toString();
  }
}

class NextSearch {
  String query;
  String params;
  String? ctoken;

  NextSearch({
    required this.query,
    this.params = '',
    this.ctoken,
  });

  @override
  String toString() {
    return {'query': query, 'params': params, 'ctoken': ctoken}.toString();
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

  @override
  String toString() {
    return {'category': category, 'contents': contents, 'next': next}.toString();
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

  Playlist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.secondSubtitle,
    required this.description,
    required this.thumbnail,
    required this.contents,
  });

  @override
  String toString() {
    return {'id': id, 'title': title, 'subtitle': subtitle, 'secondSubtitle': secondSubtitle, 'description': description, 'thumbnail': thumbnail, 'contents': contents}.toString();
  }
}

class CurrentLyrics {
  final bool available;
  final String? browseId;
  
  CurrentLyrics({
    required this.available,
    required this.browseId,
  });

  @override
  String toString() {
    return {'available': available, 'browseId': browseId}.toString();
  }
}

class Queue {
  final int index;
  final String playlistId;
  final CurrentLyrics lyrics;
  final List<Content> queue;

  Queue({
    required this.index,
    required this.playlistId,
    required this.lyrics,
    required this.queue,
  });

  @override
  String toString() {
    return {'index': index, 'playlistId': playlistId, 'lyrics': lyrics, 'queue': queue}.toString();
  }
}

class Lyrics {
  final String lyrics;
  final String footer;

  Lyrics({
    required this.lyrics,
    required this.footer,
  });

  @override
  String toString() {
    return {'lyrics': lyrics, 'footer': footer}.toString();
  }
}