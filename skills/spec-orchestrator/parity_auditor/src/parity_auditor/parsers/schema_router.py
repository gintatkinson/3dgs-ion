import os
from typing import List, Tuple, Set, Optional, Dict
from .base import IParser
from .regex import RegexSchemaParser
from ..core.workspace import WorkspaceRepository

class SchemaRouter(IParser):
    def __init__(self, workspace_repo: WorkspaceRepository):
        self.workspace_repo = workspace_repo
        self._parsers: List[IParser] = [RegexSchemaParser(workspace_repo)]

    def register(self, parser: IParser):
        self._parsers.append(parser)

    def can_parse(self, filepath: str) -> bool:
        return any(parser.can_parse(filepath) for parser in self._parsers)

    def parse(self, filepath: str) -> Tuple[Optional[str], Dict[str, str]]:
        for parser in self._parsers:
            if parser.can_parse(filepath):
                return parser.parse(filepath)
        ext = os.path.splitext(filepath)[1].lower()
        print(f"Warning: Extensible schema parser not yet implemented for extension '{ext}' in {os.path.basename(filepath)}")
        return os.path.basename(filepath), {}

def parse_schema_file(filepath: str, repo: Optional[WorkspaceRepository] = None) -> Tuple[Optional[str], Dict[str, str]]:
    if repo is None:
        repo = WorkspaceRepository()
    router = SchemaRouter(repo)
    return router.parse(filepath)
