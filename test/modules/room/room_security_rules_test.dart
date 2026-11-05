// Opt-in real rules-engine tests. See docs/ROOM_LIFECYCLE_AUDIT.md.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

const _project = 'demo-splitex-room-audit';
const _documents = 'projects/$_project/databases/(default)/documents';

void main() {
  final host = Platform.environment['ROOM_FIRESTORE_EMULATOR'];
  final client = HttpClient();
  final room = <String, dynamic>{
    'name': 'Home',
    'inviteCode': 'ABC123',
    'adminId': 'alice',
    'memberIds': ['alice', 'bob'],
    'participantIds': ['alice', 'bob'],
    'legacyBillMemberIds': ['alice', 'bob'],
    'isArchived': false,
    'isLocked': false,
    'currentMonth': '2026-10',
    'createdAt': DateTime.utc(2026, 10, 1),
    'ledgerVersion': 0,
  };
  final expense = <String, dynamic>{
    'title': 'Dinner',
    'amount': 120,
    'paidBy': 'alice',
    'createdBy': 'alice',
    'splitAmong': ['alice', 'bob'],
    'splitType': 'equal',
    'month': '2026-10',
    'date': DateTime.utc(2026, 10, 12),
    'createdAt': DateTime.utc(2026, 10, 12),
  };
  Map<String, dynamic> field(dynamic value) => switch (value) {
    null => {'nullValue': null},
    bool value => {'booleanValue': value},
    int value => {'integerValue': value.toString()},
    double value => {'doubleValue': value},
    String value => {'stringValue': value},
    DateTime value => {'timestampValue': value.toUtc().toIso8601String()},
    List value => {
      'arrayValue': {'values': value.map(field).toList()},
    },
    Map value => {
      'mapValue': {
        'fields': value.map((key, value) => MapEntry(key, field(value))),
      },
    },
    _ => throw ArgumentError('Unsupported Firestore value'),
  };
  Map<String, dynamic> write(
    String path,
    Map<String, dynamic> data, {
    List<String> timestamps = const [],
  }) => {
    'update': {
      'name': '$_documents/$path',
      'fields': data.map((key, value) => MapEntry(key, field(value))),
    },
    if (timestamps.isNotEmpty)
      'updateTransforms': [
        for (final path in timestamps)
          {'fieldPath': path, 'setToServerValue': 'REQUEST_TIME'},
      ],
  };
  String token(String uid) {
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return '${part({'alg': 'none', 'typ': 'JWT'})}.${part({
      'iss': 'https://securetoken.google.com/$_project',
      'aud': _project,
      'auth_time': now,
      'iat': now,
      'exp': now + 3600,
      'sub': uid,
      'user_id': uid,
      'firebase': {'sign_in_provider': 'custom', 'identities': {}},
    })}.';
  }

  Future<(int, String)> request(
    String method,
    String path, {
    String user = 'owner',
    Object? body,
  }) async {
    final req = await client.openUrl(method, Uri.parse('http://$host/$path'));
    req.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${user == 'owner' ? 'owner' : token(user)}',
    );
    req.headers.contentType = ContentType.json;
    if (body != null) req.write(jsonEncode(body));
    final response = await req.close();
    return (response.statusCode, await utf8.decoder.bind(response).join());
  }

  Future<void> commit(
    String user,
    List<Map<String, dynamic>> writes, {
    bool allowed = true,
  }) async {
    final result = await request(
      'POST',
      'v1/$_documents:commit',
      user: user,
      body: {'writes': writes},
    );
    expect(result.$1, allowed ? 200 : 403, reason: result.$2);
  }

  Map<String, dynamic> versionWrite({
    Map<String, dynamic> changes = const {},
    int version = 1,
  }) => write('rooms/home', {...room, ...changes, 'ledgerVersion': version});

  group(
    'Firestore room security rules',
    () {
      setUpAll(() async {
        final rules = await File('firestore.rules').readAsString();
        final result = await request(
          'PUT',
          'emulator/v1/projects/$_project:securityRules',
          body: {
            'rules': {
              'files': [
                {'name': 'firestore.rules', 'content': rules},
              ],
            },
          },
        );
        expect(result.$1, 200, reason: result.$2);
      });
      setUp(() async {
        final cleared = await request(
          'DELETE',
          'emulator/v1/projects/$_project/databases/(default)/documents',
        );
        expect(cleared.$1, 200);
        await commit('owner', [
          write('rooms/home', room),
          write('rooms/home/expenses/dinner', expense),
          write('users/alice', {
            'rooms': ['home'],
            'name': 'Alice',
          }),
          write('users/bob', {
            'rooms': ['home'],
            'name': 'Bob',
          }),
        ]);
      });
      tearDownAll(() => client.close(force: true));

      test(
        'former members retain history but cannot mutate expenses; outsiders cannot read the ledger',
        () async {
          final left = {
            ...room,
            'memberIds': ['alice'],
            'ledgerVersion': 1,
          };
          await commit('bob', [
            write('rooms/home', left),
            write('users/bob', {'rooms': [], 'name': 'Bob'}),
          ]);
          expect(
            (await request(
              'GET',
              'v1/$_documents/rooms/home/expenses/dinner',
              user: 'bob',
            )).$1,
            200,
          );
          expect(
            (await request(
              'GET',
              'v1/$_documents/rooms/home/expenses/dinner',
              user: 'outsider',
            )).$1,
            403,
          );
          await commit('bob', [
            write('rooms/home', {...left, 'ledgerVersion': 2}),
            write('rooms/home/expenses/new', {
              ...expense,
              'createdBy': 'bob',
              'paidBy': 'bob',
            }),
          ], allowed: false);
        },
      );

      test(
        'joining changes membership without allowing an admin takeover',
        () async {
          final joined = {
            ...room,
            'memberIds': ['alice', 'bob', 'carol'],
            'participantIds': ['alice', 'bob', 'carol'],
            'ledgerVersion': 1,
          };
          await commit('carol', [
            write('rooms/home', {...joined, 'adminId': 'carol'}),
          ], allowed: false);
          await commit('carol', [write('rooms/home', joined)]);
        },
      );

      test(
        'admin must transfer before leaving; another member cannot promote themselves',
        () async {
          await commit('alice', [
            versionWrite(
              changes: {
                'memberIds': ['bob'],
              },
            ),
          ], allowed: false);
          await commit('bob', [
            versionWrite(changes: {'adminId': 'bob'}),
          ], allowed: false);
          await commit('alice', [
            versionWrite(changes: {'adminId': 'bob'}),
          ]);
          await commit('alice', [
            versionWrite(
              version: 2,
              changes: {
                'adminId': 'bob',
                'memberIds': ['bob'],
              },
            ),
          ]);
        },
      );

      test(
        'admin removal may unlink the room but cannot edit the former member profile',
        () async {
          final removed = versionWrite(
            changes: {
              'memberIds': ['alice'],
            },
          );
          await commit('alice', [
            removed,
            write('users/bob', {'rooms': [], 'name': 'Changed'}),
          ], allowed: false);
          await commit('alice', [
            removed,
            write('users/bob', {'rooms': [], 'name': 'Bob'}),
          ]);
        },
      );

      test(
        'archival preserves reads and rejects expense writes, joins and hard deletion',
        () async {
          final archived = {
            ...room,
            'isArchived': true,
            'archivedBy': 'alice',
            'ledgerVersion': 1,
          };
          await commit('alice', [
            write('rooms/home', archived, timestamps: ['archivedAt']),
          ]);
          expect(
            (await request(
              'GET',
              'v1/$_documents/rooms/home/expenses/dinner',
              user: 'bob',
            )).$1,
            200,
          );
          await commit('bob', [
            write('rooms/home', {...archived, 'ledgerVersion': 2}),
            write('rooms/home/expenses/new', expense),
          ], allowed: false);
          await commit('carol', [
            write('rooms/home', {
              ...archived,
              'memberIds': ['alice', 'bob', 'carol'],
              'participantIds': ['alice', 'bob', 'carol'],
              'ledgerVersion': 2,
            }),
          ], allowed: false);
          await commit('alice', [
            {'delete': '$_documents/rooms/home'},
          ], allowed: false);
        },
      );

      test(
        'last departure archives; the historical admin can restore the empty room',
        () async {
          await commit('owner', [
            write('rooms/home', {
              ...room,
              'memberIds': ['alice'],
            }),
          ]);
          final archived = {
            ...room,
            'memberIds': [],
            'isArchived': true,
            'archivedBy': 'alice',
            'ledgerVersion': 1,
          };
          await commit('alice', [
            write('rooms/home', archived, timestamps: ['archivedAt']),
            write('users/alice', {'rooms': [], 'name': 'Alice'}),
          ]);
          await commit('alice', [
            write('rooms/home', {
              ...room,
              'memberIds': ['alice'],
              'archivedAt': null,
              'archivedBy': null,
              'ledgerVersion': 2,
            }),
          ]);
        },
      );

      test(
        'only the recipient confirms a pending payment and cannot alter its amount',
        () async {
          final payment = {
            'roomId': 'home',
            'fromUserId': 'bob',
            'toUserId': 'alice',
            'amount': 60,
            'status': 'pending',
            'createdAt': DateTime.utc(2026, 11, 5),
            'ledgerMonth': '2026-10',
          };
          await commit('bob', [
            versionWrite(),
            write('rooms/home/settlements/payment', payment),
          ]);
          await commit('bob', [
            versionWrite(version: 2),
            write(
              'rooms/home/settlements/payment',
              {...payment, 'status': 'confirmed'},
              timestamps: ['confirmedAt'],
            ),
          ], allowed: false);
          await commit('alice', [
            versionWrite(version: 2),
            write(
              'rooms/home/settlements/payment',
              {...payment, 'status': 'confirmed', 'amount': 600},
              timestamps: ['confirmedAt'],
            ),
          ], allowed: false);
          await commit('alice', [
            versionWrite(version: 2),
            write(
              'rooms/home/settlements/payment',
              {...payment, 'status': 'confirmed'},
              timestamps: ['confirmedAt'],
            ),
          ]);
          await commit('bob', [
            versionWrite(version: 3),
            write(
              'rooms/home/settlements/payment',
              {...payment, 'status': 'cancelled'},
              timestamps: ['cancelledAt'],
            ),
          ], allowed: false);
        },
      );

      test(
        'historical recovery is admin-only and never drops retained participants',
        () async {
          await commit('owner', [
            write('rooms/home', {
              ...room,
              'memberIds': ['alice'],
              'participantIds': ['alice'],
            }),
          ]);
          await commit('bob', [
            versionWrite(
              changes: {
                'memberIds': ['alice'],
              },
            ),
          ], allowed: false);
          await commit('alice', [
            versionWrite(
              changes: {
                'memberIds': ['alice'],
              },
            ),
          ]);
          await commit('alice', [
            versionWrite(
              version: 2,
              changes: {
                'memberIds': ['alice'],
                'participantIds': ['alice'],
              },
            ),
          ], allowed: false);
        },
      );

      test(
        'a former debtor can record a payment and the recipient can confirm it',
        () async {
          final left = {
            ...room,
            'memberIds': ['alice'],
            'ledgerVersion': 1,
          };
          await commit('bob', [write('rooms/home', left)]);
          final payment = {
            'roomId': 'home',
            'fromUserId': 'bob',
            'toUserId': 'alice',
            'amount': 60,
            'status': 'pending',
            'createdAt': DateTime.utc(2026, 11, 5),
            'ledgerMonth': '2026-10',
          };
          await commit('bob', [
            write('rooms/home', {...left, 'ledgerVersion': 2}),
            write('rooms/home/settlements/payment', payment),
          ]);
          await commit('alice', [
            write('rooms/home', {...left, 'ledgerVersion': 3}),
            write(
              'rooms/home/settlements/payment',
              {...payment, 'status': 'confirmed'},
              timestamps: ['confirmedAt'],
            ),
          ]);
        },
      );

      test(
        'a non-member cannot forge a payment or edit a room participant list',
        () async {
          await commit('outsider', [
            versionWrite(
              changes: {
                'participantIds': ['alice', 'bob', 'outsider'],
              },
            ),
          ], allowed: false);
          await commit('outsider', [
            versionWrite(),
            write('rooms/home/settlements/payment', {
              'roomId': 'home',
              'fromUserId': 'bob',
              'toUserId': 'outsider',
              'amount': 60,
              'status': 'pending',
            }),
          ], allowed: false);
        },
      );
    },
    skip: host == null
        ? 'Set ROOM_FIRESTORE_EMULATOR to a local Firestore emulator host:port.'
        : false,
  );
}
