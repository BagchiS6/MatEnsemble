===============
Getting Started
===============

Here we walk you through how to start a flux session and begin running workflows interactively
with MatEnsemble. We assume that you have already installed MatEnsemble on whatever system you
are planning to run on (if not you can refer to :doc:`installation`).

.. contents:: Contents
   :depth 1

Starting Flux
=============

Flux is a resource manager much like slurm, but is entirely in user space. Flux gives users the
ability to have fine grained control over their allocation, allowing them to run jobs on individual
CPU cores, GPUs and entire nodes hierarchically.

.. contents:: Systems
   :local:
   :depth: 1

Locally
-------

If you have flux installed locally then you can start flux with:

.. code-block:: bash

   flux start

This will launch an interactive flux session and give you a shell into the environment.
You can see what resources flux is seeing with:

.. code-block:: bash

   flux resource list

Which will print a message showing the number of nodes, cores and gpus that flux sees.
If you have downloaded the general linux container image for MatEnsemble then you will
first need to spin up a container from the image. Depending on what container engine
you are running the command will differ slightly (refer to :doc:`installation` for more
details). Here is how to start a container with docker.

.. code-block:: bash

   docker run --rm -it ghcr.io/q-cad/matensemble:linux-vX.Y.Z /bin/bash

This will give you a shell into a single use docker container where you can then run:

.. code-block:: bash

   flux start

To put begin a flux session.

Frontier
--------

On the OLCF Frontier system you will need a conainer setup in order to run flux. The system
provided module is outdated and does not have the most recent features of flux that MatEnsemble
makes use of. Follow our :doc:`installation` instructions for Frontier to get a container
ready on Frontier.

Once you have a SIF file ready you can start flux on either a login node or under a SLURM allocation
on a compute node

Login Node
~~~~~~~~~~

Go to the directory where your SIF file is located and run the command:

.. code-block:: bash

   apptainer exec <name>.sif flux start

This will give you a shell into the flux session. You can verify with:

.. code-block:: bash

   flux resource list

Which will print out the resources that flux is seeing.

Compute Node
~~~~~~~~~~~~

In order to start flux on a compute node you can run the following command:

.. code-block:: bash

   srun \
    -N $SLURM_NNODES \
    -n $SLURM_NNODES \
    --external-launcher \
    --gpu-bind=closest \
    --mpi=pmi2 \
    apptainer exec <name>.sif flux start

This will give you an interactive shell into the flux session which can see the entire SLURM
allocation. You can verify by running:

.. code-block:: bash

   flux resource list

Pathfinder
----------

Pathfinder is virtually identical to Frontier. You can start a flux session on a login node
for some quick testing or on a compute node.

Login
~~~~~

Go to the directory where your SIF file is located and run the command:

.. code-block:: bash

   apptainer exec <name>.sif flux start

This will give you a shell into the flux session. You can verify with:

.. code-block:: bash

   flux resource list

Which will print out the resources that flux is seeing.

Compute
~~~~~~~

In order to start flux on a compute node you can run the following command:

.. code-block:: bash

   srun \
    -N $SLURM_NNODES \
    -n $SLURM_NNODES \
    --external-launcher \
    --mpi=pmi2 \
    apptainer exec <name>.sif flux start

This will give you an interactive shell to the flux session which can see all of your
resources. You can verify with.

.. code-block:: bash

   flux resource list

Perlmutter
----------

Currently it is not recommended to start an interactive flux session on Perlmutter, it is very unstable
and note very user friendly. Instead the recommended approach is to use the MatEnsemble CLI tool. If you
are really curious then you can take a look at the `cli script <https://github.com/FredDude2004/MatEnsemble/blob/main/src/cli/matensemble-perlmutter>_`
for Perlmutter.

Running MatEnsemble
===================

After you are in a flux session you can now run a MatEnsemble script. Here we will go over the
general shape of MatEnsemble workflows and common patterns.

Pipeline
--------

The main user facing APIs of MatEnsemble are accesed through the Pipeline object. The pipline object
is used to define work for the manager to schedule, add strategies and launch dynamic and adaptive
workflows.

.. code-block:: python

   from matensemble.pipeline import Pipeline

   pipe = Pipeline(
            basedir=None,
            registry=None,
            reserve_broker_node=None,
            controller_cores=None,
          )

Accepting the defaults is the recommended use of MatEnsemble but some of the arguments are worth
noting depending on your use case. If you are on a single node machine (i.e. your local computer)
then the reserve_broker_node should be set to False. MatEnsemble defaults to reserving an entire
node to run the manager. If you are only on one node this wouldn't leave any resources for the
actual jobs to run. Instead you can have the manager run on a specified number of CPU cores.

Chores
------

Chores are simply a unit of work that the manager will schedule and monitor throughout the workflow.
These will be the 'jobs' or 'tasks' that the user will create through the
:obj:`matensemble.pipeline.Pipeline` to then be submitted to the
:obj:`matensemble.manager.FluxManager`. There are two seperate types of chores,
:obj:`matensemble.model.ChoreType.EXECUTABLE` and :obj:`matensemble.model.ChoreType.PYTHON`.

Executable
~~~~~~~~~~

Executable chores are the simpler of the two. Which is a command that will be shell command which
gets scheduled and run with flux. The chore will receive its own output directory with a stdout and
stderr file to record any outputs. These folders will be found under the
`matensemble_workflow-YYYYMMDD-HHMMSS/out/` directory with the chores ID as the name of the output
directory.

You can create executable chores with the :meth:`matensemble.pipeline.Pipeline.exec()` factory
method of the Python object.

.. code-block:: python

   from matensemble.pipeline import Pipeline

   pipe = Pipeline()

   for _ in range(10):
       pipe.exec(command=["echo", "Hello, World!"], num_tasks=10)

   pipe.submit()

This workflow script will initiate a Pipeline object named 'pipe' and then create 10 EXECUTABLE
chores which will echo "Hello, World!" to the stdout. Each chore will have 10 MPI tasks all doing
the same thing. It then submits this workflow with `pipe.submit()`. You can also specify how many
resources should be used for each executable chore by passing in cores_per_task and gpus_per_task as
parameters to the method. These will all be used as arguements to the underlying Chore objects
constructor.

There are many other options with the :meth:`matensemble.pipeline.Pipeline.exec()` method which can
be found at :doc:`reference`

Python
~~~~~~

PYTHON chores are more complicated but are much more interesting. A `ChoreType.PYTHON` can be
thought of as a delayed function call to a user defined function. Creating a python chore can be
done by using the factory decorator method :meth:`matensemble.pipeline.Pipeline.chore()`. This
decorator function will record information about the resources for the Chore object and it will
record the callable object in the pipelines `registry`. After submission the
:obj:`matensemble.manager.FluxManager` will take all recorded callables in the `registry` and will
serialize them by value on disk.

.. code-block:: python

   from matensemble.pipeline import Pipeline
   from mpi4py import MPI

   pipe = Pipeline()

   @pipe.chore(num_tasks=10, cores_per_task=1, gpus_per_task=0, mpi=true)
   def mpi_hello_world():
       size = mpi.comm_world.get_size()
       rank = mpi.comm_world.get_rank()
       name = mpi.get_processor_name()

       print(f"hello world! i am process {rank} of {size} on {name}.")

   for _ in range(10):
       mpi_hello_world()

   pipe.submit(log_delay=1)

This workflow defines a function named `mpi_hello_world` which will print its size rank and name to
stdout. Using the chore decorator MatEnsemble will then record the metadata about the chore and
record the callable object in the `registry` list.

After creating the chore we can then create chore objects by simply calling the underlying function
as we have defined it. When you call the function MatEnsemble will then record the arguments that
are sent and will create a :obj:`matensemble.chore.Chore` object which will later be sent to the
manager to be scheduled. This workflow uses a loop to call the function 10 times, creating 10
seperate chore objects that will all call the `mpi_hello_world` function.

Then it calls `pipe.submit()` which will set off the manager to serialize all registered functions,
by value, to disk. It will then send the chore list to the manager containing the ten instances of
delayed calls to the serialized `mpi_hello_world` funciton.

Much like the executable chores the python chores will also recieve their own directory with a
stdout, a stderr and some metadata about the chore for debugging purposes.

Dependencies
------------

Another capability that PYTHON chores enables is automatic dependency management. You can pass the
results of one PYTHON chore to another seamlessly.

.. code-block:: python

    from matensemble.pipeline import Pipeline

    pipe = Pipeline()

    # Define a chore that calculates the factorial of a given integer and another
    @pipe.chore()
    def factorial(n: int) -> int:
        product = 1
        for i in range(2, n):
            product *= i
        return product

    # Define a chore that calculates the sum of the digits in a given integer.
    @pipe.chore()
    def digit_sum(n) -> int:
        sum = 0
        for char in str(n):
            sum += int(char)
        return sum

    # We then use these two chores together to calculate the sum of the digits in 100!
    fact = factorial(100)
    sum = digit_sum(fact)

    pipe.submit(log_delay=1)

    # Print out the results of the workflow
    print(pipe.results())

This workflow defines two chore functions `factorial` and `digit_sum`. We then create two chore
objects by calling the chore functions. MatEnsemble will ensure that the chore objects get scheduled
in the correct order and it will internally pass the objects to the dependencies allowing you to
chain chores together to create complex workflows.

Under the hood MatEnsemble will first represent the user defined chores as a Directed Graph. After
submit is called, MatEnsemble will topologically sort the graph to ensure that there are no cycles
and that dependent chores do not get scheduled in the wrong order. MatEnsemble does not allow for
cycles in the graph, which should not be possible to define with how the API is designed. However,
if you are a magician then it will throw a clean error.

Strategy
--------

MatEnsemble uses the Strategy pattern to facilitate the processing of chores. There are two built in
strategies that are shipped with MatEnsemble, but the user can also define their own. In order to do
so we have an API that allows users to define a function that will be used to determine next steps
at runtime.

.. code-block:: python

    import random

    from matensemble.chore import ChoreSpec
    from matensemble.model import Resources
    from matensemble.pipeline import Pipeline

    pipe = Pipeline()

    LOW, HIGH = 1, 100
    ANSWER = random.randint(LOW, HIGH)

    @pipe.chore()
    def guess(lower: int, upper: int, attempt: int = 1) -> dict:
        """Guess the midpoint of the current range."""
        return {
            "guess": (lower + upper) // 2,
            "low": lower,
            "high": upper,
            "attempt": attempt,
        }

    @pipe.strategy(bolo_list=["guess"])
    def higher_or_lower(result):
        """Narrow the range and schedule the next guess."""
        current = result["guess"]

        if current == ANSWER:
            print(f"Got {ANSWER} in {result['attempt']} guesses!")
            return None

        low, high = result["low"], result["high"]

        if current < ANSWER:
            low = current + 1
        else:
            high = current - 1

        return ChoreSpec(
            args=(low, high, result["attempt"] + 1),
            kwargs={},
            resources=Resources(),
            qualname="guess",
        )

    guess(LOW, HIGH)
    print(pipe.submit(log_delay=1).result())

Here we simulate playing a number guessing game, where the computer is thinking of a number between
1-100. The guess chore will pick a number between a range that it is given. The
:meth:`~matensemble.pipeline.Pipeline.strategy()` method is a decorator which will register the
function to the internal registry, but it is not a factory like the chore method. Instead the
strategy will be given to the manager, and injected into the processing code.

Any chore names that you add to the BOLO list will tell the manager to spawn a new Chore with your
strategy function. What makes this strategy function unique from other chores is that it can
optionally return a :obj:`~matensemble.chore.ChoreSpec`. This `ChoreSpec` object will then be used
by the manager to dynamically update the workflow graph and add new chores to the manager at runtime!

This way you do not have to define the entire workflow before runtime, the workflow graph can
dynamically expand at runtime. So in this example the graph will start off with one chore, a delayed
call to the `guess` function. Once the chore completes the manager will begin to process that
completion and see that it is on the BOLO list. It will pull it aside, as the wanted criminal that
it is, and then spawn a new chore which will be a call to the `higher_or_lower` funciton and it will
pass the results of the `guess` chore to it as an argument. The strategy will do its logic and will
then return a ChoreSpec, which the manager will see and add that back to the managers workflow
graph. Which will repeat the cycle.

Running on Perlmutter
=====================

Here is a walkthrough on how to run MatEnsemble on Perlmutter using the MatEnsemble CLI tool.
In order to have MatEnsemble run properly on Perlmutter there has to be a lot of extra directories
and libraries bound into the container at runtime which is impractical for users to enter by hand.
For guides on how to create workflow files and how to run MatEnsemble read the above documentation.

To install the MatEnsemble CLI tool you can run our installation script.

.. code-block:: bash

   curl -fsSL https://raw.githubusercontent.com/Q-CAD/MatEnsemble/main/src/cli/install.sh | bash

This will place an executable script at `/usr/bin/matensemble`.

Next you need to pull the MatEnsemble container image for Perlmutter:

.. code-block:: bash

   podman-hpc pull ghcr.io/q-cad/matensemble:perlmutter-vX.Y.Z

In order to run MatEnsemble on Perlmutter you need to be on a GPU node. The image has drivers that
get bound into the image that will fail if no NVIDIA GPU is detected. You can get an allocation with

.. code-block:: bash

   salloc \
    -A <project-name> \
    -C gpu \
    --qos=debug \
    -t HH:MM:SS \
    -N <num-nodes> \
    --ntasks-per-node=1 \
    --gpus-per-node=4 \
    --gpu-bind=closest

Once you have an allocation you will then need to set the container image with:

.. code-block:: bash

   matensemble set-image ghcr.io/q-cad/matensemble:perlmutter-vX.Y.Z

With everything in place you can now navigate to wherever you have a MatEnsemble workflow script and
run it with:

.. code-block:: bash

   matensemble run <script-name>.py
