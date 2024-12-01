### A Pluto.jl notebook ###
# v0.19.45

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 83e308f4-4f1f-11ef-3e91-efea12c96130
# ╠═╡ show_logs = false
begin
	using Pkg
	Pkg.activate("./")
	using PlutoUI
	using CSV
	using DataFrames
	using Printf
	using Plots
	using PointProcessTools
	import Statistics: quantile
end

# ╔═╡ 1bfb9d78-6838-49c9-97d0-8a7abc9a76ac
md"""
# Frequency analysis

## Upload data

The event record must be in a csv file. The first column must contain the ages and must have a name in the first row (the name itself does not matter).\
Excel has the option to save any table in csv format.\
Upload the csv file with the event record: $(@bind record_file FilePicker())
"""

# ╔═╡ aa7c539e-adac-4a02-9754-fd5971e96202
md"""
The proxy must contain two columns with names in the first row (again, the names do no matter). The first column contains ages of proxy measurements and the second column the proxy value corresponding to this age.\
If there also proxy data, provide it here: $(@bind proxy_file FilePicker())
"""

# ╔═╡ d6d903d0-f3af-4c39-b0b3-4eaf93af312b
if record_file !== nothing
	record_data = UInt8.(record_file["data"]) |> IOBuffer |> CSV.File |> DataFrame
	record = Record(record_data)
	if proxy_file !== nothing
		proxy_data = UInt8.(proxy_file["data"]) |> IOBuffer |> CSV.File |> DataFrame
		proxy = Proxy(proxy_data, normalize=false)
	else
		proxy = nothing
	end
else
	record = nothing
	proxy = nothing
end;

# ╔═╡ cea9d230-ab74-428a-bf4d-7b83a9ca663f
if record !== nothing
md"""
If you want to select only part of the record or provide an end age different than the last event in the record. provide the desired interval below.\
By default, the process will end in the present (time = 0) and start at the time of the oldest event in the record.

Select when the event record ends (in time before present) $(@bind s confirm(TextField(default=string(record.start))))\
Select when the event record starts (in time before present) $(@bind f confirm(TextField(default=string(record.finish))))
"""
end

# ╔═╡ 0a243162-d9a1-4b11-987c-98558d77232a
if record !== nothing
	start = parse(Float64, s);
	finish = parse(Float64, f);
		rec = Record(record, start, finish);
	if proxy !== nothing
		pr = Proxy(proxy, start, finish);
		pr_raw = Proxy(proxy, start, finish, normalize=false);
	else
		pr = nothing;
	end
else
	rec = nothing
	pr = nothing
end;

# ╔═╡ f4ed3b06-43ea-4847-929e-c39d71546bc3
if rec !== nothing 
	md"""
	If you want to customize the plot, check this box. $(@bind customize CheckBox(default=false))\
	These changes will apply to the last plot as well.
	"""
end

# ╔═╡ 63952833-fc68-48a6-ad97-606848ad0221
if rec !== nothing && customize
	md"""
	Invert the x-axis? (past represented by negative values) $(@bind rev CheckBox(default=false))\
	Choose the time unit of the plot:\
	$(@bind t_unit confirm(TextField(default="kyr")))\
	Do you want the values of the x axis to be divided by some number? (to match the time unit above?)\
	$(@bind divide confirm(TextField(default="1000")))\
	Choose the spacing between the x ticks (same unit of time as in the csv file):\
	$(@bind spacing confirm(TextField(default="100000")))\
	Choose a transformation for the event record:\
	$(@bind smooth_method Select(["None" => "None", "gaussian" => "Gaussian", "movmean" => "Moving Average"]))\
	Choose a time window for the smoothing method above (if different than "None"):\
	$(@bind smooth_window confirm(TextField(default="3000")))
	"""
end

# ╔═╡ ea654a2c-aaaf-459d-8211-9101b9ddc13e
if rec !== nothing
	if !customize
		if pr !== nothing
			plot(rec, pr_raw, rev=false, right_margin=3Plots.mm, top_margin=3Plots.mm)
		else
			plot(rec, rev=false, right_margin=3Plots.mm, top_margin=3Plots.mm)
		end
	else
		if pr != nothing
			plot(rec, pr_raw, rev=rev, time_unit=t_unit, spacing=parse(Float64, spacing), divide=parse(Float64, divide), smoothing=(smooth_method, parse(Float64, smooth_window)), right_margin=3Plots.mm, top_margin=3Plots.mm)
		else
			plot(rec, rev=rev, time_unit=t_unit, spacing=parse(Float64,spacing), divide=parse(Float64,divide), smoothing=(smooth_method, parse(Float64,smooth_window)), right_margin=3Plots.mm, top_margin=3Plots.mm)
		end
	end
end

# ╔═╡ 8b233636-9358-499a-8591-7153163d4dd3
if rec !== nothing 
md"""
## Frequency analysis settings

There are several choices on how to run the frequency analysis.

Choose the range of periodicities to be returned:\
$(@bind comp1 TextField(default=(@sprintf "%.0f" (span(rec) / n_events(rec)))))
$(@bind comp2 TextField(default=(@sprintf "%.0f" (span(rec)))))

If you want to compare the frequencies present in the data with frequencies from simulated data, choose a model for the simulations.\
For the inhomoegeneous Poisson and inhomogeneous Hawkes process, a proxy must have been uploaded.\
$(@bind model Select(["none" => "None", 
					  "hp" => "Homogeneous Poisson",
					  "ip" => "Inhomogeneous Poisson",
					  "hh" => "Homogeneous Hawkes",
					  "ih" => "Inhomogeneous Hawkes"]))
"""
end

# ╔═╡ 9c2479ba-21fb-4a0d-868d-802993474a21
if (record !== nothing) && (model != "none")
	md"""
	You can select the nuber of simulations to be performed.\
	$(@bind n_sims NumberField(1:1e6, default=1000))
		
	The maximum value over all simulations is plotted by default. You can choose additional percentiles to be calculated.\
	$(@bind percs MultiCheckBox([0.99 => "99%", 0.95 => "95%", 0.9 => "90%", 0.75 => "75%", 0.5 => "Mean"]))
	"""
end

# ╔═╡ a1053855-c4b6-4104-b68d-9a0c18bcd4f6
if (record !== nothing)
	ps = periodicities(rec, (parse(Float64, comp1), parse(Float64, comp2)))
	if model != "none"
		sm = simulate_periodicities(model, rec, proxy, (parse(Float64, comp1), parse(Float64, comp2)), n_sims=Int(n_sims))
	else
		sm = Matrix{Float64}(undef, 0, 0)
	end
end;

# ╔═╡ 834dd4a5-72d6-49a9-9132-8e336c65cdaa
if rec !== nothing
	md"## Results"
end

# ╔═╡ f2ae4ff7-e5ec-4b03-bafb-e7a634f9298a
if record !== nothing
	if model != "none"
		periodogram(ps, sm; quantiles=percs)
	else
		periodogram(ps)
	end
end

# ╔═╡ 98b9ae59-dfc2-4bf0-bd2c-e200d5ae57c2
if record !== nothing
	if model != "none"
		_labels = string.(percs) .* " quantile"
		_maxs   = maximum.(eachcol(sm))
		_quants = [quantile.(eachcol(sm), perc) for perc in percs]
		results = DataFrame([ps.Period ps.Power _maxs _quants...], ["Period", "Power", "Maximum", _labels...])
	else
		results = ps[:, ["Period", "Power"]]
	end
end;

# ╔═╡ 997f72e3-1c41-4449-9652-49957c06f5c0
if record !== nothing
	md"""
	Here are the 10 largest components. You can also download the whole table as a csv file.
	$(DownloadButton(sprint(CSV.write, results), "results.csv"))
	"""
end

# ╔═╡ d5ae129a-dd89-44e1-b36b-bfd3e468030e
if record !== nothing
	sort(results, "Power", rev=true)[1:10, :]
end

# ╔═╡ Cell order:
# ╟─83e308f4-4f1f-11ef-3e91-efea12c96130
# ╟─1bfb9d78-6838-49c9-97d0-8a7abc9a76ac
# ╟─aa7c539e-adac-4a02-9754-fd5971e96202
# ╟─d6d903d0-f3af-4c39-b0b3-4eaf93af312b
# ╟─cea9d230-ab74-428a-bf4d-7b83a9ca663f
# ╟─0a243162-d9a1-4b11-987c-98558d77232a
# ╟─ea654a2c-aaaf-459d-8211-9101b9ddc13e
# ╟─f4ed3b06-43ea-4847-929e-c39d71546bc3
# ╟─63952833-fc68-48a6-ad97-606848ad0221
# ╟─8b233636-9358-499a-8591-7153163d4dd3
# ╟─9c2479ba-21fb-4a0d-868d-802993474a21
# ╟─a1053855-c4b6-4104-b68d-9a0c18bcd4f6
# ╟─834dd4a5-72d6-49a9-9132-8e336c65cdaa
# ╟─f2ae4ff7-e5ec-4b03-bafb-e7a634f9298a
# ╟─98b9ae59-dfc2-4bf0-bd2c-e200d5ae57c2
# ╟─997f72e3-1c41-4449-9652-49957c06f5c0
# ╟─d5ae129a-dd89-44e1-b36b-bfd3e468030e
