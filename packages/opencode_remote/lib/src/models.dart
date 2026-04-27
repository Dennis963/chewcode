class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.title,
    required this.directory,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    required this.status,
    required this.parentId,
  });

  final String id;
  final String title;
  final String? directory;
  final String? createdAt;
  final String? updatedAt;
  final String? archivedAt;
  final String? status;
  final String? parentId;

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Session',
      directory: json['directory'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      archivedAt: json['archivedAt'] as String?,
      status: json['status'] as String?,
      parentId: json['parentId'] as String?,
    );
  }
}

class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.path,
    required this.opened,
    required this.runtimeState,
    required this.lastOpenedAt,
    required this.port,
  });

  final String id;
  final String name;
  final String path;
  final bool opened;
  final String runtimeState;
  final String? lastOpenedAt;
  final int? port;

  factory ProjectSummary.fromJson(Map<String, dynamic> json) {
    return ProjectSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Project',
      path: json['path'] as String? ?? '',
      opened: json['opened'] as bool? ?? false,
      runtimeState: json['runtimeState'] as String? ?? 'stopped',
      lastOpenedAt: json['lastOpenedAt'] as String?,
      port: json['port'] as int?,
    );
  }
}

class ProjectCandidate {
  const ProjectCandidate({
    required this.path,
    required this.name,
    required this.sourceRoot,
  });

  final String path;
  final String name;
  final String sourceRoot;

  factory ProjectCandidate.fromJson(Map<String, dynamic> json) {
    return ProjectCandidate(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sourceRoot: json['sourceRoot'] as String? ?? '',
    );
  }
}

class ProjectDiscoveryResult {
  const ProjectDiscoveryResult({
    required this.items,
    required this.allowedRoots,
  });

  final List<ProjectCandidate> items;
  final List<String> allowedRoots;

  factory ProjectDiscoveryResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final rawAllowedRoots = json['allowedRoots'] as List<dynamic>? ?? const [];
    return ProjectDiscoveryResult(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(ProjectCandidate.fromJson)
          .toList(growable: false),
      allowedRoots: rawAllowedRoots.whereType<String>().toList(growable: false),
    );
  }
}

class UsageMetrics {
  const UsageMetrics({
    required this.totalTokens,
    required this.inputTokens,
    required this.outputTokens,
    required this.reasoningTokens,
    required this.cacheReadTokens,
    required this.cacheWriteTokens,
    required this.cost,
    required this.contextLimit,
    required this.contextUsagePercent,
  });

  final int? totalTokens;
  final int? inputTokens;
  final int? outputTokens;
  final int? reasoningTokens;
  final int? cacheReadTokens;
  final int? cacheWriteTokens;
  final num? cost;
  final int? contextLimit;
  final int? contextUsagePercent;

  factory UsageMetrics.fromJson(Map<String, dynamic> json) {
    return UsageMetrics(
      totalTokens: json['totalTokens'] as int?,
      inputTokens: json['inputTokens'] as int?,
      outputTokens: json['outputTokens'] as int?,
      reasoningTokens: json['reasoningTokens'] as int?,
      cacheReadTokens: json['cacheReadTokens'] as int?,
      cacheWriteTokens: json['cacheWriteTokens'] as int?,
      cost: json['cost'] as num?,
      contextLimit: json['contextLimit'] as int?,
      contextUsagePercent: json['contextUsagePercent'] as int?,
    );
  }
}

sealed class ConversationPart {
  const ConversationPart({
    required this.type,
    required this.display,
    required this.text,
    required this.title,
    required this.name,
    required this.description,
    required this.tool,
    required this.path,
    required this.uri,
    required this.mimeType,
    required this.language,
    required this.callId,
    required this.status,
    required this.attempt,
    required this.error,
    required this.metadata,
  });

  final String type;
  final String display;
  final String? text;
  final String? title;
  final String? name;
  final String? description;
  final String? tool;
  final String? path;
  final String? uri;
  final String? mimeType;
  final String? language;
  final String? callId;
  final String? status;
  final int? attempt;
  final String? error;
  final Map<String, dynamic> metadata;

  factory ConversationPart.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'meta';
    switch (type) {
      case 'text':
        return TextConversationPart.fromJson(json);
      case 'file':
        return FileConversationPart.fromJson(json);
      default:
        return UnknownConversationPart.fromJson(json);
    }
  }

  static Map<String, dynamic> _metadataFromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    if (metadata is Map<String, dynamic>) {
      return metadata;
    }
    return Map<String, dynamic>.from(json);
  }
}

class TextConversationPart extends ConversationPart {
  const TextConversationPart({
    required super.type,
    required super.display,
    required super.text,
    required super.title,
    required super.name,
    required super.description,
    required super.tool,
    required super.path,
    required super.uri,
    required super.mimeType,
    required super.language,
    required super.callId,
    required super.status,
    required super.attempt,
    required super.error,
    required super.metadata,
  });

  factory TextConversationPart.fromJson(Map<String, dynamic> json) {
    return TextConversationPart(
      type: json['type'] as String? ?? 'text',
      display: json['display'] as String? ?? 'inline',
      text: json['text'] as String?,
      title: json['title'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      tool: json['tool'] as String?,
      path: json['path'] as String?,
      uri: json['uri'] as String?,
      mimeType: json['mimeType'] as String?,
      language: json['language'] as String?,
      callId: json['callId'] as String?,
      status: json['status'] as String?,
      attempt: json['attempt'] as int?,
      error: json['error'] as String?,
      metadata: ConversationPart._metadataFromJson(json),
    );
  }
}

class FileConversationPart extends ConversationPart {
  const FileConversationPart({
    required super.type,
    required super.display,
    required super.text,
    required super.title,
    required super.name,
    required super.description,
    required super.tool,
    required super.path,
    required super.uri,
    required super.mimeType,
    required super.language,
    required super.callId,
    required super.status,
    required super.attempt,
    required super.error,
    required super.metadata,
  });

  factory FileConversationPart.fromJson(Map<String, dynamic> json) {
    return FileConversationPart(
      type: json['type'] as String? ?? 'file',
      display: json['display'] as String? ?? 'inline',
      text: json['text'] as String?,
      title: json['title'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      tool: json['tool'] as String?,
      path: json['path'] as String?,
      uri: json['uri'] as String?,
      mimeType: json['mimeType'] as String?,
      language: json['language'] as String?,
      callId: json['callId'] as String?,
      status: json['status'] as String?,
      attempt: json['attempt'] as int?,
      error: json['error'] as String?,
      metadata: ConversationPart._metadataFromJson(json),
    );
  }
}

class UnknownConversationPart extends ConversationPart {
  const UnknownConversationPart({
    required super.type,
    required super.display,
    required super.text,
    required super.title,
    required super.name,
    required super.description,
    required super.tool,
    required super.path,
    required super.uri,
    required super.mimeType,
    required super.language,
    required super.callId,
    required super.status,
    required super.attempt,
    required super.error,
    required super.metadata,
  });

  factory UnknownConversationPart.fromJson(Map<String, dynamic> json) {
    return UnknownConversationPart(
      type: json['type'] as String? ?? 'meta',
      display: json['display'] as String? ?? 'hidden',
      text: json['text'] as String?,
      title: json['title'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      tool: json['tool'] as String?,
      path: json['path'] as String?,
      uri: json['uri'] as String?,
      mimeType: json['mimeType'] as String?,
      language: json['language'] as String?,
      callId: json['callId'] as String?,
      status: json['status'] as String?,
      attempt: json['attempt'] as int?,
      error: json['error'] as String?,
      metadata: ConversationPart._metadataFromJson(json),
    );
  }
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.role,
    required this.createdAt,
    required this.completedAt,
    required this.error,
    this.providerId,
    this.modelId,
    required this.usage,
    required this.parts,
  });

  final String id;
  final String role;
  final String? createdAt;
  final String? completedAt;
  final String? error;
  final String? providerId;
  final String? modelId;
  final UsageMetrics? usage;
  final List<ConversationPart> parts;

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    final rawParts = json['parts'] as List<dynamic>? ?? const [];
    return ConversationMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'unknown',
      createdAt: json['createdAt'] as String?,
      completedAt: json['completedAt'] as String?,
      error: json['error'] as String?,
      providerId: json['providerId'] as String?,
      modelId: json['modelId'] as String?,
      usage: (json['usage'] as Map<String, dynamic>?) == null
          ? null
          : UsageMetrics.fromJson(json['usage'] as Map<String, dynamic>),
      parts: rawParts
          .whereType<Map<String, dynamic>>()
          .map(ConversationPart.fromJson)
          .toList(growable: false),
    );
  }
}

class TodoItem {
  const TodoItem({
    required this.id,
    required this.content,
    required this.status,
    required this.priority,
  });

  final String id;
  final String content;
  final String? status;
  final String? priority;

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? 'Untitled todo',
      status: json['status'] as String?,
      priority: json['priority'] as String?,
    );
  }
}

class SessionView {
  const SessionView({
    required this.session,
    required this.messages,
    required this.todos,
  });

  final SessionSummary session;
  final List<ConversationMessage> messages;
  final List<TodoItem> todos;

  factory SessionView.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? const [];
    final rawTodos = json['todos'] as List<dynamic>? ?? const [];

    return SessionView(
      session: SessionSummary.fromJson(
        (json['session'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      ),
      messages: rawMessages
          .whereType<Map<String, dynamic>>()
          .map(ConversationMessage.fromJson)
          .toList(growable: false),
      todos: rawTodos
          .whereType<Map<String, dynamic>>()
          .map(TodoItem.fromJson)
          .toList(growable: false),
    );
  }
}

class SessionContextStatus {
  const SessionContextStatus({
    required this.sessionId,
    required this.directory,
    required this.status,
    required this.parentId,
    required this.createdAt,
    required this.updatedAt,
    required this.lastActivityAt,
    required this.messageCount,
    required this.todoCount,
    required this.pendingTodoCount,
    required this.inProgressTodoCount,
    required this.completedTodoCount,
    required this.activeToolCount,
    required this.compacting,
    required this.summaryAdditions,
    required this.summaryDeletions,
    required this.summaryFileCount,
    required this.currentStepTitle,
    required this.currentToolTitle,
    required this.currentToolStatus,
    required this.currentSubtaskDescription,
    required this.currentRetryAttempt,
    required this.currentRetryError,
  });

  final String sessionId;
  final String? directory;
  final String? status;
  final String? parentId;
  final String? createdAt;
  final String? updatedAt;
  final String? lastActivityAt;
  final int messageCount;
  final int todoCount;
  final int pendingTodoCount;
  final int inProgressTodoCount;
  final int completedTodoCount;
  final int activeToolCount;
  final bool compacting;
  final int? summaryAdditions;
  final int? summaryDeletions;
  final int? summaryFileCount;
  final String? currentStepTitle;
  final String? currentToolTitle;
  final String? currentToolStatus;
  final String? currentSubtaskDescription;
  final int? currentRetryAttempt;
  final String? currentRetryError;

  factory SessionContextStatus.fromJson(Map<String, dynamic> json) {
    return SessionContextStatus(
      sessionId: json['sessionId'] as String? ?? '',
      directory: json['directory'] as String?,
      status: json['status'] as String?,
      parentId: json['parentId'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      lastActivityAt: json['lastActivityAt'] as String?,
      messageCount: json['messageCount'] as int? ?? 0,
      todoCount: json['todoCount'] as int? ?? 0,
      pendingTodoCount: json['pendingTodoCount'] as int? ?? 0,
      inProgressTodoCount: json['inProgressTodoCount'] as int? ?? 0,
      completedTodoCount: json['completedTodoCount'] as int? ?? 0,
      activeToolCount: json['activeToolCount'] as int? ?? 0,
      compacting: json['compacting'] as bool? ?? false,
      summaryAdditions: json['summaryAdditions'] as int?,
      summaryDeletions: json['summaryDeletions'] as int?,
      summaryFileCount: json['summaryFileCount'] as int?,
      currentStepTitle: json['currentStepTitle'] as String?,
      currentToolTitle: json['currentToolTitle'] as String?,
      currentToolStatus: json['currentToolStatus'] as String?,
      currentSubtaskDescription: json['currentSubtaskDescription'] as String?,
      currentRetryAttempt: json['currentRetryAttempt'] as int?,
      currentRetryError: json['currentRetryError'] as String?,
    );
  }
}

class FilePreview {
  const FilePreview({
    required this.path,
    required this.displayName,
    required this.content,
    required this.isText,
    required this.isBinary,
    required this.isTruncated,
    required this.lineCount,
    required this.sizeBytes,
    required this.language,
  });

  final String path;
  final String displayName;
  final String content;
  final bool isText;
  final bool isBinary;
  final bool isTruncated;
  final int? lineCount;
  final int? sizeBytes;
  final String? language;

  factory FilePreview.fromJson(Map<String, dynamic> json) {
    return FilePreview(
      path: json['path'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isText: json['isText'] as bool? ?? true,
      isBinary: json['isBinary'] as bool? ?? false,
      isTruncated: json['isTruncated'] as bool? ?? false,
      lineCount: json['lineCount'] as int?,
      sizeBytes: json['sizeBytes'] as int?,
      language: json['language'] as String?,
    );
  }
}

class DirectoryEntry {
  const DirectoryEntry({
    required this.path,
    required this.displayName,
    required this.kind,
    required this.sizeBytes,
  });

  final String path;
  final String displayName;
  final String kind;
  final int? sizeBytes;

  bool get isDirectory => kind == 'directory';

  factory DirectoryEntry.fromJson(Map<String, dynamic> json) {
    return DirectoryEntry(
      path: json['path'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      kind: json['kind'] as String? ?? 'file',
      sizeBytes: json['sizeBytes'] as int?,
    );
  }
}

class DirectoryListing {
  const DirectoryListing({
    required this.rootPath,
    required this.currentPath,
    required this.parentPath,
    required this.items,
  });

  final String rootPath;
  final String currentPath;
  final String? parentPath;
  final List<DirectoryEntry> items;

  factory DirectoryListing.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return DirectoryListing(
      rootPath: json['rootPath'] as String? ?? '',
      currentPath: json['currentPath'] as String? ?? '',
      parentPath: json['parentPath'] as String?,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(DirectoryEntry.fromJson)
          .toList(growable: false),
    );
  }
}

class FileSearchHit {
  const FileSearchHit({
    required this.path,
    required this.displayName,
    required this.kind,
    required this.line,
    required this.column,
    required this.previewText,
  });

  final String path;
  final String displayName;
  final String kind;
  final int? line;
  final int? column;
  final String? previewText;

  factory FileSearchHit.fromJson(Map<String, dynamic> json) {
    return FileSearchHit(
      path: json['path'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      kind: json['kind'] as String? ?? 'name',
      line: json['line'] as int?,
      column: json['column'] as int?,
      previewText: json['previewText'] as String?,
    );
  }
}

class FileSearchResult {
  const FileSearchResult({
    required this.query,
    required this.mode,
    required this.items,
  });

  final String query;
  final String mode;
  final List<FileSearchHit> items;

  factory FileSearchResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return FileSearchResult(
      query: json['query'] as String? ?? '',
      mode: json['mode'] as String? ?? 'name',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(FileSearchHit.fromJson)
          .toList(growable: false),
    );
  }
}

class BridgeEvent {
  const BridgeEvent({
    required this.type,
    required this.sessionId,
    required this.timestamp,
    required this.rawType,
    required this.payload,
  });

  final String type;
  final String? sessionId;
  final String timestamp;
  final String? rawType;
  final Map<String, dynamic> payload;

  factory BridgeEvent.fromJson(Map<String, dynamic> json) {
    return BridgeEvent(
      type: json['type'] as String? ?? 'upstream.event',
      sessionId: json['sessionId'] as String?,
      timestamp: json['timestamp'] as String? ?? '',
      rawType: json['rawType'] as String?,
      payload:
          (json['payload'] as Map<String, dynamic>? ??
          const <String, dynamic>{}),
    );
  }
}

class QuestionOption {
  const QuestionOption({required this.label, required this.description});

  final String label;
  final String? description;

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      label: json['label'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}

class PendingQuestion {
  const PendingQuestion({
    required this.id,
    required this.sessionId,
    required this.header,
    required this.question,
    required this.options,
    required this.multiple,
  });

  final String id;
  final String? sessionId;
  final String header;
  final String question;
  final List<QuestionOption> options;
  final bool multiple;

  factory PendingQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? const [];
    return PendingQuestion(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String?,
      header: json['header'] as String? ?? 'Question',
      question: json['question'] as String? ?? 'Response required',
      options: rawOptions
          .whereType<Map<String, dynamic>>()
          .map(QuestionOption.fromJson)
          .toList(growable: false),
      multiple: json['multiple'] as bool? ?? false,
    );
  }
}

class PendingPermission {
  const PendingPermission({
    required this.id,
    required this.sessionId,
    required this.tool,
    required this.permission,
    required this.patterns,
    required this.metadata,
  });

  final String id;
  final String? sessionId;
  final String? tool;
  final String permission;
  final List<String> patterns;
  final Map<String, dynamic> metadata;

  factory PendingPermission.fromJson(Map<String, dynamic> json) {
    final rawPatterns = json['patterns'] as List<dynamic>? ?? const [];
    return PendingPermission(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String?,
      tool: json['tool'] as String?,
      permission: json['permission'] as String? ?? 'permission',
      patterns: rawPatterns.whereType<String>().toList(growable: false),
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }
}

class AttentionState {
  const AttentionState({required this.questions, required this.permissions});

  final List<PendingQuestion> questions;
  final List<PendingPermission> permissions;

  factory AttentionState.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List<dynamic>? ?? const [];
    final rawPermissions = json['permissions'] as List<dynamic>? ?? const [];
    return AttentionState(
      questions: rawQuestions
          .whereType<Map<String, dynamic>>()
          .map(PendingQuestion.fromJson)
          .toList(growable: false),
      permissions: rawPermissions
          .whereType<Map<String, dynamic>>()
          .map(PendingPermission.fromJson)
          .toList(growable: false),
    );
  }
}

class CreateSessionResult {
  const CreateSessionResult({
    required this.session,
    required this.started,
    required this.promptError,
  });

  final SessionSummary session;
  final bool started;
  final String? promptError;

  factory CreateSessionResult.fromJson(Map<String, dynamic> json) {
    return CreateSessionResult(
      session: SessionSummary.fromJson(
        (json['session'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      ),
      started: json['started'] as bool? ?? false,
      promptError: json['promptError'] as String?,
    );
  }
}
