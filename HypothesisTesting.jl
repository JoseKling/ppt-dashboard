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

# ╔═╡ 115ff07e-4d8c-11ef-23f5-673c44c9ec93
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
end

# ╔═╡ 71fef52e-24c7-494a-bd72-b63ca5641fa2
md"""
# Goodness-of-fit test

## Upload data

The event record must be in a csv file. The first column must contain the ages and the column must have a name (the name itself does not matter) in the first row.\
Excel has the option to save any table in csv format.\
Upload the csv file with the event record: $(@bind record_file FilePicker())
"""

# ╔═╡ 7c39502c-481e-4bd8-a0e3-0303b31a55d6
md"""
The proxy must contain two columns with names in the first row (again, the names do no matter). The first column contains ages of proxy measurements and the second column the proxy value corresponding to this age.\
If there also proxy data, provide it here: $(@bind proxy_file FilePicker())
"""

# ╔═╡ 6634e02e-2447-4096-ab15-64beba8384ba
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

# ╔═╡ af67e281-1bf2-4635-9fd6-eb1006b40617
if record !== nothing
md"""
If you want to select only part of the record or provide an end age different than the last event in the record. provide the desired interval below.\
By default, the process will end in the present (time = 0) and start at the time of the oldest event in the record.

Select when the event record ends (in time before present) $(@bind s confirm(TextField(default=string(record.start))))\
Select when the event record starts (in time before present) $(@bind f confirm(TextField(default=string(record.finish))))
"""
end

# ╔═╡ 8aa45175-ab25-476d-8a55-ac622c74fd3a
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

# ╔═╡ 91e41471-1242-4886-acbb-ddec12ae955e
if record_file !== nothing
	md"""
	If you want to customize the plot, check this box. $(@bind customize CheckBox(default=false))\
	These changes will apply to the last plot as well.
	"""
end

# ╔═╡ 52d0c74b-aa34-43a9-ad3c-ae412ab5fa6e
if record_file !== nothing
	if customize
		md"""
		Invert the x-axis? (past represented by negative values) $(@bind rev CheckBox(default=false))\
		Choose the time unit of the plot:\
		$(@bind t_unit confirm(TextField(default="kyr")))\
		Do you want the values of the x axis to be divided by some number? (to match the time unit above?)\
		$(@bind divide confirm(TextField(default="1000")))\
		Choose the spacing between the x ticks:\
		$(@bind spacing confirm(TextField(default="100000")))\
		Choose a transformation for the event record:\
		$(@bind smooth_method Select(["None" => "None", "gaussian" => "Gaussian", "movmean" => "Moving Average"]))\
		Choose a time window for the smoothing method above (if different than "None"):\
		$(@bind smooth_window confirm(TextField(default="3000")))
		"""
	end
end

# ╔═╡ 044297dd-5cfd-4399-a7da-58f3a6c0fe3b
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

# ╔═╡ 7a6e46e2-951d-40b9-802e-09d35a8b1233
if record_file !== nothing
	md"""
	## Hypothesis testing settings

	Choose the model for the hypothesis testing algorithm.\
	For the inhomogeneous Poisson and inhomogeneous Hawkes options, a proxy must have been uploaded.

	$(@bind model Select([nothing => "Choose a model",
					      "hp"    => "Homogeneous Poisson",
					      "ip"    => "Inhomogeneous Poisson",
					      "hh"    => "Homogeneous Hawkes",
					      "ih"    => "Inhomogeneous Hawkes"]))
	"""
else
	model = nothing;
end

# ╔═╡ a955748b-060c-4775-816e-519926fc3412
if model !== nothing
	md"""
	Choose the distance for the hypothesis testing algorithm.

	The Laplace Transform L2 distance performs best, but the Kolmogorov-Smirnov distance
	allows visualization with the KS-plot.

	$(@bind dist Select([nothing => "Choose a distance",
					     "lp"    => "Laplace transform L2 distance",
					 	 "ks"    => "Kolmogorov-Smirnov distance"]))
	"""
else
	dist = nothing;
end

# ╔═╡ e84f3f80-8278-4ba8-aeee-a0c2f93d3ff1
if (model !== nothing) && (dist !== nothing)
	results = fit_test(model, dist, rec, pr)
	dist == "lp" && @printf "p-value: %.2f\n" results.p
	@printf "Estimated parameters:\n"
	show(results.params)
end

# ╔═╡ 2dd1c98a-c853-48d9-9fa8-0dd9cc2601ba
if dist == "ks"
	ksplot(model, rec, pr, right_margin=3Plots.mm, top_margin=3Plots.mm)
end

# ╔═╡ 2e9d6fd6-a507-48e9-a7e9-dab1642e28d7
if (model !== nothing) && (dist !== nothing)
	md"Here is the record along with the estimated intensity"
end

# ╔═╡ fd0e52bf-646c-43f9-b405-80c9ef760879
if (model !== nothing) && (dist !== nothing)
	if !customize
		p_estimate = plot(results.params, rec, proxy, right_margin=3Plots.mm, top_margin=3Plots.mm)
	else
		p_estimate = plot(results.params, rec, proxy, rev=rev, time_unit=t_unit, spacing=parse(Float64, spacing), divide=parse(Float64, divide), smoothing=(smooth_method, parse(Float64, smooth_window)), right_margin=3Plots.mm, top_margin=3Plots.mm)
	end
end

# ╔═╡ Cell order:
# ╟─115ff07e-4d8c-11ef-23f5-673c44c9ec93
# ╟─71fef52e-24c7-494a-bd72-b63ca5641fa2
# ╟─7c39502c-481e-4bd8-a0e3-0303b31a55d6
# ╟─6634e02e-2447-4096-ab15-64beba8384ba
# ╟─af67e281-1bf2-4635-9fd6-eb1006b40617
# ╟─8aa45175-ab25-476d-8a55-ac622c74fd3a
# ╟─044297dd-5cfd-4399-a7da-58f3a6c0fe3b
# ╟─91e41471-1242-4886-acbb-ddec12ae955e
# ╟─52d0c74b-aa34-43a9-ad3c-ae412ab5fa6e
# ╟─7a6e46e2-951d-40b9-802e-09d35a8b1233
# ╟─a955748b-060c-4775-816e-519926fc3412
# ╟─e84f3f80-8278-4ba8-aeee-a0c2f93d3ff1
# ╟─2dd1c98a-c853-48d9-9fa8-0dd9cc2601ba
# ╟─2e9d6fd6-a507-48e9-a7e9-dab1642e28d7
# ╟─fd0e52bf-646c-43f9-b405-80c9ef760879
