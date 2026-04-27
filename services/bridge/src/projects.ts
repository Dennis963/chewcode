import { access, mkdir, readFile, readdir, stat, writeFile } from "node:fs/promises"
import os from "node:os"
import path from "node:path"

type StoredProject = {
  id: string
  name: string
  path: string
  createdAt: string
  lastOpenedAt: string | null
}

export type ProjectSummary = {
  id: string
  name: string
  path: string
  opened: boolean
  runtimeState: "stopped" | "starting" | "running" | "error"
  lastOpenedAt: string | null
  port: number | null
}

export type ProjectCandidate = {
  path: string
  name: string
  sourceRoot: string
}

type RegistryFile = {
  projects: StoredProject[]
}

export type ProjectRegistryOptions = {
  registryFilePath: string
  allowedRoots: string[]
}

export class ProjectRegistryError extends Error {
  constructor(
    message: string,
    readonly statusCode: number,
    readonly code: string,
  ) {
    super(message)
  }
}

const PROJECT_MARKERS = [
  ".git",
  "package.json",
  "pnpm-workspace.yaml",
  "pyproject.toml",
  "Cargo.toml",
  "go.mod",
]

const DISCOVERY_MAX_DEPTH = 2

export class ProjectRegistry {
  private readonly registryFilePath: string
  private readonly allowedRoots: string[]

  constructor(options: ProjectRegistryOptions) {
    this.registryFilePath = path.resolve(options.registryFilePath)
    this.allowedRoots = options.allowedRoots.map((root) => path.resolve(root))
  }

  getAllowedRoots(): string[] {
    return [...this.allowedRoots]
  }

  async listProjects(): Promise<StoredProject[]> {
    const data = await this.readRegistry()
    return data.projects
  }

  async registerProject(input: { path: string; name?: string | null }): Promise<StoredProject> {
    const resolvedPath = await this.validateProjectPath(input.path)
    const data = await this.readRegistry()
    const existing = data.projects.find((project) => project.path === resolvedPath)
    if (existing) {
      return existing
    }

    const createdProject: StoredProject = {
      id: createProjectId(resolvedPath),
      name: input.name?.trim() || path.basename(resolvedPath),
      path: resolvedPath,
      createdAt: new Date().toISOString(),
      lastOpenedAt: null,
    }

    data.projects.push(createdProject)
    await this.writeRegistry(data)
    return createdProject
  }

  async markOpened(projectId: string): Promise<void> {
    const data = await this.readRegistry()
    const project = data.projects.find((item) => item.id === projectId)
    if (!project) {
      return
    }
    project.lastOpenedAt = new Date().toISOString()
    await this.writeRegistry(data)
  }

  async getProject(projectId: string): Promise<StoredProject | null> {
    const projects = await this.listProjects()
    return projects.find((project) => project.id === projectId) ?? null
  }

  async deleteProject(projectId: string): Promise<StoredProject | null> {
    const data = await this.readRegistry()
    const index = data.projects.findIndex((project) => project.id === projectId)
    if (index === -1) {
      return null
    }

    const [removed] = data.projects.splice(index, 1)
    await this.writeRegistry(data)
    return removed
  }

  async discoverProjects(): Promise<ProjectCandidate[]> {
    const candidates = new Map<string, ProjectCandidate>()

    for (const root of this.allowedRoots) {
      await collectProjectCandidates(root, root, 0, candidates)
    }

    return [...candidates.values()].sort((left, right) => {
      const depthOrder = pathDepth(right.path) - pathDepth(left.path)
      if (depthOrder != 0) {
        return depthOrder
      }
      return left.name.localeCompare(right.name)
    })
  }

  private async validateProjectPath(projectPath: string): Promise<string> {
    const resolvedPath = path.resolve(projectPath)
    if (!this.allowedRoots.some((root) => isPathInsideRoot(root, resolvedPath))) {
      throw new ProjectRegistryError(
        "Project path is outside allowed roots",
        403,
        "project_path_outside_allowed_roots",
      )
    }

    const projectStats = await stat(resolvedPath).catch(() => null)
    if (projectStats == null) {
      throw new ProjectRegistryError(
        "Project path does not exist",
        404,
        "project_path_not_found",
      )
    }
    if (!projectStats.isDirectory()) {
      throw new ProjectRegistryError(
        "Project path is not a directory",
        400,
        "project_path_not_directory",
      )
    }

    if (!(await looksLikeProject(resolvedPath))) {
      throw new ProjectRegistryError(
        "Project path does not look like a supported workspace",
        400,
        "project_path_not_workspace",
      )
    }

    return resolvedPath
  }

  private async readRegistry(): Promise<RegistryFile> {
    try {
      const content = await readFile(this.registryFilePath, "utf8")
      const parsed = JSON.parse(content) as RegistryFile
      return { projects: parsed.projects ?? [] }
    } catch {
      return { projects: [] }
    }
  }

  private async writeRegistry(data: RegistryFile): Promise<void> {
    await mkdir(path.dirname(this.registryFilePath), { recursive: true })
    await writeFile(this.registryFilePath, JSON.stringify(data, null, 2))
  }
}

export function defaultRegistryPath(): string {
  return path.join(os.homedir(), ".local", "share", "chewcode", "projects.json")
}

function createProjectId(projectPath: string): string {
  const basename = path.basename(projectPath).replace(/[^a-zA-Z0-9_-]+/g, "-")
  return `${basename}-${Buffer.from(projectPath).toString("base64url").slice(-8)}`
}

async function looksLikeProject(projectPath: string): Promise<boolean> {
  if (await hasProjectMarker(projectPath)) {
    return true
  }

  const entries = await safeReadDirectory(projectPath)
  const visibleDirectories = entries.filter(
    (entry) => entry.isDirectory() && !entry.name.startsWith('.'),
  )
  const visibleFiles = entries.filter(
    (entry) => entry.isFile() && !entry.name.startsWith('.'),
  )

  return visibleDirectories.length > 0 || visibleFiles.length > 0
}

async function hasProjectMarker(projectPath: string): Promise<boolean> {
  for (const marker of PROJECT_MARKERS) {
    try {
      await access(path.join(projectPath, marker))
      return true
    } catch {
      continue
    }
  }
  return false
}

async function safeReadDirectory(directoryPath: string) {
  try {
    return await readdir(directoryPath, { withFileTypes: true })
  } catch {
    return []
  }
}

async function collectProjectCandidates(
  sourceRoot: string,
  currentPath: string,
  depth: number,
  candidates: Map<string, ProjectCandidate>,
): Promise<void> {
  if (depth > DISCOVERY_MAX_DEPTH) {
    return
  }

  const entries = await safeReadDirectory(currentPath)
  const childDirectories = entries.filter(
    (entry) => entry.isDirectory() && !entry.name.startsWith('.'),
  )
  let childProjectCount = 0

  for (const child of childDirectories) {
    const childPath = path.join(currentPath, child.name)
    if (await looksLikeProject(childPath)) {
      childProjectCount += 1
    }
  }

  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue
    }
    if (entry.name.startsWith('.')) {
      continue
    }

    const entryPath = path.join(currentPath, entry.name)
    if (await looksLikeProject(entryPath)) {
      const nestedChildren = await safeReadDirectory(entryPath)
      const nestedProjectCount = await countProjectLikeChildren(entryPath, nestedChildren)
      const descendantProjectCount = await countProjectLikeDescendants(
        entryPath,
        depth + 1,
      )
      const entryHasMarker = await hasProjectMarker(entryPath)
      const nestedVisibleDirectories = nestedChildren.filter(
        (item) => item.isDirectory() && !item.name.startsWith('.'),
      ).length

      const shouldDescend = !entryHasMarker &&
          (nestedProjectCount > 0 ||
              descendantProjectCount > 0 ||
              nestedVisibleDirectories > 2)

      if (shouldDescend) {
        await collectProjectCandidates(sourceRoot, entryPath, depth + 1, candidates)
      } else {
        candidates.set(entryPath, {
          path: entryPath,
          name: entry.name,
          sourceRoot,
        })
      }
      continue
    }

    await collectProjectCandidates(sourceRoot, entryPath, depth + 1, candidates)
  }

  if (
    depth > 0 &&
    childProjectCount == 0 &&
    await looksLikeProject(currentPath) &&
    await hasProjectMarker(currentPath)
  ) {
    const currentName = path.basename(currentPath)
    candidates.set(currentPath, {
      path: currentPath,
      name: currentName,
      sourceRoot,
    })
  }
}

async function countProjectLikeChildren(
  directoryPath: string,
  entries: Awaited<ReturnType<typeof safeReadDirectory>>,
): Promise<number> {
  let count = 0
  for (const entry of entries) {
    if (!entry.isDirectory() || entry.name.startsWith('.')) {
      continue
    }

    const entryPath = path.join(directoryPath, entry.name)
    if (await looksLikeProject(entryPath)) {
      count += 1
    }
  }
  return count
}

async function countProjectLikeDescendants(
  directoryPath: string,
  depth: number,
): Promise<number> {
  if (depth > DISCOVERY_MAX_DEPTH) {
    return 0
  }

  const entries = await safeReadDirectory(directoryPath)
  let count = 0

  for (const entry of entries) {
    if (!entry.isDirectory() || entry.name.startsWith('.')) {
      continue
    }

    const entryPath = path.join(directoryPath, entry.name)
    if (await looksLikeProject(entryPath)) {
      count += 1
    }
    count += await countProjectLikeDescendants(entryPath, depth + 1)
  }

  return count
}

function isPathInsideRoot(root: string, candidatePath: string): boolean {
  const relative = path.relative(path.resolve(root), path.resolve(candidatePath))
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative))
}

function pathDepth(projectPath: string): number {
  return projectPath.split(path.sep).filter((part) => part.length > 0).length
}
