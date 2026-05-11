import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opencode_remote/opencode_remote.dart';

void main() {
  test('adds bearer token to json GET requests', () async {
    final client = OpenCodeBridgeClient(
      baseUrl: 'http://bridge.test',
      bearerToken: 'token',
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer token');
        return http.Response(jsonEncode({'items': []}), 200);
      }),
    );

    await client.fetchSessions();
  });

  test('builds filtered session list request query', () async {
    final client = OpenCodeBridgeClient(
      baseUrl: 'http://bridge.test',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/projects/p1/sessions');
        expect(request.url.queryParameters['directory'], '/repo/demo');
        expect(request.url.queryParameters['roots'], 'true');
        expect(request.url.queryParameters['limit'], '5');
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 's1',
                'title': 'Demo',
                'directory': '/repo/demo',
                'archivedAt': '2026-04-25T00:00:00Z',
              },
            ],
          }),
          200,
        );
      }),
    );

    final sessions = await client.fetchSessions(
      projectId: 'p1',
      directory: '/repo/demo',
      roots: true,
      limit: 5,
    );

    expect(sessions.single.archivedAt, '2026-04-25T00:00:00Z');
  });

  test('builds project session view request with message limit', () async {
    final client = OpenCodeBridgeClient(
      baseUrl: 'http://bridge.test',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/projects/p1/sessions/s1/view');
        expect(request.url.queryParameters['messageLimit'], '80');
        return http.Response(
          jsonEncode({
            'session': {'id': 's1', 'title': 'Demo'},
            'messages': [
              {
                'id': 'm1',
                'role': 'assistant',
                'parts': [
                  {'type': 'text', 'text': 'hello'},
                ],
              },
            ],
            'todos': [],
          }),
          200,
        );
      }),
    );

    final view = await client.fetchSessionView(
      's1',
      projectId: 'p1',
      messageLimit: 80,
    );

    expect(view.session.id, 's1');
    expect(view.messages, hasLength(1));
  });

  test('adds bearer token to POST requests', () async {
    final client = OpenCodeBridgeClient(
      baseUrl: 'http://bridge.test',
      bearerToken: 'token',
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer token');
        return http.Response('', 202);
      }),
    );

    await client.sendPrompt(sessionId: 's1', prompt: 'continue');
  });

  test('posts compact request to summarize endpoint', () async {
    final client = OpenCodeBridgeClient(
      baseUrl: 'http://bridge.test',
      bearerToken: 'token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/sessions/s1/summarize');
        expect(request.method, 'POST');
        return http.Response('', 202);
      }),
    );

    await client.compactSession(sessionId: 's1');
  });

  test('posts project compact request to summarize endpoint', () async {
    final client = OpenCodeBridgeClient(
      baseUrl: 'http://bridge.test',
      bearerToken: 'token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/projects/p1/sessions/s1/summarize');
        expect(request.method, 'POST');
        return http.Response('', 202);
      }),
    );

    await client.compactSession(sessionId: 's1', projectId: 'p1');
  });

  test('builds file preview request path', () async {
    final client = OpenCodeBridgeClient(
      baseUrl: 'http://bridge.test',
      bearerToken: 'token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/sessions/s1/file');
        expect(request.url.queryParameters['path'], '/repo/README.md');
        return http.Response(
          jsonEncode({
            'path': '/repo/README.md',
            'displayName': 'README.md',
            'content': 'hello',
            'isText': true,
            'isBinary': false,
            'isTruncated': false,
          }),
          200,
        );
      }),
    );

    await client.fetchFilePreview(sessionId: 's1', path: '/repo/README.md');
  });

  test('builds file search request path', () async {
    final client = OpenCodeBridgeClient(
      baseUrl: 'http://bridge.test',
      bearerToken: 'token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/sessions/s1/search');
        expect(request.url.queryParameters['query'], 'token');
        expect(request.url.queryParameters['mode'], 'text');
        return http.Response(
          jsonEncode({'query': 'token', 'mode': 'text', 'items': []}),
          200,
        );
      }),
    );

    await client.searchFiles(sessionId: 's1', query: 'token', mode: 'text');
  });

  test('builds non-project download URI', () {
    final client = OpenCodeBridgeClient(baseUrl: 'http://bridge.test');

    final uri = client.buildDownloadUri(
      sessionId: 's1',
      path: '/repo/README.md',
    );

    expect(uri.path, '/v1/sessions/s1/download');
    expect(uri.queryParameters['path'], '/repo/README.md');
  });

  test('builds project-scoped download URI', () {
    final client = OpenCodeBridgeClient(baseUrl: 'http://bridge.test');

    final uri = client.buildDownloadUri(
      projectId: 'p1',
      sessionId: 's1',
      path: '/repo/README.md',
    );

    expect(uri.path, '/v1/projects/p1/sessions/s1/download');
    expect(uri.queryParameters['path'], '/repo/README.md');
  });
}
