import type { JsonObject } from "./types.js"

export function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

export function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : []
}

export function asString(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null
}

export function asStringOrEmpty(value: unknown): string {
  return typeof value === "string" ? value : ""
}

export function asBoolean(value: unknown): boolean {
  return value === true
}

export function ensureId(value: unknown, fallback: string): string {
  return asString(value) ?? fallback
}

export function pickFirstString(
  source: JsonObject,
  keys: readonly string[],
): string | null {
  for (const key of keys) {
    const value = source[key]
    const candidate = asString(value)
    if (candidate) {
      return candidate
    }
  }
  return null
}

export function toJsonObject(value: unknown): JsonObject {
  return isObject(value) ? value : {}
}
