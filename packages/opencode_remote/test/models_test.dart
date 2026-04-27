import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_remote/opencode_remote.dart';

void main() {
  test('parses session view', () {
    final view = SessionView.fromJson({
      'session': {'id': 's1', 'title': 'Demo session'},
      'messages': [
        {
          'id': 'm1',
          'role': 'assistant',
          'providerId': 'openai',
          'modelId': 'gpt-5.4',
          'usage': {
            'totalTokens': 2400,
            'inputTokens': 1600,
            'outputTokens': 600,
            'reasoningTokens': 120,
            'cacheReadTokens': 64,
            'cacheWriteTokens': 16,
            'cost': 0.42,
            'contextLimit': 8000,
            'contextUsagePercent': 30,
          },
          'parts': [
            {'type': 'text', 'display': 'inline', 'text': 'Hello'},
          ],
        },
      ],
      'todos': [
        {'id': 't1', 'content': 'Ship V1', 'status': 'in_progress'},
      ],
    });

    expect(view.session.id, 's1');
    expect(view.messages.single.parts.single, isA<TextConversationPart>());
    expect(view.messages.single.parts.single.text, 'Hello');
    expect(view.messages.single.usage?.totalTokens, 2400);
    expect(view.messages.single.usage?.contextUsagePercent, 30);
    expect(view.todos.single.content, 'Ship V1');
  });

  test('parses unknown conversation parts with fallback model', () {
    final view = SessionView.fromJson({
      'session': {'id': 's1', 'title': 'Demo session'},
      'messages': [
        {
          'id': 'm1',
          'role': 'assistant',
          'parts': [
            {
              'type': 'step-finish',
              'display': 'hidden',
              'text': 'done',
              'metadata': {'type': 'step-finish', 'text': 'done'},
            },
          ],
        },
      ],
      'todos': [],
    });

    expect(view.messages.single.parts.single, isA<UnknownConversationPart>());
    expect(view.messages.single.parts.single.type, 'step-finish');
    expect(view.messages.single.parts.single.display, 'hidden');
  });

  test('parses attention state', () {
    final state = AttentionState.fromJson({
      'questions': [
        {
          'id': 'q1',
          'header': 'Need help',
          'question': 'Choose one',
          'options': [
            {'label': 'Allow', 'description': 'Approve it'},
          ],
        },
      ],
      'permissions': [
        {
          'id': 'p1',
          'permission': 'bash',
          'patterns': ['npm test'],
        },
      ],
    });

    expect(state.questions.single.options.single.label, 'Allow');
    expect(state.permissions.single.permission, 'bash');
  });

  test('parses create session result', () {
    final result = CreateSessionResult.fromJson({
      'session': {'id': 's1', 'title': 'Create me'},
      'started': true,
      'promptError': 'upstream failed',
    });

    expect(result.session.id, 's1');
    expect(result.started, isTrue);
    expect(result.promptError, 'upstream failed');
  });

  test('parses session context status', () {
    final status = SessionContextStatus.fromJson({
      'sessionId': 's1',
      'status': 'busy',
      'messageCount': 4,
      'todoCount': 2,
      'pendingTodoCount': 1,
      'inProgressTodoCount': 1,
      'completedTodoCount': 0,
      'activeToolCount': 1,
      'compacting': true,
      'summaryAdditions': 12,
      'summaryDeletions': 3,
      'summaryFileCount': 2,
      'currentStepTitle': 'Explore codebase',
      'currentToolTitle': 'bash',
      'currentToolStatus': 'running',
      'currentSubtaskDescription': 'Search repo structure',
      'currentRetryAttempt': 2,
      'currentRetryError': 'timeout',
    });

    expect(status.sessionId, 's1');
    expect(status.activeToolCount, 1);
    expect(status.compacting, isTrue);
    expect(status.currentToolTitle, 'bash');
  });

  test('parses file preview', () {
    final preview = FilePreview.fromJson({
      'path': '/repo/README.md',
      'displayName': 'README.md',
      'content': 'hello',
      'isText': true,
      'isBinary': false,
      'isTruncated': false,
      'lineCount': 1,
      'sizeBytes': 5,
      'language': 'markdown',
    });

    expect(preview.displayName, 'README.md');
    expect(preview.isText, isTrue);
  });

  test('parses file search result', () {
    final result = FileSearchResult.fromJson({
      'query': 'token',
      'mode': 'text',
      'items': [
        {
          'path': '/repo/README.md',
          'displayName': 'README.md',
          'kind': 'text',
          'line': 8,
          'column': 3,
          'previewText': 'token docs',
        },
      ],
    });

    expect(result.items.single.kind, 'text');
    expect(result.items.single.line, 8);
  });
}
