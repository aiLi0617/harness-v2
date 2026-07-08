#Requires -Version 5.1

function Resolve-McpWorkspacePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillRoot
    )

    $local = Join-Path $SkillRoot "mcp.workspace.json"
    $legacy = Join-Path $env:USERPROFILE ".cursor\mcp.workspace.json"

    if (Test-Path $local) {
        return (Resolve-Path $local).Path
    }
    if (Test-Path $legacy) {
        Write-Warning "Using legacy ~/.cursor/mcp.workspace.json — copy to $local to finish migration"
        return (Resolve-Path $legacy).Path
    }
    return $local
}

function Resolve-McpWorkspaceSecretsPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath,
        [Parameter(Mandatory = $true)]
        [string]$SkillRoot
    )

    $adjacent = Join-Path (Split-Path -Parent $WorkspacePath) "mcp.workspace.secrets.json"
    $local = Join-Path $SkillRoot "mcp.workspace.secrets.json"
    $legacy = Join-Path $env:USERPROFILE ".cursor\mcp.workspace.secrets.json"

    if (Test-Path $adjacent) { return (Resolve-Path $adjacent).Path }
    if (Test-Path $local) { return (Resolve-Path $local).Path }
    if (Test-Path $legacy) { return (Resolve-Path $legacy).Path }
    return $local
}
