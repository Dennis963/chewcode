import { describe, expect, it } from "vitest"

import { mapAttentionState, mapBridgeEvent, mapSessionContextStatus, mapSessionSummaries, mapSessionView } from "../src/mappers.js"

describe("mapSessionSummaries", () => {
  it("maps session list and status payloads", () => {
    const sessions = {
      items: [
        {
          id: "s1",
          title: "Fix login flow",
          directory: "/repo/app",
          updatedAt: "2026-04-15T00:00:00Z",
        },
      ],
    }
    const statuses = {
      items: [
        {
          sessionId: "s1",
          status: "running",
        },
      ],
    }

    expect(mapSessionSummaries(sessions, statuses)).toEqual([
      {
        id: "s1",
        title: "Fix login flow",
        directory: "/repo/app",
        createdAt: null,
        updatedAt: "2026-04-15T00:00:00Z",
        archivedAt: null,
        status: "running",
        parentId: null,
      },
    ])
  })

  it("accepts sessionID casing in status payloads and prefers live status map", () => {
    const sessions = {
      items: [
        {
          id: "s1",
          title: "Fix login flow",
          directory: "/repo/app",
          status: "idle",
        },
      ],
    }
    const statuses = {
      items: [
        {
          sessionID: "s1",
          status: "busy",
        },
      ],
    }

    expect(mapSessionSummaries(sessions, statuses)).toEqual([
      {
        id: "s1",
        title: "Fix login flow",
        directory: "/repo/app",
        createdAt: null,
        updatedAt: null,
        archivedAt: null,
        status: "busy",
        parentId: null,
      },
    ])
  })

  it("normalizes parent id key variants including upstream parentID", () => {
    const sessions = {
      items: [
        { id: "child-upstream", parentID: "root-upstream" },
        { id: "child-camel", parentId: "root-camel" },
        { id: "child-snake", parent_id: "root-snake" },
      ],
    }

    expect(mapSessionSummaries(sessions, [])).toMatchObject([
      { id: "child-upstream", parentId: "root-upstream" },
      { id: "child-camel", parentId: "root-camel" },
      { id: "child-snake", parentId: "root-snake" },
    ])
  })
})

describe("mapSessionView", () => {
  it("maps messages and todos into app-friendly shape", () => {
    const session = { id: "s1", title: "Session 1", directory: "/repo" }
    const messages = {
      items: [
        {
          id: "m1",
          role: "assistant",
          blocks: [{ type: "text", text: "Hello" }],
        },
      ],
    }
    const todos = {
      items: [
        {
          id: "t1",
          content: "Run tests",
          status: "pending",
          priority: "high",
        },
      ],
    }

    expect(mapSessionView(session, messages, todos, { all: [] })).toEqual({
      session: {
        id: "s1",
        title: "Session 1",
        directory: "/repo",
        createdAt: null,
        updatedAt: null,
        archivedAt: null,
        status: null,
        parentId: null,
      },
      messages: [
        {
          id: "m1",
          role: "assistant",
          createdAt: null,
          completedAt: null,
          error: null,
          providerId: null,
          modelId: null,
          usage: null,
          parts: [
            {
              type: "text",
              display: "inline",
              text: "Hello",
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
              metadata: { type: "text", text: "Hello" },
            },
          ],
        },
      ],
      todos: [
        {
          id: "t1",
          content: "Run tests",
          status: "pending",
          priority: "high",
        },
      ],
    })
  })

  it("maps real opencode info and parts payloads", () => {
    const session = {
      id: 's1',
      title: 'Session 1',
      directory: '/repo',
      time: { created: 1776231132000, updated: 1776231133000 },
    }
    const messages = {
      items: [
        {
          info: {
            id: 'm1',
            role: 'user',
            time: { created: 1776231132657 },
          },
          parts: [
            {
              type: 'text',
              text: 'Say hello from smoke test.',
            },
          ],
        },
      ],
    }

    const result = mapSessionView(session, messages, { items: [] }, { all: [] })

    expect(result.session.createdAt).toBe('2026-04-15T05:32:12.000Z')
    expect(result.messages[0]).toEqual({
      id: 'm1',
      role: 'user',
      createdAt: '2026-04-15T05:32:12.657Z',
      completedAt: null,
      error: null,
      providerId: null,
      modelId: null,
      usage: null,
      parts: [
        {
          type: 'text',
          display: 'inline',
          text: 'Say hello from smoke test.',
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
          metadata: { type: 'text', text: 'Say hello from smoke test.' },
        },
      ],
    })
  })

  it("maps assistant usage onto conversation messages", () => {
    const result = mapSessionView(
      { id: 's1', title: 'Session 1', directory: '/repo' },
      {
        items: [
          {
            info: {
              id: 'm1',
              role: 'assistant',
              providerID: 'openai',
              modelID: 'gpt-5.4',
              cost: 0.42,
              tokens: {
                input: 1600,
                output: 600,
                reasoning: 120,
                cache: { read: 64, write: 16 },
              },
            },
            parts: [{ type: 'text', text: 'Done' }],
          },
        ],
      },
      { items: [] },
      {
        all: [
          {
            id: 'openai',
            models: {
              'gpt-5.4': {
                limit: { context: 8000 },
              },
            },
          },
        ],
      },
    )

    expect(result.messages[0]).toMatchObject({
      providerId: 'openai',
      modelId: 'gpt-5.4',
      usage: {
        totalTokens: 2400,
        inputTokens: 1600,
        outputTokens: 600,
        contextLimit: 8000,
        contextUsagePercent: 30,
      },
    })
  })

  it("preserves typed parts and display classification", () => {
    const result = mapSessionView(
      { id: 's1', title: 'Session 1', directory: '/repo' },
      {
        items: [
          {
            info: { id: 'm1', role: 'assistant' },
            parts: [
              { type: 'text', text: 'Done' },
              { type: 'file', path: '/repo/app.apk', name: 'app.apk' },
              { type: 'reasoning', text: 'Thinking' },
              { type: 'tool', title: 'bash', state: { status: 'running' } },
              { type: 'patch', text: 'diff' },
              { type: 'step-start', title: 'Explore' },
              { type: 'step-finish', text: 'done' },
              { type: 'subtask', description: 'Search repo structure' },
              { type: 'retry', attempt: 2, error: 'timeout' },
              { type: 'meta', content: 'raw meta' },
            ],
          },
        ],
      },
      { items: [] },
      { all: [] },
    )

    expect(result.messages[0].parts).toEqual(expect.arrayContaining([
      expect.objectContaining({ type: 'text', display: 'inline', text: 'Done' }),
      expect.objectContaining({ type: 'file', display: 'inline', path: '/repo/app.apk', name: 'app.apk' }),
      expect.objectContaining({ type: 'reasoning', display: 'collapsed', text: 'Thinking' }),
      expect.objectContaining({ type: 'tool', display: 'collapsed', title: 'bash', status: 'running' }),
      expect.objectContaining({ type: 'patch', display: 'hidden' }),
      expect.objectContaining({ type: 'step-start', display: 'hidden', title: 'Explore' }),
      expect.objectContaining({ type: 'step-finish', display: 'hidden', text: 'done' }),
      expect.objectContaining({ type: 'subtask', display: 'overlay_only', description: 'Search repo structure' }),
      expect.objectContaining({ type: 'retry', display: 'overlay_only', attempt: 2, error: 'timeout' }),
      expect.objectContaining({ type: 'meta', display: 'hidden', text: 'raw meta' }),
    ]))
  })
})

describe("mapSessionContextStatus", () => {
  it("derives context runtime counts from session payloads", () => {
    const result = mapSessionContextStatus(
      {
        id: "s1",
        title: "Session 1",
        directory: "/repo",
        time: { created: 1000, updated: 2000, compacting: 3000 },
        summary: { additions: 12, deletions: 3, files: ["a.ts", "b.ts"] },
      },
      { items: [{ sessionId: "s1", status: "busy" }] },
      {
        items: [
          {
            info: { id: "m1", role: "assistant", time: { created: 4000, completed: 5000 } },
            parts: [
              { type: "tool", state: { status: "running" } },
              { type: "text", text: "done" },
            ],
          },
        ],
      },
      {
        items: [
          { id: "t1", content: "a", status: "pending" },
          { id: "t2", content: "b", status: "in_progress" },
          { id: "t3", content: "c", status: "completed" },
        ],
      },
    )

    expect(result).toEqual({
      sessionId: "s1",
      directory: "/repo",
      status: "busy",
      parentId: null,
      createdAt: "1970-01-01T00:00:01.000Z",
      updatedAt: "1970-01-01T00:00:02.000Z",
      lastActivityAt: "1970-01-01T00:00:05.000Z",
      messageCount: 1,
      todoCount: 3,
      pendingTodoCount: 1,
      inProgressTodoCount: 1,
      completedTodoCount: 1,
      activeToolCount: 1,
      compacting: true,
      summaryAdditions: 12,
      summaryDeletions: 3,
      summaryFileCount: 2,
      currentStepTitle: null,
      currentToolTitle: null,
      currentToolStatus: "running",
      currentSubtaskDescription: null,
      currentRetryAttempt: null,
      currentRetryError: null,
    })
  })

  it("derives current step tool subtask and retry state", () => {
    const result = mapSessionContextStatus(
      { id: "s1", directory: "/repo" },
      [],
      {
        items: [
          {
            parts: [
              { type: "step-start", title: "Explore codebase" },
              { type: "tool", title: "bash", state: { status: "running" } },
              { type: "subtask", description: "Search repo structure" },
              { type: "retry", attempt: 2, error: "timeout" },
            ],
          },
        ],
      },
      { items: [] },
    )

    expect(result.currentStepTitle).toBe("Explore codebase")
    expect(result.currentToolTitle).toBe("bash")
    expect(result.currentToolStatus).toBe("running")
    expect(result.currentSubtaskDescription).toBe("Search repo structure")
    expect(result.currentRetryAttempt).toBe(2)
    expect(result.currentRetryError).toBe("timeout")
  })

  it("does not expose usage metrics on runtime-only context status", () => {
    const result = mapSessionContextStatus(
      { id: "s1", directory: "/repo" },
      [],
      {
        items: [
          {
            info: {
              id: "m1",
              role: "assistant",
              cost: 0.42,
              tokens: {
                input: 1600,
                output: 600,
                reasoning: 120,
                cache: { read: 64, write: 16 },
              },
            },
            parts: [],
          },
        ],
      },
      { items: [] },
      { items: [] },
    )

    expect(result).not.toHaveProperty('totalTokens')
    expect(result).not.toHaveProperty('contextUsagePercent')
  })
})

describe("mapBridgeEvent", () => {
  it("normalizes event payloads", () => {
    expect(
      mapBridgeEvent("todo.updated", {
        sessionId: "s1",
        value: 1,
      }),
    ).toMatchObject({
      type: "todo.updated",
      sessionId: "s1",
      rawType: "todo.updated",
      payload: { sessionId: "s1", value: 1 },
    })
  })

  it("extracts nested upstream event types and session ids", () => {
    expect(
      mapBridgeEvent(null, {
        directory: "/repo",
        payload: {
          type: "session.created",
          properties: {
            sessionID: "s1",
          },
        },
      }),
    ).toMatchObject({
      type: "session.created",
      sessionId: "s1",
    })
  })
})

describe("mapAttentionState", () => {
  it("maps pending questions and permissions", () => {
    const result = mapAttentionState(
      {
        items: [
          {
            id: "q1",
            sessionID: "s1",
            questions: [
              {
                header: "Need input",
                question: "Pick one",
                options: [{ label: "A", description: "Option A" }],
              },
            ],
          },
        ],
      },
      {
        items: [
          {
            id: "p1",
            sessionID: "s1",
            permission: "bash",
            tool: "bash",
            patterns: ["npm test"],
          },
        ],
      },
    )

    expect(result.questions[0]).toEqual({
      id: "q1",
      sessionId: "s1",
      header: "Need input",
      question: "Pick one",
      options: [{ label: "A", description: "Option A" }],
      multiple: false,
    })
    expect(result.permissions[0]).toEqual({
      id: "p1",
      sessionId: "s1",
      tool: "bash",
      permission: "bash",
      patterns: ["npm test"],
      metadata: {},
    })
  })
})
