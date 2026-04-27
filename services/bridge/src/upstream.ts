import { URL } from "node:url"

import type { JsonObject } from "./types.js"

export type UpstreamClientOptions = {
  baseUrl: string
}

export type SessionListOptions = {
  directory?: string | null
  roots?: boolean
  limit?: number | null
}

export class UpstreamError extends Error {
  readonly status: number

  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

export class OpenCodeUpstreamClient {
  private readonly baseUrl: string

  constructor(options: UpstreamClientOptions) {
    this.baseUrl = options.baseUrl.replace(/\/$/, "")
  }

  async getJson(path: string): Promise<unknown> {
    const response = await fetch(new URL(path, `${this.baseUrl}/`), {
      headers: {
        accept: "application/json",
      },
    })

    if (!response.ok) {
      throw new UpstreamError(
        `OpenCode upstream request failed for ${path}`,
        response.status,
      )
    }

    return response.json()
  }

  async postJson(path: string, body: unknown): Promise<unknown> {
    const response = await fetch(new URL(path, `${this.baseUrl}/`), {
      method: "POST",
      headers: {
        accept: "application/json",
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    })

    if (!response.ok) {
      throw new UpstreamError(
        `OpenCode upstream request failed for ${path}`,
        response.status,
      )
    }

    if (response.status === 204) {
      return null
    }

    return response.json()
  }

  async deleteJson(path: string): Promise<unknown> {
    const response = await fetch(new URL(path, `${this.baseUrl}/`), {
      method: "DELETE",
      headers: {
        accept: "application/json",
      },
    })

    if (!response.ok) {
      throw new UpstreamError(
        `OpenCode upstream request failed for ${path}`,
        response.status,
      )
    }

    if (response.status === 204) {
      return null
    }

    return response.json()
  }

  async getSessions(options: SessionListOptions = {}): Promise<unknown> {
    const query = new URLSearchParams()
    const directory = options.directory?.trim()
    if (directory) {
      query.set("directory", directory)
    }
    if (options.roots) {
      query.set("roots", "true")
    }
    if (typeof options.limit === "number" && Number.isFinite(options.limit)) {
      query.set("limit", String(Math.max(1, Math.floor(options.limit))))
    }
    const suffix = query.size > 0 ? `?${query.toString()}` : ""
    return this.getJson(`session${suffix}`)
  }

  async getSessionStatus(): Promise<unknown> {
    return this.getJson("session/status")
  }

  async getSession(sessionId: string): Promise<unknown> {
    return this.getJson(`session/${sessionId}`)
  }

  async deleteSession(sessionId: string): Promise<void> {
    await this.deleteJson(`session/${sessionId}`)
  }

  async createSession(options: { title?: string | null }): Promise<unknown> {
    const body: Record<string, unknown> = {}
    const title = options.title?.trim()
    if (title && title.length > 0) {
      body.title = title
    }

    return this.postJson("session", body)
  }

  async getSessionMessages(sessionId: string): Promise<unknown> {
    return this.getJson(`session/${sessionId}/message`)
  }

  async getSessionTodos(sessionId: string): Promise<unknown> {
    return this.getJson(`session/${sessionId}/todo`)
  }

  async getQuestions(): Promise<unknown> {
    return this.getJson("question")
  }

  async getPermissions(): Promise<unknown> {
    return this.getJson("permission")
  }

  async getProviders(): Promise<unknown> {
    return this.getJson("provider")
  }

  async getFile(path: string): Promise<unknown> {
    return this.getJson(`file?path=${encodeURIComponent(path)}`)
  }

  async getFileContent(path: string): Promise<unknown> {
    return this.getJson(`file/content?path=${encodeURIComponent(path)}`)
  }

  async findFiles(query: string): Promise<unknown> {
    return this.getJson(`find/file?query=${encodeURIComponent(query)}`)
  }

  async findText(pattern: string): Promise<unknown> {
    return this.getJson(`find?pattern=${encodeURIComponent(pattern)}`)
  }

  async promptSession(sessionId: string, prompt: string): Promise<void> {
    await this.postJson(`session/${sessionId}/prompt_async`, {
      parts: [
        {
          type: "text",
          text: prompt,
        },
      ],
    })
  }

  async summarizeSession(
    sessionId: string,
    options: { providerID: string; modelID: string; auto?: boolean },
  ): Promise<void> {
    await this.postJson(`session/${sessionId}/summarize`, {
      providerID: options.providerID,
      modelID: options.modelID,
      ...(options.auto == null ? {} : { auto: options.auto }),
    })
  }

  async replyQuestion(requestId: string, answers: string[][]): Promise<void> {
    await this.postJson(`question/${requestId}/reply`, { answers })
  }

  async rejectQuestion(requestId: string): Promise<void> {
    await this.postJson(`question/${requestId}/reject`, {})
  }

  async replyPermission(
    requestId: string,
    reply: "once" | "always" | "reject",
    message?: string,
  ): Promise<void> {
    await this.postJson(`permission/${requestId}/reply`, {
      reply,
      ...(message ? { message } : {}),
    })
  }

  async openGlobalEvents(): Promise<Response> {
    const response = await fetch(new URL("global/event", `${this.baseUrl}/`), {
      headers: {
        accept: "text/event-stream",
      },
    })

    if (!response.ok || !response.body) {
      throw new UpstreamError("OpenCode global event stream unavailable", response.status)
    }

    return response
  }

  async getHealth(): Promise<JsonObject> {
    await this.getSessions()
    return { ok: true }
  }
}
