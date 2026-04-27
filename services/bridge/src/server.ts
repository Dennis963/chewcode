import Fastify, { type FastifyReply } from "fastify"
import { createReadStream } from "node:fs"
import { readdir, readFile, stat } from "node:fs/promises"
import path from "node:path"

import { mapAttentionState, mapCreateSessionResult, mapFileSearchResult, mapSessionContextStatus, mapSessionSummaries, mapSessionView } from "./mappers.js"
import { ProjectRegistry, ProjectRegistryError, defaultRegistryPath } from "./projects.js"
import { streamEvents } from "./sse.js"
import { RuntimeSupervisor } from "./supervisor.js"
import { OpenCodeUpstreamClient, UpstreamError } from "./upstream.js"

export type ServerOptions = {
  upstreamBaseUrl: string
  bearerToken: string
  projectAllowedRoots?: string[]
  projectRegistryFile?: string
  opencodeBin?: string
}

type SessionListQuery = {
  directory?: string
  roots?: string
  limit?: string
}

export function buildServer(options: ServerOptions) {
  const app = Fastify({ logger: true })
  const upstream = new OpenCodeUpstreamClient({
    baseUrl: options.upstreamBaseUrl,
  })
  const projectRegistry = new ProjectRegistry({
    registryFilePath: options.projectRegistryFile ?? defaultRegistryPath(),
    allowedRoots: options.projectAllowedRoots ?? [],
  })
  const runtimeSupervisor = new RuntimeSupervisor(options.opencodeBin)

  app.addHook("onRequest", async (request, reply) => {
    const header = request.headers.authorization
    if (!isAuthorized(header, options.bearerToken)) {
      reply.status(401).send({
        error: "unauthorized",
        message: "Valid bearer token required",
      })
      return reply
    }
  })

  app.get("/health", async () => upstream.getHealth())

  app.get("/v1/projects/discover", async () => {
    return {
      items: await projectRegistry.discoverProjects(),
      allowedRoots: projectRegistry.getAllowedRoots(),
    }
  })

  app.get("/v1/projects", async () => {
    const projects = await projectRegistry.listProjects()
    return {
      items: projects.map((project) => {
        const runtime = runtimeSupervisor.getRuntime(project.id)
        return {
          id: project.id,
          name: project.name,
          path: project.path,
          opened: runtime?.state === "running",
          runtimeState: runtime?.state ?? "stopped",
          lastOpenedAt: project.lastOpenedAt,
          port: runtime?.port ?? null,
        }
      }),
    }
  })

  app.post<{ Body: { path?: string; name?: string } }>("/v1/projects/register", async (request, reply) => {
    const body = getJsonBody<{ path?: string; name?: string }>(request.body)
    const requestedPath = body.path?.trim()
    if (!requestedPath) {
      reply.status(400).send({ error: "invalid_path", message: "Project path is required" })
      return
    }

    const project = await projectRegistry.registerProject({
      path: requestedPath,
      name: body.name,
    })

    reply.status(201).send({
      id: project.id,
      name: project.name,
      path: project.path,
      opened: false,
      runtimeState: "stopped",
      lastOpenedAt: project.lastOpenedAt,
      port: null,
    })
  })

  app.post<{ Params: { projectId: string } }>("/v1/projects/:projectId/open", async (request) => {
    const project = await requireProject(projectRegistry, request.params.projectId)
    const runtime = await runtimeSupervisor.ensureProjectRuntime(project)
    await projectRegistry.markOpened(project.id)
    return {
      id: project.id,
      name: project.name,
      path: project.path,
      opened: runtime.state === "running",
      runtimeState: runtime.state,
      lastOpenedAt: new Date().toISOString(),
      port: runtime.port,
    }
  })

  app.post<{ Params: { projectId: string } }>("/v1/projects/:projectId/close", async (request) => {
    const project = await requireProject(projectRegistry, request.params.projectId)
    await runtimeSupervisor.stopProjectRuntime(project.id)
    return {
      id: project.id,
      name: project.name,
      path: project.path,
      opened: false,
      runtimeState: "stopped",
      lastOpenedAt: project.lastOpenedAt,
      port: null,
    }
  })

  app.delete<{ Params: { projectId: string } }>("/v1/projects/:projectId", async (request, reply) => {
    await runtimeSupervisor.stopProjectRuntime(request.params.projectId)
    const removedProject = await projectRegistry.deleteProject(request.params.projectId)
    if (!removedProject) {
      reply.status(404).send({
        error: "project_not_found",
        message: "Project is not registered",
      })
      return
    }

    reply.send({
      id: removedProject.id,
      deleted: true,
    })
  })

  app.get<{ Params: { projectId: string }; Querystring: SessionListQuery }>("/v1/projects/:projectId/sessions", async (request) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const sessionListOptions = readSessionListOptions(request.query)
    const [sessions, statuses] = await Promise.all([
      projectUpstream.getSessions(sessionListOptions),
      projectUpstream.getSessionStatus().catch(() => []),
    ])
    return { items: mapSessionSummaries(sessions, statuses) }
  })

  app.post<{
    Params: { projectId: string }
    Body: { title?: string; prompt?: string }
  }>("/v1/projects/:projectId/sessions", async (request, reply) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const body = getJsonBody<{ title?: string; prompt?: string }>(request.body)
    const title = body.title?.trim() ?? null
    const prompt = body.prompt?.trim() ?? null
    const createdSession = await projectUpstream.createSession({ title })
    let started = false
    let promptError: string | null = null

    if (prompt) {
      try {
        const session = mapCreateSessionResult(createdSession, { started: false }).session
        await projectUpstream.promptSession(session.id, prompt)
        started = true
      } catch (error) {
        if (error instanceof UpstreamError) {
          promptError = error.message
        } else {
          throw error
        }
      }
    }

    reply.status(201).send(mapCreateSessionResult(createdSession, { started, promptError }))
  })

  app.delete<{ Params: { projectId: string; id: string } }>("/v1/projects/:projectId/sessions/:id", async (request) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    await projectUpstream.deleteSession(request.params.id)
    return { ok: true, sessionId: request.params.id }
  })

  app.get<{ Params: { projectId: string; id: string } }>("/v1/projects/:projectId/sessions/:id/view", async (request) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const [session, messages, todos, providers] = await Promise.all([
      projectUpstream.getSession(request.params.id),
      projectUpstream.getSessionMessages(request.params.id),
      projectUpstream.getSessionTodos(request.params.id),
      projectUpstream.getProviders().catch(() => ({ all: [] })),
    ])
    return mapSessionView(session, messages, todos, providers)
  })

  app.get<{ Params: { projectId: string; id: string } }>("/v1/projects/:projectId/sessions/:id/context-status", async (request) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const [session, statuses, messages, todos] = await Promise.all([
      projectUpstream.getSession(request.params.id),
      projectUpstream.getSessionStatus().catch(() => []),
      projectUpstream.getSessionMessages(request.params.id),
      projectUpstream.getSessionTodos(request.params.id),
    ])
    return mapSessionContextStatus(session, statuses, messages, todos)
  })

  app.get<{
    Params: { projectId: string; id: string }
    Querystring: { path?: string }
  }>("/v1/projects/:projectId/sessions/:id/file", async (request, reply) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const requestedPath = request.query.path?.trim()
    if (!requestedPath) {
      reply.status(400).send({ error: "invalid_path", message: "Path is required" })
      return
    }

    const session = await projectUpstream.getSession(request.params.id)
    const sessionRoot = requireSessionRoot(session, reply)
    if (!sessionRoot) {
      return
    }

    const scopedPath = resolvePathInsideRoot(sessionRoot, requestedPath)
    if (!scopedPath) {
      reply.status(403).send({
        error: "path_outside_session_root",
        message: "Requested path is outside the session workspace",
      })
      return
    }

    const fileStats = await stat(scopedPath)
    if (!fileStats.isFile()) {
      reply.status(400).send({ error: "invalid_file", message: "Requested path is not a file" })
      return
    }

    return buildFilePreviewFromDisk(scopedPath, fileStats.size)
  })

  app.get<{
    Params: { projectId: string; id: string }
    Querystring: { path?: string }
  }>("/v1/projects/:projectId/sessions/:id/download", async (request, reply) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const requestedPath = request.query.path?.trim()
    if (!requestedPath) {
      reply.status(400).send({ error: "invalid_path", message: "Path is required" })
      return
    }

    const session = await projectUpstream.getSession(request.params.id)
    const sessionRoot = requireSessionRoot(session, reply)
    if (!sessionRoot) {
      return
    }

    const scopedPath = resolvePathInsideRoot(sessionRoot, requestedPath)
    if (!scopedPath) {
      reply.status(403).send({
        error: "path_outside_session_root",
        message: "Requested path is outside the session workspace",
      })
      return
    }

    const fileStats = await stat(scopedPath)
    if (!fileStats.isFile()) {
      reply.status(400).send({ error: "invalid_file", message: "Requested path is not a file" })
      return
    }

    const fileName = path.basename(scopedPath)
    reply.header("Content-Type", mimeTypeForDownload(fileName))
    reply.header("Content-Length", String(fileStats.size))
    reply.header("Content-Disposition", `attachment; filename="${fileName}"`)
    return reply.send(createReadStream(scopedPath))
  })

  app.get<{
    Params: { id: string }
    Querystring: { path?: string }
  }>("/v1/sessions/:id/download", async (request, reply) => {
    const requestedPath = request.query.path?.trim()
    if (!requestedPath) {
      reply.status(400).send({ error: "invalid_path", message: "Path is required" })
      return
    }

    const session = await upstream.getSession(request.params.id)
    const sessionRoot = requireSessionRoot(session, reply)
    if (!sessionRoot) {
      return
    }

    const scopedPath = resolvePathInsideRoot(sessionRoot, requestedPath)
    if (!scopedPath) {
      reply.status(403).send({
        error: "path_outside_session_root",
        message: "Requested path is outside the session workspace",
      })
      return
    }

    const fileStats = await stat(scopedPath)
    if (!fileStats.isFile()) {
      reply.status(400).send({ error: "invalid_file", message: "Requested path is not a file" })
      return
    }

    const fileName = path.basename(scopedPath)
    reply.header("Content-Type", mimeTypeForDownload(fileName))
    reply.header("Content-Length", String(fileStats.size))
    reply.header("Content-Disposition", `attachment; filename="${fileName}"`)
    return reply.send(createReadStream(scopedPath))
  })

  app.get<{
    Params: { projectId: string; id: string }
    Querystring: { path?: string }
  }>("/v1/projects/:projectId/sessions/:id/files", async (request, reply) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const session = await projectUpstream.getSession(request.params.id)
    const sessionRoot = requireSessionRoot(session, reply)
    if (!sessionRoot) {
      return
    }

    const requestedPath = request.query.path?.trim()
    const targetPath = requestedPath == null || requestedPath.length === 0
      ? sessionRoot
      : resolvePathInsideRoot(sessionRoot, requestedPath)

    if (!targetPath) {
      reply.status(403).send({
        error: "path_outside_session_root",
        message: "Requested path is outside the session workspace",
      })
      return
    }

    const directoryStats = await stat(targetPath)
    if (!directoryStats.isDirectory()) {
      reply.status(400).send({
        error: "invalid_directory",
        message: "Requested path is not a directory",
      })
      return
    }

    const entries = await readdir(targetPath, { withFileTypes: true })
    const mappedEntries = await Promise.all(
      entries.map(async (entry) => {
        const entryPath = path.join(targetPath, entry.name)
        const entryStats = entry.isDirectory() ? null : await stat(entryPath)
        return {
          path: entryPath,
          displayName: entry.name,
          kind: entry.isDirectory() ? "directory" : "file",
          sizeBytes: entryStats?.size ?? null,
        }
      }),
    )

    mappedEntries.sort((left, right) => {
      if (left.kind !== right.kind) {
        return left.kind === "directory" ? -1 : 1
      }
      return left.displayName.localeCompare(right.displayName)
    })

    reply.send({
      rootPath: sessionRoot,
      currentPath: targetPath,
      parentPath: targetPath === sessionRoot ? null : path.dirname(targetPath),
      items: mappedEntries,
    })
  })

  app.get<{
    Params: { projectId: string; id: string }
    Querystring: { query?: string; mode?: "name" | "text" }
  }>("/v1/projects/:projectId/sessions/:id/search", async (request, reply) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const query = request.query.query?.trim()
    const mode = request.query.mode === "text" ? "text" : "name"
    if (!query) {
      reply.status(400).send({ error: "invalid_query", message: "Query is required" })
      return
    }

    const session = await projectUpstream.getSession(request.params.id)
    const sessionRoot = requireSessionRoot(session, reply)
    if (!sessionRoot) {
      return
    }

    const payload = mode === "text"
      ? await projectUpstream.findText(query)
      : await projectUpstream.findFiles(query)

    const mapped = mapFileSearchResult(query, mode, payload)
    return {
      ...mapped,
      items: mapped.items.filter((item) => isPathInsideRoot(sessionRoot, item.path)),
    }
  })

  app.post<{
    Params: { projectId: string; id: string }
    Body: { prompt?: string }
  }>("/v1/projects/:projectId/sessions/:id/prompts", async (request, reply) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const body = getJsonBody<{ prompt?: string }>(request.body)
    const prompt = body.prompt?.trim()
    if (!prompt) {
      reply.status(400).send({ error: "invalid_prompt", message: "Prompt is required" })
      return
    }
    await projectUpstream.promptSession(request.params.id, prompt)
    reply.status(202).send({ ok: true, sessionId: request.params.id })
  })

  app.post<{ Params: { projectId: string; id: string } }>("/v1/projects/:projectId/sessions/:id/summarize", async (request, reply) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const summaryTarget = await resolveSummaryTarget(projectUpstream, request.params.id)
    if (!summaryTarget) {
      reply.status(409).send({
        error: "summarize_target_unavailable",
        message: "Unable to determine the provider and model for summarization",
      })
      return
    }

    await projectUpstream.summarizeSession(request.params.id, summaryTarget)
    reply.status(202).send({ ok: true, sessionId: request.params.id })
  })

  app.get<{ Params: { projectId: string } }>("/v1/projects/:projectId/attention", async (request) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const [questions, permissions] = await Promise.all([
      projectUpstream.getQuestions().catch(() => []),
      projectUpstream.getPermissions().catch(() => []),
    ])
    return mapAttentionState(questions, permissions)
  })

  app.post<{
    Params: { projectId: string; id: string }
    Body: { answers?: string[][] }
  }>("/v1/projects/:projectId/questions/:id/reply", async (request, reply) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const body = getJsonBody<{ answers?: string[][] }>(request.body)
    const answers = body.answers
    if (!answers || answers.length === 0) {
      reply.status(400).send({ error: "invalid_answers", message: "At least one answer selection is required" })
      return
    }
    await projectUpstream.replyQuestion(request.params.id, answers)
    reply.status(202).send({ ok: true, requestId: request.params.id })
  })

  app.post<{ Params: { projectId: string; id: string } }>("/v1/projects/:projectId/questions/:id/reject", async (request, reply) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    await projectUpstream.rejectQuestion(request.params.id)
    reply.status(202).send({ ok: true, requestId: request.params.id })
  })

  app.post<{
    Params: { projectId: string; id: string }
    Body: { reply?: "once" | "always" | "reject"; message?: string }
  }>("/v1/projects/:projectId/permissions/:id/reply", async (request, reply) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    const body = getJsonBody<{ reply?: "once" | "always" | "reject"; message?: string }>(request.body)
    const decision = body.reply
    if (!decision) {
      reply.status(400).send({ error: "invalid_reply", message: "Permission reply is required" })
      return
    }
    await projectUpstream.replyPermission(request.params.id, decision, body.message)
    reply.status(202).send({ ok: true, requestId: request.params.id })
  })

  app.get<{ Params: { projectId: string } }>("/v1/projects/:projectId/events", async (request, reply) => {
    const projectUpstream = await resolveProjectUpstream(projectRegistry, runtimeSupervisor, request.params.projectId)
    await streamEvents(reply, projectUpstream)
    return reply
  })

  app.get<{ Querystring: SessionListQuery }>("/v1/sessions", async (request) => {
    const sessionListOptions = readSessionListOptions(request.query)
    const [sessions, statuses] = await Promise.all([
      upstream.getSessions(sessionListOptions),
      upstream.getSessionStatus().catch(() => []),
    ])

    return {
      items: mapSessionSummaries(sessions, statuses),
    }
  })

  app.post<{ Body: { title?: string; prompt?: string } }>("/v1/sessions", async (request, reply) => {
    const body = getJsonBody<{ title?: string; prompt?: string }>(request.body)
    const title = body.title?.trim() ?? null
    const prompt = body.prompt?.trim() ?? null

    const createdSession = await upstream.createSession({ title })
    let started = false
    let promptError: string | null = null

    if (prompt) {
      try {
        const session = mapCreateSessionResult(createdSession, { started: false }).session
        await upstream.promptSession(session.id, prompt)
        started = true
      } catch (error) {
        if (error instanceof UpstreamError) {
          promptError = error.message
        } else {
          throw error
        }
      }
    }

    reply.status(201).send(mapCreateSessionResult(createdSession, { started, promptError }))
  })

  app.delete<{ Params: { id: string } }>("/v1/sessions/:id", async (request) => {
    await upstream.deleteSession(request.params.id)
    return { ok: true, sessionId: request.params.id }
  })

  app.get<{ Params: { id: string } }>("/v1/sessions/:id/view", async (request) => {
    const { id } = request.params
    const [session, messages, todos, providers] = await Promise.all([
      upstream.getSession(id),
      upstream.getSessionMessages(id),
      upstream.getSessionTodos(id),
      upstream.getProviders().catch(() => ({ all: [] })),
    ])

    return mapSessionView(session, messages, todos, providers)
  })

  app.get<{ Params: { id: string } }>("/v1/sessions/:id/context-status", async (request) => {
    const { id } = request.params
    const [session, statuses, messages, todos] = await Promise.all([
      upstream.getSession(id),
      upstream.getSessionStatus().catch(() => []),
      upstream.getSessionMessages(id),
      upstream.getSessionTodos(id),
    ])

    return mapSessionContextStatus(session, statuses, messages, todos)
  })

  app.get<{ Params: { id: string }; Querystring: { path?: string } }>(
    "/v1/sessions/:id/file",
    async (request, reply) => {
      const requestedPath = request.query.path?.trim()
      if (!requestedPath) {
        reply.status(400).send({
          error: "invalid_path",
          message: "Path is required",
        })
        return
      }

      const session = await upstream.getSession(request.params.id)
      const sessionRoot = requireSessionRoot(session, reply)
      if (!sessionRoot) {
        return
      }
      const scopedPath = resolvePathInsideRoot(sessionRoot, requestedPath)
      if (!scopedPath) {
        reply.status(403).send({
          error: "path_outside_session_root",
          message: "Requested path is outside the session workspace",
        })
        return
      }

      const fileStats = await stat(scopedPath)
      if (!fileStats.isFile()) {
        reply.status(400).send({
          error: "invalid_file",
          message: "Requested path is not a file",
        })
        return
      }

      return buildFilePreviewFromDisk(scopedPath, fileStats.size)
    },
  )

  app.get<{ Params: { id: string }; Querystring: { path?: string } }>(
    "/v1/sessions/:id/files",
    async (request, reply) => {
      const session = await upstream.getSession(request.params.id)
      const sessionRoot = requireSessionRoot(session, reply)
      if (!sessionRoot) {
        return
      }

      const requestedPath = request.query.path?.trim()
      const targetPath = requestedPath == null || requestedPath.length === 0
        ? sessionRoot
        : resolvePathInsideRoot(sessionRoot, requestedPath)

      if (!targetPath) {
        reply.status(403).send({
          error: "path_outside_session_root",
          message: "Requested path is outside the session workspace",
        })
        return
      }

      const directoryStats = await stat(targetPath)
      if (!directoryStats.isDirectory()) {
        reply.status(400).send({
          error: "invalid_directory",
          message: "Requested path is not a directory",
        })
        return
      }

      const entries = await readdir(targetPath, { withFileTypes: true })
      const mappedEntries = await Promise.all(
        entries.map(async (entry) => {
          const entryPath = path.join(targetPath, entry.name)
          const entryStats = entry.isDirectory() ? null : await stat(entryPath)
          return {
            path: entryPath,
            displayName: entry.name,
            kind: entry.isDirectory() ? "directory" : "file",
            sizeBytes: entryStats?.size ?? null,
          }
        }),
      )

      mappedEntries.sort((left, right) => {
        if (left.kind !== right.kind) {
          return left.kind === "directory" ? -1 : 1
        }
        return left.displayName.localeCompare(right.displayName)
      })

      reply.send({
        rootPath: sessionRoot,
        currentPath: targetPath,
        parentPath: targetPath === sessionRoot ? null : path.dirname(targetPath),
        items: mappedEntries,
      })
    },
  )

  app.get<{
    Params: { id: string }
    Querystring: { query?: string; mode?: "name" | "text" }
  }>("/v1/sessions/:id/search", async (request, reply) => {
    const query = request.query.query?.trim()
    const mode = request.query.mode === "text" ? "text" : "name"

    if (!query) {
      reply.status(400).send({
        error: "invalid_query",
        message: "Query is required",
      })
      return
    }

    const session = await upstream.getSession(request.params.id)
    const sessionRoot = requireSessionRoot(session, reply)
    if (!sessionRoot) {
      return
    }

    const payload = mode === "text"
      ? await upstream.findText(query)
      : await upstream.findFiles(query)

    const mapped = mapFileSearchResult(query, mode, payload)
    return {
      ...mapped,
      items: mapped.items.filter((item) => isPathInsideRoot(sessionRoot, item.path)),
    }
  })

  app.post<{ Params: { id: string }; Body: { prompt?: string } }>(
    "/v1/sessions/:id/prompts",
    async (request, reply) => {
      const { id } = request.params
      const body = getJsonBody<{ prompt?: string }>(request.body)
      const prompt = body.prompt?.trim()

      if (!prompt) {
        reply.status(400).send({
          error: "invalid_prompt",
          message: "Prompt is required",
        })
        return
      }

      await upstream.promptSession(id, prompt)
      reply.status(202).send({
        ok: true,
        sessionId: id,
      })
    },
  )

  app.get("/v1/attention", async () => {
    const [questions, permissions] = await Promise.all([
      upstream.getQuestions().catch(() => []),
      upstream.getPermissions().catch(() => []),
    ])

    return mapAttentionState(questions, permissions)
  })

  app.post<{ Params: { id: string } }>("/v1/sessions/:id/summarize", async (request, reply) => {
    const { id } = request.params
    const summaryTarget = await resolveSummaryTarget(upstream, id)
    if (!summaryTarget) {
      reply.status(409).send({
        error: "summarize_target_unavailable",
        message: "Unable to determine the provider and model for summarization",
      })
      return
    }

    await upstream.summarizeSession(id, summaryTarget)
    reply.status(202).send({ ok: true, sessionId: id })
  })

  app.post<{
    Params: { id: string }
    Body: { answers?: string[][] }
  }>("/v1/questions/:id/reply", async (request, reply) => {
    const body = getJsonBody<{ answers?: string[][] }>(request.body)
    const answers = body.answers
    if (!answers || answers.length == 0) {
      reply.status(400).send({
        error: "invalid_answers",
        message: "At least one answer selection is required",
      })
      return
    }

    await upstream.replyQuestion(request.params.id, answers)
    reply.status(202).send({ ok: true, requestId: request.params.id })
  })

  app.post<{ Params: { id: string } }>("/v1/questions/:id/reject", async (request, reply) => {
    await upstream.rejectQuestion(request.params.id)
    reply.status(202).send({ ok: true, requestId: request.params.id })
  })

  app.post<{
    Params: { id: string }
    Body: { reply?: "once" | "always" | "reject"; message?: string }
  }>("/v1/permissions/:id/reply", async (request, reply) => {
    const body = getJsonBody<{ reply?: "once" | "always" | "reject"; message?: string }>(request.body)
    const decision = body.reply
    if (!decision) {
      reply.status(400).send({
        error: "invalid_reply",
        message: "Permission reply is required",
      })
      return
    }

    await upstream.replyPermission(request.params.id, decision, body.message)
    reply.status(202).send({ ok: true, requestId: request.params.id })
  })

  app.get("/v1/events", async (_request, reply) => {
    await streamEvents(reply, upstream)
    return reply
  })

  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof UpstreamError) {
      reply.status(502).send({
        error: "upstream_error",
        message: error.message,
        upstreamStatus: error.status,
      })
      return
    }

    if (error instanceof ProjectRegistryError) {
      reply.status(error.statusCode).send({
        error: error.code,
        message: error.message,
      })
      return
    }

    if (hasHttpStatus(error)) {
      reply.status(error.statusCode).send({
        error: error.code ?? "request_error",
        message: error.message,
      })
      return
    }

    requestSafeLog(app, error)
    reply.status(500).send({
      error: "internal_error",
      message: "Unexpected bridge error",
    })
  })

  return app
}

function isAuthorized(header: string | undefined, expectedToken: string): boolean {
  if (!header) {
    return false
  }

  const [scheme, token] = header.split(" ")
  return scheme === "Bearer" && token === expectedToken
}

function getJsonBody<T extends object>(value: unknown): T {
  return (value && typeof value === "object" ? value : {}) as T
}

function readSessionListOptions(query: SessionListQuery) {
  return {
    directory: query.directory?.trim() || undefined,
    roots: query.roots === "true",
    limit: parsePositiveInt(query.limit),
  }
}

function parsePositiveInt(value: string | undefined): number | undefined {
  if (!value) {
    return undefined
  }
  const parsed = Number.parseInt(value, 10)
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return undefined
  }
  return parsed
}

function hasHttpStatus(
  error: unknown,
): error is { statusCode: number; message: string; code?: string } {
  return (
    typeof error === "object" &&
    error !== null &&
    "statusCode" in error &&
    typeof (error as { statusCode?: unknown }).statusCode === "number" &&
    "message" in error &&
    typeof (error as { message?: unknown }).message === "string"
  )
}

function requestSafeLog(app: ReturnType<typeof Fastify>, error: unknown): void {
  if (error instanceof Error) {
    app.log.error(error)
    return
  }

  app.log.error({ error }, "Unexpected non-Error thrown")
}

function requireSessionRoot(
  session: unknown,
  reply: FastifyReply,
): string | null {
  const root = getSessionRoot(session)
  if (!root) {
    reply.status(409).send({
      error: "session_root_unavailable",
      message: "Selected session does not expose a workspace root",
    })
    return null
  }
  return path.resolve(root)
}

function getSessionRoot(session: unknown): string | null {
  if (!session || typeof session !== "object") {
    return null
  }
  const value = session as { directory?: unknown; cwd?: unknown; path?: unknown }
  const candidates = [value.directory, value.cwd, value.path]
  for (const candidate of candidates) {
    if (typeof candidate === "string" && candidate.trim().length > 0) {
      return candidate.trim()
    }
  }
  return null
}

function resolvePathInsideRoot(root: string, requestedPath: string): string | null {
  const resolved = path.isAbsolute(requestedPath)
    ? path.resolve(requestedPath)
    : path.resolve(root, requestedPath)
  return isPathInsideRoot(root, resolved) ? resolved : null
}

function isPathInsideRoot(root: string, candidatePath: string): boolean {
  const normalizedRoot = path.resolve(root)
  const normalizedCandidate = path.resolve(candidatePath)
  const relative = path.relative(normalizedRoot, normalizedCandidate)
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative))
}

async function buildFilePreviewFromDisk(filePath: string, sizeBytes: number) {
  const buffer = await readFile(filePath)
  const maxBytes = 64 * 1024
  const truncatedBuffer = buffer.subarray(0, maxBytes)
  const isTruncated = buffer.length > maxBytes
  const isBinary = truncatedBuffer.includes(0)
  const content = isBinary ? "" : truncatedBuffer.toString("utf8")
  const lineCount = content.length === 0 ? 0 : content.split("\n").length
  const ext = path.extname(filePath).replace(/^\./, "")

  return {
    path: filePath,
    displayName: path.basename(filePath),
    content,
    isText: !isBinary,
    isBinary,
    isTruncated,
    lineCount,
    sizeBytes,
    language: ext.length > 0 ? ext : null,
  }
}

function mimeTypeForDownload(fileName: string): string {
  const lower = fileName.toLowerCase()
  if (lower.endsWith('.apk')) {
    return 'application/vnd.android.package-archive'
  }
  if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
    return 'text/markdown; charset=utf-8'
  }
  if (lower.endsWith('.txt') || lower.endsWith('.log')) {
    return 'text/plain; charset=utf-8'
  }
  if (lower.endsWith('.json')) {
    return 'application/json; charset=utf-8'
  }
  return 'application/octet-stream'
}

async function resolveProjectUpstream(
  projectRegistry: ProjectRegistry,
  runtimeSupervisor: RuntimeSupervisor,
  projectId: string,
) {
  const project = await requireProject(projectRegistry, projectId)
  const runtime = await runtimeSupervisor.ensureProjectRuntime(project)
  return new OpenCodeUpstreamClient({ baseUrl: runtime.upstreamBaseUrl })
}

async function resolveSummaryTarget(
  upstreamClient: OpenCodeUpstreamClient,
  sessionId: string,
): Promise<{ providerID: string; modelID: string; auto: false } | null> {
  const payload = await upstreamClient.getSessionMessages(sessionId)
  const items = Array.isArray(payload)
    ? payload
    : payload && typeof payload === "object" && Array.isArray((payload as { items?: unknown[] }).items)
      ? (payload as { items: unknown[] }).items
      : []

  for (let index = items.length - 1; index >= 0; index -= 1) {
    const item = items[index]
    if (!item || typeof item !== "object") {
      continue
    }

    const objectItem = item as Record<string, unknown>
    const info = objectItem.info && typeof objectItem.info === "object"
      ? objectItem.info as Record<string, unknown>
      : objectItem
    const role = typeof info.role === "string" ? info.role : null
    if (role !== "assistant") {
      continue
    }

    const providerID = firstString(info, ["providerID", "providerId", "provider_id"])
    const modelID = firstString(info, ["modelID", "modelId", "model_id"])
    if (providerID && modelID) {
      return { providerID, modelID, auto: false }
    }
  }

  return null
}

function firstString(source: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const value = source[key]
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim()
    }
  }
  return null
}

async function requireProject(projectRegistry: ProjectRegistry, projectId: string) {
  const project = await projectRegistry.getProject(projectId)
  if (!project) {
    throw new ProjectRegistryError(
      `Unknown project: ${projectId}`,
      404,
      'project_not_found',
    )
  }
  return project
}
