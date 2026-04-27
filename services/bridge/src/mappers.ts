import type {
  CreateSessionResult,
  AttentionState,
  BridgeEvent,
  ConversationMessage,
  ConversationPart,
  ConversationPartDisplay,
  FilePreview,
  FileSearchHit,
  FileSearchResult,
  JsonObject,
  PendingPermission,
  PendingQuestion,
  QuestionOption,
  SessionContextStatus,
  SessionSummary,
  SessionView,
  TodoItem,
  UsageMetrics,
} from "./types.js"
import {
  asArray,
  asBoolean,
  asString,
  asStringOrEmpty,
  ensureId,
  isObject,
  pickFirstString,
  toJsonObject,
} from "./utils.js"

function extractItems(value: unknown): unknown[] {
  if (Array.isArray(value)) {
    return value
  }
  if (isObject(value)) {
    const candidates = [value.items, value.data, value.sessions, value.messages, value.todos]
    for (const candidate of candidates) {
      if (Array.isArray(candidate)) {
        return candidate
      }
    }
  }
  return []
}

function statusMapFrom(value: unknown): Map<string, string> {
  const result = new Map<string, string>()
  for (const item of extractItems(value)) {
    if (!isObject(item)) {
      continue
    }
    const id = pickFirstString(item, ["id", "sessionId", "session_id", "sessionID"])
    const status = pickFirstString(item, ["status", "state"])
    if (id && status) {
      result.set(id, status)
    }
  }
  return result
}

export function mapSessionSummaries(
  sessionsPayload: unknown,
  statusesPayload: unknown,
): SessionSummary[] {
  const statuses = statusMapFrom(statusesPayload)

  return extractItems(sessionsPayload)
    .map((item, index) => mapSessionSummary(item, statuses, index))
    .filter((item): item is SessionSummary => item !== null)
}

function mapSessionSummary(
  value: unknown,
  statuses: Map<string, string>,
  index: number,
): SessionSummary | null {
  if (!isObject(value)) {
    return null
  }

  const id = ensureId(
    pickFirstString(value, ["id", "sessionId", "session_id"]),
    `session-${index}`,
  )
  const title =
    pickFirstString(value, ["title", "name", "summary"]) ?? `Session ${index + 1}`
  const time = isObject(value.time) ? value.time : null

  return {
    id,
    title,
    directory: pickFirstString(value, ["directory", "cwd", "path"]),
    createdAt:
      pickFirstString(value, ["createdAt", "created_at", "created"]) ??
      stringifyTimestamp(time?.created),
    updatedAt:
      pickFirstString(value, ["updatedAt", "updated_at", "updated"]) ??
      stringifyTimestamp(time?.updated),
    archivedAt:
      pickFirstString(value, ["archivedAt", "archived_at", "archived"]) ??
      stringifyTimestamp(time?.archived),
    status:
      statuses.get(id) ?? pickFirstString(value, ["status", "state"]) ?? null,
    parentId: pickFirstString(value, ["parentId", "parent_id", "parentID"]),
  }
}

export function mapSessionView(
  sessionPayload: unknown,
  messagesPayload: unknown,
  todosPayload: unknown,
  providersPayload: unknown,
): SessionView {
  const session = mapSessionSummary(sessionPayload, new Map(), 0) ?? {
    id: "unknown-session",
    title: "Unknown Session",
    directory: null,
    createdAt: null,
    updatedAt: null,
    archivedAt: null,
    status: null,
    parentId: null,
  }

  return {
    session,
    messages: extractItems(messagesPayload)
      .map((item, index) => mapConversationMessage(item, index, providersPayload))
      .filter((item): item is ConversationMessage => item !== null),
    todos: extractItems(todosPayload)
      .map((item, index) => mapTodo(item, index))
      .filter((item): item is TodoItem => item !== null),
  }
}

export function mapSessionContextStatus(
  sessionPayload: unknown,
  statusesPayload: unknown,
  messagesPayload: unknown,
  todosPayload: unknown,
): SessionContextStatus {
  const session =
    mapSessionSummary(sessionPayload, statusMapFrom(statusesPayload), 0) ?? {
      id: "unknown-session",
      title: "Unknown Session",
      directory: null,
      createdAt: null,
      updatedAt: null,
      archivedAt: null,
      status: null,
      parentId: null,
    }

  const messages = extractItems(messagesPayload)
  const todos = extractItems(todosPayload)
    .map((item, index) => mapTodo(item, index))
    .filter((item): item is TodoItem => item !== null)

  const todoCounts = countTodosByStatus(todos)
  const lastActivityAt = computeLastActivityAt(sessionPayload, messages)
  const activeToolCount = countActiveTools(messages)
  const executionState = deriveExecutionState(messages)
  const sessionObject = toJsonObject(sessionPayload)
  const summary = toJsonObject(sessionObject.summary)
  const time = toJsonObject(sessionObject.time)

  return {
    sessionId: session.id,
    directory: session.directory,
    status: session.status,
    parentId: session.parentId,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
    lastActivityAt,
    messageCount: messages.length,
    todoCount: todos.length,
    pendingTodoCount: todoCounts.pending,
    inProgressTodoCount: todoCounts.inProgress,
    completedTodoCount: todoCounts.completed,
    activeToolCount,
    compacting: time.compacting != null,
    summaryAdditions: asNumber(summary.additions),
    summaryDeletions: asNumber(summary.deletions),
    summaryFileCount: extractArrayCount(summary.files),
    currentStepTitle: executionState.currentStepTitle,
    currentToolTitle: executionState.currentToolTitle,
    currentToolStatus: executionState.currentToolStatus,
    currentSubtaskDescription: executionState.currentSubtaskDescription,
    currentRetryAttempt: executionState.currentRetryAttempt,
    currentRetryError: executionState.currentRetryError,
  }
}

function mapConversationMessage(
  value: unknown,
  index: number,
  providersPayload: unknown,
): ConversationMessage | null {
  if (!isObject(value)) {
    return null
  }

  const info = isObject(value.info) ? value.info : null
  const time = info && isObject(info.time) ? info.time : null
  const usage = extractConversationUsage(value, normalizeProviders(providersPayload))

  return {
    id: ensureId(
      pickFirstString(value, ["id", "messageId", "message_id"]) ??
          pickFirstString(info ?? {}, ["id", "messageId", "message_id"]),
      `message-${index}`,
    ),
    role:
      pickFirstString(value, ["role", "type"]) ??
      pickFirstString(info ?? {}, ["role", "type"]) ??
      "unknown",
    createdAt:
      pickFirstString(value, ["createdAt", "created_at", "timestamp"]) ??
      pickFirstString(info ?? {}, ["createdAt", "created_at", "timestamp"]) ??
      stringifyTimestamp(time?.created),
    completedAt:
      pickFirstString(value, ["completedAt", "completed_at"]) ??
      pickFirstString(info ?? {}, ["completedAt", "completed_at"]) ??
      stringifyTimestamp(time?.completed),
    error:
      pickFirstString(value, ["error", "errorMessage"]) ??
      pickFirstString(info ?? {}, ["error", "errorMessage"]),
    providerId:
      pickFirstString(info ?? {}, ["providerID", "providerId", "provider_id"]),
    modelId:
      pickFirstString(info ?? {}, ["modelID", "modelId", "model_id"]),
    usage: hasUsageMetrics(usage) ? usage : null,
    parts: mapConversationParts(value),
  }
}

function extractConversationUsage(
  value: JsonObject,
  providers: Map<string, Map<string, number | null>>,
): UsageMetrics {
  const info = toJsonObject(value.info)
  const infoUsage = extractUsageMetrics(info, providers)
  let bestUsage = infoUsage

  for (const part of extractItems(value.parts).reverse()) {
    if (!isObject(part)) {
      continue
    }
    if (pickFirstString(part, ["type"]) !== "step-finish") {
      continue
    }

    const partUsage = extractUsageMetrics(part, providers, info)
    if (hasTokenOrCostMetrics(partUsage)) {
      bestUsage = mergeUsageMetrics(infoUsage, partUsage)
      break
    }
  }

  return bestUsage
}

function mapConversationParts(value: JsonObject): ConversationPart[] {
  const blocks = extractItems(value.blocks)
  const parts = extractItems(value.parts)
  if (blocks.length > 0) {
    const mapped = blocks
      .map((block) => mapLegacyBlockPart(block))
      .filter((item): item is ConversationPart => item !== null)
    if (mapped.length > 0) {
      return mapped
    }
  }

  if (parts.length > 0) {
    const mapped = parts
      .map((part) => mapConversationPart(part))
      .filter((item): item is ConversationPart => item !== null)
    if (mapped.length > 0) {
      return mapped
    }
  }

  const fallbackText =
    pickFirstString(value, ["text", "content", "message", "summary"]) ?? JSON.stringify(value)

  return [
    {
      type: "meta",
      display: "hidden",
      text: fallbackText,
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
      metadata: value,
    },
  ]
}

function mapLegacyBlockPart(value: unknown): ConversationPart | null {
  if (!isObject(value)) {
    return null
  }

  const normalizedType = normalizePartType(pickFirstString(value, ["type", "kind"]))
  return buildConversationPart(value, normalizedType)
}

function mapConversationPart(value: unknown): ConversationPart | null {
  if (!isObject(value)) {
    return null
  }

  const normalizedType = normalizePartType(pickFirstString(value, ["type"]))
  return buildConversationPart(value, normalizedType)
}

function buildConversationPart(value: JsonObject, normalizedType: string): ConversationPart {
  const state = toJsonObject(value.state)
  return {
    type: normalizedType,
    display: classifyConversationPartDisplay(normalizedType),
    text: extractPartText(value),
    title: pickFirstString(value, ["title"]),
    name: pickFirstString(value, ["name"]),
    description: pickFirstString(value, ["description", "prompt"]),
    tool: pickFirstString(value, ["tool", "callID", "callId", "name", "title"]),
    path: pickFirstString(value, ["path", "filename", "filePath", "file"]),
    uri: pickFirstString(value, ["uri", "url"]),
    mimeType: pickFirstString(value, ["mimeType", "mediaType", "contentType"]),
    language: pickFirstString(value, ["language", "lang"]),
    callId: pickFirstString(value, ["callID", "callId"]),
    status: pickFirstString(state, ["status"]),
    attempt: asNumber(value.attempt),
    error: pickFirstString(value, ["error", "errorMessage", "message"]),
    metadata: value,
  }
}

function extractPartText(value: JsonObject): string | null {
  return pickFirstString(value, [
    "text",
    "content",
    "summary",
    "message",
    "title",
    "name",
    "description",
    "prompt",
  ]) ?? null
}

function normalizePartType(type: string | null | undefined): string {
  const normalized = type?.trim().toLowerCase()
  if (!normalized) {
    return "meta"
  }
  if (normalized === "text" || normalized.includes("delta")) {
    return "text"
  }
  if (normalized.includes("reason")) {
    return "reasoning"
  }
  if (normalized.includes("tool")) {
    return "tool"
  }
  if (normalized.includes("file")) {
    return "file"
  }
  return normalized
}

function classifyConversationPartDisplay(type: string): ConversationPartDisplay {
  switch (type) {
    case "text":
    case "file":
      return "inline"
    case "reasoning":
    case "tool":
      return "collapsed"
    case "subtask":
    case "retry":
      return "overlay_only"
    case "patch":
    case "step-start":
    case "step-finish":
    case "meta":
      return "hidden"
    default:
      return "hidden"
  }
}

function countTodosByStatus(todos: TodoItem[]): {
  pending: number
  inProgress: number
  completed: number
} {
  let pending = 0
  let inProgress = 0
  let completed = 0

  for (const todo of todos) {
    const status = todo.status?.toLowerCase() ?? ""
    if (status === "pending") {
      pending += 1
    } else if (status === "in_progress" || status === "in-progress" || status === "running") {
      inProgress += 1
    } else if (status === "completed" || status === "done") {
      completed += 1
    }
  }

  return { pending, inProgress, completed }
}

function computeLastActivityAt(sessionPayload: unknown, messages: unknown[]): string | null {
  const timestamps: number[] = []
  const sessionObject = toJsonObject(sessionPayload)
  collectTimestampsFromUnknown(sessionObject.time, timestamps)

  for (const message of messages) {
    if (!isObject(message)) {
      continue
    }
    collectTimestampsFromUnknown(message.time, timestamps)
    const info = toJsonObject(message.info)
    collectTimestampsFromUnknown(info.time, timestamps)
    for (const part of extractItems(message.parts)) {
      if (!isObject(part)) {
        continue
      }
      collectTimestampsFromUnknown(part.time, timestamps)
    }
  }

  if (timestamps.length === 0) {
    return pickFirstString(sessionObject, ["updatedAt", "createdAt"]) ?? null
  }

  return new Date(Math.max(...timestamps)).toISOString()
}

function collectTimestampsFromUnknown(value: unknown, timestamps: number[]): void {
  if (!isObject(value)) {
    return
  }

  for (const nested of Object.values(value)) {
    if (typeof nested === "number" && Number.isFinite(nested)) {
      timestamps.push(nested)
    }
  }
}

function countActiveTools(messages: unknown[]): number {
  let count = 0

  for (const message of messages) {
    if (!isObject(message)) {
      continue
    }

    for (const part of extractItems(message.parts)) {
      if (!isObject(part)) {
        continue
      }
      const type = pickFirstString(part, ["type"])
      if (type !== "tool") {
        continue
      }

      const state = toJsonObject(part.state)
      const status = pickFirstString(state, ["status"])
      if (status == null) {
        continue
      }

      if (status === "pending" || status === "running") {
        count += 1
      }
    }
  }

  return count
}

function deriveExecutionState(messages: unknown[]): {
  currentStepTitle: string | null
  currentToolTitle: string | null
  currentToolStatus: string | null
  currentSubtaskDescription: string | null
  currentRetryAttempt: number | null
  currentRetryError: string | null
} {
  let currentStepTitle: string | null = null
  let currentToolTitle: string | null = null
  let currentToolStatus: string | null = null
  let currentSubtaskDescription: string | null = null
  let currentRetryAttempt: number | null = null
  let currentRetryError: string | null = null

  for (const message of messages) {
    if (!isObject(message)) {
      continue
    }

    for (const part of extractItems(message.parts)) {
      if (!isObject(part)) {
        continue
      }

      const type = pickFirstString(part, ["type"])
      if (type === "step-start") {
        currentStepTitle = pickFirstString(part, ["title", "name"])
      }

      if (type === "tool") {
        const state = toJsonObject(part.state)
        const status = pickFirstString(state, ["status"])
        const title = pickFirstString(part, ["title", "tool", "name"])
        if (status === "pending" || status === "running") {
          currentToolStatus = status
          currentToolTitle = title
        }
      }

      if (type === "subtask") {
        currentSubtaskDescription =
          pickFirstString(part, ["description", "prompt", "title"]) ?? currentSubtaskDescription
      }

      if (type === "retry") {
        currentRetryAttempt = asNumber(part.attempt)
        currentRetryError = pickFirstString(part, ["error", "message"])
      }
    }
  }

  return {
    currentStepTitle,
    currentToolTitle,
    currentToolStatus,
    currentSubtaskDescription,
    currentRetryAttempt,
    currentRetryError,
  }
}

function extractUsageMetrics(
  source: JsonObject,
  providers: Map<string, Map<string, number | null>>,
  fallbackSource?: JsonObject,
): UsageMetrics {
  const tokens = toJsonObject(source.tokens)
  const cache = toJsonObject(tokens.cache)
  const inputTokens = asNumber(tokens.input)
  const outputTokens = asNumber(tokens.output)
  const reasoningTokens = asNumber(tokens.reasoning)
  const cacheReadTokens = asNumber(cache.read)
  const cacheWriteTokens = asNumber(cache.write)
  const explicitTotal = asNumber(tokens.total)
  const totalTokens = explicitTotal ?? sumNumbers([
    inputTokens,
    outputTokens,
    reasoningTokens,
    cacheReadTokens,
    cacheWriteTokens,
  ])
  const providerID = pickFirstString(source, ["providerID", "providerId", "provider_id"]) ??
      pickFirstString(fallbackSource ?? {}, ["providerID", "providerId", "provider_id"])
  const modelID = pickFirstString(source, ["modelID", "modelId", "model_id"]) ??
      pickFirstString(fallbackSource ?? {}, ["modelID", "modelId", "model_id"])
  const contextLimit = providerID && modelID
    ? providers.get(providerID)?.get(modelID) ?? null
    : null
  const contextUsagePercent = totalTokens != null && contextLimit != null && contextLimit > 0
    ? Math.round((totalTokens / contextLimit) * 100)
    : null

  return {
    totalTokens,
    inputTokens,
    outputTokens,
    reasoningTokens,
    cacheReadTokens,
    cacheWriteTokens,
    cost: asNumber(source.cost),
    contextLimit,
    contextUsagePercent,
  }
}

function hasUsageMetrics(value: {
  totalTokens: number | null
  inputTokens: number | null
  outputTokens: number | null
  reasoningTokens: number | null
  cacheReadTokens: number | null
  cacheWriteTokens: number | null
  cost: number | null
  contextLimit: number | null
  contextUsagePercent: number | null
}): boolean {
  return value.totalTokens != null ||
    value.inputTokens != null ||
    value.outputTokens != null ||
    value.reasoningTokens != null ||
    value.cacheReadTokens != null ||
    value.cacheWriteTokens != null ||
    value.cost != null ||
    value.contextLimit != null ||
    value.contextUsagePercent != null
}

function hasTokenOrCostMetrics(value: UsageMetrics): boolean {
  return value.totalTokens != null ||
    value.inputTokens != null ||
    value.outputTokens != null ||
    value.reasoningTokens != null ||
    value.cacheReadTokens != null ||
    value.cacheWriteTokens != null ||
    value.cost != null
}

function mergeUsageMetrics(primary: UsageMetrics, secondary: UsageMetrics): UsageMetrics {
  return {
    totalTokens: secondary.totalTokens ?? primary.totalTokens,
    inputTokens: secondary.inputTokens ?? primary.inputTokens,
    outputTokens: secondary.outputTokens ?? primary.outputTokens,
    reasoningTokens: secondary.reasoningTokens ?? primary.reasoningTokens,
    cacheReadTokens: secondary.cacheReadTokens ?? primary.cacheReadTokens,
    cacheWriteTokens: secondary.cacheWriteTokens ?? primary.cacheWriteTokens,
    cost: secondary.cost ?? primary.cost,
    contextLimit: secondary.contextLimit ?? primary.contextLimit,
    contextUsagePercent: secondary.contextUsagePercent ?? primary.contextUsagePercent,
  }
}

function normalizeProviders(payload: unknown): Map<string, Map<string, number | null>> {
  const result = new Map<string, Map<string, number | null>>()
  const objectPayload = toJsonObject(payload)
  const items = Array.isArray(objectPayload.all)
    ? objectPayload.all
    : Array.isArray(objectPayload.providers)
      ? objectPayload.providers
      : extractItems(payload)

  for (const item of items) {
    if (!isObject(item)) {
      continue
    }
    const providerID = pickFirstString(item, ["id", "providerID", "providerId"])
    if (!providerID) {
      continue
    }
    const models = toJsonObject(item.models)
    const modelLimits = new Map<string, number | null>()
    for (const [modelID, modelValue] of Object.entries(models)) {
      if (!isObject(modelValue)) {
        continue
      }
      const limit = toJsonObject(modelValue.limit)
      modelLimits.set(modelID, asNumber(limit.context))
    }
    result.set(providerID, modelLimits)
  }

  return result
}

function sumNumbers(values: Array<number | null>): number | null {
  let total = 0
  let hasValue = false
  for (const value of values) {
    if (value == null) {
      continue
    }
    total += value
    hasValue = true
  }
  return hasValue ? total : null
}

function mapTodo(value: unknown, index: number): TodoItem | null {
  if (!isObject(value)) {
    return null
  }

  return {
    id: ensureId(pickFirstString(value, ["id", "todoId", "todo_id"]), `todo-${index}`),
    content: pickFirstString(value, ["content", "title", "text", "label"]) ?? "Untitled todo",
    status: pickFirstString(value, ["status", "state"]),
    priority: pickFirstString(value, ["priority", "importance"]),
  }
}

export function mapBridgeEvent(rawType: string | null, payload: unknown): BridgeEvent {
  const objectPayload = toJsonObject(payload)
  const sessionId = extractEventSessionId(objectPayload)
  const inferredType =
    pickFirstString(objectPayload, ["type", "event", "name"]) ??
    extractNestedEventType(objectPayload) ??
    rawType ??
    "upstream.event"

  return {
    type: inferredType,
    sessionId,
    timestamp: new Date().toISOString(),
    rawType,
    payload: objectPayload,
  }
}

export function encodeSse(event: BridgeEvent): string {
  return `event: bridge-event\ndata: ${JSON.stringify(event)}\n\n`
}

export function mapCreateSessionResult(
  sessionPayload: unknown,
  options: { started: boolean; promptError?: string | null },
): CreateSessionResult {
  return {
    session:
      mapSessionSummary(sessionPayload, new Map(), 0) ?? {
        id: "unknown-session",
        title: "Unknown Session",
        directory: null,
        createdAt: null,
        updatedAt: null,
        archivedAt: null,
        status: null,
        parentId: null,
      },
    started: options.started,
    promptError: options.promptError ?? null,
  }
}

export function mapAttentionState(
  questionsPayload: unknown,
  permissionsPayload: unknown,
): AttentionState {
  return {
    questions: extractItems(questionsPayload)
      .map((item, index) => mapPendingQuestion(item, index))
      .filter((item): item is PendingQuestion => item !== null),
    permissions: extractItems(permissionsPayload)
      .map((item, index) => mapPendingPermission(item, index))
      .filter((item): item is PendingPermission => item !== null),
  }
}

export function mapFilePreview(
  path: string,
  filePayload: unknown,
  contentPayload: unknown,
): FilePreview {
  const fileObject = toJsonObject(filePayload)
  const contentObject = toJsonObject(contentPayload)
  const content =
    pickFirstString(contentObject, ["content", "text"]) ??
    pickFirstString(fileObject, ["content", "text"]) ??
    ""

  const pathParts = path.split("/")
  const displayName = pathParts[pathParts.length - 1] || path
  const language = pickFirstString(fileObject, ["language", "lang"])
  const sizeBytes = asNumber(fileObject.size)
  const isBinary = asBoolean(fileObject.binary) || asBoolean(contentObject.binary)
  const isText = !isBinary
  const isTruncated = asBoolean(fileObject.truncated) || asBoolean(contentObject.truncated)
  const lineCount = content.length === 0 ? 0 : content.split("\n").length

  return {
    path,
    displayName,
    content,
    isText,
    isBinary,
    isTruncated,
    lineCount,
    sizeBytes,
    language,
  }
}

export function mapFileSearchResult(
  query: string,
  mode: "name" | "text",
  payload: unknown,
): FileSearchResult {
  return {
    query,
    mode,
    items: extractItems(payload)
      .map((item) => mapFileSearchHit(mode, item))
      .filter((item): item is FileSearchHit => item !== null),
  }
}

function mapFileSearchHit(
  mode: "name" | "text",
  value: unknown,
): FileSearchHit | null {
  if (!isObject(value)) {
    return null
  }

  const path =
    pickFirstString(value, ["path", "file", "filename", "name"]) ?? null
  if (path == null) {
    return null
  }

  return {
    path,
    displayName: (() => {
      const pathParts = path.split("/")
      return pathParts[pathParts.length - 1] || path
    })(),
    kind: mode,
    line: asNumber(value.line),
    column: asNumber(value.column),
    previewText:
      pickFirstString(value, ["preview", "text", "content", "match"]) ?? null,
  }
}

function mapPendingQuestion(value: unknown, index: number): PendingQuestion | null {
  if (!isObject(value)) {
    return null
  }

  const questions = asArray(value.questions)
  const firstQuestion = questions.find((item) => isObject(item))
  const questionObject = isObject(firstQuestion) ? firstQuestion : {}

  return {
    id: ensureId(pickFirstString(value, ["id", "requestID", "requestId"]), `question-${index}`),
    sessionId: pickFirstString(value, ["sessionID", "sessionId"]),
    header: pickFirstString(questionObject, ["header"]) ?? "Question",
    question: pickFirstString(questionObject, ["question", "text"]) ?? "Response required",
    options: asArray(questionObject.options)
      .map((item) => mapQuestionOption(item))
      .filter((item): item is QuestionOption => item !== null),
    multiple: asBoolean(questionObject.multiple),
  }
}

function mapQuestionOption(value: unknown): QuestionOption | null {
  if (!isObject(value)) {
    return null
  }

  const label = pickFirstString(value, ["label"])
  if (!label) {
    return null
  }

  return {
    label,
    description: pickFirstString(value, ["description"]),
  }
}

function mapPendingPermission(
  value: unknown,
  index: number,
): PendingPermission | null {
  if (!isObject(value)) {
    return null
  }

  return {
    id: ensureId(pickFirstString(value, ["id", "requestID", "requestId"]), `permission-${index}`),
    sessionId: pickFirstString(value, ["sessionID", "sessionId"]),
    tool: pickFirstString(value, ["tool"]),
    permission: pickFirstString(value, ["permission", "name"]) ?? "permission",
    patterns: asArray(value.patterns)
      .map((item) => asStringOrEmpty(item))
      .filter((item) => item.length > 0),
    metadata: toJsonObject(value.metadata),
  }
}

function stringifyTimestamp(value: unknown): string | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return new Date(value).toISOString()
  }
  if (typeof value === "string" && value.length > 0) {
    return value
  }
  return null
}

function asNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null
}

function extractArrayCount(value: unknown): number | null {
  return Array.isArray(value) ? value.length : null
}

function extractNestedEventType(value: JsonObject): string | null {
  const payload = toJsonObject(value.payload)
  return pickFirstString(payload, ["type", "event", "name"])
}

function extractEventSessionId(value: JsonObject): string | null {
  const direct = pickFirstString(value, ["sessionId", "session_id", "id", "sessionID"])
  if (direct) {
    return direct
  }

  const payload = toJsonObject(value.payload)
  const payloadDirect = pickFirstString(payload, ["sessionId", "session_id", "sessionID", "aggregateID", "id"])
  if (payloadDirect) {
    return payloadDirect
  }

  const properties = toJsonObject(payload.properties)
  return pickFirstString(properties, ["sessionID", "sessionId", "session_id", "aggregateID", "id"])
}
