"""AST-based codebase analysis utilities for import checking and event-echo guard validation."""

import ast
import re
from typing import List

from .comment_utils import strip_c_style_comments


def ast_check_banned_imports(content: str, forbidden_words: List[str]) -> List[str]:
    """
    Check for banned imports using AST parsing.

    Attempts to parse source content with Python's ast.parse() for precise
    import detection. Falls back to regex-based line scanning for non-Python
    (JS/Dart) codebases.

    Args:
        content: Source code text.
        forbidden_words: List of package/module names to flag.

    Returns:
        List of unique forbidden words found in import statements.
    """
    try:
        tree = ast.parse(content)
        found_banned = []
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    for word in forbidden_words:
                        if word in alias.name:
                            found_banned.append(word)
            elif isinstance(node, ast.ImportFrom):
                if node.module:
                    for word in forbidden_words:
                        if word in node.module:
                            found_banned.append(word)
                for alias in node.names:
                    for word in forbidden_words:
                        if word in alias.name:
                            found_banned.append(word)
        return list(set(found_banned))
    except SyntaxError:
        pass

    found_banned = []
    lines = content.splitlines()
    for line in lines:
        line_strip = line.strip()
        is_import = False
        if line_strip.startswith(("import ", "import'", 'import"', "export ", "export'", 'export"', "part ", "part'")):
            is_import = True
        elif "require(" in line_strip:
            is_import = True
        if is_import:
            for word in forbidden_words:
                if re.search(r'\b' + re.escape(word) + r'\b', line_strip):
                    found_banned.append(word)
    return list(set(found_banned))


def ast_check_event_echo_guard(content: str, selection_setters: List[str], interaction_triggers: List[str], guard_method: str) -> bool:
    """
    Check whether code satisfies the Event-Echo Guard rule using AST.

    Flags code that contains a programmatic selection setter (e.g. a method
    that assigns a selection value) AND also emits an interaction callback
    (e.g. onChange, onSubmitted) without calling the required guard method.

    For Python code, walks the AST to find function bodies that contain both
    a selection setter assignment and a callback dispatch. For non-Python code,
    falls back to heuristic keyword scanning.

    Args:
        content: Source code text.
        selection_setters: Keywords that indicate a selection setter.
        interaction_triggers: Keywords that indicate a callback/event emission.
        guard_method: The method call that must appear when both are present
                      (e.g. "stopPropagation").

    Returns:
        True if the code violates the Event-Echo Guard (setter + callback
        found without guard). False if it is compliant.
    """
    try:
        tree = ast.parse(content)
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                has_setter = False
                has_trigger = False
                has_guard = False
                for child in ast.walk(node):
                    if isinstance(child, ast.Call):
                        func_name = None
                        if isinstance(child.func, ast.Attribute):
                            func_name = child.func.attr
                        elif isinstance(child.func, ast.Name):
                            func_name = child.func.id
                        if func_name:
                            if any(kw in func_name for kw in selection_setters):
                                has_setter = True
                            if any(kw in func_name for kw in interaction_triggers):
                                has_trigger = True
                            if func_name == guard_method:
                                has_guard = True
                    elif isinstance(child, ast.Assign):
                        for target in child.targets:
                            if isinstance(target, ast.Attribute):
                                if any(kw in target.attr for kw in selection_setters):
                                    has_setter = True
                if has_setter and has_trigger and not has_guard:
                    return True
        return False
    except SyntaxError:
        pass

    clean_content = strip_c_style_comments(content)
    if any(kw in clean_content for kw in selection_setters) and any(kw in clean_content for kw in interaction_triggers):
        if guard_method not in clean_content:
            return True
    return False
