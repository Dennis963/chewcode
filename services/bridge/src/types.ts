export type JsonObject = Record<string, unknown>

export type SessionSummary = {
  id: string
  title: string
  directory: string | null
  createdAt: string | null
  updatedAt: string | null
  archivedAt: string | null
  status: string | null
  parentId: string | null
}

export type ConversationPartDisplay = "inline" | "hidden" | "collapsed" | "overlay_only"

export type UsageMetrics = {
  totalTokens: number | null
  inputTokens: number | null
  outputTokens: number | null
  reasoningTokens: number | null
  cacheReadTokens: number | null
  cacheWriteTokens: number | null
  cost: number | null
  contextLimit: number | null
  contextUsagePercent: number | null
}

export type ConversationPart = {
  type: string
  display: ConversationPartDisplay
  text: string | null
  title: string | null
  name: string | null
  description: string | null
  tool: string | null
  path: string | null
  uri: string | null
  mimeType: string | null
  language: string | null
  callId: string | null
  status: string | null
  attempt: number | null
  error: string | null
  metadata: JsonObject
}

export type ConversationMessage = {
  id: string
  role: string
  createdAt: string | null
  completedAt: string | null
  error: string | null
  providerId: string | null
  modelId: string | null
  usage: UsageMetrics | null
  parts: ConversationPart[]
}

export type TodoItem = {
  id: string
  content: string
  status: string | null
  priority: string | null
}

export type SessionView = {
  session: SessionSummary
  messages: ConversationMessage[]
  todos: TodoItem[]
}

export type SessionContextStatus = {
  sessionId: string
  directory: string | null
  status: string | null
  parentId: string | null
  createdAt: string | null
  updatedAt: string | null
  lastActivityAt: string | null
  messageCount: number
  todoCount: number
  pendingTodoCount: number
  inProgressTodoCount: number
  completedTodoCount: number
  activeToolCount: number
  compacting: boolean
  summaryAdditions: number | null
  summaryDeletions: number | null
  summaryFileCount: number | null
  currentStepTitle: string | null
  currentToolTitle: string | null
  currentToolStatus: string | null
  currentSubtaskDescription: string | null
  currentRetryAttempt: number | null
  currentRetryError: string | null
}

export type QuestionOption = {
  label: string
  description: string | null
}

export type PendingQuestion = {
  id: string
  sessionId: string | null
  header: string
  question: string
  options: QuestionOption[]
  multiple: boolean
}

export type PendingPermission = {
  id: string
  sessionId: string | null
  tool: string | null
  permission: string
  patterns: string[]
  metadata: JsonObject
}

export type AttentionState = {
  questions: PendingQuestion[]
  permissions: PendingPermission[]
}

export type FilePreview = {
  path: string
  displayName: string
  content: string
  isText: boolean
  isBinary: boolean
  isTruncated: boolean
  lineCount: number | null
  sizeBytes: number | null
  language: string | null
}

export type DirectoryEntry = {
  path: string
  displayName: string
  kind: "directory" | "file"
  sizeBytes: number | null
}

export type DirectoryListing = {
  rootPath: string
  currentPath: string
  parentPath: string | null
  items: DirectoryEntry[]
}

export type FileSearchHit = {
  path: string
  displayName: string
  kind: "name" | "text"
  line: number | null
  column: number | null
  previewText: string | null
}

export type FileSearchResult = {
  query: string
  mode: "name" | "text"
  items: FileSearchHit[]
}

export type BridgeEvent = {
  type: string
  sessionId: string | null
  timestamp: string
  rawType: string | null
  payload: JsonObject
}

export type CreateSessionResult = {
  session: SessionSummary
  started: boolean
  promptError: string | null
}

export type ProjectSummary = {
  id: string
  name: string
  path: string
  opened: boolean
  runtimeState: string
  lastOpenedAt: string | null
  port: number | null
}

export type ProjectCandidate = {
  path: string
  name: string
  sourceRoot: string
}
