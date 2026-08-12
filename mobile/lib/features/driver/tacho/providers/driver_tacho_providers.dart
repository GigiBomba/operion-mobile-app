import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../driver/home/driver_providers.dart';
import '../../../teams/models/tacho.dart';

/// Fetches the current driver's tacho timeline (Tier-2 feature).
///
/// `GET /api/v1/mobile/driver/tacho` → `TachoTimelineOut` (network-only — no
/// cache). 404 (no driver tacho row yet) surfaces as a provider error; the
/// screen renders the empty/error state with a retry. Owns a [CancelToken]
/// per in-flight request tied to the provider lifecycle (§1.2).
final driverTachoProvider = FutureProvider<TachoWeek>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(driverEndpointsProvider);
  final response = await endpoints.getTacho(cancelToken: cancelToken);
  final data = response.data;
  if (data is Map<String, dynamic>) {
    return TachoWeek.fromJson(data);
  }
  throw StateError('Unexpected tacho response: ${data.runtimeType}');
});
