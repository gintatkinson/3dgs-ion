from abc import ABC, abstractmethod
from typing import Any

class IParser(ABC):
    @abstractmethod
    def can_parse(self, filepath_or_content: str) -> bool:
        pass

    @abstractmethod
    def parse(self, filepath_or_content: str) -> Any:
        pass
