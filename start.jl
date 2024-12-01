using Pkg
Pkg.activate("./")
Pkg.instantiate()
using PlutoSliderServer
PlutoSliderServer.run_git_directory("./",
                                    SliderServer_host="0.0.0.0",
                                    SliderServer_port=8080)
