import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';
import '../features/profile/data/datasources/profile_remote_data_source.dart';
import '../features/profile/data/repositories/profile_repository_impl.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../models/app_user.dart';
import 'api_providers.dart';
import 'auth_providers.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  return ProfileRemoteDataSource(ref.watch(apiServiceProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider));
});

final currentProfileProvider = FutureProvider<AppUser>((ref) async {
  // Refetch on a change of account only, not on every session write.
  final userId = await ref.watch(
    authControllerProvider.selectAsync((session) => session?.user.id),
  );
  if (userId == null) {
    throw const AppException('You need to sign in first.');
  }
  return ref.watch(profileRepositoryProvider).getMe();
});

final publicProfileProvider = FutureProvider.family<AppUser, String>((
  ref,
  shareCode,
) {
  return ref.watch(profileRepositoryProvider).getPublicProfile(shareCode);
});
