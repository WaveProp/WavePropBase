"""
    struct TensorLagInterp{N,Td,T}

Generic Lagrange interpolation over an `N`-dimensional tensor grid. The
implementation uses a multidimensional generalization of the barycentric
formula.

The main constructor takes an `SVector{N,Vector{Td}}` containig the `N`
one-dimensional `nodes` and an `Array{N,T}` of the function `vals` at the tensor
product grid formed by the one-dimensional `nodes`.

# Examples:
```julia
nx = 10
ny = 12
x   = [0.5+0.5cos((2k-1)*π/2nx) for k in 1:nx] # Chebyshev nodes
y   = [0.5+0.5cos((2k-1)*π/2ny) for k in 1:ny] # Chebyshev nodes
f   = (x) -> cos(x[1]*x[2])
vals = [f((x,y)) for x in x, y in y]
p   = TensorLagInterp(SVector(x,y),vals)
p((0.1,0.2)) ≈ f((0.1,0.2))
```
"""
mutable struct TensorLagInterp{N,Td,T}
    vals::Array{T,N}
    nodes1d::NTuple{N,Vector{Td}}
    weights1d::NTuple{N,Vector{Td}}
    _nodes::Array{SVector{N,Td},N}
    _weights::Array{Td,N}
    function TensorLagInterp{N,Td,T}(vals,nodes1d,weights1d) where {N,Td,T}
        _nodes   = Array{SVector{N,Td},N}(undef,ntuple(i->0,N))
        _weights = Array{Td,N}(undef,ntuple(i->0,N))
        new{N,Td,T}(vals,nodes1d,weights1d,_nodes,_weights)
    end
end

interpolation_nodes(p::TensorLagInterp)   = p.nodes1d
interpolation_nodes(p::TensorLagInterp,d::Int,i::Int)   = p.nodes1d[d][i]
function interpolation_nodes(p::TensorLagInterp{N},I::CartesianIndex{N}) where {N}
    ntuple(N) do d
        interpolation_nodes(p,d,I[d])
    end
end

weights1d(p::TensorLagInterp) = p.weights1d
vals(p::TensorLagInterp)    = p.vals

return_type(::TensorLagInterp{_,__,T}) where {_,__,T} = T

ambient_dimension(::TensorLagInterp{N}) where {N} = N

Base.eachindex(p::TensorLagInterp)        = eachindex(vals(p))
function Base.CartesianIndices(p::TensorLagInterp)
    sz = length.(p.nodes1d)
    CartesianIndices(sz)
end

# if passed the values and nodes, construct weights automatically
function TensorLagInterp(vals::Array{T,N},nodes::NTuple{N,Vector{Td}}) where {N,Td,T}
    weights = map(barycentric_lagrange_weights,nodes)
    TensorLagInterp{N,Td,T}(vals,nodes,weights)
end
TensorLagInterp(vals::Vector,nodes::Vector) = TensorLagInterp(vals,(nodes,))
TensorLagInterp(vals::Array,nodes::NTuple)  = TensorLagInterp(vals,SVector(nodes))

# special interpolation schemes may have explicit functions to compute
# interpolation nodes and weights.
function TensorLagInterp(vals::Array{T,N},rec::HyperRectangle{N},nodes_func,weights_func,sz=size(vals)) where {N,T}
    lc,hc = low_corner(rec),high_corner(rec)
    nodes = ntuple(N) do d
        a,b,n = lc[d],hc[d],sz[d]
        nodes_func[d](n,a,b)
    end
    weights = ntuple(N) do d
        n = sz[d]
        weights_func[d](n)
    end
    Td = eltype(weights[1])
    TensorLagInterp{N,Td,T}(vals,nodes,weights)
end
function TensorLagInterp(vals::Array{T,N},rec::HyperRectangle{N},nodes_func::Function,weights_func::Function,p=size(vals)) where {T,N}
    TensorLagInterp(vals,rec,ntuple(i->nodes_func,N),ntuple(i->weights_func,N),p)
end

# barycentric lagrange interpolation
function (p::TensorLagInterp{N,Td,T})(x::SVector) where {N,Td,T}
    num = zero(T)
    den = zero(Td)
    for I in CartesianIndices(p.vals)
        wi     = one(Td)
        x_m_xi = one(Td)
        for d in 1:N
            wi     *= p.weights1d[d][I[d]]
            dist = p.nodes1d[d][I[d]] - x[d]
            dist == 0  && (dist += eps(Td))
            x_m_xi *= dist
        end
        # FIXME: implicilty assumes that x is not one of the interpolation
        # nodes. Division by zero if that is the case.
        num += wi/x_m_xi*p.vals[I]
        den += wi/x_m_xi
    end
    num/den
end
(p::TensorLagInterp)(x::NTuple) = p(SVector(x))
(p::TensorLagInterp{1})(x::Number) = p((x,))

function precompute_nodes_and_weights!(p::TensorLagInterp{N,Td}) where {N,Td}
    iter    = Iterators.product(p.nodes1d...)
    nodes   = map(x->SVector(x),iter)
    iter    = Iterators.product(p.weights1d...)
    weights = map(x->prod(x),iter)
    p._nodes = nodes
    p._weights = weights
    return p
end
function (p::TensorLagInterp{N,Td,T})(x::SVector,::Val{:fast}) where {N,Td,T}
    nodes   = p._nodes
    weights = p._weights
    num = zero(T)
    den = zero(Td)
    for i in eachindex(p)
        x_m_xi = one(Td)
        for d in 1:N
            dist = x[d]-nodes[i][d]
            dist == 0  && (dist += eps(Td))
            x_m_xi *= dist
        end
        tmp = weights[i]/x_m_xi
        den += tmp
        num += tmp*p.vals[i]
    end
    num/den
end
(p::TensorLagInterp)(x::NTuple,::Val{:fast}) = p(SVector(x),Val(:fast))
(p::TensorLagInterp{1})(x::Number,::Val{:fast}) = p((x,),Val(:fast))


# multidimensional version of algorithm on page 504 of
# https://people.maths.ox.ac.uk/trefethen/barycentric.pdf
function barycentric_lagrange_weights(x::Vector)
    n = length(x) - 1
    w = similar(x)
    w[1] = 1.0
    for j in 1:n
        for k in 0:j-1
            w[k+1] = (x[k+1] - x[j+1]) * w[k+1]
        end
        w[j+1] = prod(0:j-1) do k
            x[j+1] - x[k+1]
        end
    end
    for j in 0:n
        w[j+1] = 1/w[j+1]
    end
    return w
end

# special nodes distributions and the corresponding weights

"""
    cheb1nodes(n,a,b)

Return the `n` Chebyshev points of the first kind on the interval `[a,b]`.
"""
cheb1nodes(n::NTuple{N},rec::HyperRectangle{N}) where {N} = cheb1nodes(n,rec.low_corner,rec.high_corner)
function cheb1nodes(n::NTuple{N},lc,uc) where {N}
    nodes1d = ntuple(d->cheb1nodes(n[d],lc[d],uc[d]),N)
    iter = Iterators.product(nodes1d...)
    map(x->SVector{N,Float64}(x),iter)
end
function cheb1nodes(n::Integer,a::Number,b::Number)
    xcheb::Vector{Float64} = cheb1nodes(n)
    c0 = (a+b)/2
    c1 = (b-a)/2
    return @. c0 + c1*xcheb
end
function cheb1nodes(n)
    [-cos( (2*i-1)*π / (2*n) ) for i in 1:n]
end

function cheb1weights(n::NTuple{N}) where {N}
    weights1d = ntuple(d->cheb1weights(n[d]),N)
    iter = Iterators.product(weights1d...)
    map(x->prod(x),iter)
end

function cheb1weights(i,n)
    sgn = (-1)^(i)
    val = sin((2*i-1)*π/(2*n))
    return sgn*val
end

function cheb1weights(n)
    [(-1)^(i)*sin((2*i-1)*π/(2*n)) for i in 1:n]
end

"""
    cheb2nodes(n,a,b)

Return the `n` Chebyshev points of the second kind on the interval `[a,b]`. The
nodes are nested in the following sense: `cheb2nodes(n,a,b) ==
cheb2nodes(2n-1,a,b)[1:2:end]`.
"""
cheb2nodes(n::NTuple{N},rec::HyperRectangle{N}) where {N} = cheb2nodes(n,rec.low_corner,rec.high_corner)
function cheb2nodes(n::NTuple{N},lc,uc) where {N}
    nodes1d = ntuple(d->cheb2nodes(n[d],lc[d],uc[d]),N)
    iter = Iterators.product(nodes1d...)
    map(x->SVector{N,Float64}(x),iter)
end
function cheb2nodes(n::Integer,a::Number,b::Number)
    xcheb::Vector{Float64} = cheb2nodes(n)
    c0 = (a+b)/2
    c1 = (b-a)/2
    return @. c0 + c1*xcheb
end
function cheb2nodes(n)
    [-cos((i-1)*π /(n-1)) for i in 1:n]
end

function cheb2weights(n::NTuple{N}) where {N}
    weights1d = ntuple(d->cheb2weights(n[d]),N)
    iter = Iterators.product(weights1d...)
    map(x->prod(x),iter)
end

function cheb2weights(i,n)
    sgn = (-1)^(i)
    val = i==n || i == 1 ? 0.5 : 1.0
    return sgn*val
end

function cheb2weights(n)
    [cheb2weights(i,n) for i in 1:n]
end

# function cheb3nodes(i,n)
#     cos(i*π/)
# end
