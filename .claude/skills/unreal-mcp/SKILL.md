---
name: unreal-mcp
description: "Connect Claude Code to the native Unreal Engine MCP server, inspect available toolsets, and operate the editor with explicit verification."
argument-hint: "[setup | status | inspect | workflow]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
model: sonnet
---

# Unreal MCP

Use this skill when a task needs direct interaction with an Unreal Editor instance through Epic's native Unreal MCP server. This skill covers connection and safe operation; it does not replace `unreal-specialist`, `ue-blueprint-specialist`, `ue-umg-specialist`, or other domain specialists.

## Scope and assumptions

- Target the engine version pinned in `docs/engine-reference/unreal/VERSION.md`.
- The native Unreal MCP server is an Experimental editor feature. Treat its tools and schemas as version-dependent.
- The server runs inside the Unreal Editor process and exposes a local HTTP endpoint. The default UE 5.8 endpoint is `http://127.0.0.1:8000/mcp`.
- Do not install a third-party MCP server unless the user explicitly requests one or the native server cannot meet a demonstrated requirement.
- Do not create or commit a project-wide `.mcp.json` automatically. Prefer a local Claude Code connection so contributors are not silently coupled to a developer's editor instance.

## Mode selection

- `setup`: guide the user through enabling the editor plugins and registering the local server.
- `status`: inspect the currently exposed MCP connection and report what is actually available.
- `inspect`: read-only inspection of the current editor/project state.
- `workflow`: execute a bounded editor operation requested by the user, with verification.

If the user has not specified a mode, infer it from the request. Do not ask them to repeat information already present in the conversation.

## Setup procedure

1. Read `docs/engine-reference/unreal/VERSION.md` and confirm the pinned and installed engine versions. If the installed version is unknown, ask the user to confirm the editor version before relying on version-specific behavior.
2. Confirm that the project is an Unreal project by locating its `.uproject`. Do not modify the project file just to enable MCP.
3. In Unreal Editor, ask the user to enable the **Unreal MCP** plugin and **All Toolsets** plugin (the Toolset Registry dependency is enabled by the editor). Restart the editor when prompted.
4. In UE 5.8, open **Edit > Editor Preferences > General > Model Context Protocol**. Auto Start Server is disabled by default in the UE 5.8 reference; ask the user to enable it, or have them start the server from the editor console with `ModelContextProtocol.StartServer`.
5. Use the default local endpoint unless the user has configured another port/path: `http://127.0.0.1:8000/mcp`.
6. Prefer a **local-scoped Claude Code registration** so the editor endpoint is not added to the shared repository configuration. First inspect the existing registration with `claude mcp get unreal-mcp`; if it is absent, show the command and obtain the user's approval before running it because it changes local Claude Code configuration:
   ```powershell
   claude mcp add --transport http unreal-mcp --scope local http://127.0.0.1:8000/mcp
   ```
7. Use Unreal's **Generate Client Config** action only if the user explicitly chooses a project-level configuration. The console alternative is `ModelContextProtocol.GenerateClientConfig ClaudeCode`. UE 5.8 documentation says this writes `.mcp.json` to the project root. Inspect the Output Log and file contents; do not stage or commit this machine-local endpoint unless the team explicitly decides to share it.
8. Restart Claude Code or reload its MCP connections. Verify with `claude mcp get unreal-mcp` and `/mcp`. Never report a connection as successful based only on the registration command.

## Discovery and status

1. Inspect the MCP tools actually exposed in this session. Do not assume a tool name, toolset, schema, or feature exists because it appears in a newer Unreal version's documentation.
2. If tool-search discovery is enabled, begin with the exposed discovery operations (for example, listing toolsets and describing a selected toolset). Request schemas before calling unfamiliar tools.
3. Record:
   - connected server name and endpoint, when visible;
   - editor/engine version, when verifiable;
   - available toolsets;
   - missing or disabled toolsets relevant to the task;
   - whether the current editor/project state can be inspected.
4. If no Unreal MCP tools are exposed, stop editor operations. Report the exact missing prerequisite and the next diagnostic step; do not simulate an editor action.

## Safe editor-operation protocol

For every requested operation:

1. **Inspect first.** Read the current selection, target asset/actor, level, or relevant property before changing anything.
2. **Scope the change.** Identify the exact object(s), property(ies), asset path(s), and expected result. Avoid broad scene changes when a targeted operation is sufficient.
3. **Respect approval.** Follow the repository's collaborative protocol. Obtain approval before destructive operations, deleting/replacing assets, changing project/plugin configuration, or making architectural changes. A user request to perform a specific bounded operation is approval for that operation, not for unrelated changes.
4. **Serialize calls.** Unreal MCP tool calls run on the editor game thread. Do not issue overlapping editor mutations; perform one call, inspect its result, then continue.
5. **Verify in the editor.** Re-read the affected state after the operation. For Blueprints, require a successful compile; for assets, verify the object exists at the expected path and has the expected properties; for level changes, verify the expected actors and transforms.
6. **Report evidence.** Separate completed and verified changes from attempted, failed, or unverified changes. Include the exact object/path and the observed result.

## Hard boundaries

- Never edit `.uasset` or `.umap` files as text or bytes. Use Unreal Editor tools/MCP or a supported commandlet.
- Never claim an asset or Blueprint change is complete without editor-side verification.
- Do not expose the server beyond loopback for convenience. The UE 5.8 native server has no authentication layer by default; do not add network interfaces or allowed origins without a separate security review and explicit user approval.
- Do not send credentials, private keys, or unrelated sensitive data through MCP tool arguments.
- Do not run multiple editor mutations concurrently.
- Do not invent toolsets, tool names, arguments, or successful results.
- Do not add custom C++/Python toolsets as part of basic connection setup. First prove that native toolsets are insufficient for a concrete COV workflow.

## Troubleshooting

- **Connection refused:** ensure the editor has fully loaded, Auto Start Server is enabled or `ModelContextProtocol.StartServer` was run, and the configured port/path match the client URL.
- **Connection closes immediately:** verify the full endpoint includes `/mcp`, not only the port; reconnect after editor/client restarts.
- **No useful tools:** enable All Toolsets, restart the editor, reconnect, then inspect available toolsets. Tool discovery may expose meta-tools instead of every editor tool.
- **Wrong editor instance:** confirm the port and project root; only connect to the intended COV editor instance.
- **Calls appear stalled:** wait for the previous call; the server serializes tool execution on the game thread.

## Completion criteria

A setup is **CONNECTED** only when Claude Code reports the server connected and at least one read-only discovery/inspection call returns data from the intended Unreal Editor instance. A workflow is **VERIFIED** only when the post-operation inspection confirms the requested state. Otherwise report **NOT CONNECTED**, **PARTIAL**, or **NOT VERIFIED** with evidence.


## Next step

After setup, run `/unreal-mcp status` to confirm the live connection. Before an editor change, use `/unreal-mcp inspect` to identify the intended project, level, target object, and available tool schema. Then involve the relevant Unreal domain specialist for the implementation decision.
