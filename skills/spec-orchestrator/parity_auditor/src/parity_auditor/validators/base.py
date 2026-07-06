from abc import ABC, abstractmethod
from typing import List
from ..core.workspace import WorkspaceRepository

class IValidator(ABC):
    @abstractmethod
    def validate(self, repo: WorkspaceRepository, **kwargs) -> List[str]:
        """
        Executes the validation check and returns a list of error strings.
        An empty list indicates success.
        """
        pass
