import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_room_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreRoomRepository rooms;

  setUp(() {
    db = FakeFirebaseFirestore();
    rooms = FirestoreRoomRepository(firestore: db);
  });

  test(
    'create, join and leave keep room and user membership in sync',
    () async {
      final room = await rooms.createRoom('Flat', 'alice');
      final created = await db.collection('rooms').doc(room.id).get();
      final alice = await db.collection('users').doc('alice').get();
      expect(created.data()?['memberIds'], ['alice']);
      expect(alice.data()?['rooms'], [room.id]);

      await rooms.joinRoom(room.inviteCode.toLowerCase(), 'bob');
      final joined = await db.collection('rooms').doc(room.id).get();
      final bob = await db.collection('users').doc('bob').get();
      expect(joined.data()?['memberIds'], ['alice', 'bob']);
      expect(bob.data()?['rooms'], [room.id]);

      await rooms.leaveRoom(room.id, 'bob');
      final left = await db.collection('rooms').doc(room.id).get();
      final bobAfter = await db.collection('users').doc('bob').get();
      expect(left.data()?['memberIds'], ['alice']);
      expect(bobAfter.data()?['rooms'], isEmpty);
    },
  );

  test('full room rejects a new member without writing a user link', () async {
    final room = await rooms.createRoom('Flat', 'alice');
    await db.collection('rooms').doc(room.id).update({
      'memberIds': [
        'alice',
        'user2',
        'user3',
        'user4',
        'user5',
        'user6',
        'user7',
        'user8',
        'user9',
        'user10',
      ],
    });

    await expectLater(
      rooms.joinRoom(room.inviteCode, 'extra'),
      throwsA(anything),
    );
    final stored = await db.collection('rooms').doc(room.id).get();
    expect((stored.data()?['memberIds'] as List), hasLength(10));
    expect((await db.collection('users').doc('extra').get()).exists, isFalse);
  });

  test(
    'member with no user profile can still be removed from a room',
    () async {
      final room = await rooms.createRoom('Flat', 'alice');
      await db.collection('rooms').doc(room.id).update({
        'memberIds': ['alice', 'missing-user'],
      });

      await rooms.removeMember(room.id, 'missing-user');
      final stored = await db.collection('rooms').doc(room.id).get();
      expect(stored.data()?['memberIds'], ['alice']);
      expect(
        (await db.collection('users').doc('missing-user').get()).exists,
        isFalse,
      );
    },
  );
}
