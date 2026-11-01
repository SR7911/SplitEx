import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/project/dependencies.dart';
import 'package:split_ex/modules/project/data/repositories/firestore_project_repositories.dart';

List<Override> projectDependencyOverrides() => [
  projectServiceProvider.overrideWith(
    (ref) => FirestoreProjectRepository(firestore: FirebaseFirestore.instance),
  ),
  projectFirestoreExpenseRepositoryProvider.overrideWith(
    (ref) => FirestoreProjectExpenseRepository(
      firestore: FirebaseFirestore.instance,
    ),
  ),
];
