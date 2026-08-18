===================
Repository Examples
===================

MatEnsemble is designed to be intuitive so if you are already familiar with HPC and
want to get from 0 to 60 as fast as possible then take a look at the example workflows
that we have in the repository. There are explanations for anything that may be confusing.

Example directories
===================

* ``general/dependencies`` — portable, site-independent dependency-aware Python chores.
* ``general/mpi`` — portable, site-independent MPI-enabled Python chores.
* ``general/strategy`` — portable, site-independent adaptive strategy and ``ChoreSpec``.
* ``general/executable`` — portable, site-independent executable chores using ``Pipeline.exec``.
* ``general/lammps_adaptive`` — portable LAMMPS Python-module campaign with dependency-aware analysis and adaptive validation.
* ``frontier/lammps_smoke`` — Frontier LAMMPS GPU smoke workflow and CLI batch scripts.
* ``pathfinder/lammps_smoke`` — Pathfinder LAMMPS CPU smoke workflow and CLI batch scripts.
* ``perlmutter/lammps_smoke`` — Perlmutter LAMMPS GPU smoke workflow and CLI batch scripts.
* ``perlmutter/lammps_mace`` — Perlmutter LAMMPS/MACE workflow and launch pattern.
* ``perlmutter/dependency_campaign`` — dependency-aware recrystallization campaign and smoke config.

The ``general`` examples show the Python workflow shape. They are intended
to be adapted to Frontier, Perlmutter, Pathfinder, Linux containers, or another
Flux-capable runtime by pairing them with the appropriate system-specific
launch scripts, containers, scheduler flags, and dependency setup.

.. code-block:: bash

   flux start -s 2 python example_workflows/general/dependencies/workflow.py

The dev container sets ``MATENSEMBLE_FLUX_START`` to ``flux start -s 2`` for
these simulated scheduling tests. ``--test-size`` is not needed for real
single-node workflows.

MCP loading behavior

``get_examples(system)`` always returns the portable files under
``example_workflows/general`` followed by every file under the matching system
tree. This ensures an agent has the canonical MatEnsemble workflow patterns as
well as the site-specific launch and runtime details.
``get_example(system, name)`` returns every file under one example directory.
The general Linux/Flux examples are stored under ``example_workflows/general``.

Keep generated workflow outputs, model binaries, pickled artifacts, and raw
logs outside these source example directories unless they are intentionally
part of the context supplied to MCP clients.
