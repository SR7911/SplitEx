import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/user_model.dart';

class UserService {
  final _usersRef = FirebaseFirestore.instance.collection('users');

  Future<void> createUserProfile(UserModel user) {
    return _usersRef.doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, uid);
  }

  Stream<UserModel?> userStream(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!, uid);
    });
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) {
    return _usersRef.doc(uid).update(data);
  }

  Future<bool> profileExists(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    return doc.exists;
  }
}
