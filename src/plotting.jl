using Plots
using CSV: write as write_csv
using Statistics: median
using DataStructures: OrderedDict


struct BenchmarkSeries{XT,YT}
    x::Vector{XT}
    y::Vector{YT}
    text::Vector{String}
    label::Union{Nothing,String}

    function BenchmarkSeries(
        collected_benchmarks,
        x,
        y;
        transform = (row -> row),
        label = nothing,
        text = nothing
    )
        x_vals = []
        y_vals = []
        text_vals = String[]
        for row in collected_benchmarks
            row = transform(copy(row))
            x_val = row[x]
            push!(x_vals, x_val)
            push!(y_vals, row[y])
            if isnothing(text)
                push!(text_vals, "")
            else
                push!(text_vals, string(row[text]))
            end
        end
        x_vals = [x_vals...]  # narrow ...
        y_vals = [y_vals...]  # ... eltype
        new{eltype(x_vals),eltype(y_vals)}(x_vals, y_vals, text_vals, label)
    end

end


function plot_prec_runtimes(
    collected_data,
    N_vals;
    csv = nothing,
    units = Dict(),
    kwargs...
)
    plot_data = Dict(
        N => Dict(
            :precision => Float64[],
            :runtime_min => Float64[],
            :runtime_max => Float64[],
            :runtime_median => Float64[],
        ) for N in N_vals
    )
    for row in collected_data
        N = row[:N]
        push!(plot_data[N][:precision], row[:precision])
        push!(plot_data[N][:runtime_min], minimum(row[:propagate].times * Units.eval(:ns)))
        push!(plot_data[N][:runtime_max], maximum(row[:propagate].times * Units.eval(:ns)))
        push!(
            plot_data[N][:runtime_median],
            median(row[:propagate].times * Units.eval(:ns))
        )
    end
    panels = []
    for N in N_vals
        unit = get(units, N, :ms)
        u = Units.eval(unit)
        x_vals = plot_data[N][:precision]
        y_median = plot_data[N][:runtime_median] / u
        y_mindist = y_median - plot_data[N][:runtime_min] / u
        y_maxdist = plot_data[N][:runtime_max] / Units.eval(unit) - y_median
        ymax = maximum(plot_data[N][:runtime_max]) / u
        panel = plot(
            x_vals,
            y_median;
            yerror = (y_mindist, y_maxdist),
            label = "N=$N",
            xlabel = (N == N_vals[end]) ? "precision" : "",
            ylabel = "runtime ($unit)",
            xscale = :log10,
            marker = true,
            xticks = plot_data[N][:precision],
            ylim = [0, ymax],
        )
        push!(panels, panel)
        if !isnothing(csv)
            @assert contains(csv, "{N}")
            csvfile = replace(csv, "{N}" => string(N))
            write_csv(
                csvfile,
                OrderedDict(
                    "precision" => x_vals,
                    "min runtime ($unit)" => plot_data[N][:runtime_min] / u,
                    "max runtime ($unit)" => plot_data[N][:runtime_max] / u,
                    "median runtime ($unit)" => y_median,
                )
            )
            @info "Written $csvfile"
        end
    end
    plot(panels...; layout = (length(panels), 1), kwargs...)
end


function plot_size_runtime(classifier, collected_data, unit = :s; csv = nothing, kwargs...)
    keys = Symbol[]
    plot_data = Dict{Symbol, Dict{Symbol,Any}}()
    for row in collected_data
        key = classifier(row)
        if isnothing(key)
            continue
        end
        if !haskey(plot_data, key)
            plot_data[key] = Dict(
                :N => Int64[],
                :runtime_min => Float64[],
                :runtime_max => Float64[],
                :runtime_median => Float64[],
            )
            push!(keys, key)
        end
        push!(plot_data[key][:N], row[:N])
        push!(
            plot_data[key][:runtime_min],
            minimum(row[:propagate].times * Units.eval(:ns))
        )
        push!(
            plot_data[key][:runtime_max],
            maximum(row[:propagate].times * Units.eval(:ns))
        )
        push!(
            plot_data[key][:runtime_median],
            median(row[:propagate].times * Units.eval(:ns))
        )
    end
    fig = plot(; xlabel = "system size", ylabel = "runtime ($unit)")
    u = Units.eval(unit)
    for key in keys
        x_vals = plot_data[key][:N]
        y_median = plot_data[key][:runtime_median] / u
        y_mindist = y_median - plot_data[key][:runtime_min] / u
        y_maxdist = plot_data[key][:runtime_max] / Units.eval(unit) - y_median
        plot!(
            fig,
            x_vals,
            y_median;
            yerror = (y_mindist, y_maxdist),
            label = "$key precision",
            marker = true,
        )
        if !isnothing(csv)
            @assert contains(csv, "{key}")
            csvfile = replace(csv, "{key}" => string(key))
            write_csv(
                csvfile,
                OrderedDict(
                    "precision" => x_vals,
                    "min runtime ($unit)" => plot_data[key][:runtime_min] / u,
                    "max runtime ($unit)" => plot_data[key][:runtime_max] / u,
                    "median runtime ($unit)" => y_median,
                )
            )
            @info "Written $csvfile"
        end
    end
    ymax = ylims(fig)[end]
    plot!(fig; ylims = [0, ymax], kwargs...)
end


function plot_scaling(classifier, scaling_data; csv = nothing, kwargs...)
    keys = Symbol[]
    plot_data = Dict{Symbol, Dict{Symbol,Any}}()
    for row in scaling_data
        key = classifier(row)
        if !haskey(plot_data, key)
            plot_data[key] = Dict(:mvp_per_timestep => Float64[], :spectral_envelope => Float64[])
            push!(keys, key)
        end
        push!(
            plot_data[classifier(row)][:mvp_per_timestep],
            row[:matrix_vector_products] / row[:timesteps]
        )
        push!(plot_data[classifier(row)][:spectral_envelope], row[:spectral_envelope])
    end
    if !isnothing(csv)
        @assert contains(csv, "{key}")
        for key in keys
            csvfile = replace(csv, "{key}" => string(key))
            write_csv(
                csvfile,
                OrderedDict(
                    "spectral envelope" => plot_data[key][:spectral_envelope],
                    "MVP per timestep" => plot_data[key][:mvp_per_timestep],
                )
            )
            @info "Written $csvfile"
        end
    end
    fig = plot(; xlabel = "spectral envelope", ylabel = "MVP per timestep")
    for key in keys
        plot!(
            fig,
            plot_data[key][:spectral_envelope],
            plot_data[key][:mvp_per_timestep],
            label = "$key precision",
            marker = true
        )
    end
    ymax = ylims(fig)[end]
    plot!(fig; ylim = (0, ymax), kwargs...)
end


function plot_overhead(overhead_data; csv = nothing, marker = true, label = "", kwargs...)
    series = BenchmarkSeries(overhead_data, :N, :percent)
    if !isnothing(csv)
        csvfile = csv
        write_csv(
            csvfile,
            OrderedDict(
                "system size" => series.x,
                "overhead (runtime percent)" => (100 .- series.y),
            )
        )
        @info "Written $csvfile"
    end
    plot(
        series.x,
        100 .- series.y;
        marker,
        xlabel = "system size",
        ylabel = "overhead (runtime percent)",
        label,
        kwargs...
    )
end
