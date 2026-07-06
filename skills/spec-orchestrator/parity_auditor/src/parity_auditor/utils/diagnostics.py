import os
import sys
import json
import subprocess
from datetime import datetime

def get_git_info(workspace_dir):
    try:
        remote_url = subprocess.check_output(["git", "config", "--get", "remote.origin.url"], cwd=workspace_dir, text=True).strip()
        commit_hash = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=workspace_dir, text=True).strip()
        return remote_url, commit_hash
    except Exception:
        return "", ""

def serialize_diagnostics(workspace_dir, tool_name, exit_code, errors, traceback_str, target_file=None, snippet_content=None):
    os.makedirs(os.path.join(workspace_dir, ".pipeline", "diagnostics"), exist_ok=True)
    remote_url, commit_hash = get_git_info(workspace_dir)
    timestamp = datetime.utcnow().isoformat() + "Z"
    
    payload = {
        "timestamp": timestamp,
        "tooling": {
            "name": tool_name,
            "version": "1.0.0"
        },
        "context": {
            "command": " ".join(sys.argv),
            "exit_code": exit_code,
            "downstream_repo": remote_url,
            "commit_hash": commit_hash
        },
        "failure": {
            "traceback": traceback_str or "",
            "error_summary": errors or []
        },
        "reproduction_case": {
            "target_file": target_file or "",
            "snippet_type": "markdown" if target_file and target_file.endswith(".md") else "text",
            "snippet_content": snippet_content or ""
        }
    }
    
    safe_ts = timestamp.replace(":", "-").replace(".", "-")
    filename = f"repro_payload_{safe_ts}.json"
    filepath = os.path.join(workspace_dir, ".pipeline", "diagnostics", filename)
    
    try:
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2)
        print(f"\n[Diagnostics] Saved reproduction payload to: {filepath}")
    except Exception as e:
        print(f"Warning: Failed to write diagnostic payload: {e}", file=sys.stderr)
