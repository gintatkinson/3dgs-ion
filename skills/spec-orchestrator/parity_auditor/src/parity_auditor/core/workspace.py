import os
import json
import re
from typing import Dict, List, Set, Optional, Tuple, Any
from .models import CodebaseRules, FeatureFile, load_from_dict

class WorkspaceRepository:
    def __init__(self, workspace_dir: Optional[str] = None):
        if not workspace_dir:
            workspace_dir = self._find_workspace_dir(os.getcwd())
        self.workspace_dir = os.path.abspath(workspace_dir)
        self._codebase_rules: Optional[CodebaseRules] = None
        self._behavioral_triggers: Optional[List[dict]] = None
        self._feature_files: Optional[List[FeatureFile]] = None
        self._design_tokens: Optional[Dict[str, Any]] = None
        self._forbidden_colors: Optional[Set[str]] = None

    def _find_workspace_dir(self, start_path: str) -> str:
        curr = os.path.abspath(start_path)
        while True:
            if os.path.exists(os.path.join(curr, ".pipeline", "logical-ui", "codebase_rules.json")):
                return curr
            parent = os.path.dirname(curr)
            if parent == curr:
                break
            curr = parent
        return os.path.abspath(start_path)

    def get_codebase_rules_path(self) -> str:
        rules_path = os.environ.get("CODEBASE_RULES_PATH")
        if not rules_path:
            rules_path = os.path.join(self.workspace_dir, ".pipeline", "logical-ui", "codebase_rules.json")
        return rules_path

    def get_codebase_rules(self) -> CodebaseRules:
        if self._codebase_rules is not None:
            return self._codebase_rules
        
        rules_path = self.get_codebase_rules_path()
        if os.path.exists(rules_path):
            try:
                with open(rules_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self._codebase_rules = load_from_dict(data)
                    return self._codebase_rules
            except Exception as e:
                print(f"Warning: Failed to load codebase_rules.json: {e}")
        
        self._codebase_rules = CodebaseRules()
        return self._codebase_rules

    def get_behavioral_triggers(self, schema_dir: str) -> List[dict]:
        if self._behavioral_triggers is not None:
            return self._behavioral_triggers
        
        rules = self.get_codebase_rules()
        meta_trig_path = rules.meta.behavioral_triggers_path
        
        search_paths = []
        if meta_trig_path:
            search_paths.append(os.path.join(self.workspace_dir, meta_trig_path))
        search_paths.extend([
            os.path.join(schema_dir, "behavioral_triggers.json"),
            os.path.join(self.workspace_dir, "rules", "behavioral_triggers.json"),
            os.path.join(self.workspace_dir, "skills", "spec-orchestrator", "scripts", "behavioral_triggers.json")
        ])
        
        for path in search_paths:
            if os.path.exists(path):
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        self._behavioral_triggers = json.load(f)
                        return self._behavioral_triggers
                except Exception as e:
                    print(f"Warning: Failed to load behavioral triggers from {path}: {e}")
        
        self._behavioral_triggers = []
        return self._behavioral_triggers

    def get_feature_files(self, features_dir: str) -> List[FeatureFile]:
        if self._feature_files is not None:
            return self._feature_files
            
        features = []
        if not os.path.exists(features_dir):
            self._feature_files = []
            return self._feature_files

        for filename in os.listdir(features_dir):
            if not filename.endswith(".md"):
                continue
            filepath = os.path.join(features_dir, filename)
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception as e:
                print(f"Warning: Failed to read feature file {filename}: {e}")
                continue

            labels = []
            frontmatter_match = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
            if frontmatter_match:
                frontmatter_text = frontmatter_match.group(1)
                for line in frontmatter_text.splitlines():
                    if line.startswith("labels:"):
                        labels_match = re.search(r"\[(.*?)\]", line)
                        if labels_match:
                            labels = [lbl.strip().strip('"').strip("'") for lbl in labels_match.group(1).split(",")]
            
            features.append(FeatureFile(
                filename=filename,
                labels=labels,
                content=content
            ))
        self._feature_files = features
        return self._feature_files

    def get_design_tokens(self) -> Dict[str, Any]:
        if self._design_tokens is not None:
            return self._design_tokens
            
        rules = self.get_codebase_rules()
        tokens_path_rel = rules.spec_rules.design_tokens_path
        if not tokens_path_rel:
            self._design_tokens = {}
            return self._design_tokens
            
        tokens_path = os.path.join(self.workspace_dir, tokens_path_rel)
        if not os.path.exists(tokens_path):
            self._design_tokens = {}
            return self._design_tokens
            
        try:
            with open(tokens_path, "r", encoding="utf-8") as f:
                self._design_tokens = json.load(f)
                return self._design_tokens
        except Exception as e:
            print(f"Warning: Failed to load design tokens from {tokens_path}: {e}")
            self._design_tokens = {}
            return self._design_tokens

    def get_forbidden_colors(self) -> Set[str]:
        if self._forbidden_colors is not None:
            return self._forbidden_colors
            
        tokens_data = self.get_design_tokens()
        from ..utils.color_utils import extract_hex_colors_from_json
        self._forbidden_colors = extract_hex_colors_from_json(tokens_data)
        return self._forbidden_colors
