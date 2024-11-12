# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.16.4
#   kernelspec:
#     display_name: Julia 1.11.1
#     language: julia
#     name: julia-1.11
# ---

# # Benchmarks for `ExpProp` on dense matrices (in-place)

using QuantumPropagators: ExpProp

import QuantumPropagators
import CSV
import DataFrames
using Plots
using QuantumControl: run_or_load

import PropagationBenchmarks
using PropagationBenchmarks: run_benchmarks, params, Vary
using PropagationBenchmarks: generate_exact_solution
using PropagationBenchmarks: calibrate_cheby
using PropagationBenchmarks: generate_trial_data, generate_timing_data
using PropagationBenchmarks: BenchmarkSeries
using PropagationBenchmarks:
    Units, plot_prec_runtimes, plot_size_runtime, plot_runtime, plot_scaling, plot_overhead

using AppleAccelerate #  no-op on non-Apple
PropagationBenchmarks.info()

# +
projectdir(path...) = joinpath(@__DIR__, path...)
datadir(path...) = projectdir("data", "A02_01_ExpProp_InPlace_Dense", path...)
mkpath(datadir())

SYSTEMS_CACHE = Dict();
EXACT_SOLUTIONS_CACHE = Dict();
CALIBRATION_CACHE = Dict();

QuantumPropagators.disable_timings();
# -

FORCE = (get(ENV, "FORCE", "0") in ["true", "1"])

# ## Runtime over System Size

SYSTEM_PARAMETERS = params(
    # see arguments of `random_dynamic_generator`
    N = Vary(5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100),
    spectral_envelope = 1.0,
    exact_spectral_envelope = true,
    number_of_controls = 1,
    density = 1,
    hermitian = true,
    dt = 1.0,
    nt = 1001,
);

BENCHMARK_PARAMETERS = params(method = ExpProp, inplace = true);

size_trial_data = run_or_load(datadir("benchmark_size_trials.jld2"); force = FORCE) do
    run_benchmarks(;
        system_parameters = SYSTEM_PARAMETERS,
        benchmark_parameters = BENCHMARK_PARAMETERS,
        generate_benchmark = generate_trial_data,
        systems_cache = SYSTEMS_CACHE,
    )
end;

# +
QuantumPropagators.enable_timings();

size_timing_data = run_or_load(datadir("benchmark_size_timing.jld2"); force = FORCE) do
    run_benchmarks(;
        system_parameters = SYSTEM_PARAMETERS,
        benchmark_parameters = BENCHMARK_PARAMETERS,
        generate_benchmark = generate_timing_data,
        systems_cache = SYSTEMS_CACHE,
    )
end;

QuantumPropagators.disable_timings();
# -

size_runtime_data = merge(size_trial_data, size_timing_data)

plot_size_runtime(
    size_runtime_data;
    csv = datadir("expprop_inplace_dense_runtime_size_{key}.csv")
) do row
    return :high
end


# ## Scaling with Spectral Envelope

# For larger system sizes, the runtime of the propagation should be dominated by matrix-vector products. The number of matrix_vector products should depend only on the desired precision and the spectral envelope of the system (for `dt=1.0`; or alternatively, on `dt` if the spectral envelope is kept constant). We analyze here how the number of matrix-vector products scales with the spectral envelope for the default "high" precision (machine precision), and for lower precision (roughly half machine precision).
#
# This scaling should be mostly independent of the size or the encoding of the system.

scaling_data = run_or_load(datadir("benchmark_scaling.jld2"); force = FORCE) do
    run_benchmarks(;
        system_parameters = params(
            N = 10,
            spectral_envelope = Vary(0.5, 1.0, 5.0, 10.0, 15.0, 20.0, 25.0),
            exact_spectral_envelope = true,
            number_of_controls = 1,
            density = 1,
            hermitian = true,
            dt = 1.0,
            nt = 1001,
        ),
        benchmark_parameters = params(method = ExpProp, inplace = true,),
        generate_benchmark = generate_trial_data,
        systems_cache = SYSTEMS_CACHE,
    )
end;

scaling_data


plot_runtime(
    scaling_data;
    x = :spectral_envelope,
    xlabel = "spectral envelope",
    plot_title = "Scaling for ExpProp",
    unit = :ms,
    csv = datadir("expprop_scaling_{key}.csv")
) do row
    return :spectral_envelope
end
