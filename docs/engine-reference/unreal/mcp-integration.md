# Unreal Engine 5.8 — Native MCP Integration

**Status:** Experimental engine feature  
**Target client:** Claude Code  
**Default endpoint:** `http://127.0.0.1:8000/mcp`

This document describes the native Epic Unreal MCP server. It does not install or run a separate MCP server process: the server is hosted by the running Unreal Editor.

## Components

- **Unreal MCP** (`ModelContextProtocol`): hosts the MCP server in the editor process.
- **All Toolsets**: enables the default collection of editor toolsets.
- **Toolset Registry**: dependency used to register toolsets; the editor enables it when required.
- **Claude Code**: connects to the editor over Streamable HTTP.

The native Unreal MCP feature is Experimental in UE 5.8. Tool availability and schemas depend on the exact engine build and enabled toolset plugins. Discover them from the live server rather than relying on a static list.

## Enable the editor server

1. Open the intended COV `.uproject` in the intended Unreal Editor version.
2. In **Edit > Plugins**, enable **Unreal MCP** and **All Toolsets**.
3. Restart the editor when prompted.
4. Open **Edit > Editor Preferences > Agentic Workflows > Model Context Protocol**.
5. Enable **Auto Start Server**. The UE 5.8 defaults are port `8000` and path `/mcp`.
6. Wait until the editor has finished loading the project and level.

If Auto Start Server is disabled, run this in the editor console:

```text
ModelContextProtocol.StartServer
```

The server is local to the editor process. Do not assume it is running just because the plugin is enabled.

## Connect Claude Code

### Preferred: generate the client configuration

Use the Model Context Protocol editor preferences to select **Claude Code** and invoke **Generate Client Config**. The console alternative is:

```text
ModelContextProtocol.GenerateClientConfig ClaudeCode
```

Inspect the output log and confirm where `.mcp.json` was generated. With installed engine builds it is expected in the project root; with source engine builds it may be written under the engine root. If it is outside the project, do not launch Claude Code from the wrong directory: register the server locally for the actual project instead.

### Local Claude Code registration

From the COV project root, if the server has not already been registered:

```powershell
claude mcp add --transport http unreal-mcp --scope local http://127.0.0.1:8000/mcp
claude mcp get unreal-mcp
```

Then restart/reload Claude Code and inspect `/mcp`.

The `local` scope stores the connection in the user's Claude Code configuration for this project. It avoids committing a machine-specific editor endpoint to the repository. Use project scope and a committed `.mcp.json` only after an explicit team decision.

## Verify the connection

A connection is not verified by the registration command alone.

1. Confirm `unreal-mcp` is shown as connected in Claude Code's `/mcp` view.
2. Ask Claude Code to identify the selected actor or list the available Unreal toolsets.
3. Require a response based on live editor data, not a generic explanation of Unreal.
4. Confirm the response refers to the intended project/editor instance.

If tool search is enabled, the server may expose discovery meta-tools rather than the full tool list. Use the live discovery tools to list toolsets, inspect schemas, and only then call a specific editor tool. Do not hardcode tool names from another engine version.

## Security and operational constraints

- The default server binds to loopback (`127.0.0.1`) and is intended for same-machine use.
- The native UE 5.8 server has no authentication layer by default. Do not expose it to a LAN, public interface, reverse proxy, or untrusted browser origin.
- Adding allowed origins widens the set of browser origins that can reach the editor; do not do so without a security review.
- Tool calls execute on the editor game thread and are serialized. Do not send overlapping mutations.
- The server exists only while the editor process is running. Reconnect the client after either side restarts.
- The MCP server is an editor-control surface, not a replacement for source control, code review, automated tests, or asset validation.

## Troubleshooting

| Symptom | Check |
|---|---|
| Connection refused | Editor fully loaded; Auto Start enabled or StartServer run; port matches |
| Immediate disconnect | Client URL includes the full `/mcp` path |
| Server connected but few tools | All Toolsets enabled; editor restarted; live tool discovery inspected |
| Wrong project affected | Correct `.uproject` opened and correct editor instance/port selected |
| Tool call hangs | Wait for the current editor call; mutations are serialized |

## Project workflow contract

For COV work performed through MCP:

1. Inspect the target object/asset/level before editing.
2. State the exact scope and expected result.
3. Obtain approval for destructive, broad, or architectural changes.
4. Perform one editor mutation at a time.
5. Re-inspect the result in the editor.
6. For Blueprints, verify compilation; for assets, verify path and properties; for level edits, verify actors and transforms.
7. Report verified results separately from attempts or assumptions.

Never modify `.uasset` or `.umap` files directly as text or bytes. Use editor tooling or supported commandlets.

## References

- Epic, [Unreal MCP in Unreal Editor](https://dev.epicgames.com/documentation/unreal-engine/unreal-mcp-in-unreal-editor) — setup, toolsets, security model, and workflow.
- Epic, [ModelContextProtocol plugin API for UE 5.8](https://dev.epicgames.com/documentation/unreal-engine/API/Plugins/ModelContextProtocol?application_version=5.8).
- Epic, [Unreal MCP server API for UE 5.8](https://dev.epicgames.com/documentation/unreal-engine/API/Plugins/ModelContextProtocol/FModelContextProtocolServer?application_version=5.8).
- Anthropic, [Connect Claude Code to tools via MCP](https://code.claude.com/docs/en/mcp).
