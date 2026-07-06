import os
import re
from typing import List
from .base import IValidator
from ..core.workspace import WorkspaceRepository

class TestCompletenessValidator(IValidator):
    def validate(self, repo: WorkspaceRepository, **kwargs) -> List[str]:
        errors = []
        workspace_dir = repo.workspace_dir
        
        test_files = []
        exclusions = {".git", ".agents", "skills", ".pipeline", ".tessl-plugin", "node_modules", "build", "dist"}
        for root, dirs, files in os.walk(workspace_dir):
            dirs[:] = [d for d in dirs if d not in exclusions]
            for file in files:
                if file.endswith(("_test.dart", ".test.ts", ".test.tsx", ".spec.ts", ".spec.tsx", "test_repro_cases.py")):
                    if file == "test_repro_cases.py":
                        continue
                    test_files.append(os.path.join(root, file))
                    
        if not test_files:
            return ["Test Completeness: No test files found in the workspace."]
            
        test_contents = []
        for f in test_files:
            try:
                with open(f, "r", encoding="utf-8", errors="ignore") as file:
                    test_contents.append(file.read())
            except Exception:
                pass
                
        if not test_contents:
            return []
            
        combined_content = "\n".join(test_contents)
        
        has_regex_assertion = False
        regex_patterns = [
            r'\.toMatch\b', r'\.toMatchPattern\b', r'\bRegExp\b', r'\bre\.search\b', r'\bmatches\b', r'\bexpectMatch\b'
        ]
        if any(re.search(pat, combined_content) for pat in regex_patterns):
            has_regex_assertion = True
        if not has_regex_assertion:
            errors.append("Test Completeness: Test suite lacks assertions verifying regex pattern matches for BDD spec constraints.")
            
        has_precision_assertion = False
        precision_patterns = [
            r'\.toBeCloseTo\b', r'\.toFixed\b', r'\bcloseTo\b', r'\bexpectPrecision\b'
        ]
        if any(re.search(pat, combined_content) for pat in precision_patterns):
            has_precision_assertion = True
        if not has_precision_assertion:
            errors.append("Test Completeness: Test suite lacks assertions verifying numerical precision or decimal place constraints.")
            
        has_style_assertion = False
        style_patterns = [
            r'\bgetComputedStyle\b', r'\bcomputedStyle\b', r'\bwindow\.getComputedStyle\b'
        ]
        if any(re.search(pat, combined_content) for pat in style_patterns):
            has_style_assertion = True
        if not has_style_assertion:
            errors.append("Test Completeness: Test suite lacks computed style assertions (e.g. getComputedStyle) verifying layout highlight/selection states.")
            
        has_width_assertion = False
        width_patterns = [
            r'width\b', r'240\b', r'sidebarWidth\b', r'minWidth\b'
        ]
        if any(re.search(pat, combined_content) for pat in width_patterns):
            has_width_assertion = True
        if not has_width_assertion:
            errors.append("Test Completeness: Test suite lacks layout size assertions verifying sidebar minimum width or pane dimension constraints.")
            
        has_exception_assertion = False
        exception_patterns = [
            r'\.toThrow\b', r'\bthrowsA\b', r'\bexpectThrow\b', r'\bassertRaises\b'
        ]
        if any(re.search(pat, combined_content) for pat in exception_patterns):
            has_exception_assertion = True
        if not has_exception_assertion:
            errors.append("Test Completeness: Test suite lacks assertions verifying exception/failure paths or validation errors.")
            
        return errors
