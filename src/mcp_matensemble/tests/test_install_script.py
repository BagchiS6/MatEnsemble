from __future__ import annotations

import subprocess
from pathlib import Path


def test_root_install_script_has_valid_bash_syntax():
    root = Path(__file__).resolve().parents[3]

    completed = subprocess.run(
        ["bash", "-n", str(root / "install.sh")],
        check=False,
        capture_output=True,
        text=True,
    )

    assert completed.returncode == 0, completed.stderr


def test_container_engine_detection_priority(tmp_path: Path):
    root = Path(__file__).resolve().parents[3]
    for name in ("podman-hpc", "podman", "docker", "apptainer"):
        executable = tmp_path / name
        executable.write_text("#!/bin/sh\nexit 0\n")
        executable.chmod(0o755)

    completed = subprocess.run(
        [
            "bash",
            "-c",
            'source "$1"; PATH="$2" detect_container_engine',
            "bash",
            str(root / "install.sh"),
            str(tmp_path),
        ],
        check=False,
        capture_output=True,
        text=True,
    )

    assert completed.returncode == 0, completed.stderr
    assert completed.stdout.strip() == "apptainer"
