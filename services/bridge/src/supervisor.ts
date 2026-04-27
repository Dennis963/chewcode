import { spawn, type ChildProcess } from "node:child_process"
import net from "node:net"

import { OpenCodeUpstreamClient } from "./upstream.js"

export type RuntimeState = "stopped" | "starting" | "running" | "error"

export type RuntimeHandle = {
  projectId: string
  projectPath: string
  port: number
  state: RuntimeState
  process: ChildProcess | null
  upstreamBaseUrl: string
  lastError: string | null
}

export class RuntimeSupervisor {
  private readonly runtimes = new Map<string, RuntimeHandle>()
  private readonly startupPromises = new Map<string, Promise<RuntimeHandle>>()

  constructor(private readonly opencodeBin: string = "opencode") {}

  async ensureProjectRuntime(project: { id: string; path: string }): Promise<RuntimeHandle> {
    const existing = this.runtimes.get(project.id)
    if (existing && existing.state === "running") {
      return existing
    }

    const pendingStartup = this.startupPromises.get(project.id)
    if (pendingStartup) {
      return pendingStartup
    }

    const startup = this.startProjectRuntime(project)
    this.startupPromises.set(project.id, startup)
    try {
      return await startup
    } finally {
      this.startupPromises.delete(project.id)
    }
  }

  getRuntime(projectId: string): RuntimeHandle | null {
    return this.runtimes.get(projectId) ?? null
  }

  async stopProjectRuntime(projectId: string): Promise<RuntimeHandle | null> {
    const pendingStartup = this.startupPromises.get(projectId)
    if (pendingStartup) {
      try {
        await pendingStartup
      } catch {
        // Ignore startup failure and proceed with cleanup of any partial runtime state.
      }
    }

    const runtime = this.runtimes.get(projectId)
    if (!runtime) {
      return null
    }

    if (runtime.process != null && !runtime.process.killed) {
      runtime.process.kill("SIGTERM")
    }

    runtime.state = "stopped"
    runtime.lastError = null
    this.runtimes.delete(projectId)
    return runtime
  }

  listRuntimeStates(): Map<string, RuntimeHandle> {
    return this.runtimes
  }

  private async startProjectRuntime(
    project: { id: string; path: string },
  ): Promise<RuntimeHandle> {
    const port = await allocatePort()
    const upstreamBaseUrl = `http://127.0.0.1:${port}`

    const handle: RuntimeHandle = {
      projectId: project.id,
      projectPath: project.path,
      port,
      state: "starting",
      process: null,
      upstreamBaseUrl,
      lastError: null,
    }

    this.runtimes.set(project.id, handle)

    const child = spawn(
      this.opencodeBin,
      ["serve", "--port", String(port), "--hostname", "127.0.0.1"],
      {
        cwd: project.path,
        stdio: "ignore",
      },
    )

    handle.process = child
    child.on("exit", (code) => {
      if (handle.state !== "running") {
        handle.state = "error"
      } else {
        handle.state = "stopped"
      }
      handle.lastError = code == null ? "process exited" : `process exited with code ${code}`
    })

    try {
      await waitForHealth(upstreamBaseUrl)
      handle.state = "running"
      handle.lastError = null
      return handle
    } catch (error) {
      handle.state = "error"
      handle.lastError = error instanceof Error ? error.message : String(error)
      child.kill("SIGTERM")
      throw error
    }
  }
}

async function allocatePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const server = net.createServer()
    server.listen(0, "127.0.0.1", () => {
      const address = server.address()
      if (!address || typeof address === "string") {
        server.close()
        reject(new Error("Failed to allocate port"))
        return
      }
      const { port } = address
      server.close(() => resolve(port))
    })
    server.on("error", reject)
  })
}

async function waitForHealth(upstreamBaseUrl: string): Promise<void> {
  const client = new OpenCodeUpstreamClient({ baseUrl: upstreamBaseUrl })
  const deadline = Date.now() + 15_000

  while (Date.now() < deadline) {
    try {
      await client.getHealth()
      return
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 300))
    }
  }

  throw new Error("Timed out waiting for OpenCode runtime")
}
