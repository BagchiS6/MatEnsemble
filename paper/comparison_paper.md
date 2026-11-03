## 1 Intro

- Growth of large-scale computational science and ensemble workloads
- Increasing use of simulation, AI/ML, optimization, and uncertainty quantification within the same
  workflow
- Limitations of traditional static workflow execution

### Need for:
- heterogeneous resource management
- asynchronous execution
- adaptive workflow generation / keeping task pool saturated
- online streaming

### Introduce MatEnsemble
- MatEnsemble combines workflow construction, Flux-backed resource-aware execution, adaptive
  workflow management, and user-defined strategy injection
- An adaptive and highly asynchronous ensemble simulation workflow manager with in-memory dynamics
  (GPU) and on-the-fly analysis (CPU) capabilties.

### Main contributions:
- Python API for building workflows
- adaptive execution within an HPC allocation
- strategy injection for runtime decision-making
- Thompson Sampling case study demonstrating adaptive execution

## 2 Motivation

- Characteristics of modern ensemble workflows
- Large numbers of related simulations
- Different tasks requiring different resources
  - CPUs
  - GPUs
  - MPI ranks
  - multiple nodes
- Variation in individual task runtimes
- Problems caused by synchronized batch execution
- Need to avoid repeatedly submitting individual jobs to the system scheduler

### Requirements for MatEnsemble:
- heterogeneous resource support
- high task throughput within a single allocation
- asynchronous execution
- runtime workflow adaptation
- application-specific scheduling and decision strategies
- simple Python programming interface

## 3 MatEnsemble API Design | Expressing Workflows and Resources Together

- Overview of MatEnsemble programming model
- Pipeline
  - workflow construction
  - ownership of chores
  - workflow submission
- Chore
  - basic unit of work
  - Python functions and executables
- Resource declarations
  - number of tasks
  - cores
  - GPUs
  - MPI requirements
- OutputReference
  - dependency representation
  - passing task outputs to downstream tasks
- Automatic DAG construction
- Relationship between:
  - dependency information
  - resource information
  - task execution
- Example workflow
  - simulation
  - analysis
  - ML/inference
  - decision step

## 4 Adaptive Workflow Management — Keeping Resources Productive

- What is adaptive execution in MatEnsemble?
- Difference between:
  - synchronous batch/wave execution
  - asynchronous adaptive execution
- Completion-driven scheduling
- Avoiding synchronization barriers
- Handling variable task durations
- Reduction of idle resources caused by stragglers

## 5 Strategy Injection — Separating Scientific Policy from Scheduling Mechanism

- Motivation for user-defined strategies
- UserDefinedStrategy
- Monitoring completed futures/tasks
- Inspecting intermediate scientific results
- Making decisions based on those results
- Creation of new ChoreSpecs
- Injecting new tasks into a running workflow
- Separation of:
  - scheduling mechanism
  - scientific decision policy

### Benefits of strategy injection
- Workflow growth during execution
- Newly generated tasks entering the active workflow
- application-specific behavior without modifying MatEnsemble internals
- reusable scheduling infrastructure
- replaceable optimization or sampling strategies ### Example Strategy
- code example ### Potential Uses
- Thompson Sampling
- Bayesian optimization
- uncertainty-driven sampling
- stopping/convergence criteria
- dynamic fidelity selection
- parameter-space exploration

## 6 Comparison with Existing Workflow Systems

**6.1 Parsl — General-Purpose Dataflow vs. Resource-Coupled Ensemble Management**
- Overview of Parsl
- Strengths:
  - Python dataflow model
  - concurrency
  - portability
  - multiple executor backends
  - large-scale HPC execution
- Parsl resource/executor abstraction
- Optional Flux integration ### MatEnsemble distinction:
  - tighter relationship between task resources and workflow orchestration
  - Flux is central to execution model
  - resource availability participates directly in scheduling
  - strategy processing integrated with task completion

**6.2 Jobflow — Workflow Definition vs. Integrated HPC Orchestration**
- Overview of Jobflow
- Strengths:
  - clean Python workflow API
  - jobs and flows
  - output references
  - dynamic workflow construction
  - strong materials-science ecosystem
- Separation between workflow definition and remote execution
- Execution through external systems/backends
- Persistent storage/database considerations for remote workflows
- MatEnsemble distinction:
  - direct awareness of in-allocation resources
  - resource state affects orchestration decisions
  - tighter Flux integration
  - adaptive execution performed within MatEnsemble runtime
- Similarities between Jobflow and MatEnsemble API philosophy

**6.3 libEnsemble — Adaptive Ensemble Management with a Different Programming Model**
- Overview of libEnsemble
  - adaptive ensembles
  - CPU/GPU resource assignment
  - heterogeneous tasks
  - MPI execution
  - customizable scheduling
  - leadership-scale systems
- Comparison with MatEnsemble:
  - libEnsemble:
    - generator
    - simulator
    - allocator
    - workers
  - MatEnsemble:
    - pipeline
    - DAG
    - chores
    - futures
    - strategies

**6.4 RADICAL-Pilot — Pilot Runtime vs. Scientific Workflow Abstraction**
- Overview of RADICAL-Pilot
  - large-scale HPC execution
  - heterogeneous tasks
  - leadership-class systems
  - runtime resource management
- MatEnsemble distinction:
  - higher-level dependency-aware workflow model
  - direct scientific workflow construction
  - user-defined adaptive strategies
  - Flux-backed execution underneath workflow logic

## 7 Thompson Sampling Case Study — Demonstrating Adaptive Strategy Injection
- showcase an thompson sampling experiment with some other workflow managers
- [Thompson Sampling](https://youtu.be/Zgwfw3bzSmQ?si=Lyto2cyce82G63x5)
- [Multi armed bandit problem](https://youtu.be/e3L4VocZnnQ?si=6u8bMEW1FcODIO_8)


## What MatEnsemble Provides
- Benefits of Flux-backed resource management
- Resource efficiency from asynchronous scheduling
- Scientific efficiency from adaptive strategies
- Examples here...

 ## Limitations and Future Work
- Current MatEnsemble API maturity
- Checkpoint/restart capabilities
- Persistence/state management
- Flux availability/deployment requirements
- Strategy overhead for extremely short tasks
- Scaling limits to investigate
- Future scheduling strategies
- Multi-fidelity optimization
- Additional resource types/topology awareness

## Conclusion — Resource-Aware, Adaptive Scientific Ensembles
- Restate target problem:
  - dynamic heterogeneous scientific ensembles
- MatEnsemble's three central capabilities:
  - resource-aware workflow API
  - adaptive asynchronous execution
  - user-defined strategy injection
- Flux provides scalable resource execution
- MatEnsemble provides workflow and scientific decision logic
- Thompson Sampling demonstrates runtime adaptation
- Final message:
  - MatEnsemble enables scientific workflows whose execution plan can evolve in response to both
    resource availability and scientific results
