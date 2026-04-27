import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:opencode_remote/opencode_remote.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _defaultBridgeUrl = String.fromEnvironment(
  'BRIDGE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);
const _buildVersionLabel = '1.1.0';
const MethodChannel _downloadsChannel = MethodChannel(
  'dev.chewcode.mobile/downloads',
);

const _productName = 'ChewCode';
const _productChineseName = '口香糖';
const _defaultUiLanguage = 'zh';
const _wideLayoutBreakpoint = 900.0;
const _sessionDrawerWidth = 340.0;
const _mobileDrawerMaxWidth = 420.0;
const _maxMobileContentWidth = 760.0;
const _sessionPageSize = 5;
const _spaceXxs = 2.0;
const _spaceXs = 4.0;
const _spaceSm = 8.0;
const _spaceMd = 12.0;
const _spaceLg = 16.0;
const _mobileHeaderButtonSize = 40.0;
const _radiusSm = 14.0;
const _radiusMd = 18.0;
const _radiusLg = 24.0;

final ValueNotifier<String> _uiLanguageNotifier = ValueNotifier<String>(
  _defaultUiLanguage,
);

class _LanguageScope extends InheritedNotifier<ValueNotifier<String>> {
  const _LanguageScope({required super.notifier, required super.child});

  static ValueNotifier<String>? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_LanguageScope>();
    return scope?.notifier;
  }
}

String _tr(BuildContext context, String zh, String en) {
  return _LanguageScope.maybeOf(context)?.value == 'en' ? en : zh;
}

bool _looksLikeMarkdown(FilePreview preview) {
  final lowerPath = preview.path.toLowerCase();
  final lowerName = preview.displayName.toLowerCase();
  final lowerLanguage = preview.language?.toLowerCase();
  return lowerPath.endsWith('.md') ||
      lowerPath.endsWith('.markdown') ||
      lowerName == 'readme' ||
      lowerName == 'readme.md' ||
      lowerLanguage == 'markdown';
}

class _AppPalette {
  static const background = Color(0xFF071019);
  static const surface = Color(0xFF0E1724);
  static const surfaceElevated = Color(0xFF142131);
  static const surfaceAccent = Color(0xFF1A2C40);
  static const outline = Color(0xFF2E465C);
  static const outlineSoft = Color(0xFF213245);
  static const textPrimary = Color(0xFFE5F1FF);
  static const signal = Color(0xFF67E8F9);
  static const success = Color(0xFF7EE787);
  static const warning = Color(0xFFF2CC60);
  static const error = Color(0xFFFF7B72);
}

ThemeData _buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: _AppPalette.signal,
    brightness: brightness,
  );
  final scheme = isDark
      ? base.copyWith(
          primary: _AppPalette.signal,
          onPrimary: _AppPalette.background,
          secondary: _AppPalette.success,
          onSecondary: _AppPalette.background,
          tertiary: _AppPalette.warning,
          onTertiary: _AppPalette.background,
          error: _AppPalette.error,
          onError: _AppPalette.background,
          surface: _AppPalette.surface,
          onSurface: _AppPalette.textPrimary,
          surfaceContainerLowest: _AppPalette.background,
          surfaceContainerLow: _AppPalette.surface,
          surfaceContainer: _AppPalette.surfaceElevated,
          surfaceContainerHigh: _AppPalette.surfaceAccent,
          surfaceContainerHighest: const Color(0xFF273754),
          outline: _AppPalette.outline,
          outlineVariant: _AppPalette.outlineSoft,
          shadow: Colors.black,
          scrim: Colors.black,
        )
      : base.copyWith(
          primary: const Color(0xFF0B63D1),
          onPrimary: Colors.white,
          secondary: const Color(0xFF047857),
          onSecondary: Colors.white,
          tertiary: const Color(0xFFB45309),
          onTertiary: Colors.white,
          surface: const Color(0xFFF8FAFC),
          onSurface: const Color(0xFF0F172A),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF1F5F9),
          surfaceContainer: const Color(0xFFE2E8F0),
          surfaceContainerHigh: const Color(0xFFD6E0EC),
          surfaceContainerHighest: const Color(0xFFCBD5E1),
          outline: const Color(0xFF94A3B8),
          outlineVariant: const Color(0xFFCBD5E1),
        );

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(_radiusMd),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(7),
      radius: const Radius.circular(999),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) {
          return scheme.primary.withValues(alpha: 0.95);
        }
        return scheme.primary.withValues(alpha: 0.7);
      }),
      trackColor: WidgetStatePropertyAll(
        scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
    ),
    scaffoldBackgroundColor: isDark
        ? _AppPalette.background
        : const Color(0xFFF3F6FB),
    canvasColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      width: _sessionDrawerWidth,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(color: scheme.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: _spaceLg,
        vertical: _spaceMd,
      ),
    ),
  );
}

void main() {
  runApp(const ChewCodeApp());
}

class ChewCodeApp extends StatelessWidget {
  const ChewCodeApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _uiLanguageNotifier,
      builder: (context, language, _) {
        return _LanguageScope(
          notifier: _uiLanguageNotifier,
          child: MaterialApp(
            title: language == 'en'
                ? _productName
                : '$_productName / $_productChineseName',
            debugShowCheckedModeBanner: false,
            theme: _buildAppTheme(Brightness.light),
            darkTheme: _buildAppTheme(Brightness.dark),
            themeMode: ThemeMode.dark,
            home: home ?? const WorkspaceScreen(),
          ),
        );
      },
    );
  }
}

class _BridgeRefreshRequest {
  const _BridgeRefreshRequest({
    this.sessions = false,
    this.attention = false,
    this.sessionView = false,
    this.contextStatus = false,
  });

  final bool sessions;
  final bool attention;
  final bool sessionView;
  final bool contextStatus;

  bool get isEmpty => !sessions && !attention && !sessionView && !contextStatus;

  _BridgeRefreshRequest merge(_BridgeRefreshRequest other) {
    return _BridgeRefreshRequest(
      sessions: sessions || other.sessions,
      attention: attention || other.attention,
      sessionView: sessionView || other.sessionView,
      contextStatus: contextStatus || other.contextStatus,
    );
  }
}

class _SessionLoadResult {
  const _SessionLoadResult({required this.sessions, required this.exhausted});

  final List<SessionSummary> sessions;
  final bool exhausted;
}

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    this.client,
    this.initialBridgeUrl,
    this.loadPreferences = true,
  });

  final OpenCodeBridgeClient? client;
  final String? initialBridgeUrl;
  final bool loadPreferences;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  static const _bridgeUrlKey = 'bridge_url';
  static const _recentBridgeUrlsKey = 'recent_bridge_urls';
  static const _bridgeTokenKey = 'bridge_bearer_token';
  static const _uiLanguageKey = 'ui_language';
  static final _secureStorage = FlutterSecureStorage();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late OpenCodeBridgeClient _client;
  late final bool _ownsClient;
  StreamSubscription<BridgeEvent>? _eventSubscription;
  Timer? _eventReconnectTimer;
  Timer? _eventRefreshTimer;
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final TextEditingController _newSessionTitleController =
      TextEditingController();
  final TextEditingController _newSessionPromptController =
      TextEditingController();
  final TextEditingController _bridgeUrlController = TextEditingController();
  final TextEditingController _bridgeTokenController = TextEditingController();
  final TextEditingController _fileSearchController = TextEditingController();
  final TextEditingController _projectPathController = TextEditingController();
  final TextEditingController _projectNameController = TextEditingController();

  List<ProjectSummary> _projects = const [];
  List<ProjectCandidate> _projectCandidates = const [];
  List<String> _projectAllowedRoots = const [];
  List<SessionSummary> _sessions = const [];
  SessionView? _selectedSessionView;
  SessionContextStatus? _selectedSessionContextStatus;
  AttentionState _attention = const AttentionState(
    questions: [],
    permissions: [],
  );
  String? _selectedProjectId;
  String? _selectedSessionId;
  bool _loadingSessions = true;
  bool _loadingProjects = true;
  bool _discoveringProjects = false;
  bool _openingProject = false;
  bool _registeringProject = false;
  bool _loadingSessionView = false;
  bool _loadingSessionContextStatus = false;
  bool _searchingFiles = false;
  bool _loadingFilePreview = false;
  int _inFlightPromptCount = 0;
  bool _compactingSession = false;
  bool _respondingAttention = false;
  bool _creatingSession = false;
  bool _checkingBridgeHealth = false;
  bool _switchingBridge = false;
  int _eventReconnectAttempts = 0;
  bool _processingEventRefresh = false;
  int _mobilePanelIndex = 0;
  String? _deletingSessionId;
  Future<void>? _sessionsLoadFuture;
  String? _sessionsLoadProjectId;
  String? _sessionVisibilityProjectId;
  int _sessionVisibilityLimit = _sessionPageSize;
  bool _sessionsExhausted = false;
  Timer? _realtimeContextStatusTimer;
  bool _realtimeContextStatusArmed = false;
  final Map<String, Future<void>> _sessionViewLoadFutures = {};
  final Map<String, Future<void>> _sessionContextLoadFutures = {};
  final Map<String, UsageMetrics> _retainedAssistantUsageBySession = {};
  String? _error;
  String _connectionLabel = 'Connecting…';
  String _bridgeUrl = _defaultBridgeUrl;
  String _bridgeToken = '';
  String _fileSearchMode = 'name';
  FileSearchResult? _fileSearchResult;
  FilePreview? _selectedFilePreview;
  FileSearchHit? _selectedFileHit;
  String? _selectedFilePreviewSource;
  List<FileSearchHit> _recentFileHits = const [];
  String? _lastBrowsedDirectoryPath;
  String? _expandedProjectId;
  List<String> _recentBridgeUrls = const [];
  _BridgeRefreshRequest _pendingEventRefresh = const _BridgeRefreshRequest();

  @override
  void initState() {
    super.initState();
    _bridgeUrl = widget.initialBridgeUrl ?? _defaultBridgeUrl;
    _ownsClient = widget.client == null;
    _client = widget.client ?? OpenCodeBridgeClient(baseUrl: _bridgeUrl);
    _bridgeUrlController.text = _bridgeUrl;
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _eventReconnectTimer?.cancel();
    _eventRefreshTimer?.cancel();
    _realtimeContextStatusTimer?.cancel();
    if (_ownsClient) {
      _client.close();
    }
    _composerController.dispose();
    _composerFocusNode.dispose();
    _newSessionTitleController.dispose();
    _newSessionPromptController.dispose();
    _bridgeUrlController.dispose();
    _bridgeTokenController.dispose();
    _fileSearchController.dispose();
    _projectPathController.dispose();
    _projectNameController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (widget.loadPreferences) {
      await _loadBridgePreferences();
    }
    await _reloadFromBridge(selectFirst: true, restartStream: true);
  }

  Future<void> _loadBridgePreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final savedBridgeUrl = preferences.getString(_bridgeUrlKey)?.trim();
    final recentBridgeUrls =
        preferences.getStringList(_recentBridgeUrlsKey) ?? const <String>[];
    final uiLanguage =
        preferences.getString(_uiLanguageKey)?.trim().toLowerCase() ??
        _defaultUiLanguage;

    final bridgeUrl = savedBridgeUrl != null && savedBridgeUrl.isNotEmpty
        ? savedBridgeUrl
        : _defaultBridgeUrl;

    final bridgeToken = await _readBridgeToken();

    _client = OpenCodeBridgeClient(
      baseUrl: bridgeUrl,
      bearerToken: bridgeToken,
    );

    if (!mounted) {
      _bridgeUrl = bridgeUrl;
      _bridgeToken = bridgeToken;
      _recentBridgeUrls = recentBridgeUrls;
      _bridgeUrlController.text = bridgeUrl;
      _bridgeTokenController.text = bridgeToken;
      _uiLanguageNotifier.value = uiLanguage == 'en'
          ? 'en'
          : _defaultUiLanguage;
      return;
    }

    setState(() {
      _bridgeUrl = bridgeUrl;
      _bridgeToken = bridgeToken;
      _recentBridgeUrls = recentBridgeUrls;
      _bridgeUrlController.text = bridgeUrl;
      _bridgeTokenController.text = bridgeToken;
    });
    _uiLanguageNotifier.value = uiLanguage == 'en' ? 'en' : _defaultUiLanguage;
  }

  Future<void> _persistBridgePreferences(String bridgeUrl) async {
    final preferences = await SharedPreferences.getInstance();
    final updatedRecents = <String>[
      bridgeUrl,
      ..._recentBridgeUrls.where((item) => item != bridgeUrl),
    ].take(5).toList(growable: false);

    await preferences.setString(_bridgeUrlKey, bridgeUrl);
    await preferences.setStringList(_recentBridgeUrlsKey, updatedRecents);

    if (!mounted) {
      _recentBridgeUrls = updatedRecents;
      return;
    }

    setState(() {
      _recentBridgeUrls = updatedRecents;
    });
  }

  String _txt(String zh, String en) {
    return _uiLanguageNotifier.value == 'en' ? en : zh;
  }

  Future<void> _persistUiLanguagePreference(String language) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_uiLanguageKey, language);
    _uiLanguageNotifier.value = language;
  }

  Future<void> _setUiLanguage(String language) async {
    final normalized = language == 'en' ? 'en' : _defaultUiLanguage;
    if (_uiLanguageNotifier.value == normalized) {
      return;
    }
    await _persistUiLanguagePreference(normalized);
    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _readBridgeToken() async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(_bridgeTokenKey) ?? '';
    }

    return await _secureStorage.read(key: _bridgeTokenKey) ?? '';
  }

  Future<void> _persistBridgeToken(String token) async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_bridgeTokenKey, token);
      return;
    }

    await _secureStorage.write(key: _bridgeTokenKey, value: token);
  }

  Future<void> _reloadFromBridge({
    required bool selectFirst,
    required bool restartStream,
    bool refreshSelectedSession = false,
    bool showLoadingIndicators = true,
    bool reportErrors = true,
  }) async {
    if (restartStream) {
      _eventSubscription?.cancel();
      _eventReconnectTimer?.cancel();
      _eventRefreshTimer?.cancel();
      _eventReconnectAttempts = 0;
      _pendingEventRefresh = const _BridgeRefreshRequest();
    }

    await _loadProjects(selectFirst: selectFirst, reportErrors: reportErrors);
    await _loadSessions(
      selectFirst: selectFirst,
      showLoadingIndicator: showLoadingIndicators,
      reportErrors: reportErrors,
    );
    await _loadAttention(reportErrors: reportErrors);

    final selectedId = _selectedSessionId;
    if (refreshSelectedSession && selectedId != null) {
      await _loadSessionView(
        selectedId,
        preserveSelection: true,
        showLoadingIndicator: showLoadingIndicators,
        reportErrors: reportErrors,
      );
    }

    if (restartStream) {
      _listenToEvents();
    }
  }

  Future<void> _loadProjects({
    required bool selectFirst,
    bool reportErrors = true,
  }) async {
    if (mounted) {
      setState(() {
        _loadingProjects = true;
        if (reportErrors) {
          _error = null;
        }
      });
    }

    try {
      final projects = await _client.fetchProjects();
      if (!mounted) {
        return;
      }

      final currentSelectedProjectId = _selectedProjectId;
      final currentExpandedProjectId = _expandedProjectId;
      final selectedStillExists =
          currentSelectedProjectId != null &&
          projects.any((project) => project.id == currentSelectedProjectId);
      final expandedStillExists =
          currentExpandedProjectId != null &&
          projects.any((project) => project.id == currentExpandedProjectId);
      final nextProjectId = selectedStillExists
          ? currentSelectedProjectId
          : selectFirst && projects.isNotEmpty
          ? projects.first.id
          : currentSelectedProjectId;
      final nextExpandedProjectId = expandedStillExists
          ? currentExpandedProjectId
          : nextProjectId;

      setState(() {
        _projects = projects;
        _selectedProjectId = nextProjectId;
        _expandedProjectId = nextExpandedProjectId;
        _loadingProjects = false;
      });

      if (nextProjectId != null) {
        final selectedProject = projects.firstWhere(
          (project) => project.id == nextProjectId,
        );
        if (!selectedProject.opened) {
          await _openProject(nextProjectId, reloadWorkspace: false);
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingProjects = false;
        if (reportErrors) {
          _error = error.toString();
        }
      });
    }
  }

  Future<void> _openProject(
    String projectId, {
    bool reloadWorkspace = true,
  }) async {
    if (_openingProject) {
      return;
    }

    setState(() {
      _openingProject = true;
      _error = null;
    });

    try {
      final openedProject = await _client.openProject(projectId);
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedProjectId = openedProject.id;
        _expandedProjectId = openedProject.id;
        _projects = _projects
            .map(
              (project) =>
                  project.id == openedProject.id ? openedProject : project,
            )
            .toList(growable: false);
        _selectedSessionId = null;
        _selectedSessionView = null;
        _selectedSessionContextStatus = null;
        _attention = const AttentionState(questions: [], permissions: []);
        _fileSearchResult = null;
        _selectedFilePreview = null;
        _selectedFileHit = null;
        _selectedFilePreviewSource = null;
        _lastBrowsedDirectoryPath = null;
        _mobilePanelIndex = 0;
        _sessionsLoadFuture = null;
        _sessionsLoadProjectId = null;
      });

      if (reloadWorkspace) {
        await _reloadFromBridge(
          selectFirst: true,
          restartStream: true,
          showLoadingIndicators: true,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _openingProject = false;
        });
      }
    }
  }

  Future<void> _closeProject(String projectId) async {
    setState(() {
      _openingProject = true;
      _error = null;
    });

    try {
      final closedProject = await _client.closeProject(projectId);
      if (!mounted) {
        return;
      }

      final nextProjects = _projects
          .map(
            (project) =>
                project.id == closedProject.id ? closedProject : project,
          )
          .toList(growable: false);

      final selectedWasClosed = _selectedProjectId == projectId;
      setState(() {
        _projects = nextProjects;
        if (selectedWasClosed) {
          _selectedProjectId = null;
          _selectedSessionId = null;
          _selectedSessionView = null;
          _selectedSessionContextStatus = null;
          _attention = const AttentionState(questions: [], permissions: []);
          _fileSearchResult = null;
          _selectedFilePreview = null;
          _selectedFileHit = null;
          _selectedFilePreviewSource = null;
          _lastBrowsedDirectoryPath = null;
          _mobilePanelIndex = 0;
          _sessions = const [];
          _expandedProjectId = null;
          _sessionsLoadFuture = null;
          _sessionsLoadProjectId = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _openingProject = false;
        });
      }
    }
  }

  Future<void> _deleteProject(String projectId) async {
    setState(() {
      _openingProject = true;
      _error = null;
    });

    try {
      await _client.deleteProject(projectId);
      if (!mounted) {
        return;
      }

      final selectedWasDeleted = _selectedProjectId == projectId;
      setState(() {
        _projects = _projects
            .where((project) => project.id != projectId)
            .toList(growable: false);
        if (selectedWasDeleted) {
          _selectedProjectId = null;
          _selectedSessionId = null;
          _selectedSessionView = null;
          _selectedSessionContextStatus = null;
          _attention = const AttentionState(questions: [], permissions: []);
          _fileSearchResult = null;
          _selectedFilePreview = null;
          _selectedFileHit = null;
          _selectedFilePreviewSource = null;
          _lastBrowsedDirectoryPath = null;
          _mobilePanelIndex = 0;
          _sessions = const [];
          _expandedProjectId = null;
          _sessionsLoadFuture = null;
          _sessionsLoadProjectId = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _openingProject = false;
        });
      }
    }
  }

  Future<void> _registerProject() async {
    final projectPath = _projectPathController.text.trim();
    final projectName = _projectNameController.text.trim();
    if (projectPath.isEmpty || _registeringProject) {
      return;
    }

    setState(() {
      _registeringProject = true;
      _error = null;
    });

    try {
      final project = await _client.registerProject(
        path: projectPath,
        name: projectName.isEmpty ? null : projectName,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _projects = [..._projects, project]
          ..sort(
            (left, right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          );
      });

      await _openProject(project.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _registeringProject = false;
        });
      }
    }
  }

  Future<void> _discoverProjects() async {
    if (_discoveringProjects) {
      return;
    }

    setState(() {
      _discoveringProjects = true;
      _error = null;
    });

    try {
      final candidates = await _client.discoverProjects();
      if (!mounted) {
        return;
      }
      setState(() {
        _projectCandidates = candidates.items;
        _projectAllowedRoots = candidates.allowedRoots;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _discoveringProjects = false;
        });
      }
    }
  }

  void _listenToEvents() {
    _eventSubscription?.cancel();
    _eventReconnectTimer?.cancel();
    _eventSubscription = _client
        .watchEvents(projectId: _selectedProjectId)
        .listen(
          (event) {
            if (!mounted) {
              return;
            }

            final liveLabel = 'Live updates active · $_bridgeUrl';
            if (_connectionLabel != liveLabel) {
              setState(() {
                _connectionLabel = liveLabel;
              });
            }
            _eventReconnectAttempts = 0;

            _queueRefreshFromEvent(event);
          },
          onError: (Object error) {
            if (!mounted) {
              return;
            }
            setState(() {
              _connectionLabel = 'Stream disconnected';
              _error = error.toString();
            });
            _scheduleEventReconnect();
          },
          onDone: () {
            if (!mounted) {
              return;
            }
            setState(() {
              _connectionLabel = 'Stream ended';
            });
            _scheduleEventReconnect();
          },
          cancelOnError: false,
        );
  }

  bool _shouldInvalidateFromEvent(BridgeEvent event) {
    return event.type.startsWith('session.') ||
        event.type.startsWith('message.') ||
        event.type.startsWith('todo.') ||
        event.type.startsWith('question.') ||
        event.type.startsWith('permission.');
  }

  _BridgeRefreshRequest _refreshRequestForEvent(BridgeEvent event) {
    if (!_shouldInvalidateFromEvent(event)) {
      return const _BridgeRefreshRequest();
    }

    final selectedId = _selectedSessionId;
    final touchesSelectedSession =
        selectedId != null &&
        (event.sessionId == null || event.sessionId == selectedId);

    if (event.type.startsWith('session.')) {
      return _BridgeRefreshRequest(
        sessions: true,
        sessionView: touchesSelectedSession,
        contextStatus: touchesSelectedSession,
      );
    }

    if (event.type.startsWith('message.')) {
      return _BridgeRefreshRequest(
        sessionView: touchesSelectedSession,
        contextStatus: touchesSelectedSession,
      );
    }

    if (event.type.startsWith('todo.')) {
      return _BridgeRefreshRequest(
        sessionView: touchesSelectedSession,
        contextStatus: touchesSelectedSession,
      );
    }

    if (event.type.startsWith('question.') ||
        event.type.startsWith('permission.')) {
      return const _BridgeRefreshRequest(attention: true);
    }

    return const _BridgeRefreshRequest();
  }

  void _queueRefreshFromEvent(BridgeEvent event) {
    final refresh = _refreshRequestForEvent(event);
    if (refresh.isEmpty) {
      return;
    }

    if (event.type.startsWith('message.') &&
        _selectedSessionId != null &&
        (event.sessionId == null || event.sessionId == _selectedSessionId)) {
      _realtimeContextStatusArmed = true;
      _syncRealtimeContextStatusRefresh();
    }

    _pendingEventRefresh = _pendingEventRefresh.merge(refresh);
    _eventRefreshTimer?.cancel();
    _eventRefreshTimer = Timer(const Duration(milliseconds: 220), () {
      unawaited(_flushQueuedEventRefresh());
    });
  }

  Future<void> _flushQueuedEventRefresh() async {
    if (_processingEventRefresh) {
      return;
    }

    final refresh = _pendingEventRefresh;
    _pendingEventRefresh = const _BridgeRefreshRequest();
    if (refresh.isEmpty) {
      return;
    }

    _processingEventRefresh = true;
    try {
      if (refresh.sessions) {
        await _loadSessions(
          selectFirst: _selectedSessionId == null,
          showLoadingIndicator: false,
          reportErrors: false,
        );
      }
      if (refresh.attention) {
        await _loadAttention(reportErrors: false);
      }

      final selectedId = _selectedSessionId;
      if (selectedId != null) {
        if (refresh.sessionView) {
          await _loadSessionView(
            selectedId,
            preserveSelection: true,
            showLoadingIndicator: false,
            loadContextStatus: refresh.contextStatus,
            reportErrors: false,
          );
        } else if (refresh.contextStatus) {
          await _loadSessionContextStatus(
            selectedId,
            showLoadingIndicator: false,
            reportErrors: false,
          );
        }
      }
    } finally {
      _processingEventRefresh = false;
      _syncRealtimeContextStatusRefresh();
      if (!_pendingEventRefresh.isEmpty) {
        unawaited(_flushQueuedEventRefresh());
      }
    }
  }

  void _scheduleEventReconnect() {
    _eventReconnectTimer?.cancel();
    _eventReconnectAttempts += 1;
    final delaySeconds = _eventReconnectAttempts <= 3 ? 2 : 5;

    _eventReconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (!mounted) {
        return;
      }

      setState(() {
        _connectionLabel = 'Reconnecting stream…';
      });

      await _reloadFromBridge(
        selectFirst: _selectedSessionId == null,
        restartStream: true,
      );
    });
  }

  Future<void> _loadAttention({bool reportErrors = true}) async {
    final requestedProjectId = _selectedProjectId;
    if (requestedProjectId == null) {
      if (mounted &&
          !_attentionStateEquals(
            _attention,
            const AttentionState(questions: [], permissions: []),
          )) {
        setState(() {
          _attention = const AttentionState(questions: [], permissions: []);
        });
      }
      return;
    }

    try {
      final attention = await _client.fetchAttention(
        projectId: requestedProjectId,
      );
      if (!mounted) {
        return;
      }
      if (_selectedProjectId != requestedProjectId) {
        return;
      }
      if (!_attentionStateEquals(_attention, attention)) {
        setState(() {
          _attention = attention;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_selectedProjectId != requestedProjectId) {
        return;
      }
      if (reportErrors) {
        setState(() {
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _loadSessions({
    required bool selectFirst,
    bool showLoadingIndicator = true,
    bool reportErrors = true,
  }) async {
    final requestedProjectId = _selectedProjectId;
    _syncSessionVisibilityScope(requestedProjectId);
    if (requestedProjectId == null) {
      if (mounted) {
        setState(() {
          _sessions = const [];
          _sessionsExhausted = true;
          _selectedSessionId = null;
          _selectedSessionView = null;
          _selectedSessionContextStatus = null;
          _retainedAssistantUsageBySession.clear();
          _loadingSessions = false;
        });
      }
      return;
    }

    final existingLoad = _sessionsLoadFuture;
    if (existingLoad != null && _sessionsLoadProjectId == requestedProjectId) {
      await existingLoad;
      return;
    }

    if (existingLoad != null && _sessionsLoadProjectId != requestedProjectId) {
      _sessionsLoadFuture = null;
      _sessionsLoadProjectId = null;
    }

    if (mounted) {
      setState(() {
        if (showLoadingIndicator || _sessions.isEmpty) {
          _loadingSessions = true;
        }
        if (reportErrors) {
          _error = null;
        }
      });
    }

    Future<void> loadFuture() async {
      try {
        final loadResult = await _fetchProjectSessions(
          requestedProjectId,
        );
        final sessions = loadResult.sessions;
        final visibleSessions = _visibleRootSessionsFrom(
          sessions,
          directory: _sessionQueryDirectory,
        );
        if (!mounted) {
          return;
        }
        if (_selectedProjectId != requestedProjectId) {
          return;
        }
        final connectionLabel = 'Connected · $_bridgeUrl';
        final sessionsChanged = !_sessionSummaryListsEqual(_sessions, sessions);
        if (sessionsChanged ||
            _loadingSessions ||
            _connectionLabel != connectionLabel ||
            _sessionsExhausted != loadResult.exhausted) {
          setState(() {
            _sessions = sessions;
            _sessionsExhausted = loadResult.exhausted;
            _loadingSessions = false;
            _connectionLabel = connectionLabel;
          });
        }

        final selectedId = _selectedSessionId;
        if (selectedId != null &&
            visibleSessions.any((item) => item.id == selectedId)) {
          return;
        }

        if (visibleSessions.isEmpty) {
          if (selectedId != null) {
            setState(() {
              _selectedSessionId = null;
              _selectedSessionView = null;
              _selectedSessionContextStatus = null;
            });
          }
          return;
        }

        if (selectFirst || selectedId != null) {
          await _loadSessionView(
            visibleSessions.first.id,
            preserveSelection: false,
          );
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _loadingSessions = false;
          if (reportErrors) {
            _error = error.toString();
          }
          _connectionLabel = 'Bridge unavailable · $_bridgeUrl';
        });
      }
    }

    _sessionsLoadProjectId = requestedProjectId;
    _sessionsLoadFuture = loadFuture();
    try {
      await _sessionsLoadFuture;
    } finally {
      if (_sessionsLoadProjectId == requestedProjectId) {
        _sessionsLoadFuture = null;
        _sessionsLoadProjectId = null;
      }
    }
  }

  Future<void> _testBridgeHealth() async {
    final bridgeUrl = _bridgeUrlController.text.trim();
    if (bridgeUrl.isEmpty || _checkingBridgeHealth) {
      return;
    }

    setState(() {
      _checkingBridgeHealth = true;
      _error = null;
    });

    try {
      final token = _bridgeTokenController.text.trim();
      final authenticatedProbeClient = OpenCodeBridgeClient(
        baseUrl: bridgeUrl,
        bearerToken: token,
      );
      final ok = await authenticatedProbeClient.checkHealth();
      authenticatedProbeClient.close();
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionLabel = ok
            ? 'Bridge healthy at $bridgeUrl'
            : 'Bridge unhealthy at $bridgeUrl';
        if (!ok) {
          _error = 'Health check failed for $bridgeUrl';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _connectionLabel = 'Bridge health check failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingBridgeHealth = false;
        });
      }
    }
  }

  Future<void> _applyBridgeUrl(String bridgeUrl) async {
    final normalizedBridgeUrl = bridgeUrl.trim();
    final normalizedToken = _bridgeTokenController.text.trim();
    if (normalizedBridgeUrl.isEmpty || _switchingBridge) {
      return;
    }

    setState(() {
      _switchingBridge = true;
      _error = null;
      _connectionLabel = 'Switching bridge…';
    });

    try {
      await _persistBridgePreferences(normalizedBridgeUrl);
      await _persistBridgeToken(normalizedToken);
      if (_ownsClient) {
        _client.close();
      }
      _client = OpenCodeBridgeClient(
        baseUrl: normalizedBridgeUrl,
        bearerToken: normalizedToken,
      );

      if (!mounted) {
        _bridgeUrl = normalizedBridgeUrl;
        _bridgeToken = normalizedToken;
        return;
      }

      setState(() {
        _bridgeUrl = normalizedBridgeUrl;
        _bridgeToken = normalizedToken;
        _bridgeUrlController.text = normalizedBridgeUrl;
        _bridgeTokenController.text = normalizedToken;
        _sessions = const [];
        _selectedSessionId = null;
        _selectedSessionView = null;
        _selectedSessionContextStatus = null;
        _retainedAssistantUsageBySession.clear();
        _fileSearchResult = null;
        _selectedFilePreview = null;
        _selectedFileHit = null;
        _selectedFilePreviewSource = null;
        _recentFileHits = const [];
        _lastBrowsedDirectoryPath = null;
        _attention = const AttentionState(questions: [], permissions: []);
        _mobilePanelIndex = 0;
        _expandedProjectId = null;
      });

      _eventRefreshTimer?.cancel();
      _pendingEventRefresh = const _BridgeRefreshRequest();

      await _reloadFromBridge(selectFirst: true, restartStream: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _connectionLabel = 'Failed to switch bridge';
      });
    } finally {
      if (mounted) {
        setState(() {
          _switchingBridge = false;
        });
      }
    }
  }

  Future<void> _loadSessionView(
    String sessionId, {
    required bool preserveSelection,
    bool showLoadingIndicator = true,
    bool loadContextStatus = true,
    bool reportErrors = true,
  }) async {
    final requestedProjectId = _selectedProjectId;
    if (requestedProjectId == null) {
      return;
    }

    final requestKey = _sessionRequestKey(requestedProjectId, sessionId);
    final existingLoad = _sessionViewLoadFutures[requestKey];
    if (existingLoad != null) {
      await existingLoad;
      if (loadContextStatus &&
          _selectedProjectId == requestedProjectId &&
          _selectedSessionId == sessionId) {
        await _loadSessionContextStatus(
          sessionId,
          showLoadingIndicator: showLoadingIndicator,
          reportErrors: reportErrors,
        );
      }
      return;
    }

    if (_selectedSessionId == sessionId) {
      _retainAssistantUsageSnapshot(
        requestedProjectId,
        sessionId,
        _stickyLatestAssistantUsage(
          requestedProjectId,
          sessionId,
          _selectedSessionView,
        ),
      );
    }

    if (mounted) {
      setState(() {
        if (showLoadingIndicator ||
            !preserveSelection ||
            _selectedSessionView == null) {
          _loadingSessionView = true;
        }
        if (!preserveSelection) {
          _selectedSessionId = sessionId;
          _selectedSessionView = null;
          _selectedSessionContextStatus = null;
          _fileSearchResult = null;
          _selectedFilePreview = null;
          _selectedFileHit = null;
          _selectedFilePreviewSource = null;
          _recentFileHits = const [];
          _lastBrowsedDirectoryPath = null;
        }
        if (reportErrors) {
          _error = null;
        }
      });
    }

    Future<void> loadFuture() async {
      try {
        final view = await _client.fetchSessionView(
          sessionId,
          projectId: requestedProjectId,
        );
        if (!mounted) {
          return;
        }
        if (_selectedProjectId != requestedProjectId ||
            _selectedSessionId != sessionId) {
          return;
        }
        _rememberLatestAssistantUsage(requestedProjectId, sessionId, view);
        final viewChanged = !_sessionViewEquals(_selectedSessionView, view);
        if (viewChanged || _loadingSessionView) {
          setState(() {
            _selectedSessionId = sessionId;
            _selectedSessionView = view;
            _loadingSessionView = false;
          });
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        if (_selectedProjectId != requestedProjectId ||
            _selectedSessionId != sessionId) {
          return;
        }
        setState(() {
          _loadingSessionView = false;
          if (reportErrors) {
            _error = error.toString();
          }
        });
      }
    }

    _sessionViewLoadFutures[requestKey] = loadFuture();
    try {
      await _sessionViewLoadFutures[requestKey];
    } finally {
      _sessionViewLoadFutures.remove(requestKey);
    }

    if (loadContextStatus &&
        _selectedProjectId == requestedProjectId &&
        _selectedSessionId == sessionId) {
      await _loadSessionContextStatus(
        sessionId,
        showLoadingIndicator: showLoadingIndicator,
        reportErrors: reportErrors,
      );
    }
  }

  void _rememberLatestAssistantUsage(
    String? projectId,
    String? sessionId,
    SessionView? view,
  ) {
    if (sessionId == null || view == null) {
      return;
    }

    final latestUsage = _latestAssistantUsage(view.messages);
    if (latestUsage == null) {
      return;
    }

    final requestKey = _sessionRequestKey(projectId, sessionId);
    _retainedAssistantUsageBySession[requestKey] = _mergeUsageMetrics(
      latestUsage,
      _retainedAssistantUsageBySession[requestKey],
    );
  }

  void _retainAssistantUsageSnapshot(
    String? projectId,
    String? sessionId,
    UsageMetrics? usage,
  ) {
    if (sessionId == null || !_hasUsageMetrics(usage)) {
      return;
    }

    final requestKey = _sessionRequestKey(projectId, sessionId);
    _retainedAssistantUsageBySession[requestKey] = _mergeUsageMetrics(
      usage!,
      _retainedAssistantUsageBySession[requestKey],
    );
  }

  UsageMetrics? _stickyLatestAssistantUsage(
    String? projectId,
    String? sessionId,
    SessionView? view,
  ) {
    if (sessionId == null) {
      return null;
    }

    final requestKey = _sessionRequestKey(projectId, sessionId);
    final retainedUsage = _retainedAssistantUsageBySession[requestKey];
    final liveUsage = _latestAssistantUsage(view?.messages ?? const []);
    if (liveUsage != null) {
      return _mergeUsageMetrics(liveUsage, retainedUsage);
    }

    return retainedUsage;
  }

  Future<void> _loadSessionContextStatus(
    String sessionId, {
    bool showLoadingIndicator = true,
    bool reportErrors = true,
  }) async {
    final requestedProjectId = _selectedProjectId;
    if (requestedProjectId == null) {
      return;
    }

    final requestKey = _sessionRequestKey(requestedProjectId, sessionId);
    final existingLoad = _sessionContextLoadFutures[requestKey];
    if (existingLoad != null) {
      await existingLoad;
      return;
    }

    if (mounted) {
      setState(() {
        if (showLoadingIndicator ||
            _selectedSessionContextStatus == null ||
            _selectedSessionContextStatus!.sessionId != sessionId) {
          _loadingSessionContextStatus = true;
        }
      });
    }

    Future<void> loadFuture() async {
      try {
        final contextStatus = await _client.fetchSessionContextStatus(
          sessionId,
          projectId: requestedProjectId,
        );
        if (!mounted) {
          return;
        }
        if (_selectedProjectId != requestedProjectId ||
            _selectedSessionId != sessionId) {
          return;
        }
        final contextChanged = !_sessionContextStatusEquals(
          _selectedSessionContextStatus,
          contextStatus,
        );
        if (contextChanged || _loadingSessionContextStatus) {
          setState(() {
            _selectedSessionContextStatus = contextStatus;
            _loadingSessionContextStatus = false;
          });
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        if (_selectedProjectId != requestedProjectId ||
            _selectedSessionId != sessionId) {
          return;
        }
        setState(() {
          _loadingSessionContextStatus = false;
          if (reportErrors) {
            _error = error.toString();
          }
        });
      }
    }

    _sessionContextLoadFutures[requestKey] = loadFuture();
    try {
      await _sessionContextLoadFutures[requestKey];
    } finally {
      _sessionContextLoadFutures.remove(requestKey);
    }
  }

  Future<void> _refreshWorkspace() async {
    await _reloadFromBridge(
      selectFirst: _selectedSessionId == null,
      restartStream: false,
      refreshSelectedSession: _selectedSessionId != null,
    );
  }

  Future<void> _sendPrompt() async {
    final sessionId = _selectedSessionId;
    final prompt = _composerController.text.trim();

    if (sessionId == null || prompt.isEmpty) {
      return;
    }

    if (prompt == '/compact' || prompt == '/summarize') {
      await _compactSession(clearComposer: true);
      return;
    }

    _retainAssistantUsageSnapshot(
      _selectedProjectId,
      sessionId,
      _stickyLatestAssistantUsage(
        _selectedProjectId,
        sessionId,
        _selectedSessionView,
      ),
    );

    setState(() {
      _inFlightPromptCount += 1;
      _error = null;
      if (_selectedSessionView != null) {
        final optimisticMessage = ConversationMessage(
          id: 'local-user-${DateTime.now().microsecondsSinceEpoch}',
          role: 'user',
          createdAt: DateTime.now().toIso8601String(),
          completedAt: DateTime.now().toIso8601String(),
          error: null,
          usage: null,
          parts: [
            TextConversationPart(
              type: 'text',
              display: 'inline',
              text: prompt,
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
            ),
          ],
        );
        _selectedSessionView = SessionView(
          session: _selectedSessionView!.session,
          messages: [..._selectedSessionView!.messages, optimisticMessage],
          todos: _selectedSessionView!.todos,
        );
      }
    });

    try {
      await _client.sendPrompt(
        sessionId: sessionId,
        prompt: prompt,
        projectId: _selectedProjectId,
      );
      if (_composerController.text.trim() == prompt) {
        _composerController.clear();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionLabel = 'Prompt sent';
      });
      _realtimeContextStatusArmed = true;
      _queueSelectedSessionRefresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _inFlightPromptCount = math.max(0, _inFlightPromptCount - 1);
        });
      }
    }
  }

  Future<void> _compactSession({bool clearComposer = false}) async {
    final sessionId = _selectedSessionId;
    if (sessionId == null || _compactingSession || _inFlightPromptCount > 0) {
      return;
    }

    setState(() {
      _compactingSession = true;
      _error = null;
    });

    try {
      await _client.compactSession(
        sessionId: sessionId,
        projectId: _selectedProjectId,
      );
      if (clearComposer) {
        _composerController.clear();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionLabel = _txt('已开始压缩上下文', 'Context compaction started');
      });
      _realtimeContextStatusArmed = true;
      _queueSelectedSessionRefresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _compactingSession = false;
        });
      }
    }
  }

  void _queueSelectedSessionRefresh() {
    _pendingEventRefresh = _pendingEventRefresh.merge(
      const _BridgeRefreshRequest(sessionView: true, contextStatus: true),
    );
    _eventRefreshTimer?.cancel();
    _eventRefreshTimer = Timer(const Duration(milliseconds: 180), () {
      unawaited(_flushQueuedEventRefresh());
    });
    _syncRealtimeContextStatusRefresh();
  }

  void _syncRealtimeContextStatusRefresh() {
    final contextStatus = _selectedSessionContextStatus;
    final shouldFollowLiveTurn =
        _inFlightPromptCount > 0 ||
        _compactingSession ||
        _pendingEventRefresh.sessionView ||
        _pendingEventRefresh.contextStatus ||
        _latestPendingAssistant(_selectedSessionView?.messages ?? const []) !=
            null ||
        (contextStatus?.compacting ?? false) ||
        _hasBusySessionStatus(contextStatus);
    final shouldPoll =
        _realtimeContextStatusArmed &&
        _selectedSessionId != null &&
        shouldFollowLiveTurn;

    if (!shouldPoll) {
      _realtimeContextStatusTimer?.cancel();
      _realtimeContextStatusTimer = null;
      if (_selectedSessionId == null || !shouldFollowLiveTurn) {
        _realtimeContextStatusArmed = false;
      }
      return;
    }

    if (_realtimeContextStatusTimer != null) {
      return;
    }

    _realtimeContextStatusTimer = Timer(
      const Duration(milliseconds: 450),
      () async {
        _realtimeContextStatusTimer = null;
        final sessionId = _selectedSessionId;
        if (sessionId != null && mounted) {
          await _loadSessionContextStatus(
            sessionId,
            showLoadingIndicator: false,
            reportErrors: false,
          );
        }
        if (mounted) {
          _syncRealtimeContextStatusRefresh();
        }
      },
    );
  }

  void _showVoiceInputUnavailable() {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _txt(
              '当前构建保留了语音转文字入口，但还没有接入本地语音服务。',
              'This build keeps the voice-to-text entry point, but local speech input is not wired up yet.',
            ),
          ),
        ),
      );
  }

  Future<void> _replyQuestion(PendingQuestion question, String answer) async {
    if (_respondingAttention) {
      return;
    }

    setState(() {
      _respondingAttention = true;
      _error = null;
    });

    try {
      await _client.replyQuestion(
        requestId: question.id,
        answers: [
          <String>[answer],
        ],
        projectId: _selectedProjectId,
      );
      await _loadAttention();
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _respondingAttention = false;
        });
      }
    }
  }

  Future<void> _rejectQuestion(PendingQuestion question) async {
    if (_respondingAttention) {
      return;
    }

    setState(() {
      _respondingAttention = true;
      _error = null;
    });

    try {
      await _client.rejectQuestion(
        requestId: question.id,
        projectId: _selectedProjectId,
      );
      await _loadAttention();
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _respondingAttention = false;
        });
      }
    }
  }

  Future<void> _replyPermission(
    PendingPermission permission,
    String reply,
  ) async {
    if (_respondingAttention) {
      return;
    }

    setState(() {
      _respondingAttention = true;
      _error = null;
    });

    try {
      await _client.replyPermission(
        requestId: permission.id,
        reply: reply,
        projectId: _selectedProjectId,
      );
      await _loadAttention();
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _respondingAttention = false;
        });
      }
    }
  }

  Future<void> _createSession() async {
    if (_creatingSession || _selectedProjectId == null) {
      return;
    }

    final title = _newSessionTitleController.text.trim();
    final prompt = _newSessionPromptController.text.trim();

    setState(() {
      _creatingSession = true;
      _error = null;
    });

    try {
      final result = await _client.createSession(
        title: title.isEmpty ? null : title,
        prompt: prompt.isEmpty ? null : prompt,
        projectId: _selectedProjectId,
      );
      if (!mounted) {
        return;
      }
      _newSessionTitleController.clear();
      _newSessionPromptController.clear();

      await _loadSessions(selectFirst: false);
      await _loadSessionView(result.session.id, preserveSelection: false);
      await _loadAttention();

      if (!mounted) {
        return;
      }

      setState(() {
        _connectionLabel = result.started
            ? 'Session created and started'
            : 'Session created';
        _error = result.promptError;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _creatingSession = false;
        });
      }
    }
  }

  Future<void> _searchFiles() async {
    final sessionId = _selectedSessionId;
    final query = _fileSearchController.text.trim();
    if (sessionId == null || query.isEmpty || _searchingFiles) {
      return;
    }

    setState(() {
      _searchingFiles = true;
      _error = null;
    });

    try {
      final result = await _client.searchFiles(
        sessionId: sessionId,
        query: query,
        mode: _fileSearchMode,
        projectId: _selectedProjectId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _fileSearchResult = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _searchingFiles = false;
        });
      }
    }
  }

  String? get _activeSessionDirectory =>
      _selectedSessionContextStatus?.directory ??
      _selectedSessionView?.session.directory;

  ProjectSummary? get _selectedProjectSummary {
    final selectedProjectId = _selectedProjectId;
    if (selectedProjectId == null) {
      return null;
    }

    for (final project in _projects) {
      if (project.id == selectedProjectId) {
        return project;
      }
    }

    return null;
  }

  SessionSummary? get _selectedSessionSummary {
    final viewSession = _selectedSessionView?.session;
    if (viewSession != null) {
      return viewSession;
    }

    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId == null) {
      return null;
    }

    for (final session in _sessions) {
      if (session.id == selectedSessionId) {
        return session;
      }
    }

    return null;
  }

  String? get _sessionQueryDirectory =>
      _sessionQueryDirectoryForProject(_selectedProjectSummary);

  List<SessionSummary> get _visibleRootSessions => _visibleRootSessionsFrom(
    _sessions,
    directory: _sessionQueryDirectory,
  );

  List<SessionSummary> get _paginatedVisibleRootSessions {
    return _visibleRootSessions
        .take(_sessionVisibilityLimit)
        .toList(growable: false);
  }

  bool get _hasMoreVisibleRootSessions =>
      !_sessionsExhausted ||
      _paginatedVisibleRootSessions.length < _visibleRootSessions.length;

  int get _selectedAttentionCount =>
      _filteredQuestionsForSession(
        _attention.questions,
        _selectedSessionId,
      ).length +
      _filteredPermissionsForSession(
        _attention.permissions,
        _selectedSessionId,
      ).length;

  String? get _mobileFileBadge {
    if (_selectedFilePreview != null) {
      return _txt('预览中', 'Preview');
    }

    final result = _fileSearchResult;
    if (result != null && result.items.isNotEmpty) {
      return '${result.items.length}';
    }

    return null;
  }

  String? get _mobileSessionBadge {
    if (_selectedAttentionCount > 0) {
      return '$_selectedAttentionCount';
    }

    final todoCount = _selectedSessionView?.todos.length ?? 0;
    if (todoCount > 0) {
      return '$todoCount';
    }

    return null;
  }

  double _mobileDrawerWidth(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - _spaceSm;
    return math.min(availableWidth, _mobileDrawerMaxWidth);
  }

  String? _sessionQueryDirectoryForProject(ProjectSummary? project) {
    final projectPath = project?.path.trim();
    if (projectPath != null && projectPath.isNotEmpty) {
      return projectPath;
    }

    final sessionDirectory = _activeSessionDirectory?.trim();
    if (sessionDirectory != null && sessionDirectory.isNotEmpty) {
      return sessionDirectory;
    }

    final selectedDirectory = _selectedSessionSummary?.directory?.trim();
    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      return selectedDirectory;
    }

    return null;
  }

  void _syncSessionVisibilityScope(String? projectId) {
    if (_sessionVisibilityProjectId == projectId) {
      return;
    }

    _sessionVisibilityProjectId = projectId;
    _sessionVisibilityLimit = _sessionPageSize;
    _sessionsExhausted = false;
  }

  List<SessionSummary> _visibleRootSessionsFrom(
    List<SessionSummary> sessions, {
    String? directory,
  }) {
    final normalizedDirectory = directory?.trim();

    return sessions.where((session) {
      final parentId = session.parentId?.trim();
      if (parentId != null && parentId.isNotEmpty) {
        return false;
      }

      final archivedAt = session.archivedAt?.trim();
      if (archivedAt != null && archivedAt.isNotEmpty) {
        return false;
      }

      final sessionDirectory = session.directory?.trim();
      if (normalizedDirectory != null && normalizedDirectory.isNotEmpty) {
        if (sessionDirectory == null || sessionDirectory.isEmpty) {
          return false;
        }
        if (!_pathFallsWithinRoot(sessionDirectory, normalizedDirectory)) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);
  }

  Future<_SessionLoadResult> _fetchProjectSessions(String projectId) async {
    ProjectSummary? project;
    for (final item in _projects) {
      if (item.id == projectId) {
        project = item;
        break;
      }
    }

    final directory = _sessionQueryDirectoryForProject(project);
    var requestLimit = math.max(_sessionVisibilityLimit, _sessionPageSize);

    while (true) {
      final sessions = await _client.fetchSessions(
        projectId: projectId,
        directory: directory,
        roots: true,
        limit: requestLimit,
      );
      final exhausted = sessions.length < requestLimit;
      final visibleSessions = _visibleRootSessionsFrom(
        sessions,
        directory: directory,
      );
      if (visibleSessions.length >= _sessionVisibilityLimit || exhausted) {
        return _SessionLoadResult(sessions: sessions, exhausted: exhausted);
      }
      requestLimit += _sessionPageSize;
    }
  }

  String _projectPreviewLabel(ProjectSummary project) {
    return _compactPathLabel(project.path);
  }

  String _sessionPreviewLabel(SessionSummary session) {
    final directory = session.directory?.trim();
    if (directory == null || directory.isEmpty) {
      return _txt('未知目录', 'Unknown directory');
    }

    final relativePath = _displayPathRelativeTo(
      directory,
      _selectedProjectSummary?.path,
    );
    if (relativePath == '.') {
      return _txt('工作区根目录', 'Workspace root');
    }
    if (relativePath != directory) {
      return relativePath;
    }

    return _compactPathLabel(directory);
  }

  Widget _buildSessionLoadMoreButton({
    Key? key,
    Future<void> Function()? onPressed,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: key,
        onPressed: () {
          unawaited((onPressed ?? _loadMoreSessions)());
        },
        icon: const Icon(Icons.expand_more_rounded),
        label: Text(_txt('再加载 5 个', 'Load 5 more')),
      ),
    );
  }

  Future<void> _loadMoreSessions() async {
    if (!_hasMoreVisibleRootSessions) {
      return;
    }

    setState(() {
      _sessionVisibilityLimit += _sessionPageSize;
    });

    await _loadSessions(
      selectFirst: false,
      showLoadingIndicator: false,
      reportErrors: false,
    );
  }

  void _openMobilePrimaryDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openMobileSecondaryDrawer({int? tabIndex}) {
    if (tabIndex != null) {
      setState(() {
        _mobilePanelIndex = tabIndex;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  Future<void> _confirmDeleteSession(SessionSummary session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_txt('删除会话？', 'Delete session?')),
          content: Text(
            _txt(
              '会永久删除“${session.title}”及其消息历史。',
              'This permanently deletes “${session.title}” and its message history.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_txt('取消', 'Cancel')),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_txt('删除', 'Delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _deleteSession(session.id);
  }

  Future<void> _deleteSession(String sessionId) async {
    if (_deletingSessionId == sessionId) {
      return;
    }

    final selectedWasDeleted = _selectedSessionId == sessionId;
    setState(() {
      _deletingSessionId = sessionId;
      _error = null;
    });

    try {
      await _client.deleteSession(sessionId, projectId: _selectedProjectId);
      if (!mounted) {
        return;
      }

      if (selectedWasDeleted) {
        setState(() {
          _retainedAssistantUsageBySession.remove(
            _sessionRequestKey(_selectedProjectId, sessionId),
          );
          _selectedSessionId = null;
          _selectedSessionView = null;
          _selectedSessionContextStatus = null;
          _fileSearchResult = null;
          _selectedFilePreview = null;
          _selectedFileHit = null;
          _selectedFilePreviewSource = null;
          _recentFileHits = const [];
          _lastBrowsedDirectoryPath = null;
          _mobilePanelIndex = 0;
        });
      }

      await _loadSessions(
        selectFirst: selectedWasDeleted,
        showLoadingIndicator: false,
      );
      await _loadAttention(reportErrors: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          if (_deletingSessionId == sessionId) {
            _deletingSessionId = null;
          }
        });
      }
    }
  }

  void _rememberRecentFileHit(FileSearchHit hit) {
    final updated = <FileSearchHit>[hit];
    for (final existing in _recentFileHits) {
      if (existing.path != hit.path) {
        updated.add(existing);
      }
      if (updated.length >= 10) {
        break;
      }
    }
    _recentFileHits = updated;
  }

  void _returnToFileList() {
    setState(() {
      _selectedFilePreview = null;
      _selectedFileHit = null;
      _selectedFilePreviewSource = null;
    });
  }

  Future<void> _toggleProjectHierarchy(String projectId) async {
    final isExpanded = _expandedProjectId == projectId;
    if (isExpanded && _selectedProjectId == projectId) {
      setState(() {
        _expandedProjectId = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _expandedProjectId = projectId;
      });
    }

    if (_selectedProjectId != projectId) {
      await _openProject(projectId);
    }
  }

  void _rememberBrowsedDirectory(String? path) {
    final normalizedPath = path?.trim();
    if (_lastBrowsedDirectoryPath == normalizedPath) {
      return;
    }

    setState(() {
      _lastBrowsedDirectoryPath = normalizedPath;
    });
  }

  Future<void> _returnToBrowsedDirectory() async {
    _returnToFileList();
    await _showFileWorkflowSheet(initialTab: 'browse');
  }

  Future<void> _openSessionFromSwitcher(String sessionId) async {
    if (mounted) {
      setState(() {
        _mobilePanelIndex = 0;
      });
    }

    await _loadSessionView(sessionId, preserveSelection: false);
  }

  Future<void> _openFilePreview(
    FileSearchHit hit, {
    String source = 'search',
  }) async {
    final sessionId = _selectedSessionId;
    if (sessionId == null || _loadingFilePreview) {
      return;
    }

    setState(() {
      _loadingFilePreview = true;
      _selectedFileHit = hit;
      _selectedFilePreviewSource = source;
      _mobilePanelIndex = 1;
      _error = null;
    });

    try {
      final preview = await _client.fetchFilePreview(
        sessionId: sessionId,
        path: hit.path,
        projectId: _selectedProjectId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedFilePreview = preview;
        _rememberRecentFileHit(hit);
      });
      _openMobileSecondaryDrawer(tabIndex: 1);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingFilePreview = false;
        });
      }
    }
  }

  Future<void> _downloadSelectedFile() async {
    final sessionId = _selectedSessionId;
    final preview = _selectedFilePreview;
    final token = _client.bearerToken?.trim();

    if (sessionId == null ||
        preview == null ||
        token == null ||
        token.isEmpty) {
      return;
    }

    try {
      await _downloadsChannel.invokeMethod('enqueueDownload', {
        'url': _client
            .buildDownloadUri(
              sessionId: sessionId,
              path: preview.path,
              projectId: _selectedProjectId,
            )
            .toString(),
        'token': token,
        'fileName': preview.displayName,
        'mimeType': preview.language == 'apk'
            ? 'application/vnd.android.package-archive'
            : null,
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionLabel = _txt('已加入下载队列', 'Added to downloads');
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    }
  }

  FileSearchHit _fileHitFromDirectoryEntry(DirectoryEntry entry) {
    return FileSearchHit(
      path: entry.path,
      displayName: entry.displayName,
      kind: 'name',
      line: null,
      column: null,
      previewText: null,
    );
  }

  Future<void> _showSessionSheet() async {
    final navigator = Navigator.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final visibleSessions = _visibleRootSessions;
            final paginatedSessions = _paginatedVisibleRootSessions;

            return FractionallySizedBox(
              heightFactor: 0.92,
              child: Padding(
                padding: EdgeInsets.only(
                  left: _spaceLg,
                  right: _spaceLg,
                  top: _spaceLg,
                  bottom: MediaQuery.of(context).viewInsets.bottom + _spaceLg,
                ),
                child: Column(
                  key: const ValueKey<String>('session-switch-sheet'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Switch session',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: _spaceXs),
                    Text(
                      _selectedProjectSummary == null
                          ? 'Choose a project first, then switch or create a session for it.'
                          : 'Jump between sessions without leaving the current mobile workspace.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: _spaceMd),
                    if (_selectedProjectSummary != null)
                      _PanelCard(
                        padding: const EdgeInsets.all(_spaceMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedProjectSummary!.name,
                                    style: Theme.of(context).textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                _StatusChip(
                                  label: _selectedProjectSummary!.runtimeState,
                                ),
                              ],
                            ),
                            const SizedBox(height: _spaceXs),
                            Text(
                              _projectPreviewLabel(_selectedProjectSummary!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _monoTextStyle(
                                Theme.of(context).textTheme.bodySmall,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: _spaceSm),
                            _MetricPill(
                              label: 'Sessions',
                              value: '${visibleSessions.length}',
                              tone: Theme.of(context).colorScheme.secondary,
                            ),
                          ],
                        ),
                      ),
                    if (_selectedProjectSummary != null)
                      const SizedBox(height: _spaceMd),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (_selectedProjectId == null) {
                            return const _PanelCard(
                              child: Text(
                                'Open a project to see and switch its sessions.',
                              ),
                            );
                          }

                          if (_loadingSessions && _sessions.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (visibleSessions.isEmpty) {
                            return const _PanelCard(
                              child: Text(
                                'No sessions are available for this project yet. Start a new session to begin.',
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount:
                                paginatedSessions.length +
                                (_hasMoreVisibleRootSessions ? 1 : 0),
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: _spaceSm),
                            itemBuilder: (context, index) {
                              if (index == paginatedSessions.length) {
                                return _buildSessionLoadMoreButton(
                                  key: const ValueKey<String>(
                                    'session-switcher-load-more',
                                  ),
                                  onPressed: () async {
                                    await _loadMoreSessions();
                                    if (mounted) {
                                      modalSetState(() {});
                                    }
                                  },
                                );
                              }

                              final session = paginatedSessions[index];
                              final selected = session.id == _selectedSessionId;
                              return _PanelCard(
                                padding: const EdgeInsets.all(_spaceMd),
                                highlighted: selected,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(session.title),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: _spaceXs),
                                    child: Text(
                                      _sessionPreviewLabel(session),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  trailing: _StatusChip(
                                    label: session.status ?? 'unknown',
                                  ),
                                  onTap: () async {
                                    navigator.pop();
                                    await _openSessionFromSwitcher(session.id);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: _spaceMd),
                    Row(
                      children: [
                        TextButton(
                          onPressed: navigator.pop,
                          child: const Text('Close'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _selectedProjectId == null
                              ? null
                              : () async {
                                  navigator.pop();
                                  await _showCreateSessionSheet();
                                },
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('New session'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileTopSwitchers() {
    final project = _selectedProjectSummary;
    final session = _selectedSessionSummary;
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxMobileContentWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _spaceLg,
            _spaceMd,
            _spaceLg,
            _spaceSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: _PanelCard(
                  padding: const EdgeInsets.all(_spaceMd),
                  highlighted: project != null,
                  tone: scheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Project',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: scheme.primary),
                            ),
                          ),
                          TextButton(
                            onPressed: _showProjectSheet,
                            child: Text(project == null ? 'Open' : 'Change'),
                          ),
                        ],
                      ),
                      Text(
                        project?.name ?? 'No project selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: _spaceXs),
                      Text(
                        project == null
                            ? 'Open a workspace to load its sessions.'
                            : _projectPreviewLabel(project),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: project == null
                            ? Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              )
                            : _monoTextStyle(
                                Theme.of(context).textTheme.bodySmall,
                                color: scheme.onSurfaceVariant,
                              ),
                      ),
                      const SizedBox(height: _spaceSm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: project == null
                            ? const _StatusChip(label: 'workspace required')
                            : _StatusChip(label: project.runtimeState),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _spaceSm),
              Expanded(
                child: _PanelCard(
                  padding: const EdgeInsets.all(_spaceMd),
                  highlighted: session != null,
                  tone: scheme.secondary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Session',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: scheme.secondary),
                            ),
                          ),
                          TextButton(
                            onPressed: _selectedProjectId == null
                                ? null
                                : _showSessionSheet,
                            child: const Text('Switch'),
                          ),
                        ],
                      ),
                      Text(
                        session?.title ?? 'No session selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: _spaceXs),
                      Text(
                        session == null
                            ? (_selectedProjectId == null
                                  ? 'Choose a project first.'
                                  : _visibleRootSessions.isEmpty
                                  ? 'No sessions for this project yet.'
                                  : 'Switch from the session sheet.')
                            : _sessionPreviewLabel(session),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: session == null
                            ? Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              )
                            : _monoTextStyle(
                                Theme.of(context).textTheme.bodySmall,
                                color: scheme.onSurfaceVariant,
                              ),
                      ),
                      const SizedBox(height: _spaceSm),
                      Wrap(
                        spacing: _spaceSm,
                        runSpacing: _spaceSm,
                        children: [
                          _MetricPill(
                            label: 'Sessions',
                            value: '${_visibleRootSessions.length}',
                            tone: scheme.secondary,
                          ),
                          if (session != null)
                            _StatusChip(label: session.status ?? 'unknown'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileWorkspaceBody() {
    if (_loadingSessions && _sessions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedSessionId != null) {
      return _buildSessionDetail(compact: true);
    }

    final hasProject = _selectedProjectId != null;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxMobileContentWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            _spaceLg,
            _spaceMd,
            _spaceLg,
            _spaceLg,
          ),
          child: _PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasProject
                      ? _visibleRootSessions.isEmpty
                            ? 'Start the first session for this project'
                            : 'Choose a session to keep working'
                      : 'Open a project to begin',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: _spaceSm),
                Text(
                  hasProject
                      ? _visibleRootSessions.isEmpty
                            ? 'The project is loaded, but there are no sessions yet. Create one to start chatting, browsing files, and tracking runtime state.'
                            : 'Project and session switching now live in the top bars above, so the main phone view can stay focused on the active conversation.'
                      : 'Use the project switcher above to connect this phone shell to one of your registered workspaces.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: _spaceLg),
                Wrap(
                  spacing: _spaceSm,
                  runSpacing: _spaceSm,
                  children: [
                    FilledButton.icon(
                      onPressed: hasProject
                          ? _showSessionSheet
                          : _showProjectSheet,
                      icon: Icon(
                        hasProject
                            ? Icons.chat_bubble_outline
                            : Icons.folder_open_outlined,
                      ),
                      label: Text(
                        hasProject ? 'Choose session' : 'Open project',
                      ),
                    ),
                    if (hasProject)
                      OutlinedButton.icon(
                        onPressed: _showCreateSessionSheet,
                        icon: const Icon(Icons.add_comment_outlined),
                        label: const Text('New session'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFileWorkflowSheet({String initialTab = 'search'}) async {
    if (_selectedSessionId == null) {
      return;
    }

    final navigator = Navigator.of(context);
    var sheetTab = initialTab;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.96,
          child: StatefulBuilder(
            builder: (context, modalSetState) {
              final sessionDirectory = _activeSessionDirectory;
              final isBrowseTab = sheetTab == 'browse';

              return Padding(
                padding: EdgeInsets.only(
                  left: _spaceLg,
                  right: _spaceLg,
                  top: _spaceMd,
                  bottom: MediaQuery.of(context).viewInsets.bottom + _spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isBrowseTab
                                ? 'Browse current session files'
                                : 'Search current session files',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: navigator.pop,
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                    const SizedBox(height: _spaceXs),
                    Text(
                      isBrowseTab
                          ? 'Stay read-only while browsing the real session workspace and opening previews.'
                          : 'Keep the control shell read-only: search, inspect hits, and open previews without turning this into an editor.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (sessionDirectory != null && !isBrowseTab) ...[
                      const SizedBox(height: _spaceMd),
                      _InsetSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Session workspace root',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                            const SizedBox(height: _spaceXs),
                            SelectableText(
                              sessionDirectory,
                              style: _monoTextStyle(
                                Theme.of(context).textTheme.bodyMedium,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: _spaceMd),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'search',
                          icon: Icon(Icons.search),
                          label: Text('Search'),
                        ),
                        ButtonSegment<String>(
                          value: 'browse',
                          icon: Icon(Icons.folder_copy_outlined),
                          label: Text('Browse'),
                        ),
                      ],
                      selected: {sheetTab},
                      onSelectionChanged: (selection) {
                        modalSetState(() {
                          sheetTab = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: _spaceMd),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeOut,
                        child: sheetTab == 'search'
                            ? _buildFileSearchSheetContent(
                                context,
                                navigator,
                                modalSetState,
                              )
                            : _buildFileBrowseSheetContent(context, navigator),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFileSearchSheetContent(
    BuildContext context,
    NavigatorState navigator,
    StateSetter modalSetState,
  ) {
    final result = _fileSearchResult;

    return Column(
      key: const ValueKey<String>('file-search-sheet'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: 'name',
              icon: Icon(Icons.description_outlined),
              label: Text('Files'),
            ),
            ButtonSegment<String>(
              value: 'text',
              icon: Icon(Icons.subject_outlined),
              label: Text('Text'),
            ),
          ],
          selected: {_fileSearchMode},
          onSelectionChanged: (selection) {
            modalSetState(() {
              _fileSearchMode = selection.first;
            });
            setState(() {
              _fileSearchMode = selection.first;
            });
          },
        ),
        const SizedBox(height: _spaceMd),
        TextField(
          controller: _fileSearchController,
          textInputAction: TextInputAction.search,
          onSubmitted: _searchingFiles
              ? null
              : (_) async {
                  await _searchFiles();
                  modalSetState(() {});
                },
          decoration: InputDecoration(
            labelText: _fileSearchMode == 'name'
                ? 'Filename or path fragment'
                : 'Text snippet',
            helperText: _fileSearchMode == 'name'
                ? 'Search filenames and path fragments inside the current session workspace.'
                : 'Search read-only text hits inside the current session workspace.',
            prefixIcon: Icon(
              _fileSearchMode == 'name'
                  ? Icons.insert_drive_file_outlined
                  : Icons.manage_search_outlined,
            ),
          ),
        ),
        const SizedBox(height: _spaceMd),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _searchingFiles
                    ? null
                    : () async {
                        await _searchFiles();
                        modalSetState(() {});
                      },
                icon: _searchingFiles
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_searchingFiles ? 'Searching…' : 'Search'),
              ),
            ),
          ],
        ),
        const SizedBox(height: _spaceMd),
        if (result == null)
          const _PanelCard(
            child: Text(
              'Search by filename or text inside the current session workspace, then open a read-only preview. The Browse tab walks the real session-root folders and files without turning this shell into an editor.',
            ),
          )
        else ...[
          _PanelCard(
            padding: const EdgeInsets.all(_spaceMd),
            highlighted: true,
            child: Wrap(
              spacing: _spaceSm,
              runSpacing: _spaceSm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetricPill(label: 'Hits', value: '${result.items.length}'),
                _StatusChip(
                  label: result.mode == 'text' ? 'text search' : 'file search',
                  tone: Theme.of(context).colorScheme.secondary,
                ),
                SelectableText(
                  'Query: ${result.query}',
                  style: _monoTextStyle(
                    Theme.of(context).textTheme.bodySmall,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _spaceMd),
          Expanded(
            child: _buildFileSearchResults(
              context,
              navigator,
              shrinkWrap: false,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileBrowseSheetContent(
    BuildContext context,
    NavigatorState navigator,
  ) {
    final sessionId = _selectedSessionId;
    if (sessionId == null) {
      return const SizedBox.shrink();
    }

    return _FileDirectoryBrowser(
      key: const ValueKey<String>('file-browse-sheet'),
      initialPath: _lastBrowsedDirectoryPath,
      sessionDirectory: _activeSessionDirectory,
      selectedFilePath: _selectedFilePreview?.path,
      onLoadDirectory: (path) => _client.fetchDirectoryListing(
        sessionId: sessionId,
        path: path,
        projectId: _selectedProjectId,
      ),
      onDirectoryChanged: _rememberBrowsedDirectory,
      onOpenFile: (entry) async {
        navigator.pop();
        await _openFilePreview(
          _fileHitFromDirectoryEntry(entry),
          source: 'browse',
        );
      },
    );
  }

  Widget _buildFileSearchResults(
    BuildContext context,
    NavigatorState navigator, {
    bool shrinkWrap = true,
  }) {
    final result = _fileSearchResult;
    if (result == null || result.items.isEmpty) {
      return const _PanelCard(child: Text('No files matched this query.'));
    }

    return ListView.separated(
      shrinkWrap: shrinkWrap,
      itemCount: result.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final hit = result.items[index];
        return _FileSearchResultCard(
          hit: hit,
          workspaceRoot: _activeSessionDirectory,
          onTap: () async {
            navigator.pop();
            await _openFilePreview(hit);
          },
        );
      },
    );
  }

  Widget _buildMobileScaffold() {
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      drawerEnableOpenDragGesture: true,
      endDrawerEnableOpenDragGesture: true,
      drawer: _buildMobilePrimaryDrawer(),
      endDrawer: _buildMobileSecondaryDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildMobileCompactHeader(),
            if (_loadingSessionView ||
                _loadingSessionContextStatus ||
                (_loadingSessions && _sessions.isNotEmpty))
              const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _spaceLg,
                  _spaceSm,
                  _spaceLg,
                  0,
                ),
                child: _PanelCard(
                  padding: const EdgeInsets.all(_spaceMd),
                  highlighted: true,
                  tone: Theme.of(context).colorScheme.error,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: _spaceMd),
                      Expanded(child: Text(_error!)),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _maxMobileContentWidth,
                  ),
                  child: _buildMobileConversationBody(),
                ),
              ),
            ),
            if (_selectedSessionId != null)
              _MobileExecutionStatusStrip(
                presentation: _buildSessionPresentation(
                  _selectedSessionView,
                  _selectedSessionContextStatus,
                  _selectedSessionId,
                ),
                latestUsage: _stickyLatestAssistantUsage(
                  _selectedProjectId,
                  _selectedSessionId,
                  _selectedSessionView,
                ),
                contextStatus: _selectedSessionContextStatus,
                loadingContextStatus: _loadingSessionContextStatus,
                maxWidth: _maxMobileContentWidth,
              ),
            _ComposerBar(
              controller: _composerController,
              focusNode: _composerFocusNode,
              locked: _compactingSession,
              enabled: _selectedSessionId != null,
              onSend: _sendPrompt,
              onVoiceInput: _showVoiceInputUnavailable,
              maxWidth: _maxMobileContentWidth,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCompactHeader() {
    final project = _selectedProjectSummary;
    final session = _selectedSessionSummary;
    final scheme = Theme.of(context).colorScheme;
    final title = switch ((project, session)) {
      (final ProjectSummary project, final SessionSummary session) =>
        '${project.name} / ${session.title}',
      (null, final SessionSummary session) => session.title,
      (final ProjectSummary project, null) => _txt(
        '${project.name} / 选择会话',
        '${project.name} / pick a session',
      ),
      _ => _txt('打开项目会话', 'Open a project session'),
    };

    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _spaceSm,
            _spaceXs,
            _spaceSm,
            _spaceSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _openMobilePrimaryDrawer,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: _mobileHeaderButtonSize,
                      height: _mobileHeaderButtonSize,
                    ),
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: _txt(
                      '打开项目、账户与设置',
                      'Open projects, account, and settings',
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: _BrandTitle(compact: true, centered: true),
                    ),
                  ),
                  IconButton(
                    onPressed: _selectedSessionId == null
                        ? null
                        : () => _openMobileSecondaryDrawer(),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: _mobileHeaderButtonSize,
                      height: _mobileHeaderButtonSize,
                    ),
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: _txt(
                      '打开会话详情与文件',
                      'Open session details and files',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _spaceXxs),
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: title,
                      child: _OverflowTitleText(
                        text: title,
                        style: _monoTextStyle(
                          Theme.of(context).textTheme.titleSmall,
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _spaceSm),
                  IconButton.filledTonal(
                    onPressed: _selectedProjectId == null
                        ? null
                        : _showCreateSessionSheet,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: _mobileHeaderButtonSize,
                      height: _mobileHeaderButtonSize,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    tooltip: _txt('新建会话', 'New session'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileConversationBody() {
    if (_loadingSessions && _sessions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final view = _selectedSessionView;
    if (_selectedSessionId == null || view == null) {
      return _buildMobileConversationEmptyState();
    }

    final presentation = _buildSessionPresentation(
      view,
      _selectedSessionContextStatus,
      _selectedSessionId,
    );

    return _MessagesPane(
      messages: presentation.visibleMessages,
      storageId: '${_selectedSessionId ?? 'session'}-messages',
      compactShell: true,
    );
  }

  Widget _buildMobileConversationEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_spaceLg),
        child: _PanelCard(
          padding: const EdgeInsets.all(_spaceMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _txt('等待会话', 'Waiting for a session'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: _spaceSm),
              Text(
                _txt(
                  '从左侧抽屉进入一个项目会话。',
                  'Open a project session from the left drawer.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileProjectSessionHierarchy({
    required bool closeDrawerOnSessionSelect,
  }) {
    final scheme = Theme.of(context).colorScheme;

    if (_loadingProjects && _projects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(_spaceLg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_projects.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(_spaceLg, 0, _spaceLg, _spaceLg),
        child: _PanelCard(
          child: Text(_txt('还没有已注册项目。', 'No registered projects yet.')),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(_spaceLg, 0, _spaceLg, _spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < _projects.length; index++) ...[
            Builder(
              builder: (context) {
                final project = _projects[index];
                final isSelectedProject = project.id == _selectedProjectId;
                final isExpanded = project.id == _expandedProjectId;
                final visibleSessions = isSelectedProject
                    ? _visibleRootSessions
                    : const <SessionSummary>[];
                final paginatedSessions = isSelectedProject
                    ? _paginatedVisibleRootSessions
                    : const <SessionSummary>[];
                final projectTone = switch (project.runtimeState) {
                  'running' => scheme.primary,
                  'starting' => scheme.secondary,
                  'error' => scheme.error,
                  _ => scheme.outline,
                };

                Widget sessionsChild;
                if (isExpanded && !isSelectedProject) {
                  sessionsChild = Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _spaceMd,
                      0,
                      _spaceMd,
                      _spaceMd,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: _spaceSm),
                        Expanded(
                          child: Text(
                            _txt(
                              '正在加载 ${project.name} 的会话…',
                              'Loading ${project.name} sessions…',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (isSelectedProject &&
                    _loadingSessions &&
                    _sessions.isEmpty) {
                  sessionsChild = Padding(
                    padding: EdgeInsets.fromLTRB(
                      _spaceMd,
                      0,
                      _spaceMd,
                      _spaceMd,
                    ),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                } else if (isSelectedProject && visibleSessions.isEmpty) {
                  sessionsChild = Padding(
                    padding: EdgeInsets.fromLTRB(
                      _spaceMd,
                      0,
                      _spaceMd,
                      _spaceMd,
                    ),
                    child: _InsetSurface(
                      child: Text(
                        _txt(
                          '这个项目还没有会话。',
                          'No sessions found for this project.',
                        ),
                      ),
                    ),
                  );
                } else {
                  sessionsChild = Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _spaceMd,
                      0,
                      _spaceMd,
                      _spaceMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: _spaceXs),
                        for (
                          var sessionIndex = 0;
                          sessionIndex < paginatedSessions.length;
                          sessionIndex++
                        ) ...[
                          _PanelCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _spaceMd,
                              vertical: _spaceXs + _spaceXxs,
                            ),
                            highlighted:
                                paginatedSessions[sessionIndex].id ==
                                _selectedSessionId,
                            tone: scheme.secondary,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(_radiusLg),
                                onTap: () {
                                  if (closeDrawerOnSessionSelect) {
                                    Navigator.of(context).pop();
                                  }
                                  unawaited(
                                    _openSessionFromSwitcher(
                                      paginatedSessions[sessionIndex].id,
                                    ),
                                  );
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            paginatedSessions[sessionIndex].title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: _spaceXxs),
                                          Text(
                                            _sessionPreviewLabel(
                                              paginatedSessions[sessionIndex],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: _monoTextStyle(
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: _spaceSm),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        _StatusChip(
                                          label:
                                              paginatedSessions[sessionIndex]
                                                  .status ??
                                              _txt('未知', 'unknown'),
                                          tone: scheme.secondary,
                                        ),
                                        const SizedBox(height: _spaceXs),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          onPressed:
                                              _deletingSessionId ==
                                                  paginatedSessions[sessionIndex]
                                                      .id
                                              ? null
                                              : () => _confirmDeleteSession(
                                                  paginatedSessions[sessionIndex],
                                                ),
                                          icon:
                                              _deletingSessionId ==
                                                  paginatedSessions[sessionIndex]
                                                      .id
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                ),
                                          tooltip: _txt(
                                            '删除会话',
                                            'Delete session',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (sessionIndex != paginatedSessions.length - 1)
                            const SizedBox(height: _spaceXs),
                        ],
                        if (_hasMoreVisibleRootSessions) ...[
                          const SizedBox(height: _spaceSm),
                          _buildSessionLoadMoreButton(
                            key: const ValueKey<String>(
                              'session-drawer-load-more',
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return _PanelCard(
                  padding: EdgeInsets.zero,
                  highlighted: isSelectedProject || isExpanded,
                  tone: projectTone,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(_radiusLg),
                          onTap: () => _toggleProjectHierarchy(project.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _spaceMd,
                              vertical: _spaceSm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isExpanded
                                      ? Icons.folder_open_rounded
                                      : Icons.folder_outlined,
                                  color: projectTone,
                                ),
                                const SizedBox(width: _spaceSm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        project.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: _spaceXxs),
                                      Text(
                                        _projectPreviewLabel(project),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _monoTextStyle(
                                          Theme.of(context).textTheme.bodySmall,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: _spaceXs),
                                      Wrap(
                                        spacing: _spaceXs,
                                        runSpacing: _spaceXs,
                                        children: [
                                          _StatusChip(
                                            label: project.runtimeState,
                                            tone: projectTone,
                                          ),
                                          if (isSelectedProject)
                                            _StatusChip(
                                              label: _txt(
                                                '${visibleSessions.length} 个会话',
                                                '${visibleSessions.length} sessions',
                                              ),
                                              tone: scheme.secondary,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: _spaceXs),
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: isExpanded
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      _spaceMd,
                                      0,
                                      _spaceMd,
                                      _spaceSm,
                                    ),
                                    child: Row(
                                      children: [
                                        if (project.opened)
                                          TextButton(
                                            onPressed: _openingProject
                                                ? null
                                                : () =>
                                                      _closeProject(project.id),
                                            child: Text(_txt('关闭', 'Close')),
                                          ),
                                        const Spacer(),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: _openingProject
                                              ? null
                                              : () =>
                                                    _deleteProject(project.id),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                          ),
                                          tooltip: _txt(
                                            '删除项目',
                                            'Delete project',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  sessionsChild,
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (index != _projects.length - 1) const SizedBox(height: _spaceSm),
          ],
        ],
      ),
    );
  }

  Widget _buildMobilePrimaryDrawer() {
    return Drawer(
      width: _mobileDrawerWidth(context),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _spaceLg,
                _spaceLg,
                _spaceLg,
                _spaceMd,
              ),
              child: const _BrandTitle(compact: true),
            ),
            _buildDrawerSectionLabel(
              title: _txt('项目', 'Projects'),
              trailing: IconButton(
                onPressed: _showProjectSheet,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: _txt('打开项目', 'Open project'),
              ),
            ),
            _buildMobileProjectSessionHierarchy(
              closeDrawerOnSessionSelect: true,
            ),
            _buildDrawerSectionLabel(
              title: _txt('账户与设置', 'Account & settings'),
            ),
            ListTile(
              leading: const Icon(Icons.settings_ethernet),
              title: Text(_txt('账户与连接', 'Account & connection')),
              onTap: () async {
                Navigator.of(context).pop();
                await _showConnectionSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(_txt('应用设置', 'App settings')),
              onTap: () {
                Navigator.of(context).pop();
                _showSettingsSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSecondaryDrawer() {
    return Drawer(
      width: _mobileDrawerWidth(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _spaceLg,
                _spaceLg,
                _spaceLg,
                _spaceSm,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _MobilePanelTabButton(
                      label: _txt('会话', 'Session'),
                      icon: Icons.notes_rounded,
                      badge: _mobileSessionBadge,
                      selected: _mobilePanelIndex == 0,
                      onTap: () {
                        setState(() {
                          _mobilePanelIndex = 0;
                        });
                      },
                    ),
                    const SizedBox(width: _spaceSm),
                    _MobilePanelTabButton(
                      label: _txt('文件', 'Files'),
                      icon: Icons.folder_open_outlined,
                      badge: _mobileFileBadge,
                      selected: _mobilePanelIndex == 1,
                      onTap: () {
                        setState(() {
                          _mobilePanelIndex = 1;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_loadingSessionView || _loadingSessionContextStatus)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: IndexedStack(
                index: _mobilePanelIndex,
                children: [
                  _MobilePanelScrollView(
                    storageId:
                        '${_selectedSessionId ?? 'session'}-mobile-session',
                    child: _buildMobileSessionDrawerContent(),
                  ),
                  _MobilePanelScrollView(
                    storageId:
                        '${_selectedSessionId ?? 'session'}-mobile-files',
                    child: _MobileFilesPanel(
                      sessionDirectory: _activeSessionDirectory,
                      fileSearchResult: _fileSearchResult,
                      selectedFilePreview: _selectedFilePreview,
                      selectedFileHit: _selectedFileHit,
                      recentFileHits: _recentFileHits,
                      loadingPreview: _loadingFilePreview,
                      onSearchPressed: _showFileWorkflowSheet,
                      onBrowsePressed: () =>
                          _showFileWorkflowSheet(initialTab: 'browse'),
                      onReturnToBrowser: _selectedFilePreviewSource == 'browse'
                          ? _returnToBrowsedDirectory
                          : null,
                      onOpenHit: _openFilePreview,
                      onBackToList: _returnToFileList,
                      onDownload: _downloadSelectedFile,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSessionDrawerContent() {
    final todos = _selectedSessionView?.todos ?? const <TodoItem>[];
    final hasAttention = _selectedAttentionCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMobileSessionOverview(),
        const SizedBox(height: _spaceLg),
        if (hasAttention) ...[
          _AttentionPanel(
            attention: _attention,
            sessionId: _selectedSessionId,
            respondingAttention: _respondingAttention,
            onQuestionAnswer: _replyQuestion,
            onQuestionReject: _rejectQuestion,
            onPermissionReply: _replyPermission,
          ),
          const SizedBox(height: _spaceLg),
        ],
        if (todos.isNotEmpty) _TodosPanel(todos: todos),
      ],
    );
  }

  Widget _buildDrawerSectionLabel({required String title, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _spaceLg,
        _spaceLg,
        _spaceLg,
        _spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSessionOverview() {
    final session = _selectedSessionSummary;
    final contextStatus = _selectedSessionContextStatus;

    if (session == null) {
      return _PanelCard(child: Text(_txt('打开会话。', 'Open a session.')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PanelCard(
          padding: const EdgeInsets.all(_spaceMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  session.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: _spaceMd),
              _StatusChip(
                label:
                    contextStatus?.status ??
                    session.status ??
                    _txt('未知', 'unknown'),
              ),
            ],
          ),
        ),
        const SizedBox(height: _spaceLg),
        _RuntimePanel(
          latestUsage: _stickyLatestAssistantUsage(
            _selectedProjectId,
            _selectedSessionId,
            _selectedSessionView,
          ),
          contextStatus: contextStatus,
          loadingContextStatus: _loadingSessionContextStatus,
          questions: _attention.questions,
          permissions: _attention.permissions,
          sessionId: _selectedSessionId,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

        if (!isWide) {
          return _buildMobileScaffold();
        }

        return Scaffold(
          appBar: AppBar(
            title: const _BrandTitle(),
            actions: [
              IconButton(
                onPressed: () => _showBuildInfo(),
                icon: const Icon(Icons.info_outline),
                tooltip: 'About ChewCode',
              ),
              IconButton(
                onPressed: _showConnectionSheet,
                icon: const Icon(Icons.settings_ethernet),
                tooltip: 'Connection settings',
              ),
              IconButton(
                onPressed: _showCreateSessionSheet,
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: 'New session',
              ),
              IconButton(
                onPressed: _refreshWorkspace,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh workspace',
              ),
            ],
          ),
          body: Column(
            children: [
              _ConnectionBanner(label: _connectionLabel, error: _error),
              if (!isWide) _buildMobileTopSwitchers(),
              Expanded(
                child: isWide
                    ? Row(
                        children: [
                          SizedBox(
                            width: _sessionDrawerWidth,
                            child: _buildSessionListPane(title: 'Sessions'),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: _buildSessionDetail()),
                        ],
                      )
                    : _buildMobileWorkspaceBody(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBuildInfo() {
    showAboutDialog(
      context: context,
      applicationName: 'ChewCode / 口香糖',
      applicationVersion: _buildVersionLabel,
      applicationLegalese: _txt(
        '单用户公开测试控制壳层',
        'Single-user public beta control shell',
      ),
    );
  }

  Future<void> _showSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: _spaceLg,
            right: _spaceLg,
            top: _spaceLg,
            bottom: MediaQuery.of(context).viewInsets.bottom + _spaceLg,
          ),
          child: StatefulBuilder(
            builder: (context, modalSetState) {
              return ValueListenableBuilder<String>(
                valueListenable: _uiLanguageNotifier,
                builder: (context, language, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _txt('应用设置', 'App settings'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: _spaceSm),
                      Text(
                        _txt(
                          '默认界面语言为中文；你也可以在这里切换到 English。',
                          'Chinese is the default UI language; you can switch to English here.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: _spaceLg),
                      _SubsectionCard(
                        title: _txt('界面语言', 'UI language'),
                        subtitle: _txt(
                          '切换后立即生效。',
                          'Changes apply immediately.',
                        ),
                        tone: Theme.of(context).colorScheme.primary,
                        child: Wrap(
                          spacing: _spaceSm,
                          runSpacing: _spaceSm,
                          children: [
                            ChoiceChip(
                              label: const Text('中文'),
                              selected: language == 'zh',
                              onSelected: (_) async {
                                await _setUiLanguage('zh');
                                modalSetState(() {});
                              },
                            ),
                            ChoiceChip(
                              label: const Text('English'),
                              selected: language == 'en',
                              onSelected: (_) async {
                                await _setUiLanguage('en');
                                modalSetState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: _spaceMd),
                      _SubsectionCard(
                        title: _txt('构建信息', 'Build info'),
                        subtitle: _txt(
                          '保持现有项目、会话和文件流程的只读手机壳层。',
                          'A read-only mobile shell that preserves the current project, session, and file flows.',
                        ),
                        tone: Theme.of(context).colorScheme.secondary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RuntimeRow(
                              label: _txt('版本', 'Version'),
                              value: _buildVersionLabel,
                            ),
                            _RuntimeRow(
                              label: _txt('语言', 'Language'),
                              value: language == 'en' ? 'English' : '中文',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: _spaceLg),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(_txt('完成', 'Done')),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showConnectionSheet() async {
    final navigator = Navigator.of(context);
    _bridgeUrlController.text = _bridgeUrl;
    _bridgeTokenController.text = _bridgeToken;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, modalSetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _txt('连接设置', 'Connection settings'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bridgeUrlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: _txt('Bridge 地址', 'Bridge URL'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bridgeTokenController,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: _txt('访问令牌', 'Access token'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_recentBridgeUrls.isNotEmpty) ...[
                    Text(
                      _txt('最近连接过的地址', 'Recent endpoints'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final recentUrl in _recentBridgeUrls)
                          ActionChip(
                            label: Text(recentUrl),
                            onPressed: () {
                              modalSetState(() {
                                _bridgeUrlController.text = recentUrl;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _checkingBridgeHealth
                            ? null
                            : () async {
                                modalSetState(() {});
                                await _testBridgeHealth();
                                modalSetState(() {});
                              },
                        icon: _checkingBridgeHealth
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.health_and_safety_outlined),
                        label: Text(_txt('测试', 'Test')),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _switchingBridge ? null : navigator.pop,
                        child: Text(_txt('关闭', 'Close')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _switchingBridge
                            ? null
                            : () async {
                                await _applyBridgeUrl(
                                  _bridgeUrlController.text,
                                );
                                if (mounted) {
                                  navigator.pop();
                                }
                              },
                        child: Text(
                          _switchingBridge
                              ? _txt('连接中…', 'Connecting…')
                              : _txt('连接', 'Connect'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showCreateSessionSheet() async {
    final navigator = Navigator.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, modalSetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _txt('开始一个新会话', 'Start a new session'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newSessionTitleController,
                    decoration: InputDecoration(
                      labelText: _txt('会话标题', 'Session title'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newSessionPromptController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: _txt('初始提示词（可选）', 'Initial prompt (optional)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: _creatingSession
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(_txt('取消', 'Cancel')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _creatingSession
                            ? null
                            : () async {
                                modalSetState(() {});
                                await _createSession();
                                if (mounted) {
                                  navigator.pop();
                                }
                              },
                        child: Text(
                          _creatingSession
                              ? _txt('创建中…', 'Creating…')
                              : _txt('创建', 'Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showProjectSheet() async {
    final navigator = Navigator.of(context);
    _projectPathController.clear();
    _projectNameController.clear();
    await _discoverProjects();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (context, modalSetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _txt('打开项目', 'Open project'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_projectCandidates.isNotEmpty) ...[
                      if (_projectAllowedRoots.isNotEmpty) ...[
                        Text(
                          _txt('允许的根目录', 'Allowed roots'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final root in _projectAllowedRoots)
                              _StatusChip(label: root),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        _txt('发现的项目', 'Discovered projects'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _projectCandidates.length,
                          itemBuilder: (context, index) {
                            final candidate = _projectCandidates[index];
                            return ListTile(
                              title: Text(candidate.name),
                              subtitle: Text(
                                '${candidate.path}\nroot: ${candidate.sourceRoot}',
                              ),
                              isThreeLine: true,
                              onTap: () async {
                                _projectPathController.text = candidate.path;
                                _projectNameController.text = candidate.name;
                                await _registerProject();
                                if (mounted) {
                                  navigator.pop();
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _projectPathController,
                      decoration: InputDecoration(
                        labelText: _txt('远程项目路径', 'Remote project path'),
                        helperText: _txt(
                          '路径必须位于上面的允许根目录之内，并且看起来像一个真实工作区。',
                          'Path must stay inside one of the allowed roots above and look like a real workspace.',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _projectNameController,
                      decoration: InputDecoration(
                        labelText: _txt('显示名称（可选）', 'Display name (optional)'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _discoveringProjects
                              ? null
                              : () async {
                                  await _discoverProjects();
                                  modalSetState(() {});
                                },
                          child: Text(
                            _discoveringProjects
                                ? _txt('扫描中…', 'Scanning…')
                                : _txt('重新扫描', 'Rescan'),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: navigator.pop,
                          child: Text(_txt('关闭', 'Close')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _registeringProject
                              ? null
                              : () async {
                                  await _registerProject();
                                  if (mounted) {
                                    navigator.pop();
                                  }
                                },
                          child: Text(
                            _registeringProject
                                ? _txt('打开中…', 'Opening…')
                                : _txt('打开项目', 'Open project'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionListPane({
    String? title,
    bool closeDrawerOnSelect = false,
    bool showConnectionHint = false,
  }) {
    if (_loadingProjects && _projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibleSessions = _visibleRootSessions;
    final paginatedSessions = _paginatedVisibleRootSessions;

    final content = visibleSessions.isEmpty
        ? const Center(child: Text('No sessions found for this project.'))
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              _spaceLg,
              _spaceSm,
              _spaceLg,
              _spaceLg,
            ),
            itemCount:
                paginatedSessions.length + (_hasMoreVisibleRootSessions ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: _spaceSm),
            itemBuilder: (context, index) {
              if (index == paginatedSessions.length) {
                return _buildSessionLoadMoreButton(
                  key: const ValueKey<String>('wide-session-pane-load-more'),
                );
              }

              final session = paginatedSessions[index];
              final selected = session.id == _selectedSessionId;
              return _PanelCard(
                highlighted: selected,
                padding: const EdgeInsets.all(_spaceMd),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: selected,
                  title: Text(session.title),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: _spaceXs),
                    child: Text(
                      _sessionPreviewLabel(session),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: _StatusChip(label: session.status ?? 'unknown'),
                  onTap: () {
                    if (closeDrawerOnSelect) {
                      Navigator.of(context).pop();
                    }
                    unawaited(_openSessionFromSwitcher(session.id));
                  },
                ),
              );
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || showConnectionHint)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _spaceLg,
              _spaceLg,
              _spaceLg,
              _spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (showConnectionHint) ...[
                  const SizedBox(height: _spaceSm),
                  Text(
                    _selectedProjectId == null
                        ? 'Pick a project first, then resume one of its sessions.'
                        : 'Pick a session to resume the current project workspace.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        _buildProjectListPane(closeDrawerOnSelect: closeDrawerOnSelect),
        const Divider(height: 1),
        if (_loadingSessions && _sessions.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildProjectListPane({required bool closeDrawerOnSelect}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_spaceLg, 0, _spaceLg, _spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Projects', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                onPressed: _showProjectSheet,
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: 'Open project',
              ),
            ],
          ),
          const SizedBox(height: _spaceSm),
          if (_projects.isEmpty)
            const Text('No registered projects yet.')
          else
            Wrap(
              spacing: _spaceSm,
              runSpacing: _spaceSm,
              children: [
                for (final project in _projects)
                  _ProjectChip(
                    project: project,
                    selected: project.id == _selectedProjectId,
                    onOpen: () async {
                      if (closeDrawerOnSelect) {
                        Navigator.of(context).pop();
                      }
                      await _openProject(project.id);
                    },
                    onClose: project.opened
                        ? () => _closeProject(project.id)
                        : null,
                    onDelete: () => _deleteProject(project.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSessionDetail({bool compact = false}) {
    if (_selectedSessionId == null) {
      return const Center(child: Text('Select a session to inspect.'));
    }

    if (_loadingSessionView && _selectedSessionView == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final view = _selectedSessionView;
    if (view == null) {
      return const Center(child: Text('Session view unavailable.'));
    }
    final presentation = _buildSessionPresentation(
      view,
      _selectedSessionContextStatus,
      _selectedSessionId,
    );

    final header = _SessionHeader(
      session: view.session,
      contextStatus: _selectedSessionContextStatus,
      loadingContextStatus: _loadingSessionContextStatus,
      onBack: compact
          ? () {
              setState(() {
                _selectedSessionId = null;
                _selectedSessionView = null;
              });
            }
          : null,
    );

    return Column(
      children: [
        header,
        if (_loadingSessionView || _loadingSessionContextStatus)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: compact
              ? Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxMobileContentWidth,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            _spaceLg,
                            _spaceLg,
                            _spaceLg,
                            _spaceMd,
                          ),
                          child: _ExecutionSummaryCard(
                            latestUsage: _stickyLatestAssistantUsage(
                              _selectedProjectId,
                              _selectedSessionId,
                              view,
                            ),
                            contextStatus: _selectedSessionContextStatus,
                            loadingContextStatus: _loadingSessionContextStatus,
                            questions: _attention.questions,
                            permissions: _attention.permissions,
                            sessionId: _selectedSessionId,
                          ),
                        ),
                        Expanded(
                          child: _MessagesPane(
                            messages: presentation.visibleMessages,
                            storageId:
                                '${_selectedSessionId ?? 'session'}-messages',
                            compactShell: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _MessagesPane(
                              messages: presentation.visibleMessages,
                              storageId:
                                  '${_selectedSessionId ?? 'session'}-messages',
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLow,
                              padding: const EdgeInsets.fromLTRB(
                                _spaceLg,
                                _spaceSm,
                                _spaceLg,
                                _spaceLg,
                              ),
                              child: SingleChildScrollView(
                                child: _FilesPanel(
                                  sessionDirectory: _activeSessionDirectory,
                                  fileSearchResult: _fileSearchResult,
                                  selectedFilePreview: _selectedFilePreview,
                                  selectedFileHit: _selectedFileHit,
                                  recentFileHits: _recentFileHits,
                                  loadingPreview: _loadingFilePreview,
                                  onSearchPressed: _showFileWorkflowSheet,
                                  onBrowsePressed: () => _showFileWorkflowSheet(
                                    initialTab: 'browse',
                                  ),
                                  onDownload: _downloadSelectedFile,
                                  compact: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: _SidebarPane(
                        latestUsage: _stickyLatestAssistantUsage(
                          _selectedProjectId,
                          _selectedSessionId,
                          view,
                        ),
                        contextStatus: _selectedSessionContextStatus,
                        loadingContextStatus: _loadingSessionContextStatus,
                        todos: view.todos,
                        attention: _attention,
                        sessionId: _selectedSessionId,
                        respondingAttention: _respondingAttention,
                        onQuestionAnswer: _replyQuestion,
                        onQuestionReject: _rejectQuestion,
                        onPermissionReply: _replyPermission,
                      ),
                    ),
                  ],
                ),
        ),
        _ComposerBar(
          controller: _composerController,
          locked: _compactingSession,
          enabled: _selectedSessionId != null,
          onSend: _sendPrompt,
          onVoiceInput: _showVoiceInputUnavailable,
        ),
      ],
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.label, required this.error});

  final String label;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = error == null ? scheme.secondary : scheme.error;

    return Material(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _spaceLg,
          vertical: _spaceMd,
        ),
        child: Row(
          children: [
            Icon(
              error == null ? Icons.cloud_done : Icons.error_outline,
              color: tone,
            ),
            const SizedBox(width: _spaceMd),
            Expanded(child: Text(error == null ? label : '$label · $error')),
          ],
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({this.compact = false, this.centered = false});

  final bool compact;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final language = _uiLanguageNotifier.value;
    final primaryLabel = language == 'zh' ? _productChineseName : _productName;
    final secondaryLabel = language == 'zh'
        ? _productName
        : _productChineseName;

    if (compact) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              primaryLabel,
              style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              secondaryLabel,
              style: theme.labelSmall?.copyWith(
                color: muted,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primaryLabel,
          style: theme.titleLarge,
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
        Text(
          secondaryLabel,
          style: theme.labelMedium?.copyWith(color: muted, letterSpacing: 0.8),
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
      ],
    );
  }
}

class _OverflowTitleText extends StatelessWidget {
  const _OverflowTitleText({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: style,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.session,
    required this.contextStatus,
    required this.loadingContextStatus,
    this.onBack,
  });

  final SessionSummary session;
  final SessionContextStatus? contextStatus;
  final bool loadingContextStatus;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(_spaceLg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onBack != null)
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
            Expanded(
              child: Text(
                session.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: _spaceMd),
            _StatusChip(
              label:
                  contextStatus?.status ??
                  session.status ??
                  _tr(context, '未知', 'unknown'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesPane extends StatefulWidget {
  const _MessagesPane({
    required this.messages,
    this.storageId,
    this.compactShell = false,
  });

  final List<ConversationMessage> messages;
  final String? storageId;
  final bool compactShell;

  @override
  State<_MessagesPane> createState() => _MessagesPaneState();
}

class _MessagesPaneState extends State<_MessagesPane> {
  static const _latestScrollThreshold = 72.0;

  late final ScrollController _scrollController;
  bool _stickToLatest = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScrollChanged);
    _scheduleScrollToLatest();
  }

  @override
  void didUpdateWidget(covariant _MessagesPane oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.storageId != widget.storageId) {
      _stickToLatest = true;
      _scheduleScrollToLatest();
      return;
    }

    if (widget.messages.length != oldWidget.messages.length && _stickToLatest) {
      _scheduleScrollToLatest();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScrollChanged)
      ..dispose();
    super.dispose();
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    _stickToLatest = position.pixels <= _latestScrollThreshold;
  }

  void _scheduleScrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    if (messages.isEmpty) {
      return Center(
        child: Text(
          _tr(context, '这个会话还没有消息。', 'No messages for this session yet.'),
        ),
      );
    }

    final listPadding = const EdgeInsets.fromLTRB(
      _spaceMd,
      _spaceLg,
      _spaceMd,
      _spaceLg,
    );

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      interactive: true,
      thickness: 10,
      radius: const Radius.circular(999),
      child: ListView.builder(
        key: widget.storageId == null
            ? null
            : PageStorageKey<String>(widget.storageId!),
        controller: _scrollController,
        reverse: true,
        physics: const ClampingScrollPhysics(),
        cacheExtent: 1200,
        padding: listPadding,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[messages.length - 1 - index];
          return Padding(
            key: ValueKey<String>('message-${message.id}'),
            padding: const EdgeInsets.only(bottom: _spaceSm),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: widget.compactShell ? 700 : double.infinity,
                ),
                child: RepaintBoundary(
                  child: _ConversationEntryCard(
                    message: message,
                    compactShell: widget.compactShell,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConversationEntryCard extends StatelessWidget {
  const _ConversationEntryCard({
    required this.message,
    required this.compactShell,
  });

  final ConversationMessage message;
  final bool compactShell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = message.role.trim().toLowerCase();
    final tone = switch (role) {
      'assistant' => scheme.primary,
      'user' => scheme.tertiary,
      'system' => scheme.secondary,
      _ => scheme.outline,
    };

    return _PanelCard(
      highlighted: true,
      tone: tone,
      padding: const EdgeInsets.all(_spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusChip(label: message.role.toUpperCase(), tone: tone),
              const SizedBox(width: _spaceSm),
              if (message.error != null)
                _StatusChip(label: 'error', tone: scheme.error),
              const Spacer(),
              if (message.createdAt != null)
                Flexible(
                  child: Text(
                    message.createdAt!,
                    style: _monoTextStyle(
                      Theme.of(context).textTheme.bodySmall,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
          const SizedBox(height: _spaceSm),
          for (var index = 0; index < message.parts.length; index++) ...[
            _ConversationMessagePart(
              part: message.parts[index],
              tone: tone,
              compactShell: compactShell,
            ),
            if (index != message.parts.length - 1)
              const SizedBox(height: _spaceSm),
          ],
          if (message.error != null) ...[
            const SizedBox(height: _spaceSm),
            _InsetSurface(
              child: SelectableText(
                message.error!,
                style: _monoTextStyle(
                  Theme.of(context).textTheme.bodyMedium,
                  color: scheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConversationMessagePart extends StatelessWidget {
  const _ConversationMessagePart({
    required this.part,
    required this.tone,
    required this.compactShell,
  });

  final ConversationPart part;
  final Color tone;
  final bool compactShell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = part.type.trim().toLowerCase();
    final display = part.display.trim().toLowerCase();

    if (type == 'text') {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(_radiusSm),
          border: Border.all(color: tone.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compactShell ? _spaceSm : _spaceMd,
            vertical: _spaceSm,
          ),
          child: _MarkdownContent(content: part.text ?? ''),
        ),
      );
    }

    if (type == 'file') {
      final label = part.name ?? part.path ?? part.uri ?? part.text ?? 'file';
      final detail = part.path ?? part.uri;
      return _InsetSurface(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.insert_drive_file_outlined, color: tone, size: 18),
            const SizedBox(width: _spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detail != null && detail.isNotEmpty) ...[
                    const SizedBox(height: _spaceXxs),
                    Text(
                      detail,
                      style: _monoTextStyle(
                        Theme.of(context).textTheme.bodySmall,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (display == 'collapsed') {
      final label = switch (type) {
        'reasoning' => 'reasoning',
        'tool' => part.title ?? part.tool ?? 'tool',
        _ => type,
      };
      final detail =
          part.text ?? part.description ?? part.title ?? part.tool ?? part.name;
      return _InsetSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusChip(label: label, tone: scheme.outline),
            if (detail != null && detail.isNotEmpty) ...[
              const SizedBox(height: _spaceSm),
              SelectableText(
                detail,
                style: _monoTextStyle(
                  Theme.of(context).textTheme.bodySmall,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _SidebarPane extends StatelessWidget {
  const _SidebarPane({
    required this.latestUsage,
    required this.contextStatus,
    required this.loadingContextStatus,
    required this.todos,
    required this.attention,
    required this.sessionId,
    required this.respondingAttention,
    required this.onQuestionAnswer,
    required this.onQuestionReject,
    required this.onPermissionReply,
  });

  final UsageMetrics? latestUsage;
  final SessionContextStatus? contextStatus;
  final bool loadingContextStatus;
  final List<TodoItem> todos;
  final AttentionState attention;
  final String? sessionId;
  final bool respondingAttention;
  final Future<void> Function(PendingQuestion question, String answer)
  onQuestionAnswer;
  final Future<void> Function(PendingQuestion question) onQuestionReject;
  final Future<void> Function(PendingPermission permission, String reply)
  onPermissionReply;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        key: const PageStorageKey<String>('wide-sidebar-pane'),
        padding: const EdgeInsets.all(_spaceLg),
        children: [
          _RuntimePanel(
            latestUsage: latestUsage,
            contextStatus: contextStatus,
            loadingContextStatus: loadingContextStatus,
            questions: attention.questions,
            permissions: attention.permissions,
            sessionId: sessionId,
          ),
          const SizedBox(height: _spaceLg),
          _AttentionPanel(
            attention: attention,
            sessionId: sessionId,
            respondingAttention: respondingAttention,
            onQuestionAnswer: onQuestionAnswer,
            onQuestionReject: onQuestionReject,
            onPermissionReply: onPermissionReply,
          ),
          const SizedBox(height: _spaceLg),
          _TodosPanel(todos: todos),
        ],
      ),
    );
  }
}

class _MobileFilesPanel extends StatelessWidget {
  const _MobileFilesPanel({
    required this.sessionDirectory,
    required this.fileSearchResult,
    required this.selectedFilePreview,
    required this.selectedFileHit,
    required this.recentFileHits,
    required this.loadingPreview,
    required this.onSearchPressed,
    required this.onBrowsePressed,
    this.onReturnToBrowser,
    required this.onOpenHit,
    required this.onBackToList,
    required this.onDownload,
  });

  final String? sessionDirectory;
  final FileSearchResult? fileSearchResult;
  final FilePreview? selectedFilePreview;
  final FileSearchHit? selectedFileHit;
  final List<FileSearchHit> recentFileHits;
  final bool loadingPreview;
  final Future<void> Function() onSearchPressed;
  final Future<void> Function() onBrowsePressed;
  final Future<void> Function()? onReturnToBrowser;
  final Future<void> Function(FileSearchHit hit) onOpenHit;
  final VoidCallback onBackToList;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = selectedFilePreview;

    if (preview != null) {
      return _PanelSection(
        title: _tr(context, '文件', 'Files'),
        trailing: _StatusChip(
          label: _tr(context, '正在预览', 'Preview open'),
          tone: scheme.primary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelCard(
              padding: const EdgeInsets.all(_spaceMd),
              child: Wrap(
                spacing: _spaceSm,
                runSpacing: _spaceSm,
                children: [
                  FilledButton.icon(
                    onPressed: onBackToList,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(_tr(context, '返回列表', 'Back to list')),
                  ),
                  if (onReturnToBrowser != null)
                    FilledButton.tonalIcon(
                      onPressed: onReturnToBrowser,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: Text(_tr(context, '回到目录浏览', 'Return to browser')),
                    ),
                  OutlinedButton.icon(
                    onPressed: onSearchPressed,
                    icon: const Icon(Icons.search),
                    label: Text(_tr(context, '搜索文件', 'Search files')),
                  ),
                  OutlinedButton.icon(
                    onPressed: onBrowsePressed,
                    icon: const Icon(Icons.folder_copy_outlined),
                    label: Text(_tr(context, '浏览文件夹', 'Browse folders')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _spaceMd),
            _FilePreviewCard(
              sessionDirectory: sessionDirectory,
              selectedFilePreview: preview,
              selectedFileHit: selectedFileHit,
              onDownload: onDownload,
            ),
          ],
        ),
      );
    }

    return _PanelSection(
      title: _tr(context, '文件', 'Files'),
      trailing: fileSearchResult == null
          ? null
          : _StatusChip(
              label: _tr(
                context,
                '${fileSearchResult!.items.length} 个命中',
                '${fileSearchResult!.items.length} hits',
              ),
              tone: scheme.secondary,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelCard(
            padding: const EdgeInsets.all(_spaceMd),
            highlighted: true,
            tone: scheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr(
                    context,
                    '先整理文件列表，再打开预览',
                    'Build a file list, then open a preview',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: _spaceSm),
                Text(
                  _tr(
                    context,
                    '先用搜索或浏览收集候选文件，再点下面的结果打开只读预览。',
                    'Use search or browse to collect candidate files, then tap a result below to open the read-only preview.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (sessionDirectory != null) ...[
                  const SizedBox(height: _spaceMd),
                  _InsetSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr(context, '当前会话工作区根目录', 'Session workspace root'),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: scheme.primary),
                        ),
                        const SizedBox(height: _spaceXs),
                        SelectableText(
                          sessionDirectory!,
                          style: _monoTextStyle(
                            Theme.of(context).textTheme.bodySmall,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: _spaceMd),
                Wrap(
                  spacing: _spaceSm,
                  runSpacing: _spaceSm,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: onSearchPressed,
                      icon: const Icon(Icons.search),
                      label: Text(_tr(context, '搜索文件', 'Search files')),
                    ),
                    OutlinedButton.icon(
                      onPressed: onBrowsePressed,
                      icon: const Icon(Icons.folder_copy_outlined),
                      label: Text(_tr(context, '浏览文件夹', 'Browse folders')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: _spaceMd),
          if (loadingPreview)
            _PanelCard(
              child: Text(_tr(context, '正在加载文件预览…', 'Loading file preview...')),
            ),
          if (fileSearchResult != null) ...[
            _SubsectionCard(
              title: _tr(context, '搜索结果', 'Search results'),
              subtitle: _tr(
                context,
                '点一个结果就能从列表进入预览阶段。',
                'Tap a result to move from the list into the preview stage.',
              ),
              tone: scheme.secondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: _spaceSm,
                    runSpacing: _spaceSm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusChip(
                        label: fileSearchResult!.mode == 'text'
                            ? _tr(context, '文本搜索', 'text search')
                            : _tr(context, '文件搜索', 'file search'),
                        tone: scheme.secondary,
                      ),
                      _MetricPill(
                        label: _tr(context, '命中', 'Hits'),
                        value: '${fileSearchResult!.items.length}',
                        tone: scheme.secondary,
                      ),
                      SelectableText(
                        '${_tr(context, '查询', 'Query')}: ${fileSearchResult!.query}',
                        style: _monoTextStyle(
                          Theme.of(context).textTheme.bodySmall,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (fileSearchResult!.items.isEmpty) ...[
                    const SizedBox(height: _spaceMd),
                    Text(
                      _tr(
                        context,
                        '没有文件匹配这个查询。',
                        'No files matched this query.',
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: _spaceMd),
                    for (
                      var index = 0;
                      index < fileSearchResult!.items.length;
                      index++
                    ) ...[
                      _FileSearchResultCard(
                        hit: fileSearchResult!.items[index],
                        workspaceRoot: sessionDirectory,
                        onTap: () => onOpenHit(fileSearchResult!.items[index]),
                      ),
                      if (index != fileSearchResult!.items.length - 1)
                        const SizedBox(height: _spaceSm),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: _spaceMd),
          ],
          if (recentFileHits.isNotEmpty)
            _SubsectionCard(
              title: _tr(context, '最近预览', 'Recent previews'),
              subtitle: _tr(
                context,
                '快速回到你刚查看过的文件。',
                'Jump back into files you already inspected.',
              ),
              tone: scheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (
                    var index = 0;
                    index < recentFileHits.length;
                    index++
                  ) ...[
                    _FileSearchResultCard(
                      hit: recentFileHits[index],
                      workspaceRoot: sessionDirectory,
                      onTap: () => onOpenHit(recentFileHits[index]),
                    ),
                    if (index != recentFileHits.length - 1)
                      const SizedBox(height: _spaceSm),
                  ],
                ],
              ),
            ),
          if (fileSearchResult == null &&
              recentFileHits.isEmpty &&
              !loadingPreview)
            const _PanelCard(
              child: Text('还没有活动文件列表 / No file list is active yet.'),
            ),
        ],
      ),
    );
  }
}

class _FilesPanel extends StatelessWidget {
  const _FilesPanel({
    required this.sessionDirectory,
    required this.fileSearchResult,
    required this.selectedFilePreview,
    required this.selectedFileHit,
    required this.recentFileHits,
    required this.loadingPreview,
    required this.onSearchPressed,
    required this.onBrowsePressed,
    required this.onDownload,
    this.compact = false,
  });

  final String? sessionDirectory;
  final FileSearchResult? fileSearchResult;
  final FilePreview? selectedFilePreview;
  final FileSearchHit? selectedFileHit;
  final List<FileSearchHit> recentFileHits;
  final bool loadingPreview;
  final Future<void> Function() onSearchPressed;
  final Future<void> Function() onBrowsePressed;
  final Future<void> Function() onDownload;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final preview = selectedFilePreview;
    final scheme = Theme.of(context).colorScheme;

    return _PanelSection(
      title: _tr(context, '文件', 'Files'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: _spaceSm,
            runSpacing: _spaceSm,
            children: [
              FilledButton.tonalIcon(
                onPressed: onSearchPressed,
                icon: const Icon(Icons.search),
                label: Text(_tr(context, '搜索 / 浏览', 'Search / browse')),
              ),
              OutlinedButton.icon(
                onPressed: onBrowsePressed,
                icon: const Icon(Icons.folder_copy_outlined),
                label: Text(_tr(context, '浏览文件', 'Browse files')),
              ),
            ],
          ),
          if (fileSearchResult != null) ...[
            const SizedBox(height: _spaceMd),
            _InsetSurface(
              child: Wrap(
                spacing: _spaceSm,
                runSpacing: _spaceSm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusChip(
                    label: fileSearchResult!.mode == 'text'
                        ? _tr(context, '文本搜索', 'text search')
                        : _tr(context, '文件搜索', 'file search'),
                    tone: scheme.secondary,
                  ),
                  _MetricPill(
                    label: _tr(context, '命中', 'Hits'),
                    value: '${fileSearchResult!.items.length}',
                    tone: scheme.secondary,
                  ),
                  SelectableText(
                    '${_tr(context, '查询', 'Query')}: ${fileSearchResult!.query}',
                    style: _monoTextStyle(
                      Theme.of(context).textTheme.bodySmall,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: _spaceMd),
          if (loadingPreview)
            _PanelCard(
              child: Text(_tr(context, '正在加载文件预览…', 'Loading file preview...')),
            )
          else if (preview == null)
            _PanelCard(
              child: Text(
                _tr(
                  context,
                  '先在当前会话工作区里搜索文件或文本，再在这里打开只读预览。浏览文件会沿着真实的会话根目录树前进，但不会把这个壳层变成编辑器。',
                  'Search for a file or text match inside the current session workspace, then open a read-only preview here. Browse files to walk the real session-root directory tree without turning this shell into an editor.',
                ),
              ),
            )
          else
            _FilePreviewCard(
              sessionDirectory: sessionDirectory,
              selectedFilePreview: preview,
              selectedFileHit: selectedFileHit,
              onDownload: onDownload,
              compact: compact,
            ),
        ],
      ),
    );
  }
}

class _FilePreviewCard extends StatelessWidget {
  const _FilePreviewCard({
    required this.sessionDirectory,
    required this.selectedFilePreview,
    required this.selectedFileHit,
    required this.onDownload,
    this.compact = false,
  });

  final String? sessionDirectory;
  final FilePreview selectedFilePreview;
  final FileSearchHit? selectedFileHit;
  final Future<void> Function() onDownload;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final preview = selectedFilePreview;
    final scheme = Theme.of(context).colorScheme;
    final relativePath = _displayPathRelativeTo(preview.path, sessionDirectory);

    return _PanelCard(
      padding: const EdgeInsets.all(_spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InsetSurface(
            child: Row(
              children: [
                _StatusChip(
                  label: preview.isBinary
                      ? _tr(context, '只读二进制', 'readonly binary')
                      : _looksLikeMarkdown(preview)
                      ? _tr(context, 'markdown 预览', 'markdown preview')
                      : _tr(context, 'NORMAL · 只读', 'NORMAL · readonly'),
                  tone: scheme.primary,
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _tr(context, 'vim 风格只读视图', 'vim-like readonly view'),
                      style: _monoTextStyle(
                        Theme.of(context).textTheme.bodySmall,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: _spaceXs),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: onDownload,
                      tooltip: _tr(context, '下载文件', 'Download file'),
                      icon: const Icon(Icons.download_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: _spaceMd),
          Text(
            preview.displayName,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: _spaceSm),
          SelectableText(
            relativePath,
            style: _monoTextStyle(
              Theme.of(context).textTheme.bodySmall,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (sessionDirectory != null && relativePath != preview.path) ...[
            const SizedBox(height: _spaceXs),
            SelectableText(
              preview.path,
              style: _monoTextStyle(
                Theme.of(context).textTheme.bodySmall,
                color: scheme.outline,
              ),
            ),
          ],
          const SizedBox(height: _spaceSm),
          Wrap(
            spacing: _spaceSm,
            runSpacing: _spaceSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (preview.language != null && preview.language!.isNotEmpty)
                _StatusChip(label: preview.language!, tone: scheme.primary),
              if (preview.lineCount != null)
                _StatusChip(
                  label: _tr(
                    context,
                    '${preview.lineCount} 行',
                    '${preview.lineCount} lines',
                  ),
                  tone: scheme.secondary,
                ),
              if (preview.sizeBytes != null)
                _StatusChip(
                  label: _formatBytes(preview.sizeBytes!),
                  tone: scheme.outline,
                ),
              if (selectedFileHit?.line != null)
                _StatusChip(
                  label: _displayFileLocation(
                    selectedFileHit!.line,
                    selectedFileHit!.column,
                  ),
                  tone: scheme.tertiary,
                ),
              if (preview.isBinary)
                _StatusChip(
                  label: _tr(context, '二进制', 'binary'),
                  tone: scheme.error,
                ),
              if (preview.isTruncated)
                _StatusChip(
                  label: _tr(context, '已截断', 'truncated'),
                  tone: scheme.tertiary,
                ),
            ],
          ),
          if (selectedFileHit != null) ...[
            const SizedBox(height: _spaceSm),
            _InsetSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedFileHit!.kind == 'text'
                        ? _tr(context, '从文本匹配打开', 'Opened from text match')
                        : _tr(
                            context,
                            '从文件名匹配打开',
                            'Opened from filename match',
                          ),
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: scheme.primary),
                  ),
                  const SizedBox(height: _spaceXs),
                  SelectableText(
                    selectedFileHit!.previewText == null ||
                            selectedFileHit!.previewText!.isEmpty
                        ? selectedFileHit!.path
                        : selectedFileHit!.previewText!,
                    style: _monoTextStyle(
                      Theme.of(context).textTheme.bodyMedium,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!preview.isBinary && selectedFileHit?.line != null) ...[
            const SizedBox(height: _spaceMd),
            _FileHitContextCard(preview: preview, hit: selectedFileHit!),
          ],
          const SizedBox(height: _spaceMd),
          if (preview.isBinary)
            _InsetSurface(
              child: Text(
                _tr(
                  context,
                  '这个壳层暂不支持二进制文件预览。',
                  'Binary file preview is not supported in this shell.',
                ),
              ),
            )
          else
            _looksLikeMarkdown(preview)
                ? _ReadonlyMarkdownViewport(
                    preview: preview,
                    onDownload: onDownload,
                  )
                : _ReadonlyCodeViewport(
                    preview: preview,
                    highlightedLine: selectedFileHit?.line,
                    onDownload: onDownload,
                  ),
          if (compact) const SizedBox(height: _spaceSm),
        ],
      ),
    );
  }
}

class _FileSearchResultCard extends StatelessWidget {
  const _FileSearchResultCard({
    required this.hit,
    required this.workspaceRoot,
    required this.onTap,
  });

  final FileSearchHit hit;
  final String? workspaceRoot;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _PanelCard(
      padding: EdgeInsets.zero,
      highlighted: hit.kind == 'text',
      tone: hit.kind == 'text' ? scheme.primary : scheme.secondary,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_radiusLg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(_spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: _spaceSm,
                  runSpacing: _spaceSm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusChip(
                      label: hit.kind == 'text'
                          ? _tr(context, '文本命中', 'text hit')
                          : _tr(context, '文件名命中', 'filename hit'),
                      tone: hit.kind == 'text'
                          ? scheme.primary
                          : scheme.secondary,
                    ),
                    if (hit.line != null)
                      _StatusChip(
                        label: _displayFileLocation(hit.line, hit.column),
                        tone: scheme.tertiary,
                      ),
                  ],
                ),
                const SizedBox(height: _spaceSm),
                Text(
                  hit.displayName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: _spaceXs),
                SelectableText(
                  _displayPathRelativeTo(hit.path, workspaceRoot),
                  style: _monoTextStyle(
                    Theme.of(context).textTheme.bodySmall,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (hit.previewText != null && hit.previewText!.isNotEmpty) ...[
                  const SizedBox(height: _spaceSm),
                  _InsetSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Match context',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: scheme.primary),
                        ),
                        const SizedBox(height: _spaceXs),
                        SelectableText(
                          hit.previewText!,
                          style: _monoTextStyle(
                            Theme.of(context).textTheme.bodyMedium,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FileDirectoryBrowser extends StatefulWidget {
  const _FileDirectoryBrowser({
    super.key,
    this.initialPath,
    required this.sessionDirectory,
    required this.selectedFilePath,
    required this.onLoadDirectory,
    this.onDirectoryChanged,
    required this.onOpenFile,
  });

  final String? initialPath;
  final String? sessionDirectory;
  final String? selectedFilePath;
  final Future<DirectoryListing> Function(String? path) onLoadDirectory;
  final ValueChanged<String?>? onDirectoryChanged;
  final Future<void> Function(DirectoryEntry entry) onOpenFile;

  @override
  State<_FileDirectoryBrowser> createState() => _FileDirectoryBrowserState();
}

class _FileDirectoryBrowserState extends State<_FileDirectoryBrowser> {
  late final ScrollController _scrollController;
  DirectoryListing? _listing;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    unawaited(_loadDirectory(widget.initialPath));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory(String? path) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final listing = await widget.onLoadDirectory(path);
      if (!mounted) {
        return;
      }
      widget.onDirectoryChanged?.call(listing.currentPath);
      setState(() {
        _listing = listing;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final listing = _listing;
    final currentPath = listing?.currentPath ?? widget.sessionDirectory;
    final rootPath = listing?.rootPath ?? widget.sessionDirectory;

    return Column(
      key: const ValueKey<String>('file-browse-sheet-content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PanelCard(
          padding: const EdgeInsets.all(_spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _tr(context, '浏览当前会话文件', 'Browse current session files'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (listing != null)
                    _MetricPill(
                      label: _tr(context, '条目', 'Entries'),
                      value: '${listing.items.length}',
                      tone: scheme.secondary,
                    ),
                ],
              ),
              if (currentPath != null && rootPath != null) ...[
                const SizedBox(height: _spaceSm),
                Text(
                  _displayPathRelativeTo(currentPath, rootPath),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: _spaceXxs),
                SelectableText(
                  currentPath,
                  style: _monoTextStyle(
                    Theme.of(context).textTheme.bodySmall,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                const SizedBox(height: _spaceSm),
                Text(
                  _tr(
                    context,
                    '沿着当前会话工作区根目录逐层浏览，打开目录，并以只读方式预览文件。',
                    'Walk the current session workspace root, open folders, and preview files read-only.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (listing != null) ...[
                const SizedBox(height: _spaceSm),
                Wrap(
                  spacing: _spaceSm,
                  runSpacing: _spaceSm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loading || listing.parentPath == null
                          ? null
                          : () => _loadDirectory(listing.parentPath),
                      icon: const Icon(Icons.arrow_upward),
                      label: Text(_tr(context, '上级', 'Up')),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _loading || listing.currentPath == listing.rootPath
                          ? null
                          : () => _loadDirectory(listing.rootPath),
                      icon: const Icon(Icons.home_outlined),
                      label: Text(_tr(context, '根目录', 'Root')),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: _spaceSm),
        Expanded(
          child: Builder(
            builder: (context) {
              if (_loading && listing == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_error != null && listing == null) {
                return _PanelCard(
                  child: Text(
                    _tr(
                      context,
                      '目录浏览失败：$_error',
                      'Directory browse failed: $_error',
                    ),
                  ),
                );
              }
              if (listing == null) {
                return _PanelCard(
                  child: Text(
                    _tr(
                      context,
                      '这个会话暂时不能浏览目录。',
                      'Directory browse is unavailable for this session.',
                    ),
                  ),
                );
              }
              if (listing.items.isEmpty) {
                return _PanelCard(
                  child: Text(
                    _tr(context, '这个文件夹是空的。', 'This folder is empty.'),
                  ),
                );
              }

              return Stack(
                children: [
                  Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    interactive: true,
                    child: ListView.separated(
                      controller: _scrollController,
                      itemCount: listing.items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: _spaceSm),
                      itemBuilder: (context, index) {
                        final entry = listing.items[index];
                        final isSelected =
                            !entry.isDirectory &&
                            entry.path == widget.selectedFilePath;
                        return _DirectoryEntryCard(
                          entry: entry,
                          relativePath: _displayPathRelativeTo(
                            entry.path,
                            listing.currentPath,
                          ),
                          selected: isSelected,
                          onTap: _loading
                              ? null
                              : () async {
                                  if (entry.isDirectory) {
                                    await _loadDirectory(entry.path);
                                    return;
                                  }
                                  await widget.onOpenFile(entry);
                                },
                        );
                      },
                    ),
                  ),
                  if (_loading)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DirectoryEntryCard extends StatelessWidget {
  const _DirectoryEntryCard({
    required this.entry,
    required this.relativePath,
    required this.selected,
    required this.onTap,
  });

  final DirectoryEntry entry;
  final String relativePath;
  final bool selected;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _PanelCard(
      padding: EdgeInsets.zero,
      highlighted: selected,
      tone: entry.isDirectory ? scheme.primary : scheme.secondary,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_radiusLg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(_spaceMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  entry.isDirectory
                      ? Icons.folder_open_outlined
                      : Icons.insert_drive_file_outlined,
                  color: entry.isDirectory ? scheme.primary : scheme.secondary,
                ),
                const SizedBox(width: _spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: _spaceXs),
                      SelectableText(
                        relativePath,
                        style: _monoTextStyle(
                          Theme.of(context).textTheme.bodySmall,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _spaceSm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusChip(
                      label: entry.isDirectory ? 'folder' : 'file',
                      tone: entry.isDirectory
                          ? scheme.primary
                          : scheme.secondary,
                    ),
                    if (!entry.isDirectory && entry.sizeBytes != null) ...[
                      const SizedBox(height: _spaceXs),
                      _StatusChip(
                        label: _formatBytes(entry.sizeBytes!),
                        tone: scheme.outline,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FileHitContextCard extends StatelessWidget {
  const _FileHitContextCard({required this.preview, required this.hit});

  final FilePreview preview;
  final FileSearchHit hit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = _contentLines(preview.content);
    final lineNumber = hit.line;

    if (lineNumber == null || lineNumber < 1 || lineNumber > lines.length) {
      if (hit.previewText == null || hit.previewText!.isEmpty) {
        return const SizedBox.shrink();
      }

      return _InsetSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match context',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: _spaceXs),
            SelectableText(
              hit.previewText!,
              style: _monoTextStyle(
                Theme.of(context).textTheme.bodyMedium,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    final startIndex = lineNumber - 3 < 0 ? 0 : lineNumber - 3;
    final endIndex = lineNumber + 2 > lines.length
        ? lines.length
        : lineNumber + 2;
    final snippetLines = lines.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Match context',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: _spaceSm),
        _InsetSurface(
          child: _FileCodeBlock(
            lines: snippetLines,
            startLineNumber: startIndex + 1,
            highlightedLine: lineNumber,
            emptyLabel: '(no surrounding context available)',
          ),
        ),
      ],
    );
  }
}

class _ReadonlyCodeViewport extends StatelessWidget {
  const _ReadonlyCodeViewport({
    required this.preview,
    required this.highlightedLine,
    required this.onDownload,
  });

  final FilePreview preview;
  final int? highlightedLine;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final contentLines = _contentLines(preview.content);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF08111B),
        borderRadius: BorderRadius.circular(_radiusSm),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: _spaceMd,
              vertical: _spaceSm,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_radiusSm),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'NORMAL',
                  style: _monoTextStyle(
                    Theme.of(context).textTheme.labelMedium,
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: _spaceMd),
                Expanded(
                  child: Text(
                    preview.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _monoTextStyle(
                      Theme.of(context).textTheme.bodySmall,
                      color: Colors.white70,
                    ),
                  ),
                ),
                if (preview.language != null)
                  Text(
                    preview.language!,
                    style: _monoTextStyle(
                      Theme.of(context).textTheme.bodySmall,
                      color: Colors.white54,
                    ),
                  ),
                const SizedBox(width: _spaceSm),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDownload,
                  tooltip: _tr(context, '下载文件', 'Download file'),
                  icon: const Icon(Icons.download_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(_spaceMd),
            child: SizedBox(
              height: 360,
              child: ListView(
                primary: false,
                physics: const ClampingScrollPhysics(),
                children: [
                  _FileCodeBlock(
                    lines: contentLines,
                    highlightedLine: highlightedLine,
                    emptyLabel: _tr(context, '(空文件)', '(empty file)'),
                    darkMode: true,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: _spaceMd,
              vertical: _spaceSm,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(_radiusSm),
              ),
            ),
            child: Text(
              _tr(
                context,
                '只读 · ${preview.lineCount ?? contentLines.length} 行',
                'readonly · ${preview.lineCount ?? contentLines.length} lines',
              ),
              style: _monoTextStyle(
                Theme.of(context).textTheme.bodySmall,
                color: Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadonlyMarkdownViewport extends StatelessWidget {
  const _ReadonlyMarkdownViewport({
    required this.preview,
    required this.onDownload,
  });

  final FilePreview preview;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF08111B),
        borderRadius: BorderRadius.circular(_radiusSm),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: _spaceMd,
              vertical: _spaceSm,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_radiusSm),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'MARKDOWN',
                  style: _monoTextStyle(
                    Theme.of(context).textTheme.labelMedium,
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: _spaceMd),
                Expanded(
                  child: Text(
                    preview.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _monoTextStyle(
                      Theme.of(context).textTheme.bodySmall,
                      color: Colors.white70,
                    ),
                  ),
                ),
                Text(
                  _tr(context, '只读', 'readonly'),
                  style: _monoTextStyle(
                    Theme.of(context).textTheme.bodySmall,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(width: _spaceSm),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDownload,
                  tooltip: _tr(context, '下载文件', 'Download file'),
                  icon: const Icon(Icons.download_rounded),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(_spaceMd),
              physics: const ClampingScrollPhysics(),
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: scheme.copyWith(
                    surface: const Color(0xFF08111B),
                    onSurface: _AppPalette.textPrimary,
                    surfaceContainerHigh: const Color(0xFF0F1B28),
                  ),
                ),
                child: _MarkdownPreviewBlock(content: preview.content),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: _spaceMd,
              vertical: _spaceSm,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(_radiusSm),
              ),
            ),
            child: Text(
              _tr(
                context,
                '只读 markdown · ${preview.lineCount ?? _contentLines(preview.content).length} 行',
                'readonly markdown · ${preview.lineCount ?? _contentLines(preview.content).length} lines',
              ),
              style: _monoTextStyle(
                Theme.of(context).textTheme.bodySmall,
                color: Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownPreviewBlock extends StatelessWidget {
  const _MarkdownPreviewBlock({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return _MarkdownContent(content: content);
  }
}

class _MarkdownContent extends StatelessWidget {
  const _MarkdownContent({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return Text(
        _tr(context, '(空白 markdown)', '(empty markdown)'),
        style: _monoTextStyle(
          Theme.of(context).textTheme.bodyMedium,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: _buildMarkdownStyleSheet(context),
      softLineBreak: true,
    );
  }
}

MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyMedium?.copyWith(
      height: 1.58,
      color: scheme.onSurface,
    ),
    h1: theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.onSurface,
    ),
    h2: theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.onSurface,
    ),
    h3: theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    listBullet: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary),
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface,
      height: 1.55,
    ),
    blockquotePadding: const EdgeInsets.symmetric(
      horizontal: _spaceMd,
      vertical: _spaceSm,
    ),
    blockquoteDecoration: BoxDecoration(
      color: scheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(_radiusSm),
      border: Border(
        left: BorderSide(
          color: scheme.primary.withValues(alpha: 0.55),
          width: 3,
        ),
      ),
    ),
    code: _monoTextStyle(
      theme.textTheme.bodyMedium,
      color: scheme.primary,
      fontWeight: FontWeight.w600,
    ),
    codeblockPadding: const EdgeInsets.all(_spaceMd),
    codeblockDecoration: BoxDecoration(
      color: const Color(0xFF0F1722),
      borderRadius: BorderRadius.circular(_radiusSm),
      border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
    ),
    em: theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface,
      fontStyle: FontStyle.italic,
    ),
    strong: theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
    ),
    a: theme.textTheme.bodyMedium?.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    ),
  );
}

class _FileCodeBlock extends StatelessWidget {
  const _FileCodeBlock({
    required this.lines,
    required this.emptyLabel,
    this.startLineNumber = 1,
    this.highlightedLine,
    this.darkMode = false,
  });

  final List<String> lines;
  final String emptyLabel;
  final int startLineNumber;
  final int? highlightedLine;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = darkMode ? const Color(0xFFE5F1FF) : scheme.onSurface;
    final secondaryTextColor = darkMode
        ? const Color(0xFF7E93AA)
        : scheme.onSurfaceVariant;

    if (lines.isEmpty) {
      return Text(
        emptyLabel,
        style: _monoTextStyle(
          Theme.of(context).textTheme.bodyMedium,
          color: secondaryTextColor,
        ),
      );
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < lines.length; index++)
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                bottom: index == lines.length - 1 ? 0 : _spaceXxs,
              ),
              padding: const EdgeInsets.symmetric(vertical: _spaceXxs),
              decoration: BoxDecoration(
                color: highlightedLine == startLineNumber + index
                    ? scheme.primary.withValues(alpha: 0.12)
                    : index.isOdd
                    ? (darkMode
                          ? Colors.white.withValues(alpha: 0.03)
                          : scheme.surface.withValues(alpha: 0.5))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(_radiusSm),
                border: highlightedLine == startLineNumber + index
                    ? Border.all(color: scheme.primary.withValues(alpha: 0.28))
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _spaceLg * 3,
                    child: Text(
                      '${startLineNumber + index}',
                      textAlign: TextAlign.right,
                      style: _monoTextStyle(
                        Theme.of(context).textTheme.bodySmall,
                        color: highlightedLine == startLineNumber + index
                            ? scheme.primary
                            : secondaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: _spaceMd),
                  Expanded(
                    child: Text(
                      lines[index].isEmpty ? ' ' : lines[index],
                      style: _monoTextStyle(
                        Theme.of(context).textTheme.bodyMedium,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MobilePanelTabButton extends StatelessWidget {
  const _MobilePanelTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = selected ? scheme.primary : scheme.outline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: _spaceMd,
            vertical: _spaceSm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.14)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tone.withValues(alpha: 0.34)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: tone),
              const SizedBox(width: _spaceSm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: _spaceSm),
                _StatusChip(label: badge!, tone: tone),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectChip extends StatelessWidget {
  const _ProjectChip({
    required this.project,
    required this.selected,
    required this.onOpen,
    required this.onDelete,
    this.onClose,
  });

  final ProjectSummary project;
  final bool selected;
  final Future<void> Function() onOpen;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onClose;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (project.runtimeState) {
      'running' => Theme.of(context).colorScheme.primary,
      'starting' => Theme.of(context).colorScheme.secondary,
      'error' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.outline,
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.all(_spaceXs),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_radiusLg),
        border: Border.all(color: statusColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: _spaceXxs),
          _StatusChip(label: project.runtimeState, tone: statusColor),
          const SizedBox(height: _spaceXs),
          Wrap(
            spacing: _spaceXs,
            runSpacing: _spaceXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: _spaceSm,
                    vertical: _spaceXs,
                  ),
                ),
                onPressed: onOpen,
                child: Text(project.opened ? 'Switch' : 'Open'),
              ),
              if (onClose != null)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: _spaceSm,
                      vertical: _spaceXs,
                    ),
                  ),
                  onPressed: onClose,
                  child: const Text('Close'),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete project',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobilePanelScrollView extends StatefulWidget {
  const _MobilePanelScrollView({required this.storageId, required this.child});

  final String storageId;
  final Widget child;

  @override
  State<_MobilePanelScrollView> createState() => _MobilePanelScrollViewState();
}

class _MobilePanelScrollViewState extends State<_MobilePanelScrollView> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      interactive: true,
      child: SingleChildScrollView(
        key: PageStorageKey<String>(widget.storageId),
        controller: _scrollController,
        primary: false,
        padding: const EdgeInsets.fromLTRB(
          _spaceLg,
          _spaceXs,
          _spaceLg,
          _spaceLg,
        ),
        child: widget.child,
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: _spaceSm),
        child,
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.child,
    this.padding = const EdgeInsets.all(_spaceLg),
    this.highlighted = false,
    this.tone,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = tone ?? scheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted ? scheme.surfaceContainerHigh : scheme.surface,
        borderRadius: BorderRadius.circular(_radiusLg),
        border: Border.all(
          color: highlighted
              ? accent.withValues(alpha: 0.4)
              : scheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tone ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _spaceMd,
        vertical: _spaceXs + _spaceXxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: _monoTextStyle(
              Theme.of(context).textTheme.titleSmall,
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: _spaceSm),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _InsetSurface extends StatelessWidget {
  const _InsetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_radiusSm),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(_spaceMd), child: child),
    );
  }
}

class _SubsectionCard extends StatelessWidget {
  const _SubsectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.tone,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = tone ?? scheme.primary;

    return _PanelCard(
      padding: const EdgeInsets.all(_spaceMd),
      tone: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: _spaceXs),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: _spaceMd),
          child,
        ],
      ),
    );
  }
}

class _ExecutionSummaryCard extends StatelessWidget {
  const _ExecutionSummaryCard({
    required this.latestUsage,
    required this.contextStatus,
    required this.loadingContextStatus,
    required this.questions,
    required this.permissions,
    required this.sessionId,
  });

  final UsageMetrics? latestUsage;
  final SessionContextStatus? contextStatus;
  final bool loadingContextStatus;
  final List<PendingQuestion> questions;
  final List<PendingPermission> permissions;
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    final filteredQuestions = _filteredQuestionsForSession(
      questions,
      sessionId,
    );
    final filteredPermissions = _filteredPermissionsForSession(
      permissions,
      sessionId,
    );

    if (loadingContextStatus) {
      return _PanelCard(
        padding: const EdgeInsets.all(_spaceMd),
        child: Text(_tr(context, '正在载入执行状态…', 'Loading execution status…')),
      );
    }

    final status = contextStatus;
    if (status == null) {
      return _PanelCard(
        padding: const EdgeInsets.all(_spaceMd),
        child: Text(_tr(context, '执行状态暂不可用。', 'Execution status unavailable.')),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final currentTool = status.currentToolTitle == null
        ? null
        : status.currentToolStatus == null
        ? status.currentToolTitle!
        : '${status.currentToolTitle!} (${status.currentToolStatus!})';
    final retryLabel = status.currentRetryAttempt == null
        ? null
        : _tr(
            context,
            '重试 ${status.currentRetryAttempt}',
            'Retry ${status.currentRetryAttempt}',
          );
    final usageLabels = <Widget>[
      if (latestUsage?.totalTokens != null)
        _MetricPill(
          label: _tr(context, '总 Token', 'Total tokens'),
          value: '${latestUsage!.totalTokens}',
          tone: scheme.primary,
        ),
      if (latestUsage?.inputTokens != null)
        _MetricPill(
          label: _tr(context, '输入', 'Input'),
          value: '${latestUsage!.inputTokens}',
          tone: scheme.secondary,
        ),
      if (latestUsage?.outputTokens != null)
        _MetricPill(
          label: _tr(context, '输出', 'Output'),
          value: '${latestUsage!.outputTokens}',
          tone: scheme.tertiary,
        ),
      if (latestUsage?.cost != null)
        _MetricPill(
          label: _tr(context, '成本', 'Cost'),
          value: latestUsage!.cost!.toStringAsFixed(2),
          tone: scheme.outline,
        ),
      if (latestUsage?.contextUsagePercent != null)
        _MetricPill(
          label: _tr(context, '上下文占用', 'Context usage'),
          value: '${latestUsage!.contextUsagePercent}%',
          tone: scheme.primary,
        ),
    ];

    return _PanelCard(
      padding: const EdgeInsets.all(_spaceMd),
      highlighted: true,
      tone: scheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (status.currentStepTitle != null) ...[
                      Text(
                        status.currentStepTitle!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: _spaceXs),
                    ],
                    Text(
                      _tr(
                        context,
                        '${status.inProgressTodoCount} 进行中 · ${status.pendingTodoCount} 待处理 · ${status.completedTodoCount} 已完成',
                        '${status.inProgressTodoCount} active · ${status.pendingTodoCount} pending · ${status.completedTodoCount} done',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _spaceMd),
              _StatusChip(
                label: status.status ?? _tr(context, '未知', 'unknown'),
              ),
            ],
          ),
          const SizedBox(height: _spaceMd),
          _TodoProgressBar(
            pendingCount: status.pendingTodoCount,
            inProgressCount: status.inProgressTodoCount,
            completedCount: status.completedTodoCount,
          ),
          if (usageLabels.isNotEmpty) ...[
            const SizedBox(height: _spaceMd),
            Wrap(
              spacing: _spaceSm,
              runSpacing: _spaceSm,
              children: usageLabels,
            ),
          ],
          const SizedBox(height: _spaceMd),
          Wrap(
            spacing: _spaceSm,
            runSpacing: _spaceSm,
            children: [
              if (currentTool != null)
                _StatusChip(label: currentTool, tone: scheme.secondary),
              if (status.currentSubtaskDescription != null)
                _StatusChip(
                  label: status.currentSubtaskDescription!,
                  tone: scheme.tertiary,
                ),
              if (retryLabel != null)
                _StatusChip(
                  label: retryLabel,
                  tone: status.currentRetryError == null
                      ? scheme.outline
                      : scheme.error,
                ),
              if (status.compacting)
                _StatusChip(
                  label: _tr(context, '压缩中', 'Compacting'),
                  tone: scheme.primary,
                ),
              if (status.activeToolCount > 0)
                _MetricPill(
                  label: _tr(context, '工具', 'Tools'),
                  value: '${status.activeToolCount}',
                  tone: scheme.secondary,
                ),
              if (filteredQuestions.isNotEmpty)
                _MetricPill(
                  label: _tr(context, '问题', 'Questions'),
                  value: '${filteredQuestions.length}',
                  tone: scheme.tertiary,
                ),
              if (filteredPermissions.isNotEmpty)
                _MetricPill(
                  label: _tr(context, '权限', 'Permissions'),
                  value: '${filteredPermissions.length}',
                  tone: scheme.error,
                ),
            ],
          ),
          if (status.currentRetryError != null) ...[
            const SizedBox(height: _spaceSm),
            Text(
              status.currentRetryError!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuntimePanel extends StatelessWidget {
  const _RuntimePanel({
    required this.latestUsage,
    required this.contextStatus,
    required this.loadingContextStatus,
    required this.questions,
    required this.permissions,
    required this.sessionId,
  });

  final UsageMetrics? latestUsage;
  final SessionContextStatus? contextStatus;
  final bool loadingContextStatus;
  final List<PendingQuestion> questions;
  final List<PendingPermission> permissions;
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    return _PanelSection(
      title: _tr(context, '状态', 'Runtime'),
      trailing: contextStatus == null
          ? null
          : _StatusChip(
              label: contextStatus!.status ?? _tr(context, '未知', 'unknown'),
            ),
      child: _ExecutionSummaryCard(
        latestUsage: latestUsage,
        contextStatus: contextStatus,
        loadingContextStatus: loadingContextStatus,
        questions: questions,
        permissions: permissions,
        sessionId: sessionId,
      ),
    );
  }
}

class _MobileExecutionStatusStrip extends StatelessWidget {
  const _MobileExecutionStatusStrip({
    required this.presentation,
    required this.latestUsage,
    required this.contextStatus,
    required this.loadingContextStatus,
    required this.maxWidth,
  });

  final _SessionPresentationModel presentation;
  final UsageMetrics? latestUsage;
  final SessionContextStatus? contextStatus;
  final bool loadingContextStatus;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detailText = _mobileExecutionInlineDetail(context, contextStatus);

    return SafeArea(
      top: false,
      bottom: false,
      child: SizedBox(
        key: const ValueKey<String>('mobile-execution-status-strip'),
        height: 28,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _spaceLg,
                _spaceXs,
                _spaceLg,
                0,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _AnimatedExecutionHighlightBar(
                        active: presentation.shouldAnimateStrip,
                      ),
                    ),
                  ),
                  const SizedBox(width: _spaceSm),
                  Expanded(
                    child: detailText == null
                        ? const SizedBox.shrink()
                        : KeyedSubtree(
                            key: const ValueKey<String>(
                              'mobile-execution-inline-detail',
                            ),
                            child: _OverflowTitleText(
                              text: detailText,
                              style: _monoTextStyle(
                                Theme.of(context).textTheme.labelSmall,
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.9,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: _spaceSm),
                  Text(
                    _mobileExecutionUsageLabel(
                      latestUsage,
                      loadingContextStatus: loadingContextStatus,
                    ),
                    key: const ValueKey<String>('mobile-execution-usage'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _monoTextStyle(
                      Theme.of(context).textTheme.labelMedium,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedExecutionHighlightBar extends StatefulWidget {
  const _AnimatedExecutionHighlightBar({required this.active});

  final bool active;

  @override
  State<_AnimatedExecutionHighlightBar> createState() =>
      _AnimatedExecutionHighlightBarState();
}

class _AnimatedExecutionHighlightBarState
    extends State<_AnimatedExecutionHighlightBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedExecutionHighlightBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (widget.active) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }

    _controller
      ..stop()
      ..value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = scheme.primary.withValues(
      alpha: widget.active ? 0.16 : 0.08,
    );
    final pulseColor = scheme.primary.withValues(
      alpha: widget.active ? 0.82 : 0.45,
    );
    final edgeColor = scheme.secondary.withValues(
      alpha: widget.active ? 0.42 : 0.2,
    );

    return SizedBox(
      height: 8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travelDistance = math.max(constraints.maxWidth - 22, 0.0);

          return ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final left = travelDistance * _controller.value;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [baseColor, scheme.surfaceContainerHighest],
                        ),
                      ),
                    ),
                    Positioned(
                      key: const ValueKey<String>(
                        'mobile-execution-status-strip-pulse',
                      ),
                      left: left,
                      top: 0,
                      bottom: 0,
                      width: 22,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [pulseColor, edgeColor, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TodoProgressBar extends StatelessWidget {
  const _TodoProgressBar({
    required this.pendingCount,
    required this.inProgressCount,
    required this.completedCount,
  });

  final int pendingCount;
  final int inProgressCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = pendingCount + inProgressCount + completedCount;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: _spaceSm,
        child: total == 0
            ? ColoredBox(color: scheme.surfaceContainerHighest)
            : Row(
                children: [
                  if (completedCount > 0)
                    Expanded(
                      flex: completedCount,
                      child: const ColoredBox(color: _AppPalette.success),
                    ),
                  if (inProgressCount > 0)
                    Expanded(
                      flex: inProgressCount,
                      child: ColoredBox(color: scheme.primary),
                    ),
                  if (pendingCount > 0)
                    Expanded(
                      flex: pendingCount,
                      child: ColoredBox(color: scheme.outline),
                    ),
                ],
              ),
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({
    required this.attention,
    required this.sessionId,
    required this.respondingAttention,
    required this.onQuestionAnswer,
    required this.onQuestionReject,
    required this.onPermissionReply,
  });

  final AttentionState attention;
  final String? sessionId;
  final bool respondingAttention;
  final Future<void> Function(PendingQuestion question, String answer)
  onQuestionAnswer;
  final Future<void> Function(PendingQuestion question) onQuestionReject;
  final Future<void> Function(PendingPermission permission, String reply)
  onPermissionReply;

  @override
  Widget build(BuildContext context) {
    final questions = _filteredQuestionsForSession(
      attention.questions,
      sessionId,
    );
    final permissions = _filteredPermissionsForSession(
      attention.permissions,
      sessionId,
    );

    return _PanelSection(
      title: 'Attention',
      trailing: questions.isEmpty && permissions.isEmpty
          ? null
          : _StatusChip(label: '${questions.length + permissions.length} open'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (questions.isEmpty && permissions.isEmpty)
            const _PanelCard(child: Text('No pending approvals or questions.')),
          if (questions.isNotEmpty || permissions.isNotEmpty) ...[
            _PanelCard(
              padding: const EdgeInsets.all(_spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: _spaceSm,
                    runSpacing: _spaceSm,
                    children: [
                      _MetricPill(
                        label: 'Open',
                        value: '${questions.length + permissions.length}',
                        tone: Theme.of(context).colorScheme.primary,
                      ),
                      _MetricPill(
                        label: 'Questions',
                        value: '${questions.length}',
                        tone: Theme.of(context).colorScheme.tertiary,
                      ),
                      _MetricPill(
                        label: 'Permissions',
                        value: '${permissions.length}',
                        tone: Theme.of(context).colorScheme.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (questions.isNotEmpty) ...[
            const SizedBox(height: _spaceMd),
            _SubsectionCard(
              title: 'Questions',
              subtitle:
                  'Resolve multiple-choice prompts waiting on this session.',
              tone: Theme.of(context).colorScheme.tertiary,
              child: Column(
                children: [
                  for (var index = 0; index < questions.length; index++) ...[
                    _PanelCard(
                      padding: const EdgeInsets.all(_spaceMd),
                      tone: Theme.of(context).colorScheme.tertiary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: _spaceSm,
                            runSpacing: _spaceSm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _StatusChip(
                                label: 'question',
                                tone: Theme.of(context).colorScheme.tertiary,
                              ),
                              Text(
                                questions[index].header,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: _spaceSm),
                          _InsetSurface(
                            child: SelectableText(questions[index].question),
                          ),
                          const SizedBox(height: _spaceMd),
                          for (final option in questions[index].options)
                            Padding(
                              padding: const EdgeInsets.only(bottom: _spaceSm),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _spaceMd,
                                    vertical: _spaceMd,
                                  ),
                                  alignment: Alignment.centerLeft,
                                ),
                                onPressed: respondingAttention
                                    ? null
                                    : () => onQuestionAnswer(
                                        questions[index],
                                        option.label,
                                      ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(option.label),
                                    if (option.description != null &&
                                        option.description!.isNotEmpty)
                                      Text(
                                        option.description!,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          TextButton(
                            onPressed: respondingAttention
                                ? null
                                : () => onQuestionReject(questions[index]),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    ),
                    if (index != questions.length - 1)
                      const SizedBox(height: _spaceSm),
                  ],
                ],
              ),
            ),
          ],
          if (permissions.isNotEmpty) ...[
            const SizedBox(height: _spaceMd),
            _SubsectionCard(
              title: 'Permissions',
              subtitle:
                  'Approve or reject tool access requests for this session.',
              tone: Theme.of(context).colorScheme.error,
              child: Column(
                children: [
                  for (var index = 0; index < permissions.length; index++) ...[
                    _PanelCard(
                      padding: const EdgeInsets.all(_spaceMd),
                      tone: Theme.of(context).colorScheme.error,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: _spaceSm,
                            runSpacing: _spaceSm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _StatusChip(
                                label: 'permission',
                                tone: Theme.of(context).colorScheme.error,
                              ),
                              if (permissions[index].tool != null &&
                                  permissions[index].tool!.isNotEmpty)
                                _StatusChip(
                                  label: permissions[index].tool!,
                                  tone: Theme.of(context).colorScheme.outline,
                                ),
                            ],
                          ),
                          const SizedBox(height: _spaceSm),
                          _InsetSurface(
                            child: SelectableText(
                              permissions[index].permission,
                            ),
                          ),
                          if (permissions[index].patterns.isNotEmpty) ...[
                            const SizedBox(height: _spaceSm),
                            _InsetSurface(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Requested paths',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                  const SizedBox(height: _spaceSm),
                                  SelectableText(
                                    permissions[index].patterns.join('\n'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: _spaceMd),
                          Wrap(
                            spacing: _spaceSm,
                            runSpacing: _spaceSm,
                            children: [
                              FilledButton(
                                onPressed: respondingAttention
                                    ? null
                                    : () => onPermissionReply(
                                        permissions[index],
                                        'once',
                                      ),
                                child: const Text('Allow once'),
                              ),
                              OutlinedButton(
                                onPressed: respondingAttention
                                    ? null
                                    : () => onPermissionReply(
                                        permissions[index],
                                        'always',
                                      ),
                                child: const Text('Always allow'),
                              ),
                              TextButton(
                                onPressed: respondingAttention
                                    ? null
                                    : () => onPermissionReply(
                                        permissions[index],
                                        'reject',
                                      ),
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (index != permissions.length - 1)
                      const SizedBox(height: _spaceSm),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodosPanel extends StatelessWidget {
  const _TodosPanel({required this.todos});

  final List<TodoItem> todos;

  @override
  Widget build(BuildContext context) {
    final inProgress = <TodoItem>[];
    final pending = <TodoItem>[];
    final completed = <TodoItem>[];
    final other = <TodoItem>[];

    for (final todo in todos) {
      switch (_normalizeStatus(todo.status)) {
        case 'in_progress':
        case 'running':
          inProgress.add(todo);
          break;
        case 'pending':
        case 'queued':
          pending.add(todo);
          break;
        case 'completed':
        case 'done':
          completed.add(todo);
          break;
        default:
          other.add(todo);
      }
    }

    inProgress.sort(_compareTodos);
    pending.sort(_compareTodos);
    completed.sort(_compareTodos);
    other.sort(_compareTodos);

    return _PanelSection(
      title: 'Tasks',
      trailing: todos.isEmpty
          ? null
          : _StatusChip(label: '${todos.length} total'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (todos.isEmpty)
            const _PanelCard(child: Text('No tasks for this session.'))
          else ...[
            _PanelCard(
              padding: const EdgeInsets.all(_spaceMd),
              child: Wrap(
                spacing: _spaceSm,
                runSpacing: _spaceSm,
                children: [
                  _MetricPill(
                    label: 'In progress',
                    value: '${inProgress.length}',
                  ),
                  _MetricPill(
                    label: 'Pending',
                    value: '${pending.length}',
                    tone: Theme.of(context).colorScheme.tertiary,
                  ),
                  _MetricPill(
                    label: 'Completed',
                    value: '${completed.length}',
                    tone: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: _spaceMd),
            _TodoLane(
              title: 'In progress',
              description: 'Active execution queue.',
              items: inProgress,
            ),
            const SizedBox(height: _spaceSm),
            _TodoLane(
              title: 'Pending',
              description: 'Queued next work.',
              items: pending,
            ),
            const SizedBox(height: _spaceSm),
            _TodoLane(
              title: 'Completed',
              description: 'Recently finished steps.',
              items: completed,
            ),
            if (other.isNotEmpty) ...[
              const SizedBox(height: _spaceSm),
              _TodoLane(
                title: 'Other',
                description: 'Non-standard bridge states.',
                items: other,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TodoLane extends StatelessWidget {
  const _TodoLane({
    required this.title,
    required this.description,
    required this.items,
  });

  final String title;
  final String description;
  final List<TodoItem> items;

  @override
  Widget build(BuildContext context) {
    final tone = _toneForStatus(context, title);

    return _PanelCard(
      padding: const EdgeInsets.all(_spaceMd),
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(_iconForStatus(title), size: 18, color: tone),
              ),
              const SizedBox(width: _spaceSm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: _spaceSm),
              _StatusChip(label: '${items.length}', tone: tone),
            ],
          ),
          const SizedBox(height: _spaceXs),
          Text(
            description,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: _spaceSm),
          if (items.isEmpty)
            Text(
              'No $title work.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final todo in items) ...[
              _TodoCard(todo: todo),
              const SizedBox(height: _spaceXs),
            ],
        ],
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({required this.todo});

  final TodoItem todo;

  @override
  Widget build(BuildContext context) {
    final tone = _toneForStatus(context, todo.status);

    return Container(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_radiusSm),
        border: Border.all(color: tone.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _spaceMd,
          vertical: _spaceSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: _spaceSm),
            Expanded(
              child: Text(
                todo.content,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: _spaceSm),
            Wrap(
              spacing: _spaceXs,
              runSpacing: _spaceXs,
              alignment: WrapAlignment.end,
              children: [
                if (todo.status != null && todo.status!.isNotEmpty)
                  _StatusChip(label: _labelize(todo.status!)),
                if (todo.priority != null && todo.priority!.isNotEmpty)
                  _StatusChip(
                    label: _labelize(todo.priority!),
                    tone: _toneForPriority(context, todo.priority),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _normalizeStatus(String? value) {
  return value?.trim().toLowerCase() ?? '';
}

String _labelize(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) {
    return value;
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

int _compareTodos(TodoItem left, TodoItem right) {
  final priorityOrder =
      _priorityRank(left.priority) - _priorityRank(right.priority);
  if (priorityOrder != 0) {
    return priorityOrder;
  }
  return left.content.toLowerCase().compareTo(right.content.toLowerCase());
}

int _priorityRank(String? priority) {
  switch (_normalizeStatus(priority)) {
    case 'high':
      return 0;
    case 'medium':
      return 1;
    case 'low':
      return 2;
    default:
      return 3;
  }
}

Color _toneForStatus(BuildContext context, String? status) {
  final scheme = Theme.of(context).colorScheme;
  switch (_normalizeStatus(status)) {
    case 'in progress':
    case 'in_progress':
    case 'running':
    case 'busy':
      return scheme.primary;
    case 'pending':
    case 'queued':
    case 'waiting':
      return scheme.tertiary;
    case 'completed':
    case 'done':
    case 'success':
      return scheme.secondary;
    case 'rejected':
    case 'error':
    case 'failed':
      return scheme.error;
    default:
      return scheme.outline;
  }
}

IconData _iconForStatus(String? status) {
  switch (_normalizeStatus(status)) {
    case 'in progress':
    case 'in_progress':
    case 'running':
    case 'busy':
      return Icons.play_arrow_rounded;
    case 'pending':
    case 'queued':
    case 'waiting':
      return Icons.schedule_rounded;
    case 'completed':
    case 'done':
    case 'success':
      return Icons.done_rounded;
    case 'rejected':
    case 'error':
    case 'failed':
      return Icons.close_rounded;
    default:
      return Icons.drag_indicator_rounded;
  }
}

Color _toneForPriority(BuildContext context, String? priority) {
  final scheme = Theme.of(context).colorScheme;
  switch (_normalizeStatus(priority)) {
    case 'high':
      return scheme.error;
    case 'medium':
      return scheme.tertiary;
    case 'low':
      return scheme.secondary;
    default:
      return scheme.primary;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.tone});

  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tone ?? _toneForStatus(context, label);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _spaceSm,
        vertical: _spaceXs + _spaceXxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: _monoTextStyle(
          Theme.of(context).textTheme.labelMedium,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

class _RuntimeRow extends StatelessWidget {
  const _RuntimeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final monoLabels = <String>{
      'Directory',
      'Task state',
      'Current tool',
      'Current step',
      'Current subtask',
      'Retry error',
      'Last activity',
      'Summary delta',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: _spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: monoLabels.contains(label)
                  ? _monoTextStyle(Theme.of(context).textTheme.bodyMedium)
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
const _ComposerBar({
    required this.controller,
    this.focusNode,
    required this.locked,
    required this.enabled,
    required this.onSend,
    required this.onVoiceInput,
    this.maxWidth,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool locked;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onVoiceInput;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actionEnabled = enabled && !locked;

    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(_spaceMd),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth ?? double.infinity,
              ),
              child: _InsetSurface(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey<String>('composer-input'),
                            controller: controller,
                            focusNode: focusNode,
                            enabled: enabled && !locked,
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 6,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              filled: false,
                              isDense: true,
                              hintText: locked
                                  ? _tr(context, '发送中…', 'Sending…')
                                  : _tr(
                                      context,
                                      '继续当前任务…',
                                      'Continue the current task…',
                                    ),
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: _mobileHeaderButtonSize,
                                minHeight: _mobileHeaderButtonSize,
                              ),
                              suffixIcon: IconButton(
                                key: const ValueKey<String>(
                                  'composer-voice-button',
                                ),
                                onPressed: actionEnabled ? onVoiceInput : null,
                                tooltip: _tr(context, '语音转文字', 'Voice to text'),
                                icon: const Icon(Icons.keyboard_voice_outlined),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: _spaceMd),
                        FilledButton(
                          key: const ValueKey<String>('composer-action-button'),
                          onPressed: actionEnabled ? onSend : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: _spaceLg,
                              vertical: _spaceMd,
                            ),
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            key: const ValueKey<String>(
                              'composer-action-send-icon',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle? _monoTextStyle(
  TextStyle? base, {
  Color? color,
  FontWeight? fontWeight,
}) {
  return base?.copyWith(
    fontFamily: 'monospace',
    color: color,
    fontWeight: fontWeight,
    height: 1.25,
    letterSpacing: 0.1,
  );
}

List<String> _contentLines(String content) {
  if (content.isEmpty) {
    return const [];
  }

  return content.split('\n');
}

String _displayPathRelativeTo(String path, String? root) {
  final normalizedPath = path.trim();
  final normalizedRoot = root?.trim();
  if (normalizedRoot == null || normalizedRoot.isEmpty) {
    return normalizedPath;
  }
  if (normalizedPath == normalizedRoot) {
    return '.';
  }
  if (normalizedPath.startsWith('$normalizedRoot/')) {
    return normalizedPath.substring(normalizedRoot.length + 1);
  }
  return normalizedPath;
}

bool _pathFallsWithinRoot(String path, String root) {
  final normalizedPath = path.trim();
  final normalizedRoot = root.trim();
  return normalizedPath == normalizedRoot ||
      normalizedPath.startsWith('$normalizedRoot/');
}

String _compactPathLabel(String path, {int keepSegments = 2}) {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    return normalizedPath;
  }

  final hasLeadingSlash = normalizedPath.startsWith('/');
  final segments = normalizedPath
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) {
    return hasLeadingSlash ? '/' : normalizedPath;
  }

  final visibleSegments = segments.length <= keepSegments
      ? segments
      : segments.sublist(segments.length - keepSegments);
  final prefix = segments.length > keepSegments
      ? '…/'
      : hasLeadingSlash
      ? '/'
      : '';
  return '$prefix${visibleSegments.join('/')}';
}

String _displayFileLocation(int? line, int? column) {
  if (line == null) {
    return 'location unknown';
  }
  if (column == null) {
    return 'line $line';
  }
  return 'line $line · col $column';
}

String _formatBytes(int sizeBytes) {
  if (sizeBytes < 1024) {
    return '$sizeBytes B';
  }
  if (sizeBytes < 1024 * 1024) {
    return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

List<PendingQuestion> _filteredQuestionsForSession(
  List<PendingQuestion> questions,
  String? sessionId,
) {
  return questions
      .where((item) => sessionId == null || item.sessionId == sessionId)
      .toList(growable: false);
}

List<PendingPermission> _filteredPermissionsForSession(
  List<PendingPermission> permissions,
  String? sessionId,
) {
  return permissions
      .where((item) => sessionId == null || item.sessionId == sessionId)
      .toList(growable: false);
}

class _SessionPresentationModel {
  const _SessionPresentationModel({
    required this.activeTurn,
    required this.busy,
    required this.shouldAnimateStrip,
    required this.latestUsage,
    required this.visibleMessages,
  });

  final bool activeTurn;
  final bool busy;
  final bool shouldAnimateStrip;
  final UsageMetrics? latestUsage;
  final List<ConversationMessage> visibleMessages;
}

_SessionPresentationModel _buildSessionPresentation(
  SessionView? view,
  SessionContextStatus? status,
  String? sessionId,
) {
  final messages = view?.messages ?? const <ConversationMessage>[];
  final activeTurn = _latestPendingAssistant(messages) != null;
  final busy = _hasBusySessionStatus(status);
  final latestUsage = _latestAssistantUsage(messages);

  return _SessionPresentationModel(
    activeTurn: activeTurn,
    busy: busy,
    shouldAnimateStrip: activeTurn || busy || (status?.compacting ?? false),
    latestUsage: latestUsage,
    visibleMessages: _visibleConversationMessages(messages),
  );
}

ConversationMessage? _latestPendingAssistant(
  List<ConversationMessage> messages,
) {
  for (var index = messages.length - 1; index >= 0; index -= 1) {
    final message = messages[index];
    if (message.role.trim().toLowerCase() != 'assistant') {
      continue;
    }
    if (message.completedAt == null || message.completedAt!.trim().isEmpty) {
      return message;
    }
  }
  return null;
}

bool _hasBusySessionStatus(SessionContextStatus? status) {
  return status?.status?.trim().toLowerCase() == 'busy';
}

List<ConversationMessage> _visibleConversationMessages(
  List<ConversationMessage> messages,
) {
  final result = <ConversationMessage>[];

  for (final message in messages) {
    final visibleParts = message.parts
        .where((part) {
          return part.display == 'inline' || part.display == 'collapsed';
        })
        .toList(growable: false);
    if (visibleParts.isEmpty &&
        (message.error == null || message.error!.isEmpty)) {
      continue;
    }

    result.add(
      ConversationMessage(
        id: message.id,
        role: message.role,
        createdAt: message.createdAt,
        completedAt: message.completedAt,
        error: message.error,
        providerId: message.providerId,
        modelId: message.modelId,
        usage: message.usage,
        parts: visibleParts,
      ),
    );
  }

  return result;
}

String _mobileExecutionUsageLabel(
  UsageMetrics? latestUsage, {
  required bool loadingContextStatus,
}) {
  if (loadingContextStatus && latestUsage == null) {
    return '…/… · …%';
  }

  final usedLabel = latestUsage?.totalTokens?.toString() ?? '—';
  final limitLabel = latestUsage?.contextLimit?.toString() ?? '—';
  final contextPercent = latestUsage?.contextUsagePercent;
  final contextLabel = contextPercent == null ? '—%' : '$contextPercent%';
  return '$usedLabel/$limitLabel · $contextLabel';
}

UsageMetrics? _latestAssistantUsage(List<ConversationMessage> messages) {
  for (var index = messages.length - 1; index >= 0; index -= 1) {
    final message = messages[index];
    if (message.role.trim().toLowerCase() != 'assistant') {
      continue;
    }
    if (_hasUsageMetrics(message.usage)) {
      return message.usage;
    }
  }
  return null;
}

bool _hasUsageMetrics(UsageMetrics? usage) {
  return usage?.totalTokens != null ||
      usage?.inputTokens != null ||
      usage?.outputTokens != null ||
      usage?.reasoningTokens != null ||
      usage?.cacheReadTokens != null ||
      usage?.cacheWriteTokens != null ||
      usage?.cost != null ||
      usage?.contextLimit != null ||
      usage?.contextUsagePercent != null;
}

UsageMetrics _mergeUsageMetrics(UsageMetrics source, UsageMetrics? fallback) {
  return UsageMetrics(
    totalTokens: source.totalTokens ?? fallback?.totalTokens,
    inputTokens: source.inputTokens ?? fallback?.inputTokens,
    outputTokens: source.outputTokens ?? fallback?.outputTokens,
    reasoningTokens: source.reasoningTokens ?? fallback?.reasoningTokens,
    cacheReadTokens: source.cacheReadTokens ?? fallback?.cacheReadTokens,
    cacheWriteTokens: source.cacheWriteTokens ?? fallback?.cacheWriteTokens,
    cost: source.cost ?? fallback?.cost,
    contextLimit: source.contextLimit ?? fallback?.contextLimit,
    contextUsagePercent:
        source.contextUsagePercent ?? fallback?.contextUsagePercent,
  );
}

String? _mobileExecutionStatusLine(
  BuildContext context,
  SessionContextStatus status,
) {
  if (status.compacting) {
    return _tr(context, '压缩中', 'Compacting');
  }

  if (status.status != null && status.status!.isNotEmpty) {
    return status.status!;
  }

  if (status.currentRetryAttempt != null) {
    return _tr(
      context,
      '重试 ${status.currentRetryAttempt}',
      'Retry ${status.currentRetryAttempt}',
    );
  }

  return null;
}

String? _mobileExecutionToolLabel(SessionContextStatus status) {
  if (status.currentToolTitle == null || status.currentToolTitle!.isEmpty) {
    return null;
  }

  if (status.currentToolStatus == null || status.currentToolStatus!.isEmpty) {
    return status.currentToolTitle!;
  }

  return '${status.currentToolTitle!} (${status.currentToolStatus!})';
}

String? _mobileExecutionInlineDetail(
  BuildContext context,
  SessionContextStatus? status,
) {
  if (status == null || !_hasExecutionStripDetails(status)) {
    return null;
  }

  final labels = <String>[
    if (_mobileExecutionStatusLine(context, status) case final String label
        when label.isNotEmpty)
      label,
    if (status.currentStepTitle case final String label when label.isNotEmpty)
      label,
    if (_mobileExecutionToolLabel(status) case final String label
        when label.isNotEmpty)
      label,
    if (status.currentSubtaskDescription case final String label
        when label.isNotEmpty)
      label,
    if (status.currentRetryError case final String label when label.isNotEmpty)
      label,
  ];

  if (labels.isEmpty) {
    return null;
  }

  return labels.join(' · ');
}

bool _hasExecutionStripDetails(SessionContextStatus status) {
  return status.compacting ||
      (status.currentStepTitle?.isNotEmpty ?? false) ||
      (status.currentToolTitle?.isNotEmpty ?? false) ||
      (status.currentSubtaskDescription?.isNotEmpty ?? false) ||
      status.currentRetryAttempt != null ||
      (status.currentRetryError?.isNotEmpty ?? false);
}

String _sessionRequestKey(String? projectId, String sessionId) {
  return '${projectId ?? '<global>'}::$sessionId';
}

bool _sessionSummaryListsEqual(
  List<SessionSummary> left,
  List<SessionSummary> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (!_sessionSummaryEquals(left[index], right[index])) {
      return false;
    }
  }
  return true;
}

bool _sessionSummaryEquals(SessionSummary? left, SessionSummary? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left == null || right == null) {
    return false;
  }
  return left.id == right.id &&
      left.title == right.title &&
      left.directory == right.directory &&
      left.createdAt == right.createdAt &&
      left.updatedAt == right.updatedAt &&
      left.archivedAt == right.archivedAt &&
      left.status == right.status &&
      left.parentId == right.parentId;
}

bool _sessionViewEquals(SessionView? left, SessionView? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left == null || right == null) {
    return false;
  }
  return _sessionSummaryEquals(left.session, right.session) &&
      _conversationMessagesEqual(left.messages, right.messages) &&
      _todoItemsEqual(left.todos, right.todos);
}

bool _conversationMessagesEqual(
  List<ConversationMessage> left,
  List<ConversationMessage> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    final leftMessage = left[index];
    final rightMessage = right[index];
    if (leftMessage.id != rightMessage.id ||
        leftMessage.role != rightMessage.role ||
        leftMessage.createdAt != rightMessage.createdAt ||
        leftMessage.completedAt != rightMessage.completedAt ||
        leftMessage.error != rightMessage.error ||
        leftMessage.providerId != rightMessage.providerId ||
        leftMessage.modelId != rightMessage.modelId ||
        !_usageMetricsEqual(leftMessage.usage, rightMessage.usage) ||
        !_conversationPartsEqual(leftMessage.parts, rightMessage.parts)) {
      return false;
    }
  }
  return true;
}

bool _usageMetricsEqual(UsageMetrics? left, UsageMetrics? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left == null || right == null) {
    return false;
  }
  return left.totalTokens == right.totalTokens &&
      left.inputTokens == right.inputTokens &&
      left.outputTokens == right.outputTokens &&
      left.reasoningTokens == right.reasoningTokens &&
      left.cacheReadTokens == right.cacheReadTokens &&
      left.cacheWriteTokens == right.cacheWriteTokens &&
      left.cost == right.cost &&
      left.contextLimit == right.contextLimit &&
      left.contextUsagePercent == right.contextUsagePercent;
}

bool _conversationPartsEqual(
  List<ConversationPart> left,
  List<ConversationPart> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    final leftPart = left[index];
    final rightPart = right[index];
    if (leftPart.type != rightPart.type ||
        leftPart.display != rightPart.display ||
        leftPart.text != rightPart.text ||
        leftPart.title != rightPart.title ||
        leftPart.name != rightPart.name ||
        leftPart.description != rightPart.description ||
        leftPart.tool != rightPart.tool ||
        leftPart.path != rightPart.path ||
        leftPart.uri != rightPart.uri ||
        leftPart.mimeType != rightPart.mimeType ||
        leftPart.language != rightPart.language ||
        leftPart.callId != rightPart.callId ||
        leftPart.status != rightPart.status ||
        leftPart.attempt != rightPart.attempt ||
        leftPart.error != rightPart.error) {
      return false;
    }
  }
  return true;
}

bool _todoItemsEqual(List<TodoItem> left, List<TodoItem> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index].id != right[index].id ||
        left[index].content != right[index].content ||
        left[index].status != right[index].status ||
        left[index].priority != right[index].priority) {
      return false;
    }
  }
  return true;
}

bool _sessionContextStatusEquals(
  SessionContextStatus? left,
  SessionContextStatus? right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left == null || right == null) {
    return false;
  }
  return left.sessionId == right.sessionId &&
      left.directory == right.directory &&
      left.status == right.status &&
      left.parentId == right.parentId &&
      left.createdAt == right.createdAt &&
      left.updatedAt == right.updatedAt &&
      left.lastActivityAt == right.lastActivityAt &&
      left.messageCount == right.messageCount &&
      left.todoCount == right.todoCount &&
      left.pendingTodoCount == right.pendingTodoCount &&
      left.inProgressTodoCount == right.inProgressTodoCount &&
      left.completedTodoCount == right.completedTodoCount &&
      left.activeToolCount == right.activeToolCount &&
      left.compacting == right.compacting &&
      left.summaryAdditions == right.summaryAdditions &&
      left.summaryDeletions == right.summaryDeletions &&
      left.summaryFileCount == right.summaryFileCount &&
      left.currentStepTitle == right.currentStepTitle &&
      left.currentToolTitle == right.currentToolTitle &&
      left.currentToolStatus == right.currentToolStatus &&
      left.currentSubtaskDescription == right.currentSubtaskDescription &&
      left.currentRetryAttempt == right.currentRetryAttempt &&
      left.currentRetryError == right.currentRetryError;
}

bool _attentionStateEquals(AttentionState left, AttentionState right) {
  return _pendingQuestionsEqual(left.questions, right.questions) &&
      _pendingPermissionsEqual(left.permissions, right.permissions);
}

bool _pendingQuestionsEqual(
  List<PendingQuestion> left,
  List<PendingQuestion> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    final leftQuestion = left[index];
    final rightQuestion = right[index];
    if (leftQuestion.id != rightQuestion.id ||
        leftQuestion.sessionId != rightQuestion.sessionId ||
        leftQuestion.header != rightQuestion.header ||
        leftQuestion.question != rightQuestion.question ||
        leftQuestion.multiple != rightQuestion.multiple ||
        !_questionOptionsEqual(leftQuestion.options, rightQuestion.options)) {
      return false;
    }
  }
  return true;
}

bool _questionOptionsEqual(
  List<QuestionOption> left,
  List<QuestionOption> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index].label != right[index].label ||
        left[index].description != right[index].description) {
      return false;
    }
  }
  return true;
}

bool _pendingPermissionsEqual(
  List<PendingPermission> left,
  List<PendingPermission> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    final leftPermission = left[index];
    final rightPermission = right[index];
    if (leftPermission.id != rightPermission.id ||
        leftPermission.sessionId != rightPermission.sessionId ||
        leftPermission.tool != rightPermission.tool ||
        leftPermission.permission != rightPermission.permission ||
        !_stringListsEqual(leftPermission.patterns, rightPermission.patterns) ||
        !_stringDynamicMapsEqual(
          leftPermission.metadata,
          rightPermission.metadata,
        )) {
      return false;
    }
  }
  return true;
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _stringDynamicMapsEqual(
  Map<String, dynamic> left,
  Map<String, dynamic> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
