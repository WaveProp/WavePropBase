"""
    struct GenericMesh{N,T} <: AbstractMesh{N,T}

Data structure representing a generic mesh in an ambient space of dimension `N`, with data of type `T`.
"""
Base.@kwdef struct GenericMesh{N,T} <: AbstractMesh{N,T}
    nodes::Vector{SVector{N,T}} = Vector{SVector{N,T}}()
    # for each element type (key), store the data required to reconstruct the
    # elements (value).
    elements::Dict{DataType,Any} = Dict{DataType,Any}()
    # mapping from entity to (etype,tags)
    ent2tags::Dict{AbstractEntity,Dict{DataType,Vector{Int}}} = Dict{AbstractEntity,Dict{DataType,Vector{Int}}}()
end

nodes(m::GenericMesh)    = m.nodes
elements(m::GenericMesh) = m.elements
ent2tags(m::GenericMesh) = m.ent2tags

Base.keys(m::GenericMesh) = keys(elements(m))
entities(m::GenericMesh) = keys(ent2tags(m))

"""
    dom2elt(m::GenericMesh,Ω,E)

Compute the element indices `idxs` of the elements of type `E` composing `Ω`, so that `m[E][idxs]` gives all
the elements of type `E` meshing `Ω`.
"""
function dom2elt(m::GenericMesh, Ω, E::DataType)
    idxs = Int[]
    for ent in entities(Ω)
        tags = get(m.ent2tags[ent], E, Int[])
        append!(idxs, tags)
    end
    return idxs
end

"""
    dom2elt(m::GenericMesh,Ω)

Return a `Dict` with keys being the element types of `m`, and values being the
indices of the elements in `Ω` of that type.
"""
function dom2elt(m::GenericMesh, Ω)
    dict = Dict{DataType,Vector{Int}}()
    for E in keys(m)
        tags = dom2elt(m, Ω, E)
        if !isempty(tags)
            dict[E] = tags
        end
    end
    return dict
end

# UTILITIES

# convert a mesh to 2d by ignoring third component. Note that this also requires
# converting various element types to their 2d counterpart.
function convert_to_2d(mesh::GenericMesh{3})
    @assert all(x -> geometric_dimension(x) < 3, keys(mesh))
    T = eltype(mesh)
    # create new dictionaries for elements and ent2tags with 2d elements as keys
    elements  = empty(mesh.elements)
    ent2tags  = empty(mesh.ent2tags)
    for (E, tags) in mesh.elements
        E2d = convert_to_2d(E)
        elements[E2d] = tags
    end
    for (ent, dict) in mesh.ent2tags
        new_dict = empty(dict)
        for (E, tags) in dict
            E2d = convert_to_2d(E)
            new_dict[E2d] = tags
        end
        ent2tags[ent] = new_dict
    end
    # construct new 2d mesh
    GenericMesh{2,T}(;
        nodes=[x[1:2] for x in nodes(mesh)],
        etypes=convert_to_2d.(keys(mesh)),
        elements=elements,
        ent2tags=ent2tags
    )
end

function convert_to_2d(::Type{LagrangeElement{R,N,SVector{3,T}}}) where {R,N,T}
    LagrangeElement{R,N,SVector{2,T}}
end
convert_to_2d(::Type{SVector{3,T}}) where {T} = SVector{2,T}
