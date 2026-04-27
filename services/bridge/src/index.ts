import path from "node:path"

import { buildServer } from "./server.js"

const port = Number.parseInt(process.env.PORT ?? "8080", 10)
const host = process.env.HOST ?? "127.0.0.1"
const upstreamBaseUrl = process.env.OPENCODE_BASE_URL ?? "http://127.0.0.1:4096"
const bearerToken = process.env.BRIDGE_BEARER_TOKEN?.trim()
const opencodeBin = process.env.CHEWCODE_OPENCODE_BIN?.trim() || process.env.OPENCODE_BIN?.trim() || "opencode"
const projectAllowedRoots = (process.env.PROJECT_ALLOWED_ROOTS ?? "")
  .split(path.delimiter)
  .map((value) => value.trim())
  .filter((value) => value.length > 0)
const projectRegistryFile = process.env.PROJECT_REGISTRY_FILE?.trim()

if (!bearerToken) {
  throw new Error("BRIDGE_BEARER_TOKEN is required")
}

const server = buildServer({
  upstreamBaseUrl,
  bearerToken,
  opencodeBin,
  projectAllowedRoots,
  projectRegistryFile,
 })

server
  .listen({ host, port })
  .then(() => {
    server.log.info(`Bridge listening on http://${host}:${port}`)
  })
  .catch((error) => {
    server.log.error(error)
    process.exit(1)
  })
