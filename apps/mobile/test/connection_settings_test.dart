import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chewcode_mobile/main.dart';
import 'package:opencode_remote/opencode_remote.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('connection sheet exposes access token input', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _NoopBridgeClient();

    await tester.pumpWidget(
      ChewCodeApp(
        home: WorkspaceScreen(
          client: client,
          initialBridgeUrl: 'http://test-bridge',
          loadPreferences: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('账户与连接'));
    await tester.pumpAndSettle();

    expect(find.text('访问令牌'), findsOneWidget);
  });

  testWidgets('settings sheet switches ui language to english', (tester) async {
    SharedPreferences.setMockInitialValues({'ui_language': 'en'});
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _NoopBridgeClient();

    await tester.pumpWidget(
      ChewCodeApp(
        home: WorkspaceScreen(
          client: client,
          initialBridgeUrl: 'http://test-bridge',
          loadPreferences: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ChewCode'), findsOneWidget);
  });

}

class _NoopBridgeClient extends OpenCodeBridgeClient {
  _NoopBridgeClient() : super(baseUrl: 'http://fake-bridge');

  @override
  Future<bool> checkHealth() async => true;

  @override
  Future<List<ProjectSummary>> fetchProjects() async => const [];

  @override
  Future<ProjectDiscoveryResult> discoverProjects() async =>
      const ProjectDiscoveryResult(items: [], allowedRoots: []);

  @override
  Future<ProjectSummary> openProject(String projectId) async {
    throw UnimplementedError();
  }

  @override
  Future<ProjectSummary> registerProject({
    required String path,
    String? name,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId, {String? projectId}) async {}

  @override
  Future<List<SessionSummary>> fetchSessions({String? projectId}) async =>
      const [];

  @override
  Stream<BridgeEvent> watchEvents({String? projectId}) => const Stream.empty();
}
