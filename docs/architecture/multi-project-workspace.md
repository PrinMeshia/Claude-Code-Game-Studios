# Multi-project workspace architecture

**Status:** Architecture decision; runtime implementation is intentionally incomplete.
**Scope:** Claude Code Game Studios workspace and projects hosted beneath `projects/`.
**Compatibility:** Preserve the existing single-project-at-repository-root workflow until the multi-project path is implemented end to end.

## Decision

Use one framework workspace with one directory per game or application project:

```text
Claude-Code-Game-Studios/
├── .claude/                 # shared framework agents, skills, hooks and rules
├── docs/                    # framework documentation
├── studio-tests/            # tests of the framework itself
├── projects/
│   ├── README.md
│   ├── covLab/              # independent project checkout
│   ├── AuditStack/          # independent project checkout
│   └── <project-id>/
└── ...
```

Each child project owns its own source tree, engine files, project documentation, tests, build configuration and `project.yaml`. For example, Unreal's `covLab` keeps `covLab.uproject`, `Config/`, `Content/`, `Plugins/` and `Source/` inside `projects/covLab/`. The framework must not flatten these folders into its own root.

## Repository boundaries

A child project is an independently versioned codebase. Use a separate Git clone in `projects/<project-id>/`, or a Git submodule when the workspace should pin a particular project revision. Do not treat project source as framework source, and do not accidentally stage an embedded repository as ordinary files.

The framework repository owns shared orchestration, agents, skills, hooks, engine references, framework tests and workspace-level documentation. A child project repository owns game/application implementation and its project-level configuration.

## Configuration ownership

The current root `project.yaml` is project configuration, not a workspace registry. Existing code reads it as the single source of truth. It must not be silently repurposed as a workspace manifest.

Target ownership:

- Workspace configuration: framework-wide defaults and workspace metadata only.
- `projects/<id>/project.yaml`: authoritative shared configuration for that project (engine, version, roots, commands, modes and project settings).
- `projects/<id>/project.local.yaml`: developer-local overrides, ignored by that project's Git repository.
- Active-project state: an explicit selection, never inferred from whichever project happens to have a matching folder name.

The workspace must not copy a project's engine settings into another project's configuration. `/setup-engine` must update only the selected project's configuration and engine references.

## Runtime requirements before claiming multi-project support

The directory layout alone is not multi-project support. All of the following must be implemented and tested together:

1. **Discovery:** enumerate direct child directories containing a valid project marker/configuration; ignore caches, worktrees and arbitrary folders.
2. **Selection:** provide an explicit project selection workflow and a clear active-project display. Reject unknown or ambiguous identifiers.
3. **Context resolution:** resolve the selected project's absolute root once, validate it, and pass it consistently to hooks, skill bootstraps, scripts and agents. Never silently fall back to the workspace root when a selected project is missing or invalid.
4. **Path safety:** resolve project-relative paths against the selected project root; reject traversal outside that root unless a workflow explicitly authorizes an external path.
5. **Engine isolation:** load the selected project's engine/version and derive code, content, config, plugin, asset and test roots from its configuration and engine table. Unreal's `Source/<Module>/` is a C++ code root, not the whole Unreal project root; Blueprints and levels remain under `Content/`.
6. **Command coverage:** audit every skill and script that reads or writes `project.yaml`, `CLAUDE.md`, `src/`, `Assets/`, `Source/`, `Content/`, `tests/`, `design/`, `docs/` or `production/`. No command may act on the workspace root by accident.
7. **Isolation tests:** run two fixture projects with different engines and settings. Verify selection, config resolution, code/test root resolution, setup-engine writes, hooks, and path traversal rejection for both.
8. **Backward compatibility:** keep root-level single-project behavior working for existing users and document an explicit migration path. Do not auto-move user files or rewrite Git history.

## Current limitation

At this decision's introduction, the existing configuration resolver prefers a `project.yaml` in the current directory and otherwise may use `CLAUDE_PROJECT_DIR`. The repository also contains many commands and hooks that use paths relative to the current working directory. Therefore merely adding `projects/covLab/` or setting a project name does not redirect the whole framework safely.

Until the requirements above are met, the supported workflow remains the existing single-project root. The `projects/` directory is the agreed target layout and a place for independent project checkouts, not a claim that project selection is already operational.