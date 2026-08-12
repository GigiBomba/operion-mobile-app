import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/driver_providers.dart';
import '../../models/driver_trip_overview.dart';

/// Fetches the driver's current trip overview.
///
/// Owns a [CancelToken] per in-flight request tied to the provider lifecycle
/// (§1.2): navigating away disposes the provider and cancels the call — a
/// disposed provider has no listeners, so the cancellation never surfaces as
/// an error state.
final tripOverviewProvider =
    FutureProvider<DriverTripOverview>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(driverEndpointsProvider);
  final response =
      await endpoints.getTripOverview(cancelToken: cancelToken);
  final data = response.data;
  if (data is Map<String, dynamic>) {
    return DriverTripOverview.fromJson(data);
  }
  throw StateError('Unexpected response type: ${data.runtimeType}');
});
