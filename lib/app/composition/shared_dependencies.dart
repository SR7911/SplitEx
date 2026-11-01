import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/shared/data/services/upi_service.dart';
import 'package:split_ex/shared/dependencies.dart';

List<Override> sharedDependencyOverrides() => [
  upiServiceProvider.overrideWith((ref) => UpiService()),
];
