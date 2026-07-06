import os
import re
from typing import List
from .base import IValidator
from ..core.workspace import WorkspaceRepository
from ..parsers.schema_router import parse_schema_file

class SchemaMappingValidator(IValidator):
    def validate(self, repo: WorkspaceRepository, **kwargs) -> List[str]:
        rules = repo.get_codebase_rules()
        backlog_dirs = rules.backlog_directories
        target_dirs = rules.target_directories
        
        schema_dir = os.path.join(repo.workspace_dir, backlog_dirs.schemas)
        
        react_dir_name = target_dirs.react
        react_dir = os.path.join(repo.workspace_dir, react_dir_name) if react_dir_name else None
        
        flutter_dir_name = target_dirs.flutter
        flutter_dir = os.path.join(repo.workspace_dir, flutter_dir_name) if flutter_dir_name else None
        
        errors = []
        
        if not os.path.exists(schema_dir):
            return []
            
        definitions = {}
        for filename in os.listdir(schema_dir):
            filepath = os.path.join(schema_dir, filename)
            if os.path.isdir(filepath):
                continue
            try:
                _, defs = parse_schema_file(filepath, repo=repo)
                if defs:
                    definitions.update(defs)
            except Exception:
                pass
                
        codebase_files = []
        ui_files = []
        
        react_rules = rules.react_rules
        react_exclusions = set(react_rules.exclusions)
        react_ui_dirs = set(react_rules.ui_directories)
        
        flutter_rules = rules.flutter_rules
        flutter_exclusions = set(flutter_rules.exclusions)
        flutter_ui_dirs = set(flutter_rules.ui_directories)
        
        def collect_files(directory, extensions, exclusions, ui_dirs):
            if not directory or not os.path.exists(directory):
                return
            for root, dirs, files in os.walk(directory):
                dirs[:] = [d for d in dirs if d not in exclusions]
                rel_path = os.path.relpath(root, directory)
                parts = rel_path.split(os.sep)
                is_ui = any(p in ui_dirs for p in parts)
                for file in files:
                    if any(file.endswith(ext) for ext in extensions):
                           filepath = os.path.join(root, file)
                           codebase_files.append((filepath, is_ui))
                           if is_ui:
                               ui_files.append(filepath)
                                 
        collect_files(react_dir, react_rules.file_extensions, react_exclusions, react_ui_dirs)
        collect_files(flutter_dir, flutter_rules.file_extensions, flutter_exclusions, flutter_ui_dirs)
        
        if not codebase_files:
            return ["Schema Mapping: Codebase is empty. No source files found for validation."]
            
        if not definitions:
            return []
            
        def strip_comments(content: str) -> str:
            content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
            content = re.sub(r'//.*', '', content)
            return content

        codebase_contents = []
        for filepath, is_ui in codebase_files:
            try:
                with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                    raw_content = f.read()
                    clean_content = strip_comments(raw_content)
                    codebase_contents.append((filepath, clean_content, is_ui))
            except Exception:
                pass
                
        for name in sorted(definitions):
            def_type = definitions[name]
            found_in_code = False
            found_in_ui = False
            
            if def_type in ("container", "list", "grouping", "typedef", "identity"):
                patterns = [
                    r'\b(class|interface|type|enum|struct|mixin|extension)\s+' + re.escape(name) + r'\b'
                ]
            elif def_type in ("rpc", "action", "notification"):
                patterns = [
                    r'\bfunction\s+' + re.escape(name) + r'\b',
                    r'\b' + re.escape(name) + r'\s*\([^)]*\)\s*(\{|=)',
                    r'\b(void|int|double|num|bool|String|[A-Z][a-zA-Z0-9_<>]*)\s+' + re.escape(name) + r'\s*\('
                ]
            else:
                patterns = [
                    r'\b(let|const|var|final|late|dynamic)\s+[^=;]*\b' + re.escape(name) + r'\b',
                    r'\b' + re.escape(name) + r'\s*\??\s*:',
                    r'\b([A-Z][a-zA-Z0-9_<>]*|String|int|double|num|bool)\s+' + re.escape(name) + r'\b',
                    r'\bthis\.' + re.escape(name) + r'\b'
                ]
            
            for filepath, content, is_ui in codebase_contents:
                match = any(re.search(pat, content) for pat in patterns)
                if match:
                    found_in_code = True
                    if is_ui:
                        found_in_ui = True
                        
            if not found_in_code:
                errors.append(f"Schema field '{name}' is missing from the codebase source files.")
            elif not found_in_ui and ui_files:
                errors.append(f"Schema field '{name}' is not bound to a UI component or display element.")
                
        return errors
