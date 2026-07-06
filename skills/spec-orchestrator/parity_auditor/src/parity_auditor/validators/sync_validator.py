import os
import re
import subprocess
import json
from typing import List
from .base import IValidator
from ..core.workspace import WorkspaceRepository

class SyncValidator(IValidator):
    def validate(self, repo: WorkspaceRepository, **kwargs) -> List[str]:
        rules = repo.get_codebase_rules()
        tracker_rules = rules.tracker_rules
        backlog_dirs = rules.backlog_directories
        
        epics_dir = os.path.join(repo.workspace_dir, backlog_dirs.epics)
        features_dir = os.path.join(repo.workspace_dir, backlog_dirs.features)
        
        errors = []
        
        # 1. Fetch registered issues from GitHub
        cmd = tracker_rules.get("commands", {}).get("list_issues") if isinstance(tracker_rules, dict) else None
        if not cmd:
            print("Warning: Missing commands.list_issues in tracker_rules.")
            return []
            
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, cwd=repo.workspace_dir)
            if res.returncode != 0:
                print(f"Warning: Failed to fetch issue backlog from remote: {res.stderr.strip()}")
                return []
            issues = json.loads(res.stdout)
        except Exception as e:
            print(f"Warning: Issue backlog offline or unavailable: {e}")
            return []
            
        # Helper to normalize titles
        def normalize_title(title):
            if not title: return ""
            title = title.strip().strip('"\'')
            regex = r'^(epic|feature|feat|user[- ]story|use[- ]case|us|uc)[s]?(?:[- ]*\d+)?\s*[:\-]?\s*'
            title = re.sub(regex, '', title, flags=re.IGNORECASE)
            title = title.replace("-", " ").replace("_", " ")
            title = re.sub(r'[^\w\s]', '', title)
            return " ".join(title.split()).lower()
            
        # Parse tracker issues
        labels_config = tracker_rules.get("labels", {}) if isinstance(tracker_rules, dict) else {}
        epic_label = labels_config.get("epic", "epic").lower()
        feature_label = labels_config.get("feature", "feature").lower()
        
        tracker_specs = {}
        tracker_indices = {}
        
        for issue in issues:
            labels = []
            for l in issue.get("labels", []):
                if isinstance(l, dict):
                    labels.append(l.get("name", "").lower())
                elif isinstance(l, str):
                    labels.append(l.lower())
                    
            is_spec = False
            spec_type = None
            if epic_label in labels:
                is_spec = True
                spec_type = "epic"
            elif feature_label in labels:
                is_spec = True
                spec_type = "feature"
                
            if not is_spec:
                continue
                
            title = issue.get("title", "")
            norm_title = normalize_title(title)
            tracker_specs[norm_title] = issue
            
            # Extract index, e.g. "Epic 2: Common Types" -> index 2
            match = re.search(r'\b(epic|feature|feat)[s]?[- ]*(\d+)', title, re.IGNORECASE)
            if match:
                idx = int(match.group(2))
                std_type = "epic" if match.group(1).lower().startswith("epic") else "feature"
                tracker_indices[(std_type, idx)] = norm_title
                
        # 2. Scan local files
        local_specs = set()
        local_indices = {}
        
        def scan_local_dir(directory, std_type):
            if not os.path.exists(directory):
                return
            for filename in os.listdir(directory):
                if not filename.endswith(".md"):
                    continue
                filepath = os.path.join(directory, filename)
                title = None
                try:
                    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                        content = f.read(2048)
                    title_match = re.search(r'^title:\s*(["\']?)(.*?)\1\s*$', content, re.MULTILINE)
                    if title_match:
                        title = title_match.group(2).strip()
                    else:
                        h1_match = re.search(r'^#\s+(.*?)$', content, re.MULTILINE)
                        if h1_match:
                            title = h1_match.group(1).strip()
                except Exception:
                    pass
                    
                if title:
                    norm_title = normalize_title(title)
                    local_specs.add(norm_title)
                    
                    match = re.search(r'\b(epic|feature|feat)[s]?[- ]*(\d+)', filename, re.IGNORECASE)
                    if not match:
                        match = re.search(r'\b(epic|feature|feat)[s]?[- ]*(\d+)', title, re.IGNORECASE)
                    if match:
                        idx = int(match.group(2))
                        local_indices[(std_type, idx)] = norm_title
                        
        scan_local_dir(epics_dir, "epic")
        scan_local_dir(features_dir, "feature")
        
        # 3. Check for missing local specs
        for norm_title, issue in tracker_specs.items():
            if norm_title not in local_specs:
                errors.append(f"Missing specification file for registered Issue #{issue['number']} - '{issue['title']}'. Please check your branch baseline.")
                
        # 4. Check for index collisions
        for (std_type, idx), norm_title in local_indices.items():
            tracker_title = tracker_indices.get((std_type, idx))
            if tracker_title and tracker_title != norm_title:
                issue_num = tracker_specs.get(tracker_title, {}).get("number", "unknown")
                errors.append(f"Index collision detected. Local specification with index {idx} ('{norm_title}') overlaps with registered Issue #{issue_num} ('{tracker_title}').")
                
        return errors
