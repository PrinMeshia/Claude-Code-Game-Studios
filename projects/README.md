# Projects workspace

Place one independent project checkout in each direct child folder:

```text
projects/
├── README.md
├── covLab/
├── AuditStack/
└── <another-project>/
```

Each child owns its source, engine files, tests, documentation and `project.yaml`. Keep each child as a separate Git repository or configure it as a Git submodule; do not mix project source files into the framework history.

**Runtime status:** an explicit launcher now exists at `.claude/scripts/launch-project.sh`. From the framework root, run `bash .claude/scripts/launch-project.sh covLab` to start Claude Code in `projects/covLab` while loading shared framework resources and hooks. The launcher requires a child `project.yaml`, a child Git repository/submodule root, and the ability to create `.claude/hooks` and `.claude/scripts` directory links. Existing directories are never overwritten; a conflict stops the launch. The launcher also rejects `--worktree` / `-w` and agent frontmatter declaring `isolation: worktree`.

**Validation warning:** this path and its contract tests have been added but not yet executed on Fedora or Windows Git Bash. Treat it as an implementation candidate until the launcher tests pass and `/status` plus real hook events confirm that settings were loaded.

See [the architecture decision](../docs/architecture/multi-project-workspace.md).