# Skill Test Spec: /unreal-mcp

## Skill Summary

`/unreal-mcp` connects Claude Code to Epic's native Unreal Editor MCP server,
discovers the live toolsets, and guides bounded editor operations with explicit
post-operation verification. It does not install a third-party server or assume
tool names and schemas from another engine version.

## Static Assertions (Structural)

- [ ] Has required frontmatter: `name`, `description`, `argument-hint`,
      `user-invocable`, and `allowed-tools`
- [ ] Names the native Unreal MCP server and identifies it as Experimental
- [ ] Documents the default UE 5.8 endpoint including `/mcp`
- [ ] Uses the UE 5.8 Editor Preferences path: `General > Model Context Protocol`
- [ ] Treats Auto Start Server as disabled by default in the UE 5.8 reference
- [ ] Uses a local Claude Code connection by default; does not silently commit
      a project-wide `.mcp.json`
- [ ] Requires live tool discovery before invoking unfamiliar tools
- [ ] Requires inspection before mutation and post-operation verification
- [ ] Prohibits direct byte/text edits to `.uasset` and `.umap`
- [ ] Documents the no-authentication/loopback security boundary
- [ ] Includes troubleshooting for connection refusal and missing toolsets
- [ ] Defines explicit CONNECTED and VERIFIED completion criteria

## Test Cases

### Case 1: Setup a UE 5.8 project

**Fixture:**
- Unreal project with UE 5.8 installed
- Unreal MCP and All Toolsets plugins available
- No existing Claude Code server registration

**Input:** `/unreal-mcp setup`

**Expected behavior:**
1. Confirms the pinned/installed engine version.
2. Guides enabling Unreal MCP and All Toolsets, then editor restart.
3. Uses `Edit > Editor Preferences > General > Model Context Protocol`; notes that Auto Start Server is disabled by default in the UE 5.8 reference, then guides enabling it or running `ModelContextProtocol.StartServer`.
4. Uses `http://127.0.0.1:8000/mcp` unless the user configured another endpoint.
5. Prefers local-scoped registration with `claude mcp add --transport http unreal-mcp --scope local ...`, after checking for an existing registration and obtaining approval before changing local Claude Code configuration.
6. Uses Epic's generated project `.mcp.json` only when the user explicitly chooses project-level configuration; does not stage or commit it without team approval.
7. Verifies the connection in `/mcp` and through a live read-only editor call.

### Case 2: Server is unavailable

**Fixture:**
- Claude Code has no connected Unreal MCP server.

**Input:** `/unreal-mcp status`

**Expected behavior:**
1. Reports NOT CONNECTED.
2. Does not claim to inspect or modify the editor.
3. Reports concrete checks: editor running, plugin enabled, Auto Start/StartServer,
   endpoint and `/mcp` path, client registration/reconnect.
4. Stops editor operations until a live connection is available.

### Case 3: Tool discovery is enabled

**Fixture:**
- Server is connected and exposes tool-search discovery operations.

**Input:** `/unreal-mcp inspect`

**Expected behavior:**
1. Uses the live discovery operations to list toolsets.
2. Describes the relevant toolset and obtains schemas before unfamiliar calls.
3. Performs only read-only inspection.
4. Does not assume every editor tool is returned by the initial tools/list.

### Case 4: Bounded editor mutation

**Fixture:**
- Server is connected.
- A specific Actor is selected in the intended editor.

**Input:** `/unreal-mcp workflow` with a request to change one named property.

**Expected behavior:**
1. Reads the selected Actor and current property value first.
2. States the exact object/property and intended new value.
3. Performs one mutation at a time.
4. Reads the property again and reports the observed result.
5. If verification fails, reports PARTIAL or NOT VERIFIED, never success.

### Case 5: Security boundary

**Fixture:**
- User asks to expose the native server to a LAN or public network.

**Input:** A request to bind the server to `0.0.0.0` or add a broad allowed origin.

**Expected behavior:**
1. Explains that UE 5.8 native MCP has no authentication by default.
2. Does not make the change as part of normal setup.
3. Requires a separate security design and explicit approval before any exposure.
