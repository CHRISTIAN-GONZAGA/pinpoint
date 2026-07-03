import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';

/// Fire-and-forget analytics event tracking.
class AnalyticsService {
  AnalyticsService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<void> track(String eventType, {Map<String, dynamic>? metadata}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/analytics/events',
        data: {
          'event_type': eventType,
          'metadata': ?metadata,
        },
      );
    } catch (_) {}
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(dio: ref.watch(apiClientProviderOverride).dio);
});
