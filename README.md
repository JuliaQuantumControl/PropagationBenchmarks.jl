# Benchmarks for QuantumPropagators.jl


## Prerequisites

You must have the following installed in the active user-space:

* Jupyter (https://jupyter.org/install) with the [Jupytext extension](https://python-poetry.org), with the [Python local-`.venv`](https://github.com/goerz/python-localvenv-kernel) and [Markdown](https://github.com/vatlab/markdown-kernel) kernels
* Julia, with the [`IJulia` kernel](https://github.com/JuliaLang/IJulia.jl). Make sure that the kernel is set up to automatically pick up the current project (`IJulia.installkernel("Julia", "--project=@.")`)


## Running the Benchmarks

Each set of benchmarks is a Jupyter notebook stored via Jupytext as a `.jl` file. The `master` branch of the repo does not contain the equivalent `ipynb` files. A given `.jl` file can be converted to a `.ipynb` file with the command

```
jupytext --to notebook "<name>.jl"
```

This does not automatically execute the notebook and thus create any benchmark data or any analysis plots in the notebooks. In order to create a fully evaluated notebook, run

```
JULIA_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 time jupytext --to notebook --execute "<name>.jl"
```

instead. Note the environment variables forcing the benchmark to run single-threaded. This is intentional. In the context of quantum control, multi-threading inside the propagation is usually unwanted, since parallelization comes in at the higher level of multiple optimization trajectories. Unwanted (BLAS) multithreading can oversubscribe the resources of the compute node and severely hurt performance. Also, multithreading in a benchmarking context adds a lot of variability and effectively prevents running multiple benchmarks in parallel ([batch processing](#batch-processing)).

You can execute all notebooks in this way by running

```
make ipynb
```

See `make` or `make help` for further tasks


### Manually running benchmark notebooks

To run an individual benchmark interactively, you have two options:

1. Convert the `.jl` file to `.ipynb` (`jupytext --to notebook "<name>.jl"`), open the notebook in a running Jupyter server, and execute it there by running the individual cells.

2. Open a REPL with `make devrepl`, and `include` the `.jl` file there. You could also paste code from the `.jl` file into the REPL, using a mechanism like [vim-slime](https://github.com/jpalardy/vim-slime).


### Batch processing

To get comparable benchmarks, all notebooks should be executed on a dedicated compute node. The resulting `.ipynb` can be kept in a branch of this repo. Starting from a checkout of the `master` branch:

1. Run `make distclean` to ensure a clean working directory.
2. Create a new branch to store the benchmarks, e.g., `git checkout -b 2024-11-workstation` where `workstation` would be an identifier for the compute node.
3. Run `make init`.
4. Run, e.g., `make -j8 ipynb` if the compute node has 8 cores dedicated to the benchmark. This executes up to 8 notebook files in parallel, each one running single-threaded. Make sure the compute node is not oversubscribed, i.e. there are no other tasks running on those 8 cores.

Once the benchmarks have finished, you may commit all `.ipynb` files and the `data` folder to the branch and push it. The resulting notebooks are then best viewed by [selecting the relevant branch on Github](https://github.com/JuliaQuantumControl/PropagationBenchmarks.jl/branches) and then pasting the URL for the branch (`https://github.com/JuliaQuantumControl/PropagationBenchmarks.jl/tree/<branchname>`) into https://nbviewer.org.
