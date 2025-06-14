# Fix for ChromaDB sqlite3 version compatibility
import sys

try:
    __import__("pysqlite3")
    sys.modules["sqlite3"] = sys.modules.pop("pysqlite3")
except ImportError:
    # pysqlite3-binary not installed, continue with built-in sqlite3
    pass

from .task_team import get_task_team
from .teams.orchestrator.orchestrator_config import OrchestratorConfig
from .input_func import AsyncInputFunc, InputFuncType, InputRequestType, SyncInputFunc
from .approval_guard import (
    BaseApprovalGuard,
    MaybeRequiresApproval,
    DEFAULT_REQUIRES_APPROVAL,
)
from .guarded_action import GuardedAction, ApprovalDeniedError, TrivialGuardedAction
from .magentic_ui_config import MagenticUIConfig, ModelClientConfigs

from .version import __version__

ABOUT = "Magentic-UI - A web browsing assistant."
__all__ = [
    "get_task_team",
    "OrchestratorConfig",
    "AsyncInputFunc",
    "InputFuncType",
    "InputRequestType",
    "SyncInputFunc",
    "BaseApprovalGuard",
    "MaybeRequiresApproval",
    "DEFAULT_REQUIRES_APPROVAL",
    "GuardedAction",
    "ApprovalDeniedError",
    "TrivialGuardedAction",
    "__version__",
    "ABOUT",
    "MagenticUIConfig",
    "ModelClientConfigs",
]
