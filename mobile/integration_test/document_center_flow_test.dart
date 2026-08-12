import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/document_endpoints.dart';
import 'package:operion_mobile/features/document_center/providers/document_center_providers.dart';

import 'test_support.dart';

/// Stub [DocumentEndpoints] returning a small company document list.
class _StubDocumentEndpoints extends DocumentEndpoints {
  _StubDocumentEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  @override
  Future<Response> searchCompanyDocuments({
    String? query,
    String? category,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': [
          {
            'id': 1,
            'title': 'CMR — Transport T-101',
            'category': 'cmr',
            'file_name': 'cmr_t101.pdf',
            'uploaded_by': 'Ion Popescu',
            'uploaded_at': DateTime.now().toIso8601String(),
          },
          {
            'id': 2,
            'title': 'Invoice INV-1001',
            'category': 'invoice',
            'file_name': 'inv_1001.pdf',
            'uploaded_by': 'Test Manager',
            'uploaded_at': DateTime.now().toIso8601String(),
          },
        ],
      },
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Document Center Flow', () {
    testWidgets(
      '1. Document center renders the documents list and tabs',
      (tester) async {
        final db = await initTestLocalDatabase();
        final overrides = managerOverrides(
          db: db,
          user: managerUser,
          extra: [
            documentEndpointsProvider
                .overrideWith((ref) => _StubDocumentEndpoints()),
          ],
        );

        await pumpApp(tester, overrides: overrides);

        // More tab → Document Center tile.
        await openMoreTab(tester);
        await tapByText(tester, 'Document Center');

        // The two tabs render.
        expect(find.text('Documents'), findsWidgets);
        expect(find.text('Automation'), findsOneWidget);

        // Stub documents render in the Documents tab (rows show the file name).
        expect(
          find.text('cmr_t101.pdf'),
          findsOneWidget,
          reason: 'The document list should render the stub CMR document.',
        );
        expect(
          find.text('inv_1001.pdf'),
          findsOneWidget,
          reason: 'The document list should render the stub invoice document.',
        );
      },
    );
  });
}
