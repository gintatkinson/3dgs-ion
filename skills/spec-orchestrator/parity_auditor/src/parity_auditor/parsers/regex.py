import re
import os
from typing import Tuple, Set, Optional
from .base import IParser
from ..core.workspace import WorkspaceRepository

class RegexSchemaParser(IParser):
    def __init__(self, workspace_repo: WorkspaceRepository):
        self.workspace_repo = workspace_repo

    def can_parse(self, filepath: str) -> bool:
        ext = os.path.splitext(filepath)[1].lower()
        rules = self.workspace_repo.get_codebase_rules()
        schema_patterns = rules.validation_rules.schema_patterns
        return ext in schema_patterns

    def parse(self, filepath: str) -> Tuple[Optional[str], Set[str]]:
        ext = os.path.splitext(filepath)[1].lower()
        rules = self.workspace_repo.get_codebase_rules()
        schema_patterns = rules.validation_rules.schema_patterns
        config = schema_patterns.get(ext)
        if not config:
            return None, set()

        with open(filepath, "r", encoding="utf-8") as f:
            raw_content = f.read()

        name_regex = config.get("name_regex")
        module_match = re.search(name_regex, raw_content) if name_regex else None
        if not module_match:
            module_name = os.path.splitext(os.path.basename(filepath))[0]
        else:
            module_name = module_match.group(1)

        # Clean comments and strings
        pattern = r'(/\*.*?\*/)|(//[^\n]*)|("(?:\\.|[^"\\])*")|(\'(?:\\.|[^\'\\])*\')'
        def replacer(match):
            if match.group(1): return " "
            if match.group(2): return "\n"
            return ""
        content = re.sub(pattern, replacer, raw_content, flags=re.DOTALL)

        patterns = config.get("patterns", [])
        schema_exclude_keywords = set(rules.validation_rules.schema_exclude_keywords)

        definitions = {}
        for pattern in patterns:
            kw_match = re.search(r'\\b([a-zA-Z0-9_\-]+)\\s+', pattern)
            def_type = kw_match.group(1) if kw_match else "unknown"
            for match in re.finditer(pattern, content):
                name = match.group(1)
                if name not in schema_exclude_keywords:
                    definitions[name] = def_type

        return module_name, definitions
