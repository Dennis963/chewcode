import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class OpenCodeBridgeClient {
  OpenCodeBridgeClient({
    required String baseUrl,
    String? bearerToken,
    http.Client? httpClient,
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _bearerToken = bearerToken,
       _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final String? _bearerToken;
  final http.Client _httpClient;

  void close() {
    _httpClient.close();
  }

  Future<bool> checkHealth() async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/health'),
      headers: _headers(),
    );
    return response.statusCode == 200;
  }

  Future<List<ProjectSummary>> fetchProjects() async {
    final json = await _getJson('$_baseUrl/v1/projects');
    final items = json['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ProjectSummary.fromJson)
        .toList(growable: false);
  }

  Future<ProjectDiscoveryResult> discoverProjects() async {
    final json = await _getJson('$_baseUrl/v1/projects/discover');
    return ProjectDiscoveryResult.fromJson(json);
  }

  Future<ProjectSummary> registerProject({
    required String path,
    String? name,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/v1/projects/register'),
      headers: _headers(contentType: 'application/json'),
      body: jsonEncode({
        'path': path,
        if (name != null && name.isNotEmpty) 'name': name,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to register project: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object from bridge');
    }

    return ProjectSummary.fromJson(decoded);
  }

  Future<ProjectSummary> openProject(String projectId) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/v1/projects/$projectId/open'),
      headers: _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to open project: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object from bridge');
    }

    return ProjectSummary.fromJson(decoded);
  }

  Future<ProjectSummary> closeProject(String projectId) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/v1/projects/$projectId/close'),
      headers: _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to close project: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object from bridge');
    }

    return ProjectSummary.fromJson(decoded);
  }

  Future<void> deleteProject(String projectId) async {
    final request = http.Request(
      'DELETE',
      Uri.parse('$_baseUrl/v1/projects/$projectId'),
    );
    request.headers.addAll(_headers());

    final response = await _httpClient.send(request);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete project: ${response.statusCode}');
    }
  }

  Future<void> deleteSession(String sessionId, {String? projectId}) async {
    final route = projectId == null
        ? '$_baseUrl/v1/sessions/$sessionId'
        : '$_baseUrl/v1/projects/$projectId/sessions/$sessionId';
    final request = http.Request('DELETE', Uri.parse(route));
    request.headers.addAll(_headers());

    final response = await _httpClient.send(request);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete session: ${response.statusCode}');
    }
  }

  Future<List<SessionSummary>> fetchSessions({
    String? projectId,
    String? directory,
    bool? roots,
    int? limit,
  }) async {
    final route = projectId == null
        ? '$_baseUrl/v1/sessions'
        : '$_baseUrl/v1/projects/$projectId/sessions';
    final parameters = <String, String>{
      if (directory != null && directory.trim().isNotEmpty)
        'directory': directory.trim(),
      if (roots == true) 'roots': 'true',
      if (limit != null && limit > 0) 'limit': '$limit',
    };
    final uri = Uri.parse(route).replace(
      queryParameters: parameters.isEmpty ? null : parameters,
    );
    final json = await _getJson(uri.toString());
    final items = json['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(SessionSummary.fromJson)
        .toList(growable: false);
  }

  Future<CreateSessionResult> createSession({
    String? title,
    String? prompt,
    String? projectId,
  }) async {
    final route = projectId == null
        ? '$_baseUrl/v1/sessions'
        : '$_baseUrl/v1/projects/$projectId/sessions';
    final response = await _httpClient.post(
      Uri.parse(route),
      headers: _headers(contentType: 'application/json'),
      body: jsonEncode({
        if (title != null && title.isNotEmpty) 'title': title,
        if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create session: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object from bridge');
    }

    return CreateSessionResult.fromJson(decoded);
  }

  Future<SessionView> fetchSessionView(
    String sessionId, {
    String? projectId,
  }) async {
    final route = projectId == null
        ? '$_baseUrl/v1/sessions/$sessionId/view'
        : '$_baseUrl/v1/projects/$projectId/sessions/$sessionId/view';
    final json = await _getJson(route);
    return SessionView.fromJson(json);
  }

  Future<SessionContextStatus> fetchSessionContextStatus(
    String sessionId, {
    String? projectId,
  }) async {
    final route = projectId == null
        ? '$_baseUrl/v1/sessions/$sessionId/context-status'
        : '$_baseUrl/v1/projects/$projectId/sessions/$sessionId/context-status';
    final json = await _getJson(route);
    return SessionContextStatus.fromJson(json);
  }

  Future<AttentionState> fetchAttention({String? projectId}) async {
    final route = projectId == null
        ? '$_baseUrl/v1/attention'
        : '$_baseUrl/v1/projects/$projectId/attention';
    final json = await _getJson(route);
    return AttentionState.fromJson(json);
  }

  Future<FilePreview> fetchFilePreview({
    required String sessionId,
    required String path,
    String? projectId,
  }) async {
    final encodedPath = Uri.encodeQueryComponent(path);
    final route = projectId == null
        ? '$_baseUrl/v1/sessions/$sessionId/file?path=$encodedPath'
        : '$_baseUrl/v1/projects/$projectId/sessions/$sessionId/file?path=$encodedPath';
    final json = await _getJson(route);
    return FilePreview.fromJson(json);
  }

  Uri buildDownloadUri({
    required String sessionId,
    required String path,
    String? projectId,
  }) {
    final encodedPath = Uri.encodeQueryComponent(path);
    final route = projectId == null
        ? '$_baseUrl/v1/sessions/$sessionId/download?path=$encodedPath'
        : '$_baseUrl/v1/projects/$projectId/sessions/$sessionId/download?path=$encodedPath';
    return Uri.parse(route);
  }

  String? get bearerToken => _bearerToken;

  Future<DirectoryListing> fetchDirectoryListing({
    required String sessionId,
    String? path,
    String? projectId,
  }) async {
    final query = path == null || path.trim().isEmpty
        ? ''
        : '?path=${Uri.encodeQueryComponent(path)}';
    final route = projectId == null
        ? '$_baseUrl/v1/sessions/$sessionId/files$query'
        : '$_baseUrl/v1/projects/$projectId/sessions/$sessionId/files$query';
    final json = await _getJson(route);
    return DirectoryListing.fromJson(json);
  }

  Future<FileSearchResult> searchFiles({
    required String sessionId,
    required String query,
    required String mode,
    String? projectId,
  }) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final encodedMode = Uri.encodeQueryComponent(mode);
    final route = projectId == null
        ? '$_baseUrl/v1/sessions/$sessionId/search?query=$encodedQuery&mode=$encodedMode'
        : '$_baseUrl/v1/projects/$projectId/sessions/$sessionId/search?query=$encodedQuery&mode=$encodedMode';
    final json = await _getJson(route);
    return FileSearchResult.fromJson(json);
  }

  Future<void> sendPrompt({
    required String sessionId,
    required String prompt,
    String? projectId,
  }) async {
    final route = projectId == null
        ? '$_baseUrl/v1/sessions/$sessionId/prompts'
        : '$_baseUrl/v1/projects/$projectId/sessions/$sessionId/prompts';
    final response = await _httpClient.post(
      Uri.parse(route),
      headers: _headers(contentType: 'application/json'),
      body: jsonEncode({'prompt': prompt}),
    );

    if (response.statusCode != 202) {
      throw Exception('Failed to send prompt: ${response.statusCode}');
    }
  }

  Future<void> compactSession({
    required String sessionId,
    String? projectId,
  }) async {
    final route = projectId == null
        ? '$_baseUrl/v1/sessions/$sessionId/summarize'
        : '$_baseUrl/v1/projects/$projectId/sessions/$sessionId/summarize';
    final response = await _httpClient.post(
      Uri.parse(route),
      headers: _headers(contentType: 'application/json'),
      body: jsonEncode(const <String, dynamic>{}),
    );

    if (response.statusCode != 202) {
      throw Exception('Failed to compact session: ${response.statusCode}');
    }
  }

  Future<void> replyQuestion({
    required String requestId,
    required List<List<String>> answers,
    String? projectId,
  }) async {
    final route = projectId == null
        ? '$_baseUrl/v1/questions/$requestId/reply'
        : '$_baseUrl/v1/projects/$projectId/questions/$requestId/reply';
    final response = await _httpClient.post(
      Uri.parse(route),
      headers: _headers(contentType: 'application/json'),
      body: jsonEncode({'answers': answers}),
    );

    if (response.statusCode != 202) {
      throw Exception('Failed to reply to question: ${response.statusCode}');
    }
  }

  Future<void> rejectQuestion({
    required String requestId,
    String? projectId,
  }) async {
    final route = projectId == null
        ? '$_baseUrl/v1/questions/$requestId/reject'
        : '$_baseUrl/v1/projects/$projectId/questions/$requestId/reject';
    final response = await _httpClient.post(
      Uri.parse(route),
      headers: _headers(),
    );

    if (response.statusCode != 202) {
      throw Exception('Failed to reject question: ${response.statusCode}');
    }
  }

  Future<void> replyPermission({
    required String requestId,
    required String reply,
    String? message,
    String? projectId,
  }) async {
    final route = projectId == null
        ? '$_baseUrl/v1/permissions/$requestId/reply'
        : '$_baseUrl/v1/projects/$projectId/permissions/$requestId/reply';
    final response = await _httpClient.post(
      Uri.parse(route),
      headers: _headers(contentType: 'application/json'),
      body: jsonEncode({
        'reply': reply,
        if (message != null && message.isNotEmpty) 'message': message,
      }),
    );

    if (response.statusCode != 202) {
      throw Exception('Failed to reply to permission: ${response.statusCode}');
    }
  }

  Stream<BridgeEvent> watchEvents({String? projectId}) async* {
    final route = projectId == null
        ? '$_baseUrl/v1/events'
        : '$_baseUrl/v1/projects/$projectId/events';
    final request = http.Request('GET', Uri.parse(route));
    request.headers['accept'] = 'text/event-stream';
    final authHeader = _authorizationHeader();
    if (authHeader != null) {
      request.headers['authorization'] = authHeader;
    }
    final response = await _httpClient.send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to open event stream: ${response.statusCode}');
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String? currentEvent;
    final dataLines = <String>[];

    await for (final line in lines) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          final payload = dataLines.join('\n');
          final decoded = jsonDecode(payload) as Map<String, dynamic>;
          yield BridgeEvent.fromJson(decoded);
        }
        currentEvent = null;
        dataLines.clear();
        continue;
      }

      if (line.startsWith('event:')) {
        currentEvent = line.substring('event:'.length).trim();
        continue;
      }

      if (line.startsWith('data:')) {
        dataLines.add(line.substring('data:'.length).trim());
        continue;
      }

      if (currentEvent != null) {
        dataLines.add(line);
      }
    }
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await _httpClient.get(Uri.parse(url), headers: _headers());
    if (response.statusCode != 200) {
      throw Exception('Bridge request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object from bridge');
    }
    return decoded;
  }

  Map<String, String> _headers({String? contentType}) {
    final headers = <String, String>{};
    final authHeader = _authorizationHeader();
    if (authHeader != null) {
      headers['authorization'] = authHeader;
    }
    if (contentType != null) {
      headers['content-type'] = contentType;
    }
    return headers;
  }

  String? _authorizationHeader() {
    final token = _bearerToken?.trim();
    if (token == null || token.isEmpty) {
      return null;
    }
    return 'Bearer $token';
  }
}
