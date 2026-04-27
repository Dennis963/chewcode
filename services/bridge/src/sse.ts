import type { FastifyReply } from "fastify"

import { encodeSse, mapBridgeEvent } from "./mappers.js"
import { OpenCodeUpstreamClient } from "./upstream.js"

export async function streamEvents(
  reply: FastifyReply,
  upstream: OpenCodeUpstreamClient,
): Promise<void> {
  const upstreamResponse = await upstream.openGlobalEvents()
  const reader = upstreamResponse.body?.getReader()

  if (!reader) {
    throw new Error("Missing upstream event stream body")
  }

  reply.raw.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
    "X-Accel-Buffering": "no",
  })

  reply.raw.write(encodeSse(mapBridgeEvent("bridge.ready", { upstreamConnected: true })))

  const decoder = new TextDecoder()
  let buffer = ""

  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) {
        break
      }

      buffer += decoder.decode(value, { stream: true })

      while (buffer.includes("\n\n")) {
        const splitIndex = buffer.indexOf("\n\n")
        const rawEvent = buffer.slice(0, splitIndex)
        buffer = buffer.slice(splitIndex + 2)
        const encoded = parseAndEncode(rawEvent)
        if (encoded) {
          reply.raw.write(encoded)
        }
      }
    }
  } finally {
    reply.raw.end()
  }
}

function parseAndEncode(rawEvent: string): string | null {
  const lines = rawEvent
    .split("\n")
    .map((line) => line.trimEnd())
    .filter((line) => line.length > 0)

  if (lines.length === 0) {
    return null
  }

  let eventName: string | null = null
  const dataLines: string[] = []

  for (const line of lines) {
    if (line.startsWith(":")) {
      continue
    }
    if (line.startsWith("event:")) {
      eventName = line.slice("event:".length).trim()
      continue
    }
    if (line.startsWith("data:")) {
      dataLines.push(line.slice("data:".length).trim())
    }
  }

  if (dataLines.length === 0) {
    return null
  }

  const combinedData = dataLines.join("\n")
  let parsedPayload: unknown = {}

  if (combinedData.length > 0) {
    try {
      parsedPayload = JSON.parse(combinedData)
    } catch {
      parsedPayload = { raw: combinedData }
    }
  }

  return encodeSse(mapBridgeEvent(eventName, parsedPayload))
}
