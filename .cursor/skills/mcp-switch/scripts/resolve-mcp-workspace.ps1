function Resolve-McpWorkspacePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillRoot
    )

    $projectRoot = (Resolve-Path (Join-Path $SkillRoot "..\..\..")).Path
    $projectLocal = Join-Path $projectRoot ".cursor\mcp-workspace\mcp.workspace.json"
    if (Test-Path $projectLocal) {
        return $projectLocal
    }

    $skillDefault = Join-Path $SkillRoot "mcp.workspace.json"
    if (Test-Path $skillDefault) {
        return $skillDefault
    }

    $userLegacy = Join-Path $HOME ".cursor\mcp.workspace.json"
    if (Test-Path $userLegacy) {
        return $userLegacy
    }

    return $skillDefault
}
