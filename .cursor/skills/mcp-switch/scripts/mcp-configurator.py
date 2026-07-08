#!/usr/bin/env python3
"""Merge mcp-registry + mcp.workspace.json into Cursor mcp.json."""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from typing import Any


def mcp_config_path(project_root: Path) -> Path:
    return project_root / ".cursor" / "mcp.config.json"


def parse_env_file(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    if not path.is_file():
        return data
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        data[key.strip()] = value.strip()
    return data


def load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def merge_env_layers(*layers: dict[str, str]) -> dict[str, str]:
    merged: dict[str, str] = {}
    for layer in layers:
        merged.update({k: v for k, v in layer.items() if v})
    return merged


def detect_uvx_bin() -> str:
    for name in ("uvx", "uvx.exe"):
        path = shutil.which(name)
        if path:
            return path
    if sys.platform == "win32":
        candidates: list[Path] = []
        conda_prefix = os.environ.get("CONDA_PREFIX", "")
        if conda_prefix:
            candidates.append(Path(conda_prefix) / "Scripts" / "uvx.exe")
        home = Path.home()
        candidates.extend(
            home / name / "Scripts" / "uvx.exe"
            for name in ("miniconda3", "anaconda3", "miniforge3", "micromamba")
        )
        for candidate in candidates:
            if candidate.is_file():
                return str(candidate)
    return "uvx"


def detect_npx_bin() -> str:
    for name in ("npx", "npx.cmd", "npx.exe"):
        path = shutil.which(name)
        if path:
            return path
    if sys.platform == "win32":
        for candidate in (
            Path("D:/tool/node/npx.cmd"),
            Path(os.environ.get("ProgramFiles", "")) / "nodejs" / "npx.cmd",
            Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "nodejs" / "npx.cmd",
        ):
            if candidate.is_file():
                return str(candidate)
    return "npx"


def detect_loki_mcp_bin() -> str:
    for name in ("loki-mcp", "loki-mcp.exe", "loki-mcp-server", "loki-mcp-server.exe"):
        path = shutil.which(name)
        if path:
            return path
    if sys.platform == "win32":
        home = Path.home()
        for candidate in (
            home / "Documents" / "Codex" / "bin" / "loki-mcp.exe",
            home / "go" / "bin" / "server.exe",
            home / "go" / "bin" / "loki-mcp-server.exe",
        ):
            if candidate.is_file():
                return str(candidate)
    return "loki-mcp-server"


def detect_codegraph_bin() -> str:
    for name in ("codegraph", "codegraph.cmd", "codegraph.exe"):
        path = shutil.which(name)
        if path:
            return path
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA", "")
        if appdata:
            candidate = Path(appdata) / "npm" / "codegraph.cmd"
            if candidate.is_file():
                return str(candidate)
    return "codegraph"


def xxl_job_generated_config_path(project_root: Path, profile_name: str) -> Path:
    return project_root / ".cursor" / ".generated" / f"xxl-job-{profile_name}.yaml"


def yaml_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def prepare_xxl_job_env(
    project_root: Path,
    profile_name: str,
    env_map: dict[str, str],
) -> dict[str, str]:
    admin = env_map.get("XXL_JOB_ADMIN_ADDRESS", "").strip()
    if not admin:
        return env_map

    config_path = xxl_job_generated_config_path(project_root, profile_name)
    config_path.parent.mkdir(parents=True, exist_ok=True)

    username = env_map.get("XXL_JOB_USERNAME") or "admin"
    password = env_map.get("XXL_JOB_PASSWORD") or "123456"
    access_token = env_map.get("XXL_JOB_ACCESS_TOKEN", "").strip()

    lines = [
        "xxl_job:",
        f"  admin_address: {yaml_quote(admin)}",
        f"  username: {yaml_quote(username)}",
        f"  password: {yaml_quote(password)}",
    ]
    if access_token:
        lines.append(f"  access_token: {yaml_quote(access_token)}")
    lines.extend(
        [
            "mcp:",
            '  transport: "stdio"',
        ]
    )
    config_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    out = dict(env_map)
    out["XXL_JOB_CONFIG_PATH"] = str(config_path)
    return out


def augment_tool_paths(env_map: dict[str, str]) -> dict[str, str]:
    out = dict(env_map)
    if not out.get("UVX_BIN"):
        out["UVX_BIN"] = detect_uvx_bin()
    if not out.get("NPX_BIN"):
        out["NPX_BIN"] = detect_npx_bin()
    if not out.get("LOKI_MCP_BIN"):
        out["LOKI_MCP_BIN"] = detect_loki_mcp_bin()
    if not out.get("CODEGRAPH_BIN"):
        out["CODEGRAPH_BIN"] = detect_codegraph_bin()
    return out


def resolve_value(value: Any, env_map: dict[str, str], registry_defaults: dict[str, str]) -> Any:
    if isinstance(value, str):
        def repl(match: re.Match[str]) -> str:
            key = match.group(1)
            if key in env_map:
                return env_map[key]
            if key in registry_defaults and registry_defaults[key]:
                return registry_defaults[key]
            return match.group(0)

        return re.sub(r"\{\{(\w+)\}\}", repl, value)
    if isinstance(value, list):
        return [resolve_value(item, env_map, registry_defaults) for item in value]
    if isinstance(value, dict):
        out: dict[str, Any] = {}
        for k, v in value.items():
            resolved = resolve_value(v, env_map, registry_defaults)
            if k == "env" and isinstance(resolved, dict):
                resolved = {
                    ek: ev
                    for ek, ev in resolved.items()
                    if ev and not str(ev).startswith("{{")
                }
            out[k] = resolved
        return out
    return value


DEPRECATED_MANAGED_KEYS = frozenset({"feishu-mcp"})
SHARED_MCP_IDS = frozenset({"ONES", "codegraph"})


def projects_registry_path() -> Path:
    return Path.home() / ".cursor" / "mcp.projects.json"


def workspace_config_path() -> Path:
    return Path.home() / ".cursor" / "mcp.workspace.json"


def save_workspace_config(workspace: dict[str, Any], path: Path | None = None) -> None:
    out = path or workspace_config_path()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(workspace, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def project_config_from_workspace(workspace: dict[str, Any], project_id: str) -> dict[str, Any]:
    entry = (workspace.get("projects") or {}).get(project_id) or {}
    return {
        "projectId": project_id,
        "projectLabel": entry.get("label", project_id),
        "activeProfile": workspace.get("activeProfile", "dev"),
        "defaultProfile": workspace.get("defaultProfile", "dev"),
        "fixedServers": workspace.get("fixedServers", ["codegraph", "ONES"]),
        "fixedEnv": workspace.get("fixedEnv", {}),
        "tools": workspace.get("tools", {}),
        "profiles": entry.get("profiles", {}),
    }


def find_project_id_by_root(workspace: dict[str, Any], project_root: Path) -> str | None:
    target = project_root.resolve()
    for project_id, entry in (workspace.get("projects") or {}).items():
        raw_path = str(entry.get("path") or "").strip()
        if not raw_path:
            continue
        if Path(raw_path).expanduser().resolve() == target:
            return project_id
    return None


def merge_tools_layers(*layers: dict[str, Any]) -> dict[str, str]:
    merged: dict[str, str] = {}
    for layer in layers:
        merged.update({k: str(v) for k, v in (layer.get("tools") or {}).items() if v})
    return merged


def resolve_project_id(
    config: dict[str, Any],
    project_root: Path,
    fallback_id: str | None = None,
) -> str:
    project_id = str(config.get("projectId") or "").strip()
    if project_id:
        return project_id
    if fallback_id:
        return str(fallback_id).strip()
    return project_root.name


def prefix_server_key(project_id: str, server_id: str) -> str:
    if server_id in SHARED_MCP_IDS:
        return server_id
    return f"{project_id}-{server_id}"


def base_server_id(server_key: str, registry_ids: set[str]) -> str:
    if server_key in registry_ids or server_key in SHARED_MCP_IDS:
        return server_key
    for sid in sorted(registry_ids | SHARED_MCP_IDS, key=len, reverse=True):
        suffix = f"-{sid}"
        if server_key.endswith(suffix):
            return sid
    return server_key


def registry_defaults(registry: dict[str, Any]) -> dict[str, str]:
    defaults: dict[str, str] = {}
    for entry in registry.get("servers", {}).values():
        for key, value in (entry.get("envDefaults") or {}).items():
            defaults[key] = str(value)
    return defaults


def workspace_missing_message(workspace_path: Path) -> str:
    return (
        f"Missing {workspace_path}. "
        "Copy .cursor/skills/shared/mcp-switch/mcp.workspace.example.json "
        "to ~/.cursor/mcp.workspace.json and edit."
    )


def load_legacy_per_project_config(project_root: Path) -> dict[str, Any]:
    """Load per-project mcp.config.json (migration / legacy fallback only)."""
    path = mcp_config_path(project_root)
    if path.is_file():
        return load_json(path)

    legacy_profiles = project_root / ".cursor" / "mcp.profiles.json"
    if not legacy_profiles.is_file():
        raise FileNotFoundError(f"Missing legacy config at {path}")

    return migrate_legacy_config(project_root)


def load_project_config(
    project_root: Path,
    workspace_path: Path | None = None,
) -> tuple[dict[str, Any], Path, str]:
    ws_path = workspace_path or workspace_config_path()
    if not ws_path.is_file():
        raise FileNotFoundError(workspace_missing_message(ws_path))

    workspace = load_json(ws_path)
    project_id = find_project_id_by_root(workspace, project_root)
    if not project_id:
        raise FileNotFoundError(
            f"Project root not found in workspace: {project_root}\nWorkspace: {ws_path}"
        )
    return project_config_from_workspace(workspace, project_id), ws_path, project_id


def load_mcp_config(
    project_root: Path,
    workspace_path: Path | None = None,
) -> dict[str, Any]:
    config, _, _ = load_project_config(project_root, workspace_path)
    return config


def migrate_legacy_config(project_root: Path) -> dict[str, Any]:
    cursor = project_root / ".cursor"
    profiles_doc = load_json(cursor / "mcp.profiles.json")
    env_local = parse_env_file(cursor / "mcp.env.local")

    active = env_local.get("MCP_PROFILE") or profiles_doc.get("defaultProfile", "dev")
    active_path = cursor / "mcp.active-profile"
    if active_path.is_file():
        active = active_path.read_text(encoding="utf-8").strip() or active

    tools = {
        k: env_local[k]
        for k in ("UVX_BIN", "NPX_BIN", "LOKI_MCP_BIN", "CODEGRAPH_BIN")
        if env_local.get(k)
    }

    secret_keys = {
        "MYSQL_USER",
        "MYSQL_PASS",
        "REDIS_USERNAME",
        "REDIS_PWD",
        "REDIS_PASSWORD",
        "LOKI_USERNAME",
        "LOKI_PASSWORD",
        "LOKI_TOKEN",
        "LOKI_ORG_ID",
        "ELASTICSEARCH_USERNAME",
        "ELASTICSEARCH_PASSWORD",
        "ELASTICSEARCH_API_KEY",
        "ES_USERNAME",
        "ES_PASSWORD",
        "ES_API_KEY",
        "NACOS_PASSWORD",
        "XXL_JOB_PASSWORD",
        "XXL_JOB_ACCESS_TOKEN",
    }
    shared_secrets = {k: v for k, v in env_local.items() if k in secret_keys and v}
    if env_local.get("REDIS_PASSWORD") and not shared_secrets.get("REDIS_PWD"):
        shared_secrets["REDIS_PWD"] = env_local["REDIS_PASSWORD"]

    profiles: dict[str, Any] = {}
    for name, doc in (profiles_doc.get("profiles") or {}).items():
        profile_env = dict(doc.get("env") or {})
        profile_env.update(shared_secrets)
        profiles[name] = {
            "label": doc.get("label", name),
            "servers": doc.get("servers", []),
            "env": profile_env,
        }
        if doc.get("notes"):
            profiles[name]["notes"] = doc["notes"]

    return {
        "activeProfile": active,
        "defaultProfile": profiles_doc.get("defaultProfile", "dev"),
        "fixedServers": ["codegraph", "ONES"],
        "fixedEnv": {
            "ONES_MCP_URL": shared_secrets.get("ONES_MCP_URL")
            or (profiles_doc.get("profiles") or {})
            .get(active, {})
            .get("env", {})
            .get("ONES_MCP_URL", "https://sz.ones.cn/mcp"),
        },
        "tools": tools,
        "profiles": profiles,
    }


def save_active_profile(
    project_root: Path,
    config: dict[str, Any],
    profile: str,
    workspace_path: Path | None = None,
) -> None:
    ws_path = workspace_path or workspace_config_path()
    if not ws_path.is_file():
        raise FileNotFoundError(workspace_missing_message(ws_path))
    workspace = load_json(ws_path)
    workspace["activeProfile"] = profile
    save_workspace_config(workspace, ws_path)


def save_legacy_per_project_active_profile(
    project_root: Path,
    config: dict[str, Any],
    profile: str,
) -> None:
    config["activeProfile"] = profile
    path = mcp_config_path(project_root)
    if not path.is_file():
        return
    path.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def env_map_for_profile(config: dict[str, Any], profile_name: str) -> dict[str, str]:
    profile_doc = (config.get("profiles") or {}).get(profile_name, {})
    profile_env = profile_doc.get("env") or {}
    tools = config.get("tools") or {}
    return augment_tool_paths(merge_env_layers(tools, profile_env))


def fixed_env_map(config: dict[str, Any]) -> dict[str, str]:
    tools = config.get("tools") or {}
    fixed_env = config.get("fixedEnv") or {}
    return augment_tool_paths(merge_env_layers(tools, fixed_env))


def resolve_fixed_servers(config: dict[str, Any]) -> list[str]:
    fixed = config.get("fixedServers")
    if fixed is not None:
        return list(fixed)
    out: list[str] = list(config.get("sharedServers") or [])
    once = config.get("onceProfiles") or {}
    for server_id in once:
        if server_id not in out:
            out.append(server_id)
    return out


def resolve_profile(config: dict[str, Any], cli_profile: str | None) -> str:
    if cli_profile:
        return cli_profile
    if config.get("activeProfile"):
        return str(config["activeProfile"])
    return config.get("defaultProfile", "dev")


def build_mcp_pool(
    config: dict[str, Any],
    registry: dict[str, Any],
    project_root: Path,
) -> dict[str, Any]:
    profiles = config.get("profiles") or {}
    fixed_ids = set(resolve_fixed_servers(config))
    defaults = registry_defaults(registry)
    registry_ids = set(registry.get("servers", {}).keys())
    fixed_env = fixed_env_map(config)

    pool: dict[str, Any] = {"fixed": {}, "profiles": {p: {} for p in profiles}}

    for server_id in resolve_fixed_servers(config):
        entry = registry.get("servers", {}).get(server_id)
        if not entry or "config" not in entry:
            continue
        cfg = resolve_value(deepcopy(entry["config"]), fixed_env, defaults)
        if isinstance(cfg, dict):
            cfg.pop("disabled", None)
            if "env" in cfg and not cfg["env"]:
                cfg.pop("env", None)
        pool["fixed"][server_id] = cfg

    for profile_name, profile_doc in sorted(profiles.items()):
        env_map = env_map_for_profile(config, profile_name)
        if "xxl-job-mcp" in (profile_doc.get("servers") or []):
            env_map = prepare_xxl_job_env(project_root, profile_name, env_map)
        for server_id in profile_doc.get("servers") or []:
            if server_id in fixed_ids:
                continue
            entry = registry.get("servers", {}).get(server_id)
            if not entry or "config" not in entry:
                continue
            cfg = resolve_value(deepcopy(entry["config"]), env_map, defaults)
            if isinstance(cfg, dict):
                cfg.pop("disabled", None)
                if "env" in cfg and not cfg["env"]:
                    cfg.pop("env", None)
            pool["profiles"][profile_name][server_id] = cfg

    pool["_meta"] = {
        "registryIds": sorted(registry_ids),
        "profileNames": sorted(profiles.keys()),
        "fixedNames": sorted(fixed_ids),
        "naming": "canonical",
    }
    return pool


def managed_mcp_keys(pool: dict[str, Any]) -> set[str]:
    meta = pool.get("_meta") or {}
    registry_ids = meta.get("registryIds")
    if registry_ids:
        return set(registry_ids)
    keys: set[str] = set()
    keys.update(pool.get("fixed", {}).keys())
    for prof_servers in (pool.get("profiles") or {}).values():
        keys.update(k for k in prof_servers if not k.startswith("_"))
    return keys


def legacy_suffixed_keys(registry: dict[str, Any], profile_names: set[str]) -> set[str]:
    keys: set[str] = set()
    for sid in registry.get("servers", {}):
        for p in profile_names:
            keys.add(f"{sid}-{p}")
    return keys


def describe_server_endpoint(
    server_id: str,
    cfg: dict[str, Any],
    registry_ids: set[str] | None = None,
) -> str | None:
    if not isinstance(cfg, dict):
        return None
    base_id = base_server_id(server_id, registry_ids or {server_id})
    url = cfg.get("url")
    if isinstance(url, str) and url and not url.startswith("{{"):
        return url
    env = cfg.get("env") or {}
    if base_id == "mysql-mcp":
        host = env.get("MYSQL_HOST")
        if not host:
            return None
        port = env.get("MYSQL_PORT", "3306")
        db = env.get("MYSQL_DB", "")
        return f"{host}:{port}/{db}" if db else f"{host}:{port}"
    if base_id == "redis-mcp":
        args = cfg.get("args") or []
        for i, arg in enumerate(args):
            if arg == "--url" and i + 1 < len(args):
                return args[i + 1]
        host = env.get("REDIS_HOST")
        if not host:
            return None
        port = env.get("REDIS_PORT", "6379")
        db = env.get("REDIS_DB", "0")
        return f"{host}:{port} db={db}"
    if base_id == "elasticsearch-mcp":
        return env.get("ES_URL") or env.get("ELASTICSEARCH_HOSTS")
    if base_id == "loki-mcp":
        return env.get("LOKI_URL")
    if base_id == "nacos-mcp-router":
        addr = env.get("NACOS_ADDR")
        ns = env.get("NACOS_NAMESPACE")
        if not addr:
            return None
        return f"{addr} ns={ns}" if ns else addr
    if base_id == "xxl-job-mcp":
        env = cfg.get("env") or {}
        admin = env.get("XXL_JOB_ADMIN_ADDRESS")
        if admin:
            return admin
        args = cfg.get("args") or []
        for i, arg in enumerate(args):
            if arg == "--config" and i + 1 < len(args):
                config_path = Path(args[i + 1])
                if config_path.is_file():
                    for line in config_path.read_text(encoding="utf-8").splitlines():
                        stripped = line.strip()
                        if stripped.startswith("admin_address:"):
                            return stripped.split(":", 1)[1].strip().strip('"')
        return None
    if base_id == "rocketmq-mcp":
        url = cfg.get("url") if isinstance(cfg.get("url"), str) else env.get("ROCKETMQ_MCP_URL")
        ns = env.get("ROCKETMQ_NS_ADDR")
        if url and ns:
            return f"{url} (NS={ns})"
        return url
    if base_id == "codegraph":
        return "stdio (local ${workspaceFolder})"
    return None


def print_endpoint_summary(
    profile: str,
    label: str,
    servers: dict[str, Any],
    previous: dict[str, Any] | None = None,
) -> None:
    display_order = [
        "loki-mcp",
        "mysql-mcp",
        "redis-mcp",
        "xxl-job-mcp",
        "nacos-mcp-router",
        "ONES",
        "codegraph",
    ]
    print("")
    print(f"--- MCP 配置地址 [{profile} / {label}] ---")
    for sid in display_order:
        if sid not in servers:
            continue
        cfg = servers[sid]
        endpoint = describe_server_endpoint(sid, cfg)
        if not endpoint:
            url = cfg.get("url") if isinstance(cfg, dict) else None
            if isinstance(url, str) and url.startswith("{{"):
                print(f"  {sid}: [!] 未解析占位符 {url} — 请检查 mcp.workspace.json")
            else:
                print(f"  {sid}: (无地址字段)")
            continue
        line = f"  {sid}: {endpoint}"
        if sid in ("codegraph", "ONES"):
            line += "  (固定)"
        if previous and sid in previous:
            old = describe_server_endpoint(sid, previous[sid])
            if old and old != endpoint:
                line += f"  ← 变更 (原: {old})"
            elif old == endpoint:
                line += "  (与切换前相同)"
        print(line)
    print("---")


def compose_mcp_for_profile(pool: dict[str, Any], profile: str) -> dict[str, Any]:
    servers: dict[str, Any] = {}
    servers.update(pool.get("fixed", {}))
    servers.update((pool.get("profiles") or {}).get(profile, {}))
    return servers


def mcp_output_path(project_root: Path, target: str) -> Path:
    if target == "user":
        return Path.home() / ".cursor" / "mcp.json"
    return project_root / ".cursor" / "mcp.json"


def apply_mcp_profile(
    project_root: Path,
    skill_root: Path,
    target: str,
    profile: str,
    dry_run: bool,
    workspace_config: Path | None = None,
) -> int:
    registry_path = skill_root / "mcp-registry.json"

    config, ws_path, project_id = load_project_config(project_root, workspace_config)
    registry = load_json(registry_path)
    known = set((config.get("profiles") or {}).keys())
    if profile not in known:
        print(f"Unknown profile '{profile}'. Known: {', '.join(sorted(known))}", file=sys.stderr)
        return 1

    pool = build_mcp_pool(config, registry, project_root)

    out_path = mcp_output_path(project_root, target)
    existing = load_json(out_path) if out_path.is_file() else {}
    existing_servers = existing.get("mcpServers") or {}
    managed = managed_mcp_keys(pool) | legacy_suffixed_keys(registry, known)
    custom = {
        k: v
        for k, v in existing_servers.items()
        if k not in managed and k not in DEPRECATED_MANAGED_KEYS
    }

    active_servers = compose_mcp_for_profile(pool, profile)
    final_servers = {**custom, **active_servers}

    previous_managed = {k: v for k, v in existing_servers.items() if k in active_servers}

    label = config["profiles"][profile].get("label", profile)
    print(f"Active profile: {profile} ({label})")
    print_endpoint_summary(profile, label, active_servers, previous_managed)

    removed = sorted(
        k for k in existing_servers if k in managed and k not in active_servers
    )
    removed.extend(sorted(k for k in existing_servers if k in DEPRECATED_MANAGED_KEYS))
    if removed:
        print("Removed legacy/extra:", ", ".join(removed))

    if dry_run:
        print("\n--- dry run ---")
        print(json.dumps({"mcpServers": final_servers}, indent=2, ensure_ascii=False))
        return 0

    if out_path.is_file():
        backup = out_path.with_suffix(f".json.bak.{datetime.now():%Y%m%d-%H%M%S}")
        backup.write_text(out_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup: {backup}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps({"mcpServers": final_servers}, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    save_active_profile(project_root, config, profile, workspace_config=ws_path)

    print(f"Written: {out_path} ({len(final_servers)} servers)")
    print(f"Config: {ws_path} (project={project_id}, activeProfile={profile})")
    return 0


def build_unified_config(
    project_root: Path,
    skill_root: Path,
    target: str,
    dry_run: bool,
    force: bool,
    workspace_config: Path | None = None,
) -> int:
    config = load_mcp_config(project_root, workspace_config)
    profiles = config.get("profiles") or {}
    if not profiles:
        print("No profiles in mcp.workspace.json", file=sys.stderr)
        return 1

    default_profile = resolve_profile(config, None)
    total = sum(len(doc.get("servers") or []) for doc in profiles.values())
    print(f"Profiles: {len(profiles)} ({total} server slots total)")

    return apply_mcp_profile(
        project_root,
        skill_root,
        target,
        default_profile,
        dry_run=dry_run,
        workspace_config=workspace_config,
    )


def build_config(
    project_root: Path,
    skill_root: Path,
    target: str,
    profile: str | None,
    servers: list[str] | None,
    dry_run: bool,
    force: bool,
    workspace_config: Path | None = None,
) -> int:
    registry_path = skill_root / "mcp-registry.json"

    config, ws_path, project_id = load_project_config(project_root, workspace_config)
    registry = load_json(registry_path)
    active_profile = resolve_profile(config, profile)

    if config.get("profiles") and active_profile not in config["profiles"]:
        known = ", ".join(sorted(config["profiles"].keys()))
        print(f"Unknown profile '{active_profile}'. Known: {known}", file=sys.stderr)
        return 1

    profile_doc = (config.get("profiles") or {}).get(active_profile, {})
    env_map = env_map_for_profile(config, active_profile)
    if "xxl-job-mcp" in (profile_doc.get("servers") or []):
        env_map = prepare_xxl_job_env(project_root, active_profile, env_map)
    defaults = registry_defaults(registry)
    fixed_ids = resolve_fixed_servers(config)

    profile_servers = profile_doc.get("servers") or registry.get("defaults", [])
    selected_servers = servers or (fixed_ids + [s for s in profile_servers if s not in fixed_ids])
    if not selected_servers:
        print("No servers selected.", file=sys.stderr)
        return 1

    new_servers: dict[str, Any] = {}
    for name in selected_servers:
        entry = registry.get("servers", {}).get(name)
        if not entry or "config" not in entry:
            print(f"Skip {name} (no MCP config)")
            continue
        env_use = fixed_env_map(config) if name in fixed_ids else env_map
        cfg = resolve_value(deepcopy(entry["config"]), env_use, defaults)
        if isinstance(cfg, dict) and "env" in cfg and not cfg["env"]:
            cfg.pop("env", None)
        new_servers[name] = cfg

    out_path = mcp_output_path(project_root, target)

    merged: dict[str, Any] = {"mcpServers": {}}
    if out_path.is_file() and not force:
        merged = load_json(out_path)
        if "mcpServers" not in merged:
            merged["mcpServers"] = {}

    registry_server_ids = set(registry.get("servers", {}).keys())
    merged["mcpServers"].update(new_servers)

    if profile_doc and servers is None:
        profile_only = set(profile_doc.get("servers") or [])
        keep = set(fixed_ids) | profile_only
        for stale in list(merged["mcpServers"].keys()):
            if stale in registry_server_ids and stale not in keep:
                del merged["mcpServers"][stale]
                print(f"Removed (not in profile): {stale}")
    text = json.dumps(merged, indent=2, ensure_ascii=False) + "\n"

    print(f"Profile: {active_profile} ({profile_doc.get('label', active_profile)})")
    if profile_doc.get("notes"):
        print(f"Note: {profile_doc['notes']}")
    print(f"Config: {ws_path} (project={project_id})")

    if dry_run:
        print(f"\n--- Dry run output ({out_path}) ---")
        print(text, end="")
        return 0

    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.is_file() and not force:
        backup = out_path.with_suffix(f".json.bak.{datetime.now():%Y%m%d-%H%M%S}")
        backup.write_text(out_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup: {backup}")

    out_path.write_text(text, encoding="utf-8")
    save_active_profile(project_root, config, active_profile, workspace_config=ws_path)

    print(f"Written: {out_path}")
    print(f"Enabled: {', '.join(selected_servers)}")
    print("Restart Cursor to apply MCP changes.")
    return 0


def load_projects_registry(registry_path: Path | None = None) -> dict[str, Any]:
    path = registry_path or projects_registry_path()
    if not path.is_file():
        raise FileNotFoundError(
            f"Missing {path}. Copy .cursor/skills/shared/mcp-switch/mcp.projects.example.json to ~/.cursor/mcp.projects.json and edit."
        )
    return load_json(path)


def all_prefixed_managed_keys(
    projects_doc: dict[str, Any],
    registry_ids: set[str],
) -> set[str]:
    keys: set[str] = set(SHARED_MCP_IDS) | DEPRECATED_MANAGED_KEYS
    for entry in projects_doc.get("projects") or []:
        project_id = str(entry.get("id") or "").strip()
        if not project_id:
            continue
        for sid in registry_ids:
            keys.add(prefix_server_key(project_id, sid))
        for profile_name in ("dev", "sit", "pre", "uat"):
            for sid in registry_ids:
                keys.add(f"{sid}-{profile_name}")
    return keys


def all_prefixed_managed_keys_workspace(
    workspace: dict[str, Any],
    registry_ids: set[str],
) -> set[str]:
    keys: set[str] = set(SHARED_MCP_IDS) | DEPRECATED_MANAGED_KEYS
    for project_id in (workspace.get("projects") or {}):
        for sid in registry_ids:
            keys.add(prefix_server_key(project_id, sid))
        for profile_name in ("dev", "sit", "pre", "uat"):
            for sid in registry_ids:
                keys.add(f"{sid}-{profile_name}")
    return keys


def migrate_to_workspace(
    projects_registry: Path | None = None,
    workspace_path: Path | None = None,
    force: bool = False,
) -> int:
    out_path = workspace_path or workspace_config_path()
    if out_path.is_file() and not force:
        print(f"Already exists: {out_path}. Pass --force to overwrite.", file=sys.stderr)
        return 1

    projects_doc = load_projects_registry(projects_registry)
    entries = projects_doc.get("projects") or []
    if not entries:
        print("No projects in registry.", file=sys.stderr)
        return 1

    project_configs: dict[str, dict[str, Any]] = {}
    per_project_files: list[dict[str, Any]] = []
    for entry in entries:
        project_id = str(entry.get("id") or "").strip()
        raw_path = str(entry.get("path") or "").strip()
        if not project_id or not raw_path:
            continue
        project_root = Path(raw_path).expanduser().resolve()
        if not project_root.is_dir():
            print(f"Skip missing directory: {project_root}", file=sys.stderr)
            continue
        try:
            config = load_legacy_per_project_config(project_root)
        except FileNotFoundError as exc:
            print(f"Skip {project_root}: {exc}", file=sys.stderr)
            continue
        project_configs[project_id] = config
        per_project_files.append(config)

    if not project_configs:
        print("No project configs migrated.", file=sys.stderr)
        return 1

    first = next(iter(project_configs.values()))
    active = first.get("activeProfile") or first.get("defaultProfile") or "dev"
    for cfg in project_configs.values():
        if cfg.get("activeProfile"):
            active = cfg["activeProfile"]
            break

    workspace: dict[str, Any] = {
        "activeProfile": active,
        "defaultProfile": first.get("defaultProfile", "dev"),
        "fixedServers": first.get("fixedServers", ["codegraph", "ONES"]),
        "fixedEnv": first.get("fixedEnv", {}),
        "tools": merge_tools_layers(*per_project_files),
        "projects": {},
    }

    for entry in entries:
        project_id = str(entry.get("id") or "").strip()
        if project_id not in project_configs:
            continue
        cfg = project_configs[project_id]
        workspace["projects"][project_id] = {
            "label": cfg.get("projectLabel") or entry.get("label") or project_id,
            "path": str(Path(str(entry.get("path"))).expanduser().resolve()).replace("\\", "/"),
            "profiles": cfg.get("profiles") or {},
        }

    save_workspace_config(workspace, out_path)
    print(f"Migrated {len(workspace['projects'])} projects -> {out_path}")
    return 0


def apply_all_from_workspace(
    skill_root: Path,
    target: str,
    profile: str,
    dry_run: bool,
    workspace_path: Path,
) -> int:
    if target != "user":
        print("Multi-project switch only supports --target user", file=sys.stderr)
        return 1

    workspace = load_json(workspace_path)
    projects = workspace.get("projects") or {}
    if not projects:
        print("No projects in workspace config.", file=sys.stderr)
        return 1

    registry = load_json(skill_root / "mcp-registry.json")
    registry_ids = set(registry.get("servers", {}).keys())
    all_active: dict[str, Any] = {}

    print(f"Switch all projects -> profile: {profile}")
    print(f"Workspace: {workspace_path}")
    print("")

    for project_id, entry in sorted(projects.items()):
        raw_path = str(entry.get("path") or "").strip()
        if not raw_path:
            print(f"Skip {project_id}: missing path", file=sys.stderr)
            continue
        project_root = Path(raw_path).expanduser().resolve()
        if not project_root.is_dir():
            print(f"Skip {project_id}: missing directory {project_root}", file=sys.stderr)
            continue

        config = project_config_from_workspace(workspace, project_id)
        known = set((config.get("profiles") or {}).keys())
        if profile not in known:
            print(f"Skip {project_id}: profile '{profile}' not configured", file=sys.stderr)
            continue

        pool = build_mcp_pool(config, registry, project_root)
        active = compose_mcp_for_profile(pool, profile)
        project_label = str(entry.get("label") or project_id)
        prof_label = config["profiles"][profile].get("label", profile)

        prefixed: dict[str, Any] = {}
        for sid, cfg in active.items():
            key = prefix_server_key(project_id, sid)
            if key in SHARED_MCP_IDS:
                if key not in all_active:
                    all_active[key] = cfg
                prefixed[key] = cfg
            else:
                prefixed[key] = cfg
                all_active[key] = cfg

        print(f"=== {project_label} ({project_id}) ===")
        print(f"  path: {project_root}")
        print(f"  activeProfile: {profile} ({prof_label})")
        for key in sorted(prefixed):
            endpoint = describe_server_endpoint(key, prefixed[key], registry_ids)
            shared = " (共享)" if key in SHARED_MCP_IDS else ""
            print(f"  {key}: {endpoint or '(无地址)'}{shared}")
        print("")

    if not all_active:
        print("No MCP servers generated.", file=sys.stderr)
        return 1

    if not dry_run:
        workspace["activeProfile"] = profile
        save_workspace_config(workspace, workspace_path)

    out_path = Path.home() / ".cursor" / "mcp.json"
    existing = load_json(out_path) if out_path.is_file() else {}
    existing_servers = existing.get("mcpServers") or {}
    managed = all_prefixed_managed_keys_workspace(workspace, registry_ids) | registry_ids
    custom = {k: v for k, v in existing_servers.items() if k not in managed}
    final_servers = {**custom, **all_active}

    removed = sorted(k for k in existing_servers if k in managed and k not in all_active)
    if removed:
        print("Removed stale:", ", ".join(removed))

    if dry_run:
        print("\n--- dry run ---")
        print(json.dumps({"mcpServers": final_servers}, indent=2, ensure_ascii=False))
        return 0

    if out_path.is_file():
        backup = out_path.with_suffix(f".json.bak.{datetime.now():%Y%m%d-%H%M%S}")
        backup.write_text(out_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup: {backup}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps({"mcpServers": final_servers}, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Written: {out_path} ({len(final_servers)} servers)")
    print("")
    print("--- 当前项目如何找 MCP ---")
    print("  1. 打开目标项目工作区")
    print("  2. 读 ~/.cursor/mcp.workspace.json 中对应 projectId")
    print("  3. 分环境工具名 = {projectId}-<服务>，如 broker-mysql-mcp")
    print("  4. 共享工具：ONES、codegraph（无前缀）")
    print("  5. 运行 show-project-mcp.ps1 查看完整映射")
    return 0


def apply_all_projects_profile(
    skill_root: Path,
    target: str,
    profile: str,
    dry_run: bool,
    projects_registry: Path | None = None,
    workspace_config: Path | None = None,
) -> int:
    if target != "user":
        print("Multi-project switch only supports --target user", file=sys.stderr)
        return 1

    ws_path = workspace_config or workspace_config_path()
    if ws_path.is_file():
        return apply_all_from_workspace(
            skill_root=skill_root,
            target=target,
            profile=profile,
            dry_run=dry_run,
            workspace_path=ws_path,
        )

    projects_doc = load_projects_registry(projects_registry)
    entries = projects_doc.get("projects") or []
    if not entries:
        print("No projects in mcp.projects.json", file=sys.stderr)
        return 1

    registry_path = skill_root / "mcp-registry.json"
    registry = load_json(registry_path)
    registry_ids = set(registry.get("servers", {}).keys())

    all_active: dict[str, Any] = {}
    project_roots: list[Path] = []

    print(f"Switch all projects -> profile: {profile}")
    print(f"Registry: {projects_registry_path() if not projects_registry else projects_registry}")
    print("")

    for entry in entries:
        raw_path = str(entry.get("path") or "").strip()
        if not raw_path:
            print(f"Skip entry without path: {entry}", file=sys.stderr)
            continue
        project_root = Path(raw_path).expanduser().resolve()
        if not project_root.is_dir():
            print(f"Skip missing directory: {project_root}", file=sys.stderr)
            continue

        try:
            config = load_legacy_per_project_config(project_root)
        except FileNotFoundError as exc:
            print(f"Skip {project_root}: {exc}", file=sys.stderr)
            continue

        project_id = resolve_project_id(config, project_root, entry.get("id"))
        known = set((config.get("profiles") or {}).keys())
        if profile not in known:
            print(
                f"Skip {project_id}: profile '{profile}' not in {project_root}",
                file=sys.stderr,
            )
            continue

        pool = build_mcp_pool(config, registry, project_root)
        active = compose_mcp_for_profile(pool, profile)
        project_label = str(config.get("projectLabel") or entry.get("label") or project_id)
        prof_label = config["profiles"][profile].get("label", profile)

        prefixed: dict[str, Any] = {}
        for sid, cfg in active.items():
            key = prefix_server_key(project_id, sid)
            if key in SHARED_MCP_IDS:
                if key not in all_active:
                    all_active[key] = cfg
                prefixed[key] = cfg
            else:
                prefixed[key] = cfg
                all_active[key] = cfg

        if not dry_run:
            save_legacy_per_project_active_profile(project_root, config, profile)

        project_roots.append(project_root)
        print(f"=== {project_label} ({project_id}) ===")
        print(f"  path: {project_root}")
        print(f"  activeProfile: {profile} ({prof_label})")
        for key in sorted(prefixed):
            endpoint = describe_server_endpoint(key, prefixed[key], registry_ids)
            shared = " (共享)" if key in SHARED_MCP_IDS else ""
            print(f"  {key}: {endpoint or '(无地址)'}{shared}")
        print("")

    if not all_active:
        print("No MCP servers generated.", file=sys.stderr)
        return 1

    out_path = Path.home() / ".cursor" / "mcp.json"
    existing = load_json(out_path) if out_path.is_file() else {}
    existing_servers = existing.get("mcpServers") or {}
    managed = all_prefixed_managed_keys(projects_doc, registry_ids) | registry_ids
    custom = {
        k: v
        for k, v in existing_servers.items()
        if k not in managed
    }
    final_servers = {**custom, **all_active}

    removed = sorted(k for k in existing_servers if k in managed and k not in all_active)
    if removed:
        print("Removed stale:", ", ".join(removed))

    if dry_run:
        print("\n--- dry run ---")
        print(json.dumps({"mcpServers": final_servers}, indent=2, ensure_ascii=False))
        return 0

    if out_path.is_file():
        backup = out_path.with_suffix(f".json.bak.{datetime.now():%Y%m%d-%H%M%S}")
        backup.write_text(out_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup: {backup}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps({"mcpServers": final_servers}, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Written: {out_path} ({len(final_servers)} servers)")
    print("")
    print("--- 当前项目如何找 MCP ---")
    print("  1. 打开目标项目工作区")
    print("  2. 读 ~/.cursor/mcp.workspace.json 中对应 projectId")
    print("  3. 分环境工具名 = {projectId}-<服务>，如 broker-mysql-mcp")
    print("  4. 共享工具：ONES、codegraph（无前缀）")
    print("  5. 运行 show-project-mcp.ps1 查看完整映射")
    return 0


def show_project_mcp(
    project_root: Path,
    workspace_config: Path | None = None,
) -> int:
    config, ws_path, project_id = load_project_config(project_root, workspace_config)
    config_source = f"{ws_path} (project={project_id})"

    project_label = str(config.get("projectLabel") or project_id)
    profile = resolve_profile(config, None)
    profile_doc = (config.get("profiles") or {}).get(profile, {})
    fixed_ids = resolve_fixed_servers(config)
    profile_servers = profile_doc.get("servers") or []

    mcp_json_path = Path.home() / ".cursor" / "mcp.json"
    cursor_keys = set((load_json(mcp_json_path).get("mcpServers") or {}).keys()) if mcp_json_path.is_file() else set()
    multi_mode = any(k.startswith(f"{project_id}-") for k in cursor_keys)

    print(f"projectId: {project_id}")
    print(f"projectLabel: {project_label}")
    print(f"activeProfile: {profile} ({profile_doc.get('label', profile)})")
    print(f"config: {config_source}")
    print(f"cursorMode: {'multi-project (带前缀)' if multi_mode else 'single-project (无前缀)'}")
    print("")
    print("Agent 应使用的 MCP 工具名：")

    def tool_name(sid: str) -> str:
        return prefix_server_key(project_id, sid) if multi_mode else sid

    for sid in fixed_ids:
        name = tool_name(sid)
        shared = " (共享，全项目相同)" if sid in SHARED_MCP_IDS else ""
        mark = "Y" if name in cursor_keys else "N"
        print(f"  [{mark}] {sid} -> {name}{shared}")

    for sid in profile_servers:
        if sid in fixed_ids:
            continue
        name = tool_name(sid)
        mark = "Y" if name in cursor_keys else "N"
        print(f"  [{mark}] {sid} -> {name}")

    return 0


def list_profiles(
    project_root: Path,
    workspace_config: Path | None = None,
) -> int:
    config, ws_path, project_id = load_project_config(project_root, workspace_config)
    active = config.get("activeProfile", "")
    default = config.get("defaultProfile", "dev")
    print(f"defaultProfile: {default}")
    if active:
        print(f"activeProfile: {active}")
    print(f"config: {ws_path} (project={project_id})")
    print("")
    for name, doc in sorted((config.get("profiles") or {}).items()):
        marker = " *" if name == active else ""
        servers = ", ".join(doc.get("servers", []))
        print(f"- {name}{marker}: {doc.get('label', name)}")
        print(f"  servers: {servers}")
        if doc.get("notes"):
            print(f"  notes: {doc['notes']}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Cursor MCP config with profile support")
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--skill-root", required=True)
    parser.add_argument("--target", choices=["user", "project"], default="user")
    parser.add_argument("--profile", help="dev | pre (dev 含 sit)")
    parser.add_argument("--servers", help="Comma-separated server ids")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--mode", choices=["single", "unified"], default="single",
                        help="single=one profile at a time; unified=all profiles, switch via Cursor MCP UI")
    parser.add_argument("--apply-profile", help="Switch mcp.json to one profile slice (dev|sit|pre)")
    parser.add_argument(
        "--apply-profile-all",
        help="Switch all projects in ~/.cursor/mcp.projects.json to one profile (dev|sit|pre)",
    )
    parser.add_argument(
        "--projects-registry",
        help="Override path to mcp.projects.json (default: ~/.cursor/mcp.projects.json)",
    )
    parser.add_argument(
        "--workspace-config",
        help="Override path to mcp.workspace.json (default: ~/.cursor/mcp.workspace.json)",
    )
    parser.add_argument(
        "--migrate-to-workspace",
        action="store_true",
        help="Merge per-project mcp.config.json into ~/.cursor/mcp.workspace.json",
    )
    parser.add_argument(
        "--show-project-mcp",
        action="store_true",
        help="Show MCP tool name mapping for --project-root",
    )
    parser.add_argument("--list-profiles", action="store_true")
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    skill_root = Path(args.skill_root).resolve()
    projects_registry = Path(args.projects_registry).resolve() if args.projects_registry else None
    workspace_config = Path(args.workspace_config).resolve() if args.workspace_config else None

    if args.migrate_to_workspace:
        return migrate_to_workspace(
            projects_registry=projects_registry,
            workspace_path=workspace_config,
            force=args.force,
        )

    if args.show_project_mcp:
        return show_project_mcp(project_root, workspace_config=workspace_config)

    if args.list_profiles:
        return list_profiles(project_root, workspace_config=workspace_config)

    if args.apply_profile_all:
        return apply_all_projects_profile(
            skill_root=skill_root,
            target=args.target,
            profile=args.apply_profile_all.strip().lower(),
            dry_run=args.dry_run,
            projects_registry=projects_registry,
            workspace_config=workspace_config,
        )

    if args.apply_profile:
        return apply_mcp_profile(
            project_root=project_root,
            skill_root=skill_root,
            target=args.target,
            profile=args.apply_profile.strip().lower(),
            dry_run=args.dry_run,
            workspace_config=workspace_config,
        )

    if args.mode == "unified":
        return build_unified_config(
            project_root=project_root,
            skill_root=skill_root,
            target=args.target,
            dry_run=args.dry_run,
            force=args.force,
            workspace_config=workspace_config,
        )

    servers = [s.strip() for s in args.servers.split(",") if s.strip()] if args.servers else None
    return build_config(
        project_root=project_root,
        skill_root=skill_root,
        target=args.target,
        profile=args.profile,
        servers=servers,
        dry_run=args.dry_run,
        force=args.force,
        workspace_config=workspace_config,
    )


if __name__ == "__main__":
    raise SystemExit(main())
