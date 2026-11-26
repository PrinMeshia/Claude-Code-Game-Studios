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

**Runtime warning:** project discovery and active-project context propagation are not implemented yet. The existing framework still operates in its single-project-at-root mode. Do not launch project workflows from a child folder and assume the framework has switched context until the multi-project runtime is completed.

See [the architecture decision](../docs/architecture/multi-project-workspace.md).