using Pkg
Pkg.activate("./")

using Dash
using CSV
using DataFrames
using PointProcessTools
using PlotlyJS
import Base64: base64decode

app = dash()

app.layout = html_div() do
    html_h1("Hypothesis testing"),
    dcc_upload(id="history-file",
               multiple=false,
               children=html_div(["Drag and drop or ",
                                  html_a("select files")])),
    dcc_upload(id="proxy-file",
               multiple=false,
               children=html_div(["Drag and drop or ",
                                  html_a("select files")])),
    html_div(id="display", [dcc_graph(id="graph", figure=(data=[], layout=[]))], style=Dict(:display=>"none"))
end

bin2df(str::String) = base64decode(str[22:end]) |> IOBuffer |> CSV.File |> DataFrame

callback!(app,
          Output("graph", "figure"),
          Output("display", "style"),
          Input("history-file", "contents"),
          Input("history-file", "filename"),
          Input("proxy-file", "contents"),
          Input("proxy-file", "filename")) do hist_cont, hist_file, proxy_cont, proxy_file
        if hist_file !== nothing && endswith(hist_file, ".csv")
            df_hist = bin2df(hist_cont)
            rec = Record(df_hist)
            if "Age" in names(df_hist)
                if proxy_file !== nothing && endswith(proxy_file, ".csv")
                    df_proxy = bin2df(proxy_cont)
                    proxy = Proxy(df_proxy, rec.start, rec.finish, normalize=false)
                    x = LinRange(rec.start, rec.finish, 1000)
                    proxy_trace = scatter(x=x, y=proxy(x), name="Proxy")
                    rec_trace = scatter(x=rec.events, y=fill(minimum(proxy), n_events(rec)),
                                        mode="markers", marker_symbol=142, marker_size=10, name="Events")
                    fig = Plot([rec_trace, proxy_trace])
                    # fig = PlotlyJS.plot(rows=2, cols=1, shared_xaxes=true)
                    # PlotlyJS.add_trace!(fig, proxy_trace, row=1, col=1)
                    # PlotlyJS.add_trace!(fig, rec_trace, row=2, col=1)
                    return fig, Dict(:display=>"block")
                else
                    fig = Plot(scatter(x=rec.events, y=zeros(n_events(rec)),
                                       mode="markers", marker_symbol=142, marker_size=10))
                    return fig, Dict(:display=>"block")
                end
            else
                @warn "No 'Age' column in csv file"
            end
        end
        return (data=[], layout=[]), Dict(:display=>"none")
    end

run_server(app, "0.0.0.0", 8080)


