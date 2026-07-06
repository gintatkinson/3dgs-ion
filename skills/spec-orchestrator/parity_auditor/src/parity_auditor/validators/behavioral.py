"""
Validator that checks behavioural coverage triggers per documented node.

Ensures that for every active trigger node (present in the schema) there
is at least one user-story or use-case file that satisfies the trigger's
validation rules (mermaid blocks, body terms, etc.).
"""

import os
import re
from typing import List, Dict, Any, Set
from .base import IValidator
from ..core.workspace import WorkspaceRepository
from ..utils.case_utils import normalize_case

class BehavioralValidator(IValidator):
    """Validate behavioural triggers per active node rather than globally per trigger group."""

    def validate(self, repo: WorkspaceRepository, **kwargs) -> List[str]:
        """
        Run all behavioural trigger validations against user-story and use-case files.

        Iterates over each active trigger node (nodes that exist in the schema
        modules) independently.  For every such node it collects matching
        markdown files and applies the trigger's mermaid-block, body-term, and
        secondary-term rules.  Errors are accumulated per node, ensuring one
        documented node cannot satisfy the trigger for another.

        Args:
            repo: WorkspaceRepository providing paths and rules.
            **kwargs: Must contain ``schema_dir`` (str) and ``modules`` (dict).

        Returns:
            List of human-readable error strings, empty when all checks pass.
        """
        schema_dir = kwargs.get("schema_dir")
        if not schema_dir:
            schema_dir = os.path.join(repo.workspace_dir, repo.get_codebase_rules().backlog_directories.schemas)
            
        modules = kwargs.get("modules", {})
        
        rules = repo.get_codebase_rules()
        backlog_dirs = rules.backlog_directories
        user_stories_dir = os.path.join(repo.workspace_dir, backlog_dirs.user_stories)
        use_cases_dir = os.path.join(repo.workspace_dir, backlog_dirs.use_cases)
        
        triggers = repo.get_behavioral_triggers(schema_dir)
        
        all_nodes_normalized = {normalize_case(node) for defs in modules.values() for node in defs}
        
        errors = []
        for trigger in triggers:
            trigger_nodes = trigger.get("trigger_nodes", [])
            normalized_trigger_nodes = [normalize_case(node) for node in trigger_nodes]
            active_indices = [i for i, node in enumerate(normalized_trigger_nodes) if node in all_nodes_normalized]
            if not active_indices:
                continue
                
            for rule in trigger.get("rules", []):
                target_type = rule.get("target_type")
                target_dir = user_stories_dir if target_type == "user-story" else use_cases_dir
                
                files = []
                if os.path.exists(target_dir):
                    files = [os.path.join(target_dir, f) for f in os.listdir(target_dir) if f.endswith(".md")]
                    
                for idx in active_indices:
                    trigger_node = trigger_nodes[idx]
                    escaped_node = re.escape(trigger_node).replace(r'\-', r'[\s\-_]').replace(r'\_', r'[\s\-_]')
                    
                    trigger_files = []
                    for filepath in files:
                        try:
                            with open(filepath, "r", encoding="utf-8") as f:
                                content = f.read()
                        except Exception as e:
                            print(f"Warning: Failed to read file {filepath}: {e}")
                            continue
                        if re.search(rf'\b{escaped_node}\b', content, re.IGNORECASE):
                            trigger_files.append((filepath, content))
                            
                    if not trigger_files:
                        errors.append(f"Validation failed: No {target_type} files found referencing trigger node '{trigger_node}'. {rule.get('error_message')}")
                        continue
                        
                    for filepath, content in trigger_files:
                        file_valid = True
                        mermaid_type = rule.get("requires_mermaid_block")
                        if mermaid_type:
                            mermaid_matches = re.findall(rf"```mermaid\s*\n\s*{mermaid_type}(.*?)\n```", content, re.DOTALL)
                            if not mermaid_matches:
                                file_valid = False
                            else:
                                mermaid_terms = rule.get("match_terms_in_mermaid", [])
                                if mermaid_terms:
                                    if not any(any(term in m_content for term in mermaid_terms) for m_content in mermaid_matches):
                                        file_valid = False
                                        
                        body_terms = rule.get("match_terms_in_body", [])
                        if body_terms:
                            if not any(term in content.lower() for term in body_terms):
                                file_valid = False
                                
                        body_terms_sec = rule.get("match_terms_in_body_secondary", [])
                        if body_terms_sec:
                            if not any(term in content.lower() for term in body_terms_sec):
                                file_valid = False
                                
                        if not file_valid:
                            errors.append(f"In {os.path.basename(filepath)}: {rule.get('error_message')}")
                            
        return errors
