import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises"
import os, { tmpdir } from "node:os"
import path from "node:path"

import { afterEach, describe, expect, it, vi } from "vitest"

import { buildServer } from "../src/server.js"

const originalFetch = global.fetch
const serverOptions = {
  upstreamBaseUrl: "http://127.0.0.1:4096",
  bearerToken: "test-token",
} as const

afterEach(() => {
  global.fetch = originalFetch
  vi.restoreAllMocks()
})

describe("POST /v1/sessions/:id/prompts", () => {
  it("forwards prompt to upstream prompt_async endpoint", async () => {
    const fetchMock = vi.fn(async (input: URL | RequestInfo, init?: RequestInit) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session/abc/prompt_async")) {
        expect(init?.method).toBe("POST")
        expect(init?.body).toBe(
          JSON.stringify({
            parts: [{ type: "text", text: "Continue please" }],
          }),
        )
        return new Response(null, { status: 204 })
      }

      throw new Error(`Unexpected fetch to ${url}`)
    })

    global.fetch = fetchMock as typeof fetch

    const server = buildServer(serverOptions)

    const response = await server.inject({
      method: "POST",
      url: "/v1/sessions/abc/prompts",
      headers: { authorization: "Bearer test-token" },
      payload: { prompt: "Continue please" },
    })

    expect(response.statusCode).toBe(202)
    expect(response.json()).toEqual({ ok: true, sessionId: "abc" })
    await server.close()
  })

  it("derives summarize provider and model from the latest assistant message", async () => {
    const fetchMock = vi.fn(async (input: URL | RequestInfo, init?: RequestInit) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session/abc/message") && init?.method == null) {
        return Response.json({
          items: [
            { info: { id: "m1", role: "assistant", providerID: "openai", modelID: "gpt-5.4" }, parts: [] },
          ],
        })
      }

      if (url.endsWith("/session/abc/summarize")) {
        expect(init?.method).toBe("POST")
        expect(init?.body).toBe(
          JSON.stringify({ providerID: "openai", modelID: "gpt-5.4", auto: false }),
        )
        return Response.json(true)
      }

      throw new Error(`Unexpected fetch to ${url}`)
    })

    global.fetch = fetchMock as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "POST",
      url: "/v1/sessions/abc/summarize",
      headers: { authorization: "Bearer test-token" },
      payload: {},
    })

    expect(response.statusCode).toBe(202)
    expect(response.json()).toEqual({ ok: true, sessionId: "abc" })
    await server.close()
  })
})

describe("project route error shaping", () => {
  it("returns structured 404 for unknown project IDs", async () => {
    const server = buildServer(serverOptions)

    const response = await server.inject({
      method: "GET",
      url: "/v1/projects/missing/sessions",
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(404)
    expect(response.json()).toMatchObject({ error: "project_not_found" })
    await server.close()
  })
})

describe("POST /v1/sessions", () => {
  it("creates a session and optionally starts it with a prompt", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo, init?: RequestInit) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session") && init?.method === "POST") {
        expect(init.body).toBe(JSON.stringify({ title: "New task" }))
        return Response.json({ id: "s-new", title: "New task", directory: "/repo" })
      }

      if (url.endsWith("/session/s-new/prompt_async") && init?.method === "POST") {
        expect(init.body).toBe(JSON.stringify({ parts: [{ type: "text", text: "Start implementing" }] }))
        return new Response(null, { status: 204 })
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "POST",
      url: "/v1/sessions",
      headers: { authorization: "Bearer test-token" },
      payload: { title: "New task", prompt: "Start implementing" },
    })

    expect(response.statusCode).toBe(201)
    expect(response.json()).toEqual({
      session: {
        id: "s-new",
        title: "New task",
        directory: "/repo",
        createdAt: null,
        updatedAt: null,
        archivedAt: null,
        status: null,
        parentId: null,
      },
      started: true,
      promptError: null,
    })
    await server.close()
  })

  it("returns partial success when prompt bootstrap fails", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo, init?: RequestInit) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session") && init?.method === "POST") {
        return Response.json({ id: "s-new", title: "New task", directory: "/repo" })
      }

      if (url.endsWith("/session/s-new/prompt_async") && init?.method === "POST") {
        return Response.json({ error: "boom" }, { status: 500 })
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "POST",
      url: "/v1/sessions",
      headers: { authorization: "Bearer test-token" },
      payload: { title: "New task", prompt: "Start implementing" },
    })

    expect(response.statusCode).toBe(201)
    expect(response.json()).toMatchObject({
      session: { id: "s-new", title: "New task" },
      started: false,
      promptError: "OpenCode upstream request failed for session/s-new/prompt_async",
    })
    await server.close()
  })
})

describe("GET /v1/sessions", () => {
  it("forwards desktop-style session query filters and maps archive metadata", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.includes("/session?")) {
        const parsed = new URL(url)
        expect(parsed.searchParams.get("directory")).toBe("/repo/demo")
        expect(parsed.searchParams.get("roots")).toBe("true")
        expect(parsed.searchParams.get("limit")).toBe("5")
        return Response.json({
          items: [
            {
              id: "s1",
              title: "Visible session",
              directory: "/repo/demo",
              parentID: null,
              time: {
                created: "2026-04-20T00:00:00Z",
                updated: "2026-04-25T00:00:00Z",
                archived: "2026-04-24T00:00:00Z",
              },
            },
          ],
        })
      }

      if (url.endsWith("/session/status")) {
        return Response.json({ items: [] })
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: "/v1/sessions?directory=%2Frepo%2Fdemo&roots=true&limit=5",
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(200)
    expect(response.json()).toEqual({
      items: [
        {
          id: "s1",
          title: "Visible session",
          directory: "/repo/demo",
          createdAt: "2026-04-20T00:00:00Z",
          updatedAt: "2026-04-25T00:00:00Z",
          archivedAt: "2026-04-24T00:00:00Z",
          status: null,
          parentId: null,
        },
      ],
    })
    await server.close()
  })
})

describe("DELETE /v1/sessions/:id", () => {
  it("forwards session deletion to the upstream delete endpoint", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo, init?: RequestInit) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session/s1") && init?.method === "DELETE") {
        return Response.json(true)
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "DELETE",
      url: "/v1/sessions/s1",
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(200)
    expect(response.json()).toEqual({ ok: true, sessionId: "s1" })
    await server.close()
  })
})

describe("attention routes", () => {
  it("maps pending items from upstream", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/question")) {
        return Response.json({ items: [{ id: "q1", sessionID: "s1", questions: [{ header: "H", question: "Q", options: [] }] }] })
      }

      if (url.endsWith("/permission")) {
        return Response.json({ items: [{ id: "p1", sessionID: "s1", permission: "bash", patterns: [] }] })
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: "/v1/attention",
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(200)
    expect(response.json()).toMatchObject({
      questions: [{ id: "q1", sessionId: "s1" }],
      permissions: [{ id: "p1", sessionId: "s1" }],
    })
    await server.close()
  })
})

describe("GET /v1/sessions/:id/context-status", () => {
  it("returns derived context runtime state", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session/s1")) {
        return Response.json({
          id: "s1",
          title: "Session 1",
          directory: "/repo",
          time: { created: 1000, updated: 2000 },
          summary: { additions: 2, deletions: 1, files: ["a.ts"] },
        })
      }
      if (url.endsWith("/session/status")) {
        return Response.json({ items: [{ sessionId: "s1", status: "busy" }] })
      }
      if (url.endsWith("/session/s1/message")) {
        return Response.json({ items: [{ info: { id: "m1", time: { created: 3000 } }, parts: [] }] })
      }
      if (url.endsWith("/session/s1/todo")) {
        return Response.json({ items: [{ id: "t1", content: "todo", status: "pending" }] })
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: "/v1/sessions/s1/context-status",
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(200)
    expect(response.json()).toMatchObject({
      sessionId: "s1",
      status: "busy",
      messageCount: 1,
      todoCount: 1,
      pendingTodoCount: 1,
      summaryFileCount: 1,
    })
    await server.close()
  })
})

describe("GET /v1/sessions/:id/view", () => {
  it("returns typed parts and message-level usage", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session/s1")) {
        return Response.json({
          id: "s1",
          title: "Session 1",
          directory: "/repo",
        })
      }
      if (url.endsWith("/session/s1/message")) {
        return Response.json({
          items: [
            {
              info: {
                id: "m1",
                role: "assistant",
                providerID: "openai",
                modelID: "gpt-5.4",
                cost: 0.42,
                tokens: { input: 1600, output: 600 },
              },
              parts: [
                { type: "text", text: "done" },
                { type: "tool", title: "bash", state: { status: "running" } },
                { type: "patch", text: "diff" },
              ],
            },
          ],
        })
      }
      if (url.endsWith("/session/s1/todo")) {
        return Response.json({ items: [] })
      }
      if (url.endsWith("/provider")) {
        return Response.json({
          all: [
            {
              id: "openai",
              models: { "gpt-5.4": { limit: { context: 8000 } } },
            },
          ],
        })
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: "/v1/sessions/s1/view",
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(200)
    expect(response.json()).toMatchObject({
      session: { id: "s1", title: "Session 1" },
      messages: [
        {
          id: "m1",
          role: "assistant",
          usage: {
            totalTokens: 2200,
            inputTokens: 1600,
            outputTokens: 600,
            contextLimit: 8000,
            contextUsagePercent: 28,
          },
          parts: expect.arrayContaining([
            expect.objectContaining({ type: "text", display: "inline", text: "done" }),
            expect.objectContaining({ type: "tool", display: "collapsed", title: "bash", status: "running" }),
            expect.objectContaining({ type: "patch", display: "hidden" }),
          ]),
        },
      ],
    })
    await server.close()
  })
})

describe("request error handling", () => {
  it("preserves parser and validation-style 4xx errors", async () => {
    const server = buildServer(serverOptions)

    const response = await server.inject({
      method: "POST",
      url: "/v1/sessions",
      headers: {
        authorization: "Bearer test-token",
        "content-type": "application/json",
      },
      payload: "{",
    })

    expect(response.statusCode).toBe(400)
    expect(response.json()).toMatchObject({ error: "FST_ERR_CTP_INVALID_JSON_BODY" })
    await server.close()
  })
})

describe("file preview and search routes", () => {
  it("returns read-only file preview data", async () => {
    const workspaceRoot = await mkdtemp(path.join(tmpdir(), "bridge-file-preview-"))
    const filePath = path.join(workspaceRoot, "README.md")
    await writeFile(filePath, "hello\nworld")

    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session/s1")) {
        return Response.json({ id: "s1", directory: workspaceRoot })
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: `/v1/sessions/s1/file?path=${encodeURIComponent(filePath)}`,
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(200)
    expect(response.json()).toMatchObject({
      path: filePath,
      displayName: "README.md",
      isText: true,
      lineCount: 2,
      language: "md",
      content: "hello\nworld",
    })
    await server.close()
  })

  it("streams non-project session downloads", async () => {
    const workspaceRoot = await mkdtemp(path.join(tmpdir(), "bridge-file-download-"))
    const filePath = path.join(workspaceRoot, "README.md")
    await writeFile(filePath, "hello\nworld")

    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session/s1")) {
        return Response.json({ id: "s1", directory: workspaceRoot })
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: `/v1/sessions/s1/download?path=${encodeURIComponent(filePath)}`,
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(200)
    expect(response.headers["content-type"]).toContain("text/markdown")
    expect(response.headers["content-disposition"]).toContain('filename="README.md"')
    expect(response.body).toBe("hello\nworld")
    await server.close()
    await rm(workspaceRoot, { recursive: true, force: true })
  })

  it("lists session-root directories and files for browse flows", async () => {
    const workspaceRoot = await mkdtemp(path.join(os.tmpdir(), "bridge-files-"))
    await mkdir(path.join(workspaceRoot, "src"))
    await writeFile(path.join(workspaceRoot, "README.md"), "hello\n")

    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session/s1")) {
        return Response.json({ id: "s1", directory: workspaceRoot })
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: `/v1/sessions/s1/files?path=${encodeURIComponent(workspaceRoot)}`,
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(200)
    expect(response.json()).toMatchObject({
      rootPath: workspaceRoot,
      currentPath: workspaceRoot,
      parentPath: null,
      items: [
        { displayName: "src", kind: "directory" },
        { displayName: "README.md", kind: "file" },
      ],
    })
    await server.close()
    await rm(workspaceRoot, { recursive: true, force: true })
  })

  it("returns filename search results", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session/s1")) {
        return Response.json({ id: "s1", directory: "/repo" })
      }
      if (url.includes("/find/file?query=readme")) {
        return Response.json([
          { path: "/repo/README.md" },
          { path: "/other/ignore.md" },
        ])
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: "/v1/sessions/s1/search?query=readme&mode=name",
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(200)
    expect(response.json()).toMatchObject({
      query: "readme",
      mode: "name",
      items: [{ path: "/repo/README.md", kind: "name" }],
    })
    await server.close()
  })

  it("returns text search results", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url

      if (url.endsWith("/session/s1")) {
        return Response.json({ id: "s1", directory: "/repo" })
      }
      if (url.includes("/find?pattern=token")) {
        return Response.json([
          { path: "/repo/README.md", line: 8, column: 3, preview: "token docs" },
          { path: "/elsewhere/file.ts", line: 2, column: 1, preview: "token elsewhere" },
        ])
      }

      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: "/v1/sessions/s1/search?query=token&mode=text",
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(200)
    expect(response.json()).toMatchObject({
      query: "token",
      mode: "text",
      items: [
        {
          path: "/repo/README.md",
          kind: "text",
          line: 8,
          column: 3,
          previewText: "token docs",
        },
      ],
    })
    await server.close()
  })

  it("rejects file preview requests outside the session root", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url
      if (url.endsWith("/session/s1")) {
        return Response.json({ id: "s1", directory: "/repo" })
      }
      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: "/v1/sessions/s1/file?path=/outside/secret.txt",
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(403)
    expect(response.json()).toMatchObject({ error: "path_outside_session_root" })
    await server.close()
  })

  it("rejects directory browse requests outside the session root", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url
      if (url.endsWith("/session/s1")) {
        return Response.json({ id: "s1", directory: "/repo" })
      }
      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: "/v1/sessions/s1/files?path=/outside",
      headers: { authorization: "Bearer test-token" },
    })

    expect(response.statusCode).toBe(403)
    expect(response.json()).toMatchObject({ error: "path_outside_session_root" })
    await server.close()
  })
})

describe("bridge auth", () => {
  it("rejects missing bearer token on read route", async () => {
    const server = buildServer(serverOptions)
    const response = await server.inject({ method: "GET", url: "/health" })
    expect(response.statusCode).toBe(401)
    expect(response.json()).toMatchObject({ error: "unauthorized" })
    await server.close()
  })

  it("rejects invalid bearer token on write route", async () => {
    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "POST",
      url: "/v1/sessions",
      headers: {
        authorization: "Bearer wrong-token",
        "content-type": "application/json",
      },
      payload: { title: "New task" },
    })
    expect(response.statusCode).toBe(401)
    expect(response.json()).toMatchObject({ error: "unauthorized" })
    await server.close()
  })

  it("accepts valid bearer token on protected route", async () => {
    global.fetch = vi.fn(async (input: URL | RequestInfo) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url
      if (url.endsWith("/session")) {
        return Response.json([])
      }
      if (url.endsWith("/session/status")) {
        return Response.json([])
      }
      throw new Error(`Unexpected fetch to ${url}`)
    }) as typeof fetch

    const server = buildServer(serverOptions)
    const response = await server.inject({
      method: "GET",
      url: "/v1/sessions",
      headers: { authorization: "Bearer test-token" },
    })
    expect(response.statusCode).toBe(200)
    await server.close()
  })
})
