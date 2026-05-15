import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chewcode_mobile/main.dart';
import 'package:opencode_remote/opencode_remote.dart';

void main() {
  testWidgets('renders session list from bridge client', (tester) async {
    _setSurfaceSize(tester, const Size(1400, 1200));

    final client = _FakeBridgeClient(
      projects: const [
        ProjectSummary(
          id: 'p1',
          name: 'Demo project',
          path: '/repo/demo',
          opened: true,
          runtimeState: 'running',
          lastOpenedAt: null,
          port: 4100,
        ),
      ],
      projectCandidates: const [
        ProjectCandidate(
          path: '/repo/demo',
          name: 'Demo project',
          sourceRoot: '/repo',
        ),
      ],
      sessions: const [
        SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
      ],
      sessionView: SessionView(
        session: const SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
        messages: [],
        todos: [],
      ),
      contextStatus: const SessionContextStatus(
        sessionId: 's1',
        directory: '/repo/demo',
        status: 'running',
        parentId: null,
        createdAt: null,
        updatedAt: null,
        lastActivityAt: null,
        messageCount: 0,
        todoCount: 0,
        pendingTodoCount: 0,
        inProgressTodoCount: 0,
        completedTodoCount: 0,
        activeToolCount: 0,
        compacting: false,
        summaryAdditions: null,
        summaryDeletions: null,
        summaryFileCount: null,
        currentStepTitle: null,
        currentToolTitle: null,
        currentToolStatus: null,
        currentSubtaskDescription: null,
        currentRetryAttempt: null,
        currentRetryError: null,
      ),
      attention: const AttentionState(questions: [], permissions: []),
    );
    addTearDown(client.disposeEvents);

    await tester.pumpWidget(
      ChewCodeApp(
        home: WorkspaceScreen(
          client: client,
          initialBridgeUrl: 'http://test-bridge',
          loadPreferences: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ChewCode'), findsOneWidget);
    expect(find.text('口香糖'), findsOneWidget);
    expect(find.text('Demo session'), findsWidgets);
    expect(client.fetchSessionsRequests, hasLength(1));
    expect(client.fetchSessionsRequests.single.projectId, 'p1');
    expect(client.fetchSessionsRequests.single.directory, '/repo/demo');
    expect(client.fetchSessionsRequests.single.roots, isTrue);
    expect(client.fetchSessionsRequests.single.limit, 5);
    expect(client.fetchSessionViewRequests, hasLength(1));
    expect(client.fetchSessionViewRequests.single.projectId, 'p1');
    expect(client.fetchSessionViewRequests.single.messageLimit, 80);
    expect(find.text('running'), findsWidgets);
  });

  testWidgets('opens selected session detail and shows message/task content', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(1400, 1200));

    final client = _FakeBridgeClient(
      sessions: const [
        SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
      ],
      sessionView: SessionView(
        session: const SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
        messages: [
          _conversationMessage(
            id: 'm1',
            text: 'Hello from test',
            providerId: 'openai',
            modelId: 'gpt-5.4',
            usage: _usage(
              totalTokens: 2400,
              inputTokens: 1600,
              outputTokens: 600,
              reasoningTokens: 120,
              cacheReadTokens: 64,
              cacheWriteTokens: 16,
              cost: 0.42,
              contextLimit: 8000,
              contextUsagePercent: 30,
            ),
          ),
        ],
        todos: [
          TodoItem(
            id: 't1',
            content: 'Ship stabilization',
            status: 'in_progress',
            priority: 'high',
          ),
        ],
      ),
      contextStatus: const SessionContextStatus(
        sessionId: 's1',
        directory: '/repo/demo',
        status: 'busy',
        parentId: null,
        createdAt: null,
        updatedAt: null,
        lastActivityAt: '2026-04-15T00:00:00Z',
        messageCount: 1,
        todoCount: 1,
        pendingTodoCount: 0,
        inProgressTodoCount: 1,
        completedTodoCount: 0,
        activeToolCount: 1,
        compacting: true,
        summaryAdditions: 12,
        summaryDeletions: 3,
        summaryFileCount: 2,
        currentStepTitle: 'Explore codebase',
        currentToolTitle: 'bash',
        currentToolStatus: 'running',
        currentSubtaskDescription: 'Search repo structure',
        currentRetryAttempt: 2,
        currentRetryError: 'timeout',
      ),
      attention: const AttentionState(questions: [], permissions: []),
    );
    addTearDown(client.disposeEvents);

    await tester.pumpWidget(
      ChewCodeApp(
        home: WorkspaceScreen(
          client: client,
          initialBridgeUrl: 'http://test-bridge',
          loadPreferences: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hello from test'), findsOneWidget);
    expect(find.text('状态'), findsWidgets);
    expect(find.text('Explore codebase'), findsOneWidget);
    expect(find.text('bash (running)'), findsOneWidget);
    expect(find.textContaining('1 进行中 · 0 待处理 · 0 已完成'), findsOneWidget);
    expect(find.text('2400'), findsOneWidget);
    expect(find.text('1600'), findsOneWidget);
    expect(find.text('600'), findsOneWidget);
    expect(find.text('0.42'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('工作区'), findsNothing);
    expect(find.text('执行信号'), findsNothing);
    expect(find.text('当前状态'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('composer-action-button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'mobile layout defaults to conversation view with drawer access',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      final client = _FakeBridgeClient(
        sessions: const [
          SessionSummary(
            id: 's1',
            title: 'Demo session',
            directory: '/repo/demo',
            createdAt: null,
            updatedAt: null,
            status: 'running',
            parentId: null,
          ),
        ],
        sessionView: SessionView(
          session: const SessionSummary(
            id: 's1',
            title: 'Demo session',
            directory: '/repo/demo',
            createdAt: null,
            updatedAt: null,
            status: 'running',
            parentId: null,
          ),
          messages: [
            _conversationMessage(
              id: 'm1',
              text: 'Mobile ready',
              usage: _usage(
                totalTokens: 2400,
                inputTokens: 1600,
                outputTokens: 600,
                reasoningTokens: 120,
                cacheReadTokens: 64,
                cacheWriteTokens: 16,
                cost: 0.42,
                contextLimit: 8000,
                contextUsagePercent: 30,
              ),
            ),
          ],
          todos: [
            TodoItem(
              id: 't1',
              content: 'Tune mobile shell',
              status: 'in_progress',
              priority: 'high',
            ),
            TodoItem(
              id: 't2',
              content: 'Review SSE batching',
              status: 'pending',
              priority: 'medium',
            ),
            TodoItem(
              id: 't3',
              content: 'Ship dark theme',
              status: 'completed',
              priority: 'low',
            ),
          ],
        ),
        contextStatus: const SessionContextStatus(
          sessionId: 's1',
          directory: '/repo/demo',
          status: 'running',
          parentId: null,
          createdAt: null,
          updatedAt: null,
          lastActivityAt: null,
          messageCount: 1,
          todoCount: 3,
          pendingTodoCount: 1,
          inProgressTodoCount: 1,
          completedTodoCount: 1,
          activeToolCount: 1,
          compacting: false,
          summaryAdditions: null,
          summaryDeletions: null,
          summaryFileCount: null,
          currentStepTitle: 'Tune mobile shell',
          currentToolTitle: 'flutter',
          currentToolStatus: 'running',
          currentSubtaskDescription: null,
          currentRetryAttempt: null,
          currentRetryError: null,
        ),
        attention: const AttentionState(questions: [], permissions: []),
      );
      addTearDown(client.disposeEvents);

      await tester.pumpWidget(
        ChewCodeApp(
          home: WorkspaceScreen(
            client: client,
            initialBridgeUrl: 'http://test-bridge',
            loadPreferences: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ChewCode'), findsOneWidget);
      expect(find.text('口香糖'), findsOneWidget);
      expect(find.text('Mobile ready'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('mobile-execution-status-strip')),
        findsOneWidget,
      );
      final stripSize = tester.getSize(
        find.byKey(const ValueKey<String>('mobile-execution-status-strip')),
      );
      expect(stripSize.height, 28);
      expect(
        find.byKey(const ValueKey<String>('mobile-execution-inline-detail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('mobile-execution-overlay')),
        findsNothing,
      );
      expect(
        find.text('running · Tune mobile shell · flutter (running)'),
        findsOneWidget,
      );
      expect(find.text('2400/8000 · 30%'), findsOneWidget);
      expect(find.text('等待下一步'), findsNothing);
      expect(find.text('Waiting for the next step'), findsNothing);
      expect(find.text('对话'), findsNothing);
      expect(find.text('任务'), findsNothing);
      expect(find.text('关注'), findsNothing);
      expect(find.text('工作区'), findsNothing);
      expect(find.text('执行信号'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('composer-action-button')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('composer-input')),
          matching: find.byKey(const ValueKey<String>('composer-voice-button')),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    },
  );

  testWidgets('shared composer keeps the voice button inside the input', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(1400, 1200));

    final client = _FakeBridgeClient(
      sessions: const [
        SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
      ],
      sessionView: SessionView(
        session: const SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
        messages: const [],
        todos: const [],
      ),
      contextStatus: _buildContextStatus('s1', '/repo/demo'),
      attention: const AttentionState(questions: [], permissions: []),
    );
    addTearDown(client.disposeEvents);

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

    expect(
      find.byKey(const ValueKey<String>('composer-input')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('composer-input')),
        matching: find.byKey(const ValueKey<String>('composer-voice-button')),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('composer-action-button')),
      findsOneWidget,
    );
  });

  testWidgets('mobile strip omits inline execution detail when inactive', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(430, 932));

    final client = _FakeBridgeClient(
      sessions: const [
        SessionSummary(
          id: 's1',
          title: 'Idle session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
      ],
      sessionView: SessionView(
        session: const SessionSummary(
          id: 's1',
          title: 'Idle session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
        messages: [
          _conversationMessage(
            id: 'm1',
            text: 'Idle ready',
            completedAt: '2026-04-15T00:00:01Z',
            usage: _usage(
              totalTokens: 1200,
              inputTokens: 800,
              outputTokens: 300,
              reasoningTokens: 100,
              cacheReadTokens: 0,
              cacheWriteTokens: 0,
              cost: 0.18,
              contextLimit: 8000,
              contextUsagePercent: 15,
            ),
          ),
        ],
        todos: [],
      ),
      contextStatus: const SessionContextStatus(
        sessionId: 's1',
        directory: '/repo/demo',
        status: 'running',
        parentId: null,
        createdAt: null,
        updatedAt: null,
        lastActivityAt: null,
        messageCount: 1,
        todoCount: 0,
        pendingTodoCount: 0,
        inProgressTodoCount: 0,
        completedTodoCount: 0,
        activeToolCount: 0,
        compacting: false,
        summaryAdditions: null,
        summaryDeletions: null,
        summaryFileCount: null,
        currentStepTitle: null,
        currentToolTitle: null,
        currentToolStatus: null,
        currentSubtaskDescription: null,
        currentRetryAttempt: null,
        currentRetryError: null,
      ),
      attention: const AttentionState(questions: [], permissions: []),
    );
    addTearDown(client.disposeEvents);

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

    expect(find.text('Idle ready'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mobile-execution-status-strip')),
      findsOneWidget,
    );
    expect(find.text('1200/8000 · 15%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mobile-execution-inline-detail')),
      findsNothing,
    );
    expect(find.text('等待下一步'), findsNothing);
    expect(find.text('Waiting for the next step'), findsNothing);
  });

  testWidgets(
    'mobile execution strip keeps looping while the turn stays busy',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      const session = SessionSummary(
        id: 's1',
        title: 'Busy session',
        directory: '/repo/demo',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      final busyStatus = _buildContextStatus(
        session.id,
        session.directory!,
        status: 'busy',
        activeToolCount: 1,
        currentStepTitle: 'Run command',
        currentToolTitle: 'bash',
        currentToolStatus: 'running',
      );

      final client = _FakeBridgeClient(
        sessions: const [session],
        sessionView: SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm1',
              text: 'Busy ready',
              completedAt: '2026-04-15T00:00:01Z',
            ),
          ],
          todos: const [],
        ),
        contextStatus: busyStatus,
        attention: const AttentionState(questions: [], permissions: []),
      );
      addTearDown(client.disposeEvents);

      await tester.pumpWidget(
        ChewCodeApp(
          home: WorkspaceScreen(
            client: client,
            initialBridgeUrl: 'http://test-bridge',
            loadPreferences: false,
          ),
        ),
      );
      await tester.pump();

      final pulseFinder = find.byKey(
        const ValueKey<String>('mobile-execution-status-strip-pulse'),
      );
      expect(pulseFinder, findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      final earlyDx = tester.getTopLeft(pulseFinder).dx;

      await tester.pump(const Duration(milliseconds: 1800));
      final lateDx = tester.getTopLeft(pulseFinder).dx;

      await tester.pump(const Duration(milliseconds: 300));
      final restartedDx = tester.getTopLeft(pulseFinder).dx;

      expect(lateDx, greaterThan(earlyDx));
      expect(restartedDx, lessThan(lateDx));
    },
  );

  testWidgets(
    'realtime context refresh keeps polling while the selected session stays busy',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      const session = SessionSummary(
        id: 's1',
        title: 'Busy polling session',
        directory: '/repo/demo',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      final busyStatus = _buildContextStatus(
        session.id,
        session.directory!,
        status: 'busy',
        activeToolCount: 1,
        currentStepTitle: 'Run command',
        currentToolTitle: 'bash',
        currentToolStatus: 'running',
      );
      final idleStatus = _buildContextStatus(session.id, session.directory!);

      final client = _FakeBridgeClient(
        sessions: const [session],
        sessionView: SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm1',
              text: 'Ready',
              completedAt: '2026-04-15T00:00:01Z',
            ),
          ],
          todos: const [],
        ),
        contextStatus: busyStatus,
        attention: const AttentionState(questions: [], permissions: []),
      );
      addTearDown(client.disposeEvents);

      await tester.pumpWidget(
        ChewCodeApp(
          home: WorkspaceScreen(
            client: client,
            initialBridgeUrl: 'http://test-bridge',
            loadPreferences: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(client.fetchContextStatusCalls, 1);

      client.emitEvent(
        const BridgeEvent(
          type: 'message.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:00:01Z',
          rawType: null,
          payload: {},
        ),
      );

      await tester.pump(const Duration(milliseconds: 250));
      expect(client.fetchContextStatusCalls, 2);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(client.fetchContextStatusCalls, greaterThanOrEqualTo(3));

      client.updateContextStatusForSession('s1', idleStatus);
      final callsBeforeIdle = client.fetchContextStatusCalls;

      await tester.pump(const Duration(milliseconds: 1000));
      final callsAfterIdle = client.fetchContextStatusCalls;
      expect(callsAfterIdle, greaterThan(callsBeforeIdle));

      await tester.pump(const Duration(milliseconds: 1000));
      expect(client.fetchContextStatusCalls, greaterThan(callsAfterIdle));
    },
  );

  testWidgets(
    'status strip retains usage through refresh gaps and sparse assistant updates',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      final session = const SessionSummary(
        id: 's1',
        title: 'Demo session',
        directory: '/repo/demo',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );

      final client = _FakeBridgeClient(
        sessions: [session],
        sessionView: SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm1',
              text: 'Ready',
              completedAt: '2026-04-15T00:00:01Z',
              providerId: 'openai',
              modelId: 'gpt-5.4',
              usage: _usage(
                totalTokens: 1200,
                inputTokens: 800,
                outputTokens: 300,
                reasoningTokens: 100,
                cacheReadTokens: 0,
                cacheWriteTokens: 0,
                cost: 0.18,
                contextLimit: 8000,
                contextUsagePercent: 15,
              ),
            ),
          ],
          todos: [],
        ),
        contextStatus: const SessionContextStatus(
          sessionId: 's1',
          directory: '/repo/demo',
          status: 'running',
          parentId: null,
          createdAt: null,
          updatedAt: null,
          lastActivityAt: null,
          messageCount: 1,
          todoCount: 0,
          pendingTodoCount: 0,
          inProgressTodoCount: 0,
          completedTodoCount: 0,
          activeToolCount: 0,
          compacting: false,
          summaryAdditions: null,
          summaryDeletions: null,
          summaryFileCount: null,
          currentStepTitle: null,
          currentToolTitle: null,
          currentToolStatus: null,
          currentSubtaskDescription: null,
          currentRetryAttempt: null,
          currentRetryError: null,
        ),
        attention: const AttentionState(questions: [], permissions: []),
      );
      addTearDown(client.disposeEvents);

      await tester.pumpWidget(
        ChewCodeApp(
          home: WorkspaceScreen(
            client: client,
            initialBridgeUrl: 'http://test-bridge',
            loadPreferences: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1200/8000 · 15%'), findsOneWidget);
      expect(find.text('999/8000 · 12%'), findsNothing);

      client.updateViewForSession(
        's1',
        SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm2',
              text: 'Working through the next turn',
              completedAt: null,
            ),
          ],
          todos: const [],
        ),
      );
      client.emitEvent(
        const BridgeEvent(
          type: 'message.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:00:02Z',
          rawType: null,
          payload: {},
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1200/8000 · 15%'), findsOneWidget);
      expect(find.text('2400/10000 · 15%'), findsNothing);

      client.updateViewForSession(
        's1',
        SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm3',
              text: 'Done',
              completedAt: '2026-04-15T00:00:03Z',
              usage: _usagePartial(
                totalTokens: 2400,
                inputTokens: 1600,
                outputTokens: 600,
                cost: 0.36,
                contextLimit: 10000,
              ),
            ),
          ],
          todos: const [],
        ),
      );
      client.emitEvent(
        const BridgeEvent(
          type: 'message.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:00:03Z',
          rawType: null,
          payload: {},
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1200/8000 · 15%'), findsNothing);
      expect(find.text('2400/10000 · 15%'), findsOneWidget);

      client.updateViewForSession(
        's1',
        SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm4',
              text: 'Done again',
              completedAt: '2026-04-15T00:00:04Z',
              usage: _usage(
                totalTokens: 3600,
                inputTokens: 2200,
                outputTokens: 900,
                reasoningTokens: 180,
                cacheReadTokens: 0,
                cacheWriteTokens: 0,
                cost: 0.54,
                contextLimit: 12000,
                contextUsagePercent: 30,
              ),
            ),
          ],
          todos: const [],
        ),
      );
      client.emitEvent(
        const BridgeEvent(
          type: 'message.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:00:04Z',
          rawType: null,
          payload: {},
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('2400/10000 · 15%'), findsNothing);
      expect(find.text('3600/12000 · 30%'), findsOneWidget);
    },
  );

  testWidgets(
    'session re-selection keeps cached window usage visible until the new session view arrives',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      const sessionA = SessionSummary(
        id: 's1',
        title: 'Session A',
        directory: '/repo/a',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      const sessionB = SessionSummary(
        id: 's2',
        title: 'Session B',
        directory: '/repo/a/branch-b',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );

      final client = _FakeBridgeClient(
        sessions: const [sessionA, sessionB],
        sessionView: SessionView(
          session: sessionA,
          messages: [
            _conversationMessage(
              id: 'a1',
              text: 'A ready',
              usage: _usage(
                totalTokens: 1200,
                inputTokens: 800,
                outputTokens: 300,
                reasoningTokens: 100,
                cacheReadTokens: 0,
                cacheWriteTokens: 0,
                cost: 0.18,
                contextLimit: 8000,
                contextUsagePercent: 15,
              ),
            ),
          ],
          todos: const [],
        ),
        contextStatus: _buildContextStatus(sessionA.id, sessionA.directory!),
        attention: const AttentionState(questions: [], permissions: []),
        viewsBySession: {
          's1': SessionView(
            session: sessionA,
            messages: [
              _conversationMessage(
                id: 'a1',
                text: 'A ready',
                usage: _usage(
                  totalTokens: 1200,
                  inputTokens: 800,
                  outputTokens: 300,
                  reasoningTokens: 100,
                  cacheReadTokens: 0,
                  cacheWriteTokens: 0,
                  cost: 0.18,
                  contextLimit: 8000,
                  contextUsagePercent: 15,
                ),
              ),
            ],
            todos: const [],
          ),
          's2': SessionView(
            session: sessionB,
            messages: [
              _conversationMessage(
                id: 'b1',
                text: 'B ready',
                usage: _usage(
                  totalTokens: 2200,
                  inputTokens: 1500,
                  outputTokens: 500,
                  reasoningTokens: 120,
                  cacheReadTokens: 0,
                  cacheWriteTokens: 0,
                  cost: 0.31,
                  contextLimit: 9000,
                  contextUsagePercent: 24,
                ),
              ),
            ],
            todos: const [],
          ),
        },
        contextsBySession: {
          's1': _buildContextStatus(sessionA.id, sessionA.directory!),
          's2': _buildContextStatus(sessionB.id, sessionB.directory!),
        },
      );
      addTearDown(client.disposeEvents);

      await tester.pumpWidget(
        ChewCodeApp(
          home: WorkspaceScreen(
            client: client,
            initialBridgeUrl: 'http://test-bridge',
            loadPreferences: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1200/8000 · 15%'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Session B').first);
      await tester.pumpAndSettle();

      expect(find.text('2200/9000 · 24%'), findsOneWidget);

      client.updateViewForSession(
        's1',
        SessionView(
          session: sessionA,
          messages: [
            _conversationMessage(
              id: 'a2',
              text: 'A updated',
              usage: _usage(
                totalTokens: 2600,
                inputTokens: 1700,
                outputTokens: 700,
                reasoningTokens: 160,
                cacheReadTokens: 0,
                cacheWriteTokens: 0,
                cost: 0.38,
                contextLimit: 10000,
                contextUsagePercent: 26,
              ),
            ),
          ],
          todos: const [],
        ),
      );
      client.delayNextSessionView('s1');
      client.delayNextContextStatus('s1');

      await tester.tap(find.byIcon(Icons.menu_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Session A').first);
      await tester.pump();

      expect(find.text('1200/8000 · 15%'), findsOneWidget);
      expect(find.text('2600/10000 · 26%'), findsNothing);

      client.completeDelayedSessionView('s1');
      client.completeDelayedContextStatus('s1');
      await tester.pumpAndSettle();

      expect(find.text('1200/8000 · 15%'), findsNothing);
      expect(find.text('2600/10000 · 26%'), findsOneWidget);
    },
  );

  testWidgets(
    'sending a new prompt keeps the last usage visible until assistant usage arrives',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      const session = SessionSummary(
        id: 's1',
        title: 'Prompt session',
        directory: '/repo/demo',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );

      final client = _FakeBridgeClient(
        sessions: const [session],
        sessionView: SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm1',
              text: 'Ready',
              usage: _usage(
                totalTokens: 1200,
                inputTokens: 800,
                outputTokens: 300,
                reasoningTokens: 100,
                cacheReadTokens: 0,
                cacheWriteTokens: 0,
                cost: 0.18,
                contextLimit: 8000,
                contextUsagePercent: 15,
              ),
            ),
          ],
          todos: const [],
        ),
        contextStatus: _buildContextStatus(session.id, session.directory!),
        attention: const AttentionState(questions: [], permissions: []),
      );
      addTearDown(client.disposeEvents);

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

      expect(find.text('1200/8000 · 15%'), findsOneWidget);
      expect(find.text('2400/10000 · 24%'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey<String>('composer-input')),
        'Next turn',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('composer-action-button')),
      );
      await tester.pump();

      expect(client.sendPromptCalls, 1);
      expect(client.sentPrompts, ['Next turn']);
      expect(find.text('1200/8000 · 15%'), findsOneWidget);

      client.updateViewForSession(
        's1',
        SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm2',
              role: 'user',
              text: 'Next turn',
              usage: null,
            ),
          ],
          todos: const [],
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1200/8000 · 15%'), findsOneWidget);
      expect(find.text('2400/10000 · 24%'), findsNothing);

      client.updateViewForSession(
        's1',
        SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm3',
              text: 'Done',
              usage: _usage(
                totalTokens: 2400,
                inputTokens: 1600,
                outputTokens: 600,
                reasoningTokens: 160,
                cacheReadTokens: 0,
                cacheWriteTokens: 0,
                cost: 0.36,
                contextLimit: 10000,
                contextUsagePercent: 24,
              ),
            ),
          ],
          todos: const [],
        ),
      );
      client.emitEvent(
        const BridgeEvent(
          type: 'message.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:00:03Z',
          rawType: null,
          payload: {},
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1200/8000 · 15%'), findsNothing);
      expect(find.text('2400/10000 · 24%'), findsOneWidget);
    },
  );

  testWidgets(
    'prompt polling refreshes assistant replies even when message events are missed',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));
      var now = DateTime.utc(2026, 4, 15);

      const session = SessionSummary(
        id: 's1',
        title: 'Missed event session',
        directory: '/repo/demo',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );

      final client = _FakeBridgeClient(
        sessions: const [session],
        sessionView: SessionView(
          session: session,
          messages: [_conversationMessage(id: 'm1', text: 'Ready')],
          todos: const [],
        ),
        contextStatus: _buildContextStatus(session.id, session.directory!),
        attention: const AttentionState(questions: [], permissions: []),
      );
      addTearDown(client.disposeEvents);

      await tester.pumpWidget(
        ChewCodeApp(
          home: WorkspaceScreen(
            client: client,
            initialBridgeUrl: 'http://test-bridge',
            loadPreferences: false,
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('composer-input')),
        'Explain this bug',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('composer-action-button')),
      );
      await tester.pump();

      client.updateViewForSession(
        's1',
        SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm2',
              role: 'user',
              text: 'Explain this bug',
            ),
          ],
          todos: const [],
        ),
      );

      now = now.add(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Assistant reply without event'), findsNothing);

      client.updateViewForSession(
        's1',
        SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm2',
              role: 'user',
              text: 'Explain this bug',
            ),
            _conversationMessage(
              id: 'm3',
              text: 'Assistant reply without event',
            ),
          ],
          todos: const [],
        ),
      );

      now = now.add(const Duration(milliseconds: 2600));
      await tester.pump(const Duration(milliseconds: 2600));

      expect(find.text('Assistant reply without event'), findsOneWidget);
    },
  );

  testWidgets(
    'selected message events keep polling when another client starts a turn',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));
      var now = DateTime.utc(2026, 4, 15);

      const session = SessionSummary(
        id: 's1',
        title: 'Shared phone session',
        directory: '/repo/demo',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );

      final client = _FakeBridgeClient(
        sessions: const [session],
        sessionView: SessionView(
          session: session,
          messages: [
            _conversationMessage(id: 'm1', text: 'Before remote turn'),
          ],
          todos: const [],
        ),
        contextStatus: _buildContextStatus(session.id, session.directory!),
        attention: const AttentionState(questions: [], permissions: []),
      );
      addTearDown(client.disposeEvents);

      await tester.pumpWidget(
        ChewCodeApp(
          home: WorkspaceScreen(
            client: client,
            initialBridgeUrl: 'http://test-bridge',
            loadPreferences: false,
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      client.emitEvent(
        const BridgeEvent(
          type: 'message.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:00:03Z',
          rawType: null,
          payload: {},
        ),
      );

      now = now.add(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Remote assistant reply'), findsNothing);

      client.updateViewForSession(
        's1',
        SessionView(
          session: session,
          messages: [
            _conversationMessage(id: 'm1', text: 'Before remote turn'),
            _conversationMessage(id: 'm2', text: 'Remote assistant reply'),
          ],
          todos: const [],
        ),
      );

      now = now.add(const Duration(milliseconds: 2600));
      await tester.pump(const Duration(milliseconds: 2600));

      expect(find.text('Remote assistant reply'), findsOneWidget);
    },
  );

  testWidgets(
    'active turns still allow sending another prompt before the first request finishes',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      const session = SessionSummary(
        id: 's1',
        title: 'Concurrent prompt session',
        directory: '/repo/demo',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );

      final client = _FakeBridgeClient(
        sessions: const [session],
        sessionView: SessionView(
          session: session,
          messages: [
            _conversationMessage(
              id: 'm1',
              role: 'assistant',
              text: 'Still working',
              completedAt: null,
            ),
          ],
          todos: const [],
        ),
        contextStatus: _buildContextStatus(
          session.id,
          session.directory!,
          status: 'busy',
          activeToolCount: 1,
        ),
        attention: const AttentionState(questions: [], permissions: []),
      );
      addTearDown(client.disposeEvents);
      client.delayNextSendPrompt();

      await tester.pumpWidget(
        ChewCodeApp(
          home: WorkspaceScreen(
            client: client,
            initialBridgeUrl: 'http://test-bridge',
            loadPreferences: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final inputFinder = find.byKey(const ValueKey<String>('composer-input'));
      final actionFinder = find.byKey(
        const ValueKey<String>('composer-action-button'),
      );

      await tester.enterText(inputFinder, 'First follow-up');
      await tester.tap(actionFinder);
      await tester.pump();

      expect(client.sendPromptCalls, 1);
      expect(client.sentPrompts, ['First follow-up']);

      var field = tester.widget<TextField>(inputFinder);
      expect(field.enabled, isTrue);

      await tester.enterText(inputFinder, 'Second follow-up');
      await tester.tap(actionFinder);
      await tester.pump();

      expect(client.sendPromptCalls, 2);
      expect(client.sentPrompts, ['First follow-up', 'Second follow-up']);

      field = tester.widget<TextField>(inputFinder);
      expect(field.enabled, isTrue);

      await tester.enterText(inputFinder, 'Third draft');
      await tester.pump();

      client.completeDelayedSendPrompt();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Third draft'), findsOneWidget);
    },
  );

  testWidgets(
    'transcript hides hidden parts and renders collapsed parts without raw meta dumps',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      final session = const SessionSummary(
        id: 's1',
        title: 'Transcript session',
        directory: '/repo/demo',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );

      final client = _FakeBridgeClient(
        sessions: [session],
        sessionView: SessionView(
          session: session,
          messages: [
            ConversationMessage(
              id: 'm1',
              role: 'assistant',
              createdAt: '2026-04-15T00:00:00Z',
              completedAt: '2026-04-15T00:00:01Z',
              error: null,
              providerId: null,
              modelId: null,
              usage: null,
              parts: [
                _textPart('Visible text'),
                UnknownConversationPart(
                  type: 'tool',
                  display: 'collapsed',
                  text: 'bash ls',
                  title: 'bash',
                  name: null,
                  description: null,
                  tool: 'bash',
                  path: null,
                  uri: null,
                  mimeType: null,
                  language: null,
                  callId: null,
                  status: 'running',
                  attempt: null,
                  error: null,
                  metadata: const {'type': 'tool'},
                ),
                UnknownConversationPart(
                  type: 'patch',
                  display: 'hidden',
                  text: 'diff --git',
                  title: null,
                  name: null,
                  description: null,
                  tool: null,
                  path: null,
                  uri: null,
                  mimeType: null,
                  language: null,
                  callId: null,
                  status: null,
                  attempt: null,
                  error: null,
                  metadata: const {'type': 'patch'},
                ),
                UnknownConversationPart(
                  type: 'meta',
                  display: 'hidden',
                  text: 'raw meta payload',
                  title: null,
                  name: null,
                  description: null,
                  tool: null,
                  path: null,
                  uri: null,
                  mimeType: null,
                  language: null,
                  callId: null,
                  status: null,
                  attempt: null,
                  error: null,
                  metadata: const {'type': 'meta'},
                ),
              ],
            ),
          ],
          todos: const [],
        ),
        contextStatus: _buildContextStatus(session.id, '/repo/demo'),
        attention: const AttentionState(questions: [], permissions: []),
      );
      addTearDown(client.disposeEvents);

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

      expect(find.text('Visible text'), findsOneWidget);
      expect(find.text('reasoning'), findsNothing);
      expect(find.text('bash'), findsWidgets);
      expect(find.text('bash ls'), findsOneWidget);
      expect(find.text('diff --git'), findsNothing);
      expect(find.text('raw meta payload'), findsNothing);
    },
  );

  testWidgets('pressing Enter keeps newline content and does not submit', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(430, 932));

    final client = _FakeBridgeClient(
      sessions: const [
        SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
      ],
      sessionView: SessionView(
        session: const SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
        messages: const [],
        todos: const [],
      ),
      contextStatus: _buildContextStatus('s1', '/repo/demo'),
      attention: const AttentionState(questions: [], permissions: []),
    );
    addTearDown(client.disposeEvents);

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

    final inputFinder = find.byKey(const ValueKey<String>('composer-input'));
    await tester.tap(inputFinder);
    await tester.pump();
    await tester.enterText(inputFinder, 'Line 1');

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Line 1\n',
        selection: TextSelection.collapsed(offset: 7),
      ),
    );
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();

    expect(client.sendPromptCalls, 0);
    final field = tester.widget<TextField>(inputFinder);
    expect(field.controller?.text, 'Line 1\n');
  });

  testWidgets('typed /compact uses summarize flow instead of prompt send', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(430, 932));

    final client = _FakeBridgeClient(
      sessions: const [
        SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
      ],
      sessionView: SessionView(
        session: const SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
        messages: [],
        todos: [],
      ),
      contextStatus: const SessionContextStatus(
        sessionId: 's1',
        directory: '/repo/demo',
        status: 'running',
        parentId: null,
        createdAt: null,
        updatedAt: null,
        lastActivityAt: null,
        messageCount: 0,
        todoCount: 0,
        pendingTodoCount: 0,
        inProgressTodoCount: 0,
        completedTodoCount: 0,
        activeToolCount: 0,
        compacting: false,
        summaryAdditions: null,
        summaryDeletions: null,
        summaryFileCount: null,
        currentStepTitle: null,
        currentToolTitle: null,
        currentToolStatus: null,
        currentSubtaskDescription: null,
        currentRetryAttempt: null,
        currentRetryError: null,
      ),
      attention: const AttentionState(questions: [], permissions: []),
    );
    addTearDown(client.disposeEvents);

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

    await tester.enterText(
      find.byKey(const ValueKey<String>('composer-input')),
      '/compact',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('composer-action-button')),
    );
    await tester.pumpAndSettle();

    expect(client.compactSessionCalls, 1);
    expect(client.sendPromptCalls, 0);
    expect(find.text('/compact'), findsNothing);
  });

  testWidgets('busy sessions still render the send-only composer action', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(430, 932));

    final client = _FakeBridgeClient(
      sessions: const [
        SessionSummary(
          id: 's1',
          title: 'Busy session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
      ],
      sessionView: SessionView(
        session: const SessionSummary(
          id: 's1',
          title: 'Busy session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
        messages: [
          _conversationMessage(
            id: 'm1',
            role: 'assistant',
            text: 'Working through the turn',
            completedAt: null,
          ),
        ],
        todos: const [],
      ),
      contextStatus: _buildContextStatus(
        's1',
        '/repo/demo',
        status: 'busy',
        activeToolCount: 1,
      ),
      attention: const AttentionState(questions: [], permissions: []),
    );
    addTearDown(client.disposeEvents);

    await tester.pumpWidget(
      ChewCodeApp(
        home: WorkspaceScreen(
          client: client,
          initialBridgeUrl: 'http://test-bridge',
          loadPreferences: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('composer-action-stop-icon')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('composer-action-send-icon')),
      findsOneWidget,
    );
  });

  testWidgets(
    'mobile drawer shows only visible root sessions and loads five at a time',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      const root1 = SessionSummary(
        id: 's1',
        title: 'Root session 1',
        directory: '/workspaces/demo/app',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      const root2 = SessionSummary(
        id: 's2',
        title: 'Root session 2',
        directory: '/workspaces/demo/app/feature-a',
        createdAt: null,
        updatedAt: null,
        status: 'idle',
        parentId: null,
      );
      const child = SessionSummary(
        id: 's-child',
        title: 'Hidden child session',
        directory: '/workspaces/demo/app',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: 's1',
      );
      const root3 = SessionSummary(
        id: 's3',
        title: 'Root session 3',
        directory: '/workspaces/demo/app/feature-b',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      const archived = SessionSummary(
        id: 's-archived',
        title: 'Archived session',
        directory: '/workspaces/demo/app',
        createdAt: null,
        updatedAt: null,
        archivedAt: '2026-04-01T00:00:00Z',
        status: 'completed',
        parentId: null,
      );
      const root4 = SessionSummary(
        id: 's4',
        title: 'Root session 4',
        directory: '/workspaces/demo/app/feature-c',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      const root5 = SessionSummary(
        id: 's5',
        title: 'Root session 5',
        directory: '/workspaces/demo/app/feature-d',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      const root6 = SessionSummary(
        id: 's6',
        title: 'Root session 6',
        directory: '/workspaces/demo/app/packages/runner',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      const outsideWorkspace = SessionSummary(
        id: 's-outside',
        title: 'Outside workspace session',
        directory: '/workspaces/other/app',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      const betaSession = SessionSummary(
        id: 's-beta',
        title: 'Beta session',
        directory: '/workspaces/beta/app',
        createdAt: null,
        updatedAt: null,
        status: 'idle',
        parentId: null,
      );

      final client = _FakeBridgeClient(
        projects: const [
          ProjectSummary(
            id: 'p1',
            name: 'Demo project',
            path: '/workspaces/demo/app',
            opened: true,
            runtimeState: 'running',
            lastOpenedAt: null,
            port: 4100,
          ),
          ProjectSummary(
            id: 'p2',
            name: 'Beta project',
            path: '/workspaces/beta/app',
            opened: true,
            runtimeState: 'idle',
            lastOpenedAt: null,
            port: 4101,
          ),
        ],
        sessions: const [root1],
        sessionsByProject: const {
          'p1': [
            root1,
            root2,
            child,
            root3,
            archived,
            root4,
            root5,
            root6,
            outsideWorkspace,
          ],
          'p2': [betaSession],
        },
        sessionView: _buildSessionView(root1, 'Root ready'),
        contextStatus: _buildContextStatus(root1.id, root1.directory!),
        attention: const AttentionState(questions: [], permissions: []),
        viewsBySession: {
          's1': _buildSessionView(root1, 'Root ready'),
          's-beta': _buildSessionView(betaSession, 'Beta ready'),
        },
        contextsBySession: {
          's1': _buildContextStatus(root1.id, root1.directory!),
          's-beta': _buildContextStatus(betaSession.id, betaSession.directory!),
        },
      );
      addTearDown(client.disposeEvents);

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

      expect(client.fetchSessionsRequests.first.projectId, 'p1');
      expect(
        client.fetchSessionsRequests.first.directory,
        '/workspaces/demo/app',
      );
      expect(client.fetchSessionsRequests.first.roots, isTrue);
      expect(client.fetchSessionsRequests.first.limit, 5);
      expect(client.fetchSessionsRequests.last.limit, greaterThanOrEqualTo(10));

      await tester.tap(find.byIcon(Icons.menu_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Demo project'), findsWidgets);
      expect(find.text('Root session 1'), findsWidgets);
      expect(find.text('Root session 2'), findsWidgets);
      expect(find.text('Root session 3'), findsWidgets);
      expect(find.text('Root session 4'), findsWidgets);
      expect(find.text('Root session 5'), findsWidgets);
      expect(find.text('Root session 6'), findsNothing);
      expect(find.text('Hidden child session'), findsNothing);
      expect(find.text('Archived session'), findsNothing);
      expect(find.text('Outside workspace session'), findsNothing);
      expect(find.text('/workspaces/demo/app/packages/runner'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('session-drawer-load-more')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('session-drawer-load-more')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Root session 6'), findsWidgets);
      expect(find.text('packages/runner'), findsOneWidget);

      await tester.tap(find.text('Beta project').first);
      await tester.pumpAndSettle();

      expect(find.text('Beta session'), findsWidgets);
      expect(find.text('Root session 1'), findsNothing);
    },
  );

  testWidgets('wide session pane uses the same filtering and load-more rules', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(1400, 1200));

    const root1 = SessionSummary(
      id: 's1',
      title: 'Pane session 1',
      directory: '/workspaces/demo/app',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: null,
    );
    const root2 = SessionSummary(
      id: 's2',
      title: 'Pane session 2',
      directory: '/workspaces/demo/app/one',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: null,
    );
    const child = SessionSummary(
      id: 's-child',
      title: 'Pane child session',
      directory: '/workspaces/demo/app',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: 's1',
    );
    const root3 = SessionSummary(
      id: 's3',
      title: 'Pane session 3',
      directory: '/workspaces/demo/app/two',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: null,
    );
    const archived = SessionSummary(
      id: 's-archived',
      title: 'Pane archived session',
      directory: '/workspaces/demo/app',
      createdAt: null,
      updatedAt: null,
      archivedAt: '2026-04-01T00:00:00Z',
      status: 'completed',
      parentId: null,
    );
    const root4 = SessionSummary(
      id: 's4',
      title: 'Pane session 4',
      directory: '/workspaces/demo/app/three',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: null,
    );
    const root5 = SessionSummary(
      id: 's5',
      title: 'Pane session 5',
      directory: '/workspaces/demo/app/four',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: null,
    );
    const root6 = SessionSummary(
      id: 's6',
      title: 'Pane session 6',
      directory: '/workspaces/demo/app/packages/runner',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: null,
    );

    final client = _FakeBridgeClient(
      projects: const [
        ProjectSummary(
          id: 'p1',
          name: 'Demo project',
          path: '/workspaces/demo/app',
          opened: true,
          runtimeState: 'running',
          lastOpenedAt: null,
          port: 4100,
        ),
      ],
      sessions: const [root1],
      sessionsByProject: const {
        'p1': [root1, root2, child, root3, archived, root4, root5, root6],
      },
      sessionView: _buildSessionView(root1, 'Pane ready'),
      contextStatus: _buildContextStatus(root1.id, root1.directory!),
      attention: const AttentionState(questions: [], permissions: []),
    );
    addTearDown(client.disposeEvents);

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

    expect(find.text('Pane session 1'), findsWidgets);
    expect(find.text('Pane session 2'), findsOneWidget);
    expect(find.text('Pane session 3'), findsOneWidget);
    expect(find.text('Pane session 4'), findsOneWidget);
    expect(find.text('Pane session 5'), findsOneWidget);
    expect(find.text('Pane session 6'), findsNothing);
    expect(find.text('Pane child session'), findsNothing);
    expect(find.text('Pane archived session'), findsNothing);
    expect(find.text('/workspaces/demo/app/packages/runner'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('wide-session-pane-load-more')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('wide-session-pane-load-more')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pane session 6'), findsOneWidget);
    expect(find.text('packages/runner'), findsOneWidget);
  });

  testWidgets('mobile drawer deletes a session from the nested project list', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(430, 932));

    const session = SessionSummary(
      id: 's1',
      title: 'Delete me',
      directory: '/repo/demo',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: null,
    );

    final client = _FakeBridgeClient(
      projects: const [
        ProjectSummary(
          id: 'p1',
          name: 'Demo project',
          path: '/repo/demo',
          opened: true,
          runtimeState: 'running',
          lastOpenedAt: null,
          port: 4100,
        ),
      ],
      sessions: const [session],
      sessionsByProject: const {
        'p1': [session],
      },
      sessionView: _buildSessionView(session, 'Ready'),
      contextStatus: _buildContextStatus(session.id, session.directory!),
      attention: const AttentionState(questions: [], permissions: []),
    );
    addTearDown(client.disposeEvents);

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

    expect(find.text('Delete me'), findsWidgets);

    await tester.tap(find.byTooltip('删除会话').first);
    await tester.pumpAndSettle();

    expect(find.text('删除会话？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('Delete me'), findsNothing);
  });

  testWidgets('mobile right drawer files panel follows list to preview flow', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(430, 932));

    final client = _FakeBridgeClient(
      sessions: const [
        SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
      ],
      sessionView: SessionView(
        session: const SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
        messages: [],
        todos: [],
      ),
      contextStatus: const SessionContextStatus(
        sessionId: 's1',
        directory: '/repo/demo',
        status: 'running',
        parentId: null,
        createdAt: null,
        updatedAt: null,
        lastActivityAt: null,
        messageCount: 0,
        todoCount: 0,
        pendingTodoCount: 0,
        inProgressTodoCount: 0,
        completedTodoCount: 0,
        activeToolCount: 0,
        compacting: false,
        summaryAdditions: null,
        summaryDeletions: null,
        summaryFileCount: null,
        currentStepTitle: null,
        currentToolTitle: null,
        currentToolStatus: null,
        currentSubtaskDescription: null,
        currentRetryAttempt: null,
        currentRetryError: null,
      ),
      attention: const AttentionState(questions: [], permissions: []),
      directoryListing: const DirectoryListing(
        rootPath: '/repo/demo',
        currentPath: '/repo/demo',
        parentPath: null,
        items: [
          DirectoryEntry(
            path: '/repo/demo/lib',
            displayName: 'lib',
            kind: 'directory',
            sizeBytes: null,
          ),
          DirectoryEntry(
            path: '/repo/demo/README.md',
            displayName: 'README.md',
            kind: 'file',
            sizeBytes: 20,
          ),
        ],
      ),
      directoryListingsByPath: const {
        '/repo/demo/lib': DirectoryListing(
          rootPath: '/repo/demo',
          currentPath: '/repo/demo/lib',
          parentPath: '/repo/demo',
          items: [
            DirectoryEntry(
              path: '/repo/demo/lib/main.dart',
              displayName: 'main.dart',
              kind: 'file',
              sizeBytes: 96,
            ),
          ],
        ),
      },
      filePreviewsByPath: const {
        '/repo/demo/lib/main.dart': FilePreview(
          path: '/repo/demo/lib/main.dart',
          displayName: 'main.dart',
          content: 'line 1\nline 2\nline 3',
          isText: true,
          isBinary: false,
          isTruncated: false,
          lineCount: 3,
          sizeBytes: 24,
          language: 'dart',
        ),
      },
    );
    addTearDown(client.disposeEvents);

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

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.folder_open_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('先整理文件列表，再打开预览'), findsOneWidget);
    expect(find.text('搜索文件'), findsOneWidget);
    expect(find.text('浏览文件夹'), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.folder_copy_outlined).first);
    await tester.tap(find.byIcon(Icons.folder_copy_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('浏览当前会话文件'), findsWidgets);
    await tester.tap(find.text('lib').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('main.dart').first);
    await tester.pumpAndSettle();

    expect(find.text('返回列表'), findsOneWidget);
    expect(find.text('回到目录浏览'), findsOneWidget);
    expect(find.text('从文件名匹配打开'), findsOneWidget);

    await tester.ensureVisible(find.text('回到目录浏览'));
    await tester.tap(find.text('回到目录浏览'));
    await tester.pumpAndSettle();

    expect(find.text('浏览当前会话文件'), findsWidgets);
    expect(find.text('/repo/demo/lib'), findsOneWidget);
  });

  testWidgets('binary file preview still shows download action', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(430, 932));

    final client = _FakeBridgeClient(
      sessions: const [
        SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
      ],
      sessionView: SessionView(
        session: const SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
        messages: [],
        todos: [],
      ),
      contextStatus: const SessionContextStatus(
        sessionId: 's1',
        directory: '/repo/demo',
        status: 'running',
        parentId: null,
        createdAt: null,
        updatedAt: null,
        lastActivityAt: null,
        messageCount: 0,
        todoCount: 0,
        pendingTodoCount: 0,
        inProgressTodoCount: 0,
        completedTodoCount: 0,
        activeToolCount: 0,
        compacting: false,
        summaryAdditions: null,
        summaryDeletions: null,
        summaryFileCount: null,
        currentStepTitle: null,
        currentToolTitle: null,
        currentToolStatus: null,
        currentSubtaskDescription: null,
        currentRetryAttempt: null,
        currentRetryError: null,
      ),
      attention: const AttentionState(questions: [], permissions: []),
      directoryListing: const DirectoryListing(
        rootPath: '/repo/demo',
        currentPath: '/repo/demo',
        parentPath: null,
        items: [
          DirectoryEntry(
            path: '/repo/demo/app-release.apk',
            displayName: 'app-release.apk',
            kind: 'file',
            sizeBytes: 24157409,
          ),
        ],
      ),
      filePreviewsByPath: const {
        '/repo/demo/app-release.apk': FilePreview(
          path: '/repo/demo/app-release.apk',
          displayName: 'app-release.apk',
          content: '',
          isText: false,
          isBinary: true,
          isTruncated: false,
          lineCount: null,
          sizeBytes: 24157409,
          language: 'apk',
        ),
      },
    );
    addTearDown(client.disposeEvents);

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

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.folder_open_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.folder_copy_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('app-release.apk').first);
    await tester.pumpAndSettle();

    expect(find.text('这个壳层暂不支持二进制文件预览。'), findsOneWidget);
    expect(find.byTooltip('下载文件'), findsWidgets);
  });

  testWidgets(
    'opens the selected session at the latest message without forcing scroll after manual upward scroll',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      final session = const SessionSummary(
        id: 's1',
        title: 'Demo session',
        directory: '/repo/demo',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      final initialMessages = List<ConversationMessage>.generate(
        30,
        (index) => _conversationMessage(
          id: 'm$index',
          text: 'Message ${index + 1}',
          createdAt: '2026-04-15T00:00:${index.toString().padLeft(2, '0')}Z',
        ),
      );
      final updatedMessages = List<ConversationMessage>.from(initialMessages)
        ..add(
          _conversationMessage(
            id: 'm30',
            text: 'Message 31',
            createdAt: '2026-04-15T00:00:30Z',
          ),
        );

      final client = _FakeBridgeClient(
        sessions: [session],
        sessionView: SessionView(
          session: session,
          messages: initialMessages,
          todos: const [],
        ),
        contextStatus: _buildContextStatus(session.id, '/repo/demo'),
        attention: const AttentionState(questions: [], permissions: []),
      );
      addTearDown(client.disposeEvents);

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

      final messageListFinder = find.byKey(
        const PageStorageKey<String>('s1-messages'),
      );
      final initialController = tester
          .widget<ListView>(messageListFinder)
          .controller!;

      expect(initialController.offset, 0);
      expect(find.text('Message 30'), findsOneWidget);

      await tester.drag(messageListFinder, const Offset(0, 400));
      await tester.pumpAndSettle();

      final scrolledController = tester
          .widget<ListView>(messageListFinder)
          .controller!;
      expect(
        scrolledController.offset,
        lessThan(scrolledController.position.maxScrollExtent),
      );

      client.updateViewForSession(
        's1',
        SessionView(
          session: session,
          messages: updatedMessages,
          todos: const [],
        ),
      );
      client.emitEvent(
        const BridgeEvent(
          type: 'message.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:01:00Z',
          rawType: null,
          payload: {},
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final updatedController = tester
          .widget<ListView>(messageListFinder)
          .controller!;
      expect(updatedController.offset, greaterThan(0));
      expect(find.text('Message 31'), findsNothing);
    },
  );

  testWidgets('file workflow browses live directories and opens previews', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(1400, 1200));

    final client = _FakeBridgeClient(
      sessions: const [
        SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
      ],
      sessionView: SessionView(
        session: const SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
        messages: [],
        todos: [],
      ),
      contextStatus: const SessionContextStatus(
        sessionId: 's1',
        directory: '/repo/demo',
        status: 'running',
        parentId: null,
        createdAt: null,
        updatedAt: null,
        lastActivityAt: null,
        messageCount: 0,
        todoCount: 0,
        pendingTodoCount: 0,
        inProgressTodoCount: 0,
        completedTodoCount: 0,
        activeToolCount: 0,
        compacting: false,
        summaryAdditions: null,
        summaryDeletions: null,
        summaryFileCount: null,
        currentStepTitle: null,
        currentToolTitle: null,
        currentToolStatus: null,
        currentSubtaskDescription: null,
        currentRetryAttempt: null,
        currentRetryError: null,
      ),
      attention: const AttentionState(questions: [], permissions: []),
      directoryListing: const DirectoryListing(
        rootPath: '/repo/demo',
        currentPath: '/repo/demo',
        parentPath: null,
        items: [
          DirectoryEntry(
            path: '/repo/demo/lib',
            displayName: 'lib',
            kind: 'directory',
            sizeBytes: null,
          ),
          DirectoryEntry(
            path: '/repo/demo/README.md',
            displayName: 'README.md',
            kind: 'file',
            sizeBytes: 20,
          ),
        ],
      ),
      directoryListingsByPath: const {
        '/repo/demo/lib': DirectoryListing(
          rootPath: '/repo/demo',
          currentPath: '/repo/demo/lib',
          parentPath: '/repo/demo',
          items: [
            DirectoryEntry(
              path: '/repo/demo/lib/main.dart',
              displayName: 'main.dart',
              kind: 'file',
              sizeBytes: 96,
            ),
            DirectoryEntry(
              path: '/repo/demo/lib/widgets',
              displayName: 'widgets',
              kind: 'directory',
              sizeBytes: null,
            ),
          ],
        ),
      },
      fileSearchResult: const FileSearchResult(
        query: 'main',
        mode: 'name',
        items: [
          FileSearchHit(
            path: '/repo/demo/lib/main.dart',
            displayName: 'main.dart',
            kind: 'name',
            line: null,
            column: null,
            previewText: null,
          ),
        ],
      ),
      filePreviewsByPath: const {
        '/repo/demo/lib/main.dart': FilePreview(
          path: '/repo/demo/lib/main.dart',
          displayName: 'main.dart',
          content:
              'line 1\nline 2\nline 3\nline 4\nline 5\nline 6\nline 7\nconst token = bridgeToken;\nline 9\nline 10',
          isText: true,
          isBinary: false,
          isTruncated: false,
          lineCount: 10,
          sizeBytes: 96,
          language: 'dart',
        ),
      },
    );
    addTearDown(client.disposeEvents);

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

    await tester.tap(find.byIcon(Icons.folder_copy_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('浏览当前会话文件'), findsWidgets);
    expect(find.text('lib'), findsWidgets);
    expect(find.text('README.md'), findsWidgets);

    await tester.tap(find.text('lib').first);
    await tester.pumpAndSettle();

    expect(find.text('/repo/demo/lib'), findsOneWidget);
    expect(find.text('main.dart'), findsWidgets);
    expect(find.text('widgets'), findsWidgets);

    await tester.tap(find.text('main.dart').first);
    await tester.pumpAndSettle();

    expect(find.text('从文件名匹配打开'), findsOneWidget);
    expect(find.byIcon(Icons.folder_copy_outlined), findsWidgets);
    expect(find.text('main.dart'), findsWidgets);
  });

  testWidgets('coalesces rapid bridge events into one refresh cycle', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(430, 932));

    final client = _FakeBridgeClient(
      sessions: const [
        SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
      ],
      sessionView: SessionView(
        session: const SessionSummary(
          id: 's1',
          title: 'Demo session',
          directory: '/repo/demo',
          createdAt: null,
          updatedAt: null,
          status: 'running',
          parentId: null,
        ),
        messages: [_conversationMessage(id: 'm1', text: 'Watching events')],
        todos: [
          TodoItem(
            id: 't1',
            content: 'Batch refreshes',
            status: 'in_progress',
            priority: 'high',
          ),
        ],
      ),
      contextStatus: const SessionContextStatus(
        sessionId: 's1',
        directory: '/repo/demo',
        status: 'running',
        parentId: null,
        createdAt: null,
        updatedAt: null,
        lastActivityAt: null,
        messageCount: 1,
        todoCount: 1,
        pendingTodoCount: 0,
        inProgressTodoCount: 1,
        completedTodoCount: 0,
        activeToolCount: 1,
        compacting: false,
        summaryAdditions: null,
        summaryDeletions: null,
        summaryFileCount: null,
        currentStepTitle: null,
        currentToolTitle: 'watchEvents',
        currentToolStatus: 'running',
        currentSubtaskDescription: null,
        currentRetryAttempt: null,
        currentRetryError: null,
      ),
      attention: const AttentionState(questions: [], permissions: []),
    );
    addTearDown(client.disposeEvents);

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

    expect(client.fetchSessionsCalls, 1);
    expect(client.fetchSessionViewCalls, 1);
    expect(client.fetchContextStatusCalls, 1);
    expect(client.fetchAttentionCalls, 1);

    client.emitEvent(
      const BridgeEvent(
        type: 'message.updated',
        sessionId: 's1',
        timestamp: '2026-04-15T00:00:01Z',
        rawType: null,
        payload: {},
      ),
    );
    client.emitEvent(
      const BridgeEvent(
        type: 'todo.updated',
        sessionId: 's1',
        timestamp: '2026-04-15T00:00:02Z',
        rawType: null,
        payload: {},
      ),
    );
    client.emitEvent(
      const BridgeEvent(
        type: 'message.updated',
        sessionId: 's1',
        timestamp: '2026-04-15T00:00:03Z',
        rawType: null,
        payload: {},
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(client.fetchSessionViewCalls, 1);

    await tester.pump(const Duration(milliseconds: 300));

    expect(client.fetchSessionsCalls, 1);
    expect(client.fetchSessionViewCalls, 2);
    expect(client.fetchContextStatusCalls, 2);
    expect(client.fetchAttentionCalls, 1);
  });

  testWidgets(
    'ignores stale selected-session results after switching sessions',
    (tester) async {
      _setSurfaceSize(tester, const Size(1400, 1200));

      final sessionA = const SessionSummary(
        id: 's1',
        title: 'Session A',
        directory: '/repo/a',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      final sessionB = const SessionSummary(
        id: 's2',
        title: 'Session B',
        directory: '/repo/a/branch-b',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );

      final client = _FakeBridgeClient(
        sessions: [sessionA, sessionB],
        sessionView: _buildSessionView(sessionA, 'A ready'),
        contextStatus: _buildContextStatus(sessionA.id, '/repo/a'),
        attention: const AttentionState(questions: [], permissions: []),
        viewsBySession: {
          's1': _buildSessionView(sessionA, 'A stale update'),
          's2': _buildSessionView(sessionB, 'B active view'),
        },
        contextsBySession: {
          's1': _buildContextStatus(sessionA.id, '/repo/a'),
          's2': _buildContextStatus(sessionB.id, sessionB.directory!),
        },
      );
      addTearDown(client.disposeEvents);

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

      client.delayNextSessionView('s1');
      client.delayNextContextStatus('s1');
      client.emitEvent(
        const BridgeEvent(
          type: 'message.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:00:01Z',
          rawType: null,
          payload: {},
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Session B').first);
      await tester.pumpAndSettle();

      client.completeDelayedSessionView('s1');
      client.completeDelayedContextStatus('s1');
      await tester.pumpAndSettle();

      expect(find.text('B active view'), findsOneWidget);
      expect(find.text('A stale update'), findsNothing);
    },
  );

  testWidgets(
    'keeps same session ids isolated across projects while loads are in flight',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      const alphaSession = SessionSummary(
        id: 's1',
        title: 'Alpha session',
        directory: '/repo/alpha',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );
      const betaSession = SessionSummary(
        id: 's1',
        title: 'Beta session',
        directory: '/repo/beta',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );

      final client = _FakeBridgeClient(
        projects: const [
          ProjectSummary(
            id: 'p1',
            name: 'Alpha project',
            path: '/repo/alpha',
            opened: true,
            runtimeState: 'running',
            lastOpenedAt: null,
            port: 4100,
          ),
          ProjectSummary(
            id: 'p2',
            name: 'Beta project',
            path: '/repo/beta',
            opened: true,
            runtimeState: 'running',
            lastOpenedAt: null,
            port: 4101,
          ),
        ],
        sessions: const [alphaSession],
        sessionsByProject: const {
          'p1': [alphaSession],
          'p2': [betaSession],
        },
        sessionView: _buildSessionView(alphaSession, 'Alpha ready'),
        contextStatus: _buildContextStatus(
          alphaSession.id,
          alphaSession.directory!,
        ),
        attention: const AttentionState(questions: [], permissions: []),
        viewsBySession: {
          _scopedSessionKey('s1', projectId: 'p1'): _buildSessionView(
            alphaSession,
            'Alpha stale view',
          ),
          _scopedSessionKey('s1', projectId: 'p2'): _buildSessionView(
            betaSession,
            'Beta active view',
          ),
        },
        contextsBySession: {
          _scopedSessionKey('s1', projectId: 'p1'): _buildContextStatus(
            alphaSession.id,
            alphaSession.directory!,
          ),
          _scopedSessionKey('s1', projectId: 'p2'): _buildContextStatus(
            betaSession.id,
            betaSession.directory!,
          ),
        },
      );
      addTearDown(client.disposeEvents);

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

      client.delayNextSessionView('s1', projectId: 'p1');
      client.delayNextContextStatus('s1', projectId: 'p1');
      client.emitEvent(
        const BridgeEvent(
          type: 'message.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:00:01Z',
          rawType: null,
          payload: {},
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.menu_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta project').first);
      await tester.pump();

      client.completeDelayedSessionView('s1', projectId: 'p1');
      client.completeDelayedContextStatus('s1', projectId: 'p1');
      await tester.pumpAndSettle();

      expect(find.text('Beta active view'), findsOneWidget);
      expect(find.text('Alpha stale view'), findsNothing);
    },
  );

  testWidgets('ignores stale attention after switching projects', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(430, 932));

    const alphaSession = SessionSummary(
      id: 's1',
      title: 'Alpha session',
      directory: '/repo/alpha',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: null,
    );
    const betaSession = SessionSummary(
      id: 's2',
      title: 'Beta session',
      directory: '/repo/beta',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: null,
    );

    final alphaAttention = AttentionState(
      questions: const [
        PendingQuestion(
          id: 'q1',
          sessionId: 's1',
          header: 'Alpha approval',
          question: 'Use alpha session?',
          options: [QuestionOption(label: 'Yes', description: null)],
          multiple: false,
        ),
      ],
      permissions: const [],
    );

    final client = _FakeBridgeClient(
      projects: const [
        ProjectSummary(
          id: 'p1',
          name: 'Alpha project',
          path: '/repo/alpha',
          opened: true,
          runtimeState: 'running',
          lastOpenedAt: null,
          port: 4100,
        ),
        ProjectSummary(
          id: 'p2',
          name: 'Beta project',
          path: '/repo/beta',
          opened: true,
          runtimeState: 'running',
          lastOpenedAt: null,
          port: 4101,
        ),
      ],
      sessions: const [alphaSession],
      sessionsByProject: const {
        'p1': [alphaSession],
        'p2': [betaSession],
      },
      sessionView: _buildSessionView(alphaSession, 'Alpha ready'),
      contextStatus: _buildContextStatus(
        alphaSession.id,
        alphaSession.directory!,
      ),
      attention: const AttentionState(questions: [], permissions: []),
      attentionByProject: {
        'p1': alphaAttention,
        'p2': const AttentionState(questions: [], permissions: []),
      },
      viewsBySession: {
        _scopedSessionKey('s1', projectId: 'p1'): _buildSessionView(
          alphaSession,
          'Alpha ready',
        ),
        _scopedSessionKey('s2', projectId: 'p2'): _buildSessionView(
          betaSession,
          'Beta ready',
        ),
      },
      contextsBySession: {
        _scopedSessionKey('s1', projectId: 'p1'): _buildContextStatus(
          alphaSession.id,
          alphaSession.directory!,
        ),
        _scopedSessionKey('s2', projectId: 'p2'): _buildContextStatus(
          betaSession.id,
          betaSession.directory!,
        ),
      },
    );
    addTearDown(client.disposeEvents);

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

    client.delayNextAttention(projectId: 'p1');
    client.emitEvent(
      const BridgeEvent(
        type: 'question.updated',
        sessionId: 's1',
        timestamp: '2026-04-15T00:00:01Z',
        rawType: null,
        payload: {},
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.menu_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta project').first);
    await tester.pump();

    client.completeDelayedAttention(projectId: 'p1');
    await tester.pumpAndSettle();

    expect(find.text('Beta ready'), findsOneWidget);
    expect(find.text('Alpha approval'), findsNothing);
    expect(find.text('问题'), findsNothing);
  });

  testWidgets('mobile drawer shows project attention from another session', (
    tester,
  ) async {
    _setSurfaceSize(tester, const Size(430, 932));

    const selectedSession = SessionSummary(
      id: 's1',
      title: 'Selected session',
      directory: '/repo/robot',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: null,
    );
    const waitingSession = SessionSummary(
      id: 's2',
      title: 'Waiting session',
      directory: '/repo/robot',
      createdAt: null,
      updatedAt: null,
      status: 'running',
      parentId: null,
    );

    final client = _FakeBridgeClient(
      sessions: const [selectedSession, waitingSession],
      sessionView: _buildSessionView(selectedSession, 'Selected ready'),
      contextStatus: _buildContextStatus(selectedSession.id, '/repo/robot'),
      attention: const AttentionState(
        questions: [
          PendingQuestion(
            id: 'q-other-session',
            sessionId: 's2',
            header: 'P0 direction',
            question: 'Which P0 work should continue?',
            options: [QuestionOption(label: '全部非8821 P0', description: null)],
            multiple: false,
          ),
        ],
        permissions: [],
      ),
    );
    addTearDown(client.disposeEvents);

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

    expect(find.text('Selected ready'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mobile-inline-pending-question-card')),
      findsOneWidget,
    );
    expect(find.text('P0 direction'), findsOneWidget);
    expect(find.text('Which P0 work should continue?'), findsOneWidget);
    expect(find.text('全部非8821 P0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('P0 direction'), findsWidgets);
    expect(find.text('Which P0 work should continue?'), findsWidgets);
    expect(find.text('全部非8821 P0'), findsWidgets);
  });

  testWidgets(
    'deduplicates selected-session refresh while a load is in flight',
    (tester) async {
      _setSurfaceSize(tester, const Size(430, 932));

      final session = const SessionSummary(
        id: 's1',
        title: 'Session A',
        directory: '/repo/a',
        createdAt: null,
        updatedAt: null,
        status: 'running',
        parentId: null,
      );

      final client = _FakeBridgeClient(
        sessions: [session],
        sessionView: _buildSessionView(session, 'Initial view'),
        contextStatus: _buildContextStatus(session.id, '/repo/a'),
        attention: const AttentionState(questions: [], permissions: []),
      );
      addTearDown(client.disposeEvents);

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

      client.delayNextSessionView('s1');
      client.delayNextContextStatus('s1');
      client.emitEvent(
        const BridgeEvent(
          type: 'message.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:00:01Z',
          rawType: null,
          payload: {},
        ),
      );
      client.emitEvent(
        const BridgeEvent(
          type: 'todo.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:00:02Z',
          rawType: null,
          payload: {},
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(client.fetchSessionViewCalls, 2);
      expect(client.fetchContextStatusCalls, 1);

      client.emitEvent(
        const BridgeEvent(
          type: 'message.updated',
          sessionId: 's1',
          timestamp: '2026-04-15T00:00:03Z',
          rawType: null,
          payload: {},
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(client.fetchSessionViewCalls, 2);
      expect(client.fetchContextStatusCalls, 1);

      client.completeDelayedSessionView('s1');
      client.completeDelayedContextStatus('s1');
      await tester.pumpAndSettle();
    },
  );
}

SessionView _buildSessionView(SessionSummary session, String text) {
  return SessionView(
    session: session,
    messages: [_conversationMessage(id: 'm-${session.id}-$text', text: text)],
    todos: const [],
  );
}

TextConversationPart _textPart(String text) {
  return TextConversationPart(
    type: 'text',
    display: 'inline',
    text: text,
    title: null,
    name: null,
    description: null,
    tool: null,
    path: null,
    uri: null,
    mimeType: null,
    language: null,
    callId: null,
    status: null,
    attempt: null,
    error: null,
    metadata: const {'type': 'text'},
  );
}

UsageMetrics _usage({
  required int totalTokens,
  required int inputTokens,
  required int outputTokens,
  required int reasoningTokens,
  required int cacheReadTokens,
  required int cacheWriteTokens,
  required num cost,
  required int contextLimit,
  required int contextUsagePercent,
}) {
  return UsageMetrics(
    totalTokens: totalTokens,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    reasoningTokens: reasoningTokens,
    cacheReadTokens: cacheReadTokens,
    cacheWriteTokens: cacheWriteTokens,
    cost: cost,
    contextLimit: contextLimit,
    contextUsagePercent: contextUsagePercent,
  );
}

UsageMetrics _usagePartial({
  int? totalTokens,
  int? inputTokens,
  int? outputTokens,
  int? reasoningTokens,
  int? cacheReadTokens,
  int? cacheWriteTokens,
  num? cost,
  int? contextLimit,
  int? contextUsagePercent,
}) {
  return UsageMetrics(
    totalTokens: totalTokens,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    reasoningTokens: reasoningTokens,
    cacheReadTokens: cacheReadTokens,
    cacheWriteTokens: cacheWriteTokens,
    cost: cost,
    contextLimit: contextLimit,
    contextUsagePercent: contextUsagePercent,
  );
}

ConversationMessage _conversationMessage({
  required String id,
  required String text,
  String role = 'assistant',
  String? createdAt = '2026-04-15T00:00:00Z',
  String? completedAt = '2026-04-15T00:00:01Z',
  String? error,
  String? providerId,
  String? modelId,
  UsageMetrics? usage,
}) {
  return ConversationMessage(
    id: id,
    role: role,
    createdAt: createdAt,
    completedAt: completedAt,
    error: error,
    providerId: providerId,
    modelId: modelId,
    usage: usage,
    parts: [_textPart(text)],
  );
}

SessionContextStatus _buildContextStatus(
  String sessionId,
  String directory, {
  String status = 'running',
  int messageCount = 1,
  int todoCount = 0,
  int pendingTodoCount = 0,
  int inProgressTodoCount = 0,
  int completedTodoCount = 0,
  int activeToolCount = 0,
  bool compacting = false,
  int? summaryAdditions,
  int? summaryDeletions,
  int? summaryFileCount,
  String? currentStepTitle,
  String? currentToolTitle,
  String? currentToolStatus,
  String? currentSubtaskDescription,
  int? currentRetryAttempt,
  String? currentRetryError,
}) {
  return SessionContextStatus(
    sessionId: sessionId,
    directory: directory,
    status: status,
    parentId: null,
    createdAt: null,
    updatedAt: null,
    lastActivityAt: null,
    messageCount: messageCount,
    todoCount: todoCount,
    pendingTodoCount: pendingTodoCount,
    inProgressTodoCount: inProgressTodoCount,
    completedTodoCount: completedTodoCount,
    activeToolCount: activeToolCount,
    compacting: compacting,
    summaryAdditions: summaryAdditions,
    summaryDeletions: summaryDeletions,
    summaryFileCount: summaryFileCount,
    currentStepTitle: currentStepTitle,
    currentToolTitle: currentToolTitle,
    currentToolStatus: currentToolStatus,
    currentSubtaskDescription: currentSubtaskDescription,
    currentRetryAttempt: currentRetryAttempt,
    currentRetryError: currentRetryError,
  );
}

String _scopedSessionKey(String sessionId, {String? projectId}) {
  return '${projectId ?? '<global>'}::$sessionId';
}

void _setSurfaceSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FetchSessionsRequest {
  const _FetchSessionsRequest({
    required this.projectId,
    required this.directory,
    required this.roots,
    required this.limit,
  });

  final String? projectId;
  final String? directory;
  final bool? roots;
  final int? limit;
}

class _FetchSessionViewRequest {
  const _FetchSessionViewRequest({
    required this.sessionId,
    required this.projectId,
    required this.messageLimit,
  });

  final String sessionId;
  final String? projectId;
  final int? messageLimit;
}

bool _pathFallsWithinRoot(String path, String root) {
  final normalizedPath = path.trim();
  final normalizedRoot = root.trim();
  return normalizedPath == normalizedRoot ||
      normalizedPath.startsWith('$normalizedRoot/');
}

class _FakeBridgeClient extends OpenCodeBridgeClient {
  _FakeBridgeClient({
    this.projects = const [],
    this.projectCandidates = const [],
    required this.sessions,
    this.sessionsByProject = const {},
    required this.sessionView,
    required this.contextStatus,
    required this.attention,
    this.attentionByProject = const {},
    this.viewsBySession = const {},
    this.contextsBySession = const {},
    this.directoryListing,
    this.directoryListingsByPath = const {},
    this.fileSearchResult,
    this.filePreviewsByPath = const {},
  }) : _viewsBySession = Map<String, SessionView>.from(viewsBySession),
       _contextsBySession = Map<String, SessionContextStatus>.from(
         contextsBySession,
       ),
       super(baseUrl: 'http://fake-bridge');

  final List<ProjectSummary> projects;
  final List<ProjectCandidate> projectCandidates;
  final List<SessionSummary> sessions;
  final Map<String, List<SessionSummary>> sessionsByProject;
  final SessionView sessionView;
  final SessionContextStatus contextStatus;
  final AttentionState attention;
  final Map<String, AttentionState> attentionByProject;
  final Map<String, SessionView> viewsBySession;
  final Map<String, SessionContextStatus> contextsBySession;
  final DirectoryListing? directoryListing;
  final Map<String, DirectoryListing> directoryListingsByPath;
  final FileSearchResult? fileSearchResult;
  final Map<String, FilePreview> filePreviewsByPath;
  final Map<String, SessionView> _viewsBySession;
  final Map<String, SessionContextStatus> _contextsBySession;
  final Set<String> _deletedSessionIds = <String>{};
  final StreamController<BridgeEvent> _events =
      StreamController<BridgeEvent>.broadcast();
  final Map<String, Completer<SessionView>> _delayedSessionViews = {};
  final Map<String, Completer<SessionContextStatus>> _delayedContextStatuses =
      {};
  final Map<String, Completer<AttentionState>> _delayedAttention = {};
  Completer<void>? _delayedSendPrompt;

  int fetchSessionsCalls = 0;
  int fetchSessionViewCalls = 0;
  int fetchContextStatusCalls = 0;
  int fetchAttentionCalls = 0;
  int sendPromptCalls = 0;
  int compactSessionCalls = 0;
  final List<String> sentPrompts = [];
  final List<_FetchSessionsRequest> fetchSessionsRequests = [];
  final List<_FetchSessionViewRequest> fetchSessionViewRequests = [];

  void emitEvent(BridgeEvent event) {
    _events.add(event);
  }

  void updateViewForSession(
    String sessionId,
    SessionView view, {
    String? projectId,
  }) {
    _viewsBySession[_requestKey(sessionId, projectId: projectId)] = view;
  }

  void updateContextStatusForSession(
    String sessionId,
    SessionContextStatus status, {
    String? projectId,
  }) {
    _contextsBySession[_requestKey(sessionId, projectId: projectId)] = status;
  }

  void delayNextSessionView(String sessionId, {String? projectId}) {
    _delayedSessionViews[_requestKey(sessionId, projectId: projectId)] =
        Completer<SessionView>();
  }

  void completeDelayedSessionView(String sessionId, {String? projectId}) {
    final scopedKey = _requestKey(sessionId, projectId: projectId);
    final completer =
        _delayedSessionViews.remove(scopedKey) ??
        _delayedSessionViews.remove(sessionId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        _viewsBySession[scopedKey] ?? _viewsBySession[sessionId] ?? sessionView,
      );
    }
  }

  void delayNextContextStatus(String sessionId, {String? projectId}) {
    _delayedContextStatuses[_requestKey(sessionId, projectId: projectId)] =
        Completer<SessionContextStatus>();
  }

  void completeDelayedContextStatus(String sessionId, {String? projectId}) {
    final scopedKey = _requestKey(sessionId, projectId: projectId);
    final completer =
        _delayedContextStatuses.remove(scopedKey) ??
        _delayedContextStatuses.remove(sessionId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        _contextsBySession[scopedKey] ??
            _contextsBySession[sessionId] ??
            contextStatus,
      );
    }
  }

  void delayNextAttention({String? projectId}) {
    _delayedAttention[_attentionRequestKey(projectId)] =
        Completer<AttentionState>();
  }

  void delayNextSendPrompt() {
    _delayedSendPrompt = Completer<void>();
  }

  void completeDelayedSendPrompt() {
    final completer = _delayedSendPrompt;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _delayedSendPrompt = null;
  }

  void completeDelayedAttention({String? projectId}) {
    final key = _attentionRequestKey(projectId);
    final completer =
        _delayedAttention.remove(key) ?? _delayedAttention.remove('<default>');
    if (completer != null && !completer.isCompleted) {
      completer.complete(attentionByProject[projectId] ?? attention);
    }
  }

  Future<void> disposeEvents() async {
    await _events.close();
  }

  @override
  Future<bool> checkHealth() async => true;

  @override
  Future<List<ProjectSummary>> fetchProjects() async {
    if (projects.isNotEmpty) {
      return projects;
    }
    return [
      ProjectSummary(
        id: 'p1',
        name: 'Demo project',
        path: sessionView.session.directory ?? '/repo/demo',
        opened: true,
        runtimeState: 'running',
        lastOpenedAt: null,
        port: 4100,
      ),
    ];
  }

  @override
  Future<ProjectDiscoveryResult> discoverProjects() async =>
      ProjectDiscoveryResult(items: projectCandidates, allowedRoots: const []);

  @override
  Future<ProjectSummary> openProject(String projectId) async {
    return (await fetchProjects()).firstWhere(
      (project) => project.id == projectId,
    );
  }

  @override
  Future<ProjectSummary> registerProject({
    required String path,
    String? name,
  }) async {
    return ProjectSummary(
      id: 'registered-project',
      name: name ?? 'Registered project',
      path: path,
      opened: false,
      runtimeState: 'stopped',
      lastOpenedAt: null,
      port: null,
    );
  }

  @override
  Future<void> deleteSession(String sessionId, {String? projectId}) async {
    _deletedSessionIds.add(sessionId);
    _viewsBySession.remove(sessionId);
    _contextsBySession.remove(sessionId);
    if (projectId != null) {
      _viewsBySession.remove(_requestKey(sessionId, projectId: projectId));
      _contextsBySession.remove(_requestKey(sessionId, projectId: projectId));
    }
  }

  @override
  Future<List<SessionSummary>> fetchSessions({
    String? projectId,
    String? directory,
    bool? roots,
    int? limit,
  }) async {
    fetchSessionsCalls += 1;
    fetchSessionsRequests.add(
      _FetchSessionsRequest(
        projectId: projectId,
        directory: directory?.trim(),
        roots: roots,
        limit: limit,
      ),
    );

    Iterable<SessionSummary> scopedSessions =
        projectId != null && sessionsByProject.containsKey(projectId)
        ? sessionsByProject[projectId]!
        : sessions;

    scopedSessions = scopedSessions.where(
      (session) => !_deletedSessionIds.contains(session.id),
    );

    final normalizedDirectory = directory?.trim();
    if (normalizedDirectory != null && normalizedDirectory.isNotEmpty) {
      scopedSessions = scopedSessions.where((session) {
        final sessionDirectory = session.directory?.trim();
        return sessionDirectory != null &&
            _pathFallsWithinRoot(sessionDirectory, normalizedDirectory);
      });
    }

    final results = scopedSessions.toList(growable: false);
    if (limit == null) {
      return results;
    }
    return results.take(limit).toList(growable: false);
  }

  @override
  Future<SessionView> fetchSessionView(
    String sessionId, {
    String? projectId,
    int? messageLimit,
  }) async {
    fetchSessionViewCalls += 1;
    fetchSessionViewRequests.add(
      _FetchSessionViewRequest(
        sessionId: sessionId,
        projectId: projectId,
        messageLimit: messageLimit,
      ),
    );
    final scopedKey = _scopedSessionKey(sessionId, projectId: projectId);
    final delayed =
        _delayedSessionViews[scopedKey] ?? _delayedSessionViews[sessionId];
    if (delayed != null) {
      return delayed.future;
    }
    return _viewsBySession[scopedKey] ??
        _viewsBySession[sessionId] ??
        sessionView;
  }

  @override
  Future<SessionContextStatus> fetchSessionContextStatus(
    String sessionId, {
    String? projectId,
  }) async {
    fetchContextStatusCalls += 1;
    final scopedKey = _scopedSessionKey(sessionId, projectId: projectId);
    final delayed =
        _delayedContextStatuses[scopedKey] ??
        _delayedContextStatuses[sessionId];
    if (delayed != null) {
      return delayed.future;
    }
    return _contextsBySession[scopedKey] ??
        _contextsBySession[sessionId] ??
        contextStatus;
  }

  @override
  Future<AttentionState> fetchAttention({String? projectId}) async {
    fetchAttentionCalls += 1;
    final delayed =
        _delayedAttention[_attentionRequestKey(projectId)] ??
        _delayedAttention['<default>'];
    if (delayed != null) {
      return delayed.future;
    }
    return attentionByProject[projectId] ?? attention;
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required String prompt,
    String? projectId,
  }) async {
    sendPromptCalls += 1;
    sentPrompts.add(prompt);
    final delayed = _delayedSendPrompt;
    if (delayed != null) {
      await delayed.future;
    }
  }

  @override
  Future<void> compactSession({
    required String sessionId,
    String? projectId,
  }) async {
    compactSessionCalls += 1;
  }

  @override
  Future<FileSearchResult> searchFiles({
    required String sessionId,
    required String query,
    required String mode,
    String? projectId,
  }) async {
    return fileSearchResult ??
        FileSearchResult(query: query, mode: mode, items: const []);
  }

  @override
  Future<DirectoryListing> fetchDirectoryListing({
    required String sessionId,
    String? path,
    String? projectId,
  }) async {
    final normalizedPath = path?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      final rootListing =
          directoryListing ??
          _directoryListingForPath(sessionView.session.directory ?? '');
      if (rootListing != null) {
        return rootListing;
      }
    }

    final listing = _directoryListingForPath(normalizedPath ?? '');
    if (listing != null) {
      return listing;
    }

    throw Exception(
      'Missing directory listing for ${normalizedPath ?? '<root>'}',
    );
  }

  @override
  Future<FilePreview> fetchFilePreview({
    required String sessionId,
    required String path,
    String? projectId,
  }) async {
    final preview = filePreviewsByPath[path];
    if (preview == null) {
      throw Exception('Missing preview for $path');
    }
    return preview;
  }

  @override
  Stream<BridgeEvent> watchEvents({String? projectId}) => _events.stream;

  DirectoryListing? _directoryListingForPath(String path) {
    if (path.isEmpty) {
      return null;
    }
    return directoryListingsByPath[path];
  }

  String _requestKey(String sessionId, {String? projectId}) {
    return projectId == null
        ? sessionId
        : _scopedSessionKey(sessionId, projectId: projectId);
  }

  String _attentionRequestKey(String? projectId) {
    return projectId ?? '<default>';
  }
}
