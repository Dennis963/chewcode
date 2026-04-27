import { mkdir, mkdtemp, writeFile } from "node:fs/promises"
import path from "node:path"
import { tmpdir } from "node:os"

import { describe, expect, it } from "vitest"

import { ProjectRegistry } from "../src/projects.js"
import { RuntimeSupervisor } from "../src/supervisor.js"

describe("ProjectRegistry discovery", () => {
  it("discovers marker-based projects", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "project-registry-marker-"))
    const projectPath = path.join(root, "alpha")
    await mkdir(projectPath, { recursive: true })
    await writeFile(path.join(projectPath, "package.json"), "{}")

    const registry = new ProjectRegistry({
      registryFilePath: path.join(root, "registry.json"),
      allowedRoots: [root],
    })

    const candidates = await registry.discoverProjects()
    expect(candidates.map((candidate) => candidate.path)).toContain(projectPath)
  })

  it("discovers non-marker workspaces that contain visible directories", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "project-registry-content-"))
    const projectPath = path.join(root, "robot")
    await mkdir(path.join(projectPath, "ability"), { recursive: true })
    await mkdir(path.join(projectPath, "docs"), { recursive: true })

    const registry = new ProjectRegistry({
      registryFilePath: path.join(root, "registry.json"),
      allowedRoots: [root],
    })

    const candidates = await registry.discoverProjects()
    expect(candidates.map((candidate) => candidate.path)).toContain(projectPath)
  })

  it("prefers nested project leaves over container directories", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "project-registry-nested-"))
    const containerPath = path.join(root, "open_src")
    const leafAPath = path.join(containerPath, "alpha")
    const leafBPath = path.join(containerPath, "beta")

    await mkdir(leafAPath, { recursive: true })
    await mkdir(leafBPath, { recursive: true })
    await writeFile(path.join(leafAPath, "package.json"), "{}")
    await writeFile(path.join(leafBPath, "pyproject.toml"), "")

    const registry = new ProjectRegistry({
      registryFilePath: path.join(root, "registry.json"),
      allowedRoots: [root],
    })

    const candidates = await registry.discoverProjects()
    const paths = candidates.map((candidate) => candidate.path)

    expect(paths).toContain(leafAPath)
    expect(paths).toContain(leafBPath)
    expect(paths).not.toContain(containerPath)
  })

  it("does not surface markerless container directories as projects when nested leaves exist", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "project-registry-container-"))
    const containerPath = path.join(root, "open_src")
    const groupA = path.join(containerPath, "flutter")
    const groupB = path.join(containerPath, "cc-src")
    const leafAPath = path.join(groupA, "alpha")
    const leafBPath = path.join(groupB, "beta")

    await mkdir(leafAPath, { recursive: true })
    await mkdir(leafBPath, { recursive: true })
    await writeFile(path.join(leafAPath, "package.json"), "{}")
    await writeFile(path.join(leafBPath, "pyproject.toml"), "")

    const registry = new ProjectRegistry({
      registryFilePath: path.join(root, "registry.json"),
      allowedRoots: [root],
    })

    const paths = (await registry.discoverProjects()).map((candidate) => candidate.path)
    expect(paths).toContain(leafAPath)
    expect(paths).toContain(leafBPath)
    expect(paths).not.toContain(containerPath)
  })

  it("allows manual registration for non-marker workspaces with visible contents", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "project-registry-register-"))
    const projectPath = path.join(root, "robot")
    await mkdir(path.join(projectPath, "ability"), { recursive: true })

    const registry = new ProjectRegistry({
      registryFilePath: path.join(root, "registry.json"),
      allowedRoots: [root],
    })

    const project = await registry.registerProject({ path: projectPath, name: "robot" })
    expect(project.path).toBe(projectPath)
    expect(project.name).toBe("robot")
  })

  it(
    "returns a ready runtime to concurrent open requests for the same project",
    async () => {
      const supervisor = new RuntimeSupervisor(
        process.env.CHEWCODE_OPENCODE_BIN ?? "opencode",
      )
      const projectPath = await mkdtemp(path.join(tmpdir(), "project-runtime-"))
      const project = {
        id: "robot-test",
        path: projectPath,
      }

      const [first, second] = await Promise.all([
        supervisor.ensureProjectRuntime(project),
        supervisor.ensureProjectRuntime(project),
      ])

      expect(first.state).toBe("running")
      expect(second.state).toBe("running")
      expect(first.port).toBe(second.port)

      await supervisor.stopProjectRuntime(project.id)
    },
    20000,
  )
})
