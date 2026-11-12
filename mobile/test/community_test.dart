import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rucha_mobile/models/community_post.dart';
import 'package:rucha_mobile/services/community_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CommunityPost parses server JSON and normalizes chat messages', () {
    final post = CommunityPost.fromJson({
      'id': 'cpost_1',
      'clubId': 'club_1',
      'clubName': 'Bole Runners',
      'authorId': 'athlete_1',
      'authorName': 'Abebe',
      'kind': 'chat',
      'title': 'Morning run at 6?',
      'body': 'Meet at Meskel Square.',
      'createdAt': '2026-11-11T06:30:00Z',
    });

    expect(post.isMessage, isTrue);
    expect(post.kind, 'message');
    expect(post.clubName, 'Bole Runners');
    expect(post.authorName, 'Abebe');
  });

  test('CommunityPost create payload omits server-owned fields', () {
    final draft = CommunityPost(
      id: '',
      clubId: 'club_1',
      kind: 'milestone',
      title: 'First 10K',
      body: 'Done before sunrise.',
      createdAt: DateTime(2026, 11, 11),
    );
    final json = draft.toCreateJson();

    expect(json['clubId'], 'club_1');
    expect(json['kind'], 'milestone');
    expect(json.containsKey('id'), isFalse);
    expect(json.containsKey('authorId'), isFalse);
    expect(json.containsKey('createdAt'), isFalse);
  });

  test('CommunityStore creates an unread join notification and marks it read', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CommunityStore();

    await store.addJoinNotice(
      clubId: 'club_1',
      clubName: 'Bole Runners',
    );

    expect(store.notices.length, 1);
    expect(store.unreadNoticeCount, 1);
    expect(store.notices.first.title, contains('Bole Runners'));

    await store.markAllNoticesRead();
    expect(store.unreadNoticeCount, 0);
  });
}
