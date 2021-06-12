module WavePropBase

using LinearAlgebra
using StaticArrays
using RecipesBase

include("utils.jl")
include("interface.jl")
include("referenceshapes.jl")
include("hyperrectangle.jl")
include("entities.jl")
include("domain.jl")
include("lagrangeinterp.jl")
include("element.jl")
include("abstractmesh.jl")
include("cartesianmesh.jl")
include("genericmesh.jl")
include("submesh.jl")
include("plotrecipes.jl")

export
    # macros
    @interface,
    # Abstract types
    AbstractMesh,
    AbstractEntity,
    AbstractElement,
    ReferenceShape,
    # Concrete types
    HyperRectangle,
    ReferenceLine,
    ReferenceTriangle,
    ReferenceSquare,
    ReferenceTetrahedron,
    Domain,
    CartesianMesh,
    GenericMesh,
    SubMesh,
    ElementIterator,
    NodeIterator,
    ElementaryEntity,
    LagrangeElement,
    LagrangeLine,
    LagrangeTriangle,
    LagrangeTetrahedron,
    LagrangeRectangle,
    LagrangeInterp,
    # Type aliases
    Point1D,
    Point2D,
    Point3D,
    # Global consts
    ENTITIES,
    # methods
    ambient_dimension,
    geometric_dimension,
    domain,
    jacobian,
    normal,
    entities,
    external_boundary,
    internal_boundary,
    boundary,
    tag,
    skeleton,
    clear_entities!,
    radius,
    diameter,
    center,
    low_corner,
    high_corner,
    bounding_box,
    new_tag,
    global_add_entity!,
    mesh,
    grids,
    assert_concrete_type,
    svector
end
