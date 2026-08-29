import 'package:flutter_test/flutter_test.dart';
import 'package:dvcr/services/youtube_playlist_service.dart';

void main() {
  test('parsePlaylistRssXml reads yt:videoId entries', () {
    const xml = '''
<feed>
 <entry>
  <yt:videoId>abcdefghijk</yt:videoId>
  <title>One</title>
  <published>2026-08-01T12:00:00+00:00</published>
 </entry>
 <entry>
  <id>yt:video:ABCDEFGHIJK</id>
  <media:title>Two</media:title>
  <published>2026-08-02T12:00:00+00:00</published>
 </entry>
</feed>
''';
    final videos = YoutubePlaylistService.parsePlaylistRssXml(
      xml,
      category: 'adherent_vod',
    );
    expect(videos.map((v) => v.youtubeId).toSet(), {
      'abcdefghijk',
      'ABCDEFGHIJK',
    });
    expect(videos.firstWhere((v) => v.youtubeId == 'ABCDEFGHIJK').title, 'Two');
  });

  test('parsePlaylistWatchPageHtml reads lockupViewModel thumbs', () {
    const html = '''
{"lockupViewModel":{"contentImage":{"thumbnailViewModel":{"image":{"sources":[{"url":"https://i.ytimg.com/vi/b-WgJchTBJg/hqdefault.jpg","width":168}
{"lockupMetadataViewModel":{"title":{"content":"Episode 1"}
{"lockupViewModel":{"contentImage":{"thumbnailViewModel":{"image":{"sources":[{"url":"https://i.ytimg.com/vi/TbqaQ_NCzEY/hqdefault.jpg","width":168}
{"lockupMetadataViewModel":{"title":{"content":"Episode 2"}
''';
    final videos = YoutubePlaylistService.parsePlaylistWatchPageHtml(
      html,
      category: 'adherent_vod',
    );
    expect(videos.map((v) => v.youtubeId).toList(), [
      'b-WgJchTBJg',
      'TbqaQ_NCzEY',
    ]);
    expect(videos.first.title, 'Episode 1');
    expect(videos.last.title, 'Episode 2');
  });

  test('parsePlaylistWatchPageHtml returns empty when no videos', () {
    expect(
      YoutubePlaylistService.parsePlaylistWatchPageHtml(
        '<html>This playlist is private</html>',
        category: 'adherent_vod',
      ),
      isEmpty,
    );
  });
}
