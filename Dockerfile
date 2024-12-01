FROM julia

WORKDIR app
COPY    * ./
RUN     julia -e 'using Pkg; Pkg.activate("./"); Pkg.instantiate()'
ENTRYPOINT julia app.jl
