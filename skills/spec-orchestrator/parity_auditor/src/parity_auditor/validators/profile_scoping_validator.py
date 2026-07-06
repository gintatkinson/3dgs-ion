import os
import re
from typing import List
from .base import IValidator
from ..core.workspace import WorkspaceRepository

class ProfileScopingValidator(IValidator):
    def validate(self, repo: WorkspaceRepository, **kwargs) -> List[str]:
        rules = repo.get_codebase_rules()
        target_dirs = rules.target_directories
        
        react_dir_name = target_dirs.react
        react_dir = os.path.join(repo.workspace_dir, react_dir_name) if react_dir_name else None
        
        flutter_dir_name = target_dirs.flutter
        flutter_dir = os.path.join(repo.workspace_dir, flutter_dir_name) if flutter_dir_name else None
        
        errors = []
        
        def find_files(directory, extensions, exclusions):
            if not directory or not os.path.exists(directory):
                return []
            matched = []
            for root, dirs, files in os.walk(directory):
                dirs[:] = [d for d in dirs if d not in exclusions]
                for file in files:
                    if any(file.endswith(ext) for ext in extensions):
                        matched.append(os.path.join(root, file))
            return matched
            
        react_rules = rules.react_rules
        react_files = find_files(react_dir, react_rules.file_extensions, set(react_rules.exclusions))
        
        flutter_rules = rules.flutter_rules
        flutter_files = find_files(flutter_dir, flutter_rules.file_extensions, set(flutter_rules.exclusions))
        
        if not react_files and not flutter_files:
            return ["Profile Compliance: Codebase is empty. No source files found for profile validation."]
            
        if react_files:
            css_files = [f for f in react_files if f.endswith((".css", ".scss"))]
            tsx_files = [f for f in react_files if f.endswith((".tsx", ".jsx"))]
            
            css_contents = []
            for f in css_files:
                try:
                    with open(f, "r", encoding="utf-8", errors="ignore") as file:
                        css_contents.append((f, file.read()))
                except Exception:
                    pass
                    
            tsx_contents = []
            for f in tsx_files:
                try:
                    with open(f, "r", encoding="utf-8", errors="ignore") as file:
                        tsx_contents.append((f, file.read()))
                except Exception:
                    pass
                    
            if css_contents:
                has_box_sizing = False
                for filepath, content in css_contents:
                    if re.search(r'box-sizing\s*:\s*border-box', content):
                        has_box_sizing = True
                        break
                if not has_box_sizing:
                    errors.append("Profile Compliance: Global box-sizing reset ('box-sizing: border-box') is not declared in CSS/SCSS files.")
                    
            if css_contents:
                has_root_layout = False
                for filepath, content in css_contents:
                    if "#root" in content and "100vh" in content and "100vw" in content and "flex" in content:
                        has_root_layout = True
                        break
                if not has_root_layout:
                    errors.append("Profile Compliance: Viewport-constrained '#root' layout styles (100vh, 100vw, display: flex, overflow: hidden) are not declared in CSS files.")
                    
            if css_contents:
                has_containment = False
                for filepath, content in css_contents:
                    if "contain\s*:\s*layout\s+paint" in content or "contain\s*:\s*paint\s+layout" in content or re.search(r'contain\s*:\s*[^;]*layout', content):
                        if "container-type" in content:
                            has_containment = True
                            break
                if not has_containment:
                    for filepath, content in tsx_contents:
                        if "contain" in content and "containerType" in content:
                            has_containment = True
                            break
                has_splitter = any("splitter" in f.lower() or "Splitter" in c for f, c in tsx_contents)
                if has_splitter and not has_containment:
                    errors.append("Profile Compliance: CSS containment ('contain: layout paint' and 'container-type: inline-size') is missing on resizable splitter containers.")
                    
            for filepath, content in tsx_contents:
                if "splitter" in filepath.lower() or "Splitter" in content:
                    if "onPointerDown" not in content and "onMouseDown" not in content:
                        errors.append(f"Profile Compliance: Splitter component in '{os.path.basename(filepath)}' is missing pointer event state bindings (onPointerDown).")

        if flutter_files:
            dart_contents = []
            for f in flutter_files:
                try:
                    with open(f, "r", encoding="utf-8", errors="ignore") as file:
                        dart_contents.append((f, file.read()))
                except Exception:
                    pass
                    
            for filepath, content in dart_contents:
                if "splitter" in filepath.lower() or "Splitter" in content:
                    if "Listener" not in content and "GestureDetector" not in content:
                        errors.append(f"Profile Compliance: Flutter Splitter widget in '{os.path.basename(filepath)}' is missing pointer gesture event listeners (Listener or GestureDetector).")
                        
        return errors
