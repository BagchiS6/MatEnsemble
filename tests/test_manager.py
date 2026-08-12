from collections import deque
from concurrent.futures import Future
from pathlib import Path
import threading

from matensemble.chore import Chore
from matensemble.manager import FluxManager
from matensemble.model import ChoreType, Resources


def _chore(chore_id: str, deps=()):
    return Chore(
        id=chore_id,
        workdir=Path.cwd() / "tmp" / chore_id,
        command=["echo", "ok"],
        chore_type=ChoreType.EXECUTABLE,
        resources=Resources(),
        deps=deps,
    )


def test_record_failure_is_idempotent():
    manager = FluxManager.__new__(FluxManager)
    manager._failed_chores = []
    manager._record_failure("a", "x")
    manager._record_failure("a", "x")
    assert len(manager._failed_chores) == 1
    assert manager._failed_chores[0]["exception"] is None


def test_fail_dependents_marks_children():
    manager = FluxManager.__new__(FluxManager)
    manager._dependents = {"a": ["b"], "b": []}
    manager._completed_chores = []
    manager._running_chores = set()
    manager._ready = deque(["b"])
    manager._blocked = {"b"}
    manager._failed_chores = []
    manager._logger = type("L", (), {"error": staticmethod(lambda *args, **kwargs: None)})()
    manager._has_failed = FluxManager._has_failed.__get__(manager, FluxManager)
    manager._record_failure = FluxManager._record_failure.__get__(manager, FluxManager)
    manager._fail_dependents = FluxManager._fail_dependents.__get__(manager, FluxManager)
    manager._fail_dependents("a")
    assert manager._has_failed("b")


def test_manager_polls_flux_resources_once_at_start(monkeypatch, tmp_path: Path):
    calls = 0

    class _Resources:
        class free:
            ranks = [1, 2]
            ncores = 8
            ngpus = 2

    class _ResourceList:
        def get(self):
            return _Resources()

    def resource_list(_handle):
        nonlocal calls
        calls += 1
        return _ResourceList()

    monkeypatch.setattr("flux.resource.list.resource_list", resource_list)

    manager = FluxManager(
        chore_list=[_chore("a")],
        base_dir=tmp_path / "workflow",
    )

    assert calls == 1
    assert manager._total_cores == manager._free_cores == 8
    assert manager._total_gpus == manager._free_gpus == 2
    assert manager._fluxlet.num_nodes == 2
    assert manager._fluxlet.gpus_per_node == 1


def test_submit_until_resources_fills_capacity_without_delay(monkeypatch):
    chores = [_chore(f"chore-{index}") for index in range(3)]
    manager = FluxManager.__new__(FluxManager)
    manager._chores_by_id = {chore.id: chore for chore in chores}
    manager._ready = deque(chore.id for chore in chores)
    manager._blocked = set()
    manager._running_chores = set()
    manager._futures = set()
    manager._free_cores = manager._total_cores = 2
    manager._free_gpus = manager._total_gpus = 0
    manager._cores_per_node = 2
    manager._gpus_per_node = 0
    manager._state_lock = threading.RLock()
    manager._executor = object()
    manager._set_cpu_affinity = True
    manager._set_gpu_affinity = False

    class _Fluxlet:
        @staticmethod
        def submit(*_args, **_kwargs):
            return Future()

    manager._fluxlet = _Fluxlet()
    monkeypatch.setattr(
        "matensemble.manager.time.sleep",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("submission must not sleep")
        ),
    )

    submitted = manager._submit_until_ooresources(buffer_time=1.0)

    assert submitted is True
    assert len(manager._running_chores) == 2
    assert len(manager._futures) == 2
    assert list(manager._ready) == ["chore-2"]
    assert manager._free_cores == 0
