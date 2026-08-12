import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/history/providers/history_providers.dart';
import 'package:operion_mobile/features/history/screens/route_history_screen.dart';
import 'package:operion_mobile/shared/widgets/empty_state.dart';

import '../../support/test_helpers.dart';

class _Stub extends HistoryEndpoints {
  _Stub()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> getRoutes(
    RouteHistoryFilter filter, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': [
          {
            'id': 1,
            'name': 'București–Cluj',
            'origin': 'București',
            'destination': 'Cluj',
            'total_distance_km': 450,
            'duration_min': 320,
            'created_at': '2026-07-01T08:00:00Z',
          },
        ],
        'total': 1,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      },
      statusCode: 200,
    );
  }
}

class _EmptyStub extends HistoryEndpoints {
  _EmptyStub()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> getRoutes(
    RouteHistoryFilter filter, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': <dynamic>[],
        'total': 0,
        'page': 1,
        'page_size': 20,
        'total_pages': 0,
      },
      statusCode: 200,
    );
  }
}

// ── Fake HTTP layer for the thumbnail `Image.network` ──────────────────────
//
// Standard flutter_test pattern: `debugNetworkImageHttpClientProvider` + a
// fake `HttpClient` returning PNG bytes (200) or an empty body (404) for the
// thumbnail path, so widget tests never hit the network.
//
// NOTE: `NetworkImage` in current Flutter keeps a static shared `HttpClient`
// created on first use, so `HttpOverrides.global` cannot reliably steer it
// once any earlier test has loaded a network image; the
// `debugNetworkImageHttpClientProvider` hook (which `NetworkImage._httpClient`
// consults on every load) is the supported override point.

/// Minimal valid 1×1 transparent PNG returned by the fake thumbnail server.
final List<int> _kPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _ThumbnailHttpHandler {
  _ThumbnailHttpHandler({required this.statusCode, required this.bodyBytes});

  final int statusCode;
  final List<int> bodyBytes;
  final List<Uri> requestedUris = [];
}

class _ThumbnailHttpClient implements HttpClient {
  _ThumbnailHttpClient(this._handler);

  final _ThumbnailHttpHandler _handler;

  @override
  bool autoUncompress = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    _handler.requestedUris.add(url);
    return _ThumbnailHttpClientRequest(_handler);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _ThumbnailHttpClientRequest implements HttpClientRequest {
  _ThumbnailHttpClientRequest(this._handler);

  final _ThumbnailHttpHandler _handler;

  @override
  final HttpHeaders headers = _ThumbnailHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _ThumbnailHttpClientResponse(
        _handler.statusCode,
        _handler.bodyBytes,
        _handler.statusCode == 200 ? 'OK' : 'Not Found',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _ThumbnailHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _ThumbnailHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _ThumbnailHttpClientResponse(
    this.statusCode,
    this._bodyBytes,
    this.reasonPhrase,
  );

  @override
  final int statusCode;

  @override
  final String reasonPhrase;

  final List<int> _bodyBytes;

  @override
  int get contentLength => _bodyBytes.length;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpHeaders get headers => _headers;

  final HttpHeaders _headers = _ThumbnailHttpHeaders();

  @override
  Future<Socket> detachSocket() => throw UnimplementedError();

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) =>
      throw UnimplementedError();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_bodyBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

Widget _app(HistoryEndpoints endpoints) {
  return ProviderScope(
    overrides: [
      isOfflineProvider.overrideWith((ref) => false),
      historyEndpointsProvider.overrideWithValue(endpoints),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: RouteHistoryScreen(),
    ),
  );
}

void main() {
  setUp(() {
    // Failed thumbnail loads from earlier tests (same URL is reused) must not
    // leak through the global ImageCache into later tests.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets('renders route rows with name, origin→destination, distance',
      (tester) async {
      usePhoneSurface(tester);
    await tester.pumpWidget(_app(_Stub()));
    await tester.pumpAndSettle();

    expect(find.text('București–Cluj'), findsOneWidget);
    expect(find.text('București → Cluj'), findsOneWidget);
    expect(find.text('450 km · 320 min'), findsOneWidget);
  });

  testWidgets('empty routes render EmptyState', (tester) async {
      usePhoneSurface(tester);
    await tester.pumpWidget(_app(_EmptyStub()));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No routes in this period'), findsOneWidget);
  });

  testWidgets('no duplicate/archive actions (honest omission)', (tester) async {
      usePhoneSurface(tester);
    await tester.pumpWidget(_app(_Stub()));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<dynamic>), findsNothing);
    expect(find.byIcon(Icons.content_copy), findsNothing);
    expect(find.byIcon(Icons.archive_outlined), findsNothing);
  });

  testWidgets('route row renders thumbnail when the image loads',
      (tester) async {
    usePhoneSurface(tester);
    final handler = _ThumbnailHttpHandler(
      statusCode: 200,
      bodyBytes: _kPngBytes,
    );
    debugNetworkImageHttpClientProvider =
        () => _ThumbnailHttpClient(handler);
    try {
      await tester.pumpWidget(_app(_Stub()));
      await tester.pumpAndSettle();

      // The thumbnail request hit the route's thumbnail path.
      expect(handler.requestedUris, isNotEmpty);
      expect(
        handler.requestedUris.first.path,
        '/api/v1/mobile/history/routes/1/thumbnail',
      );

      // Decoding the PNG runs on the engine (real async), outside the
      // fake-async test zone — let it finish, then pump the loaded frame in.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      // The thumbnail Image decoded the PNG, so the placeholder icon is gone.
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.route_outlined), findsNothing);
      // Route info text stays intact next to the thumbnail.
      expect(find.text('București–Cluj'), findsOneWidget);
      expect(find.text('București → Cluj'), findsOneWidget);
      expect(find.text('450 km · 320 min'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      // Must be null before the test body returns or the binding's painting
      // invariants check fails.
      debugNetworkImageHttpClientProvider = null;
    }
  });

  testWidgets('thumbnail 404 falls back to the route-icon placeholder',
      (tester) async {
    usePhoneSurface(tester);
    final handler = _ThumbnailHttpHandler(
      statusCode: 404,
      bodyBytes: const <int>[],
    );
    debugNetworkImageHttpClientProvider =
        () => _ThumbnailHttpClient(handler);
    try {
      await tester.pumpWidget(_app(_Stub()));
      await tester.pumpAndSettle();

      // errorBuilder shows the placeholder icon; no crash and no broken slot.
      expect(find.byIcon(Icons.route_outlined), findsOneWidget);
      expect(find.text('București–Cluj'), findsOneWidget);
      expect(find.text('București → Cluj'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });
}
