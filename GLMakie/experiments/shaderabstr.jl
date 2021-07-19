using ShaderAbstractions: Buffer, Sampler, VertexArray

# Mesh
mesh(Sphere(Point3f(0), 1f0)) |> display
mesh(Sphere(Point3f(0), 1f0), color=:red, ambient=Vec3f(0.9))

tocolor(x) = RGBf(x...)
positions = Observable(decompose(Point3f, Sphere(Point3f(0), 1f0)))
triangles = Observable(decompose(GLTriangleFace, Sphere(Point3f(0), 1f0)))
uv = Observable(GeometryBasics.decompose_uv(Sphere(Point3f(0), 1f0)))
xyz_vertex_color = Observable(tocolor.(positions[]))
texture = Observable(rand(RGBAf, 10, 10))

pos_buff = Buffer(positions)
triangles_buff = Buffer(triangles)
vert_color_buff = Buffer(xyz_vertex_color)
uv_buff = Buffer(uv)
texture_buff = Sampler(texture)
texsampler = Makie.sampler(:viridis, rand(length(positions)))

coords = VertexArray(pos_buff, triangles_buff, color=vert_color_buff)
mesh = GeometryBasics.Mesh(coords)
GeometryBasics.coordinates(mesh);

using ShaderAbstractions: data

posmeta = Buffer(meta(data(pos_buff); color = data(vert_color_buff)))

program = disp.renderlist[1][3].vertexarray.program

struct OGLContext <: ShaderAbstractions.AbstractContext end

instance = ShaderAbstractions.VertexArray(posmeta, triangles_buff)

ShaderAbstractions.type_string(OGLContext(), Vec2f)

p = ShaderAbstractions.Program(
    OGLContext(),
    read(loadshader("mesh.vert"), String),
    read(loadshader("mesh.frag"), String),
    instance;
)

println(p.vertex_source)

uniforms = Dict{Symbol, Any}(
    :texturecoordinates => Vec2f(0),
    :image => nothing
)
rshader = GLMakie.GLAbstraction.gl_convert(shader, uniforms)

vbo = GLMakie.GLAbstraction.GLVertexArray(program, posmeta, triangles_buff)

m = GeometryBasics.Mesh(posmeta, triangles_buff)
disp = display(Makie.mesh(m, show_axis=false));


mesh_normals = GeometryBasics.normals(positions, triangles)
coords = meta(positions, color=xyz_vertex_color, normals=mesh_normals)
vertexcolor_mesh = GeometryBasics.Mesh(coords, triangles)
scren = mesh(vertexcolor_mesh, show_axis=false) |> display


function getter_function(io::IO, ::Fragment, sampler::Sampler, name::Symbol)
    index_t = type_string(context, sampler.values)
    sampler_t = type_string(context, sampler.colors)

    println(io, """
    in $(value_t) fragment_$(name)_index;
    uniform $(sampler_t) $(name)_texture;

    vec4 get_$(name)(){
        return texture($(name)_texture, fragment_$(name)_index);
    }
    """)
end

function getter_function(io::IO, ::Vertex, sampler::Sampler, name::Symbol)
    index_t = type_string(context, sampler.values)
    println(io, """
    in $(index_t) $(name)_index;
    out $(index_t) fragment_$(name)_index;

    vec4 get_$(name)(){
        fragment_uv = uv;
        // color gets calculated in fragment!
        return vec4(0);
    }
    """)
end

function getter_function(io::IO, ::Fragment, ::AbstractVector{T}, name) where T
    t_str = type_string(context, T)
    println(io, """
    in $(t_str) fragment_$(name);
    $(t_str) get_$(name)(){
        return fragment_$(name);
    }
    """)
end

function getter_function(io::IO, ::Vertex, ::AbstractVector{T}, name) where T
    t_str = type_string(context, T)
    println(io, """
    in $(t_str) $(name);
    out $(t_str) fragment_$(name);

    $(t_str) get_$(name)(){
        fragment_$(name) = $(name);
        return $(name);
    }
    """)
end

texsampler = Makie.sampler(rand(RGBf, 4, 4), uv)
coords = meta(positions, color=texsampler, normals=mesh_normals)
texture_mesh = GeometryBasics.Mesh(coords, triangles)

scren = mesh(texture_mesh, show_axis=false) |> display

texsampler = Makie.sampler(:viridis, rand(length(positions)))
coords = meta(positions, color=texsampler, normals=mesh_normals)
texture_mesh = GeometryBasics.Mesh(coords, triangles)

scren = mesh(texture_mesh, show_axis=false) |> display



glsl"""

out vec2 frag_uv;
out vec3 frag_normal;
out vec3 frag_position;
out vec4 frag_color;
out vec3 frag_lightdir;

uniform mat4 projectionMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;

vec3 tovec3(vec2 v){return vec3(v, 0.0);}
vec3 tovec3(vec3 v){return v;}

vec4 tovec4(vec3 v){return vec4(v, 1.0);}
vec4 tovec4(vec4 v){return v;}

void main(){
    // get_* gets the global inputs (uniform, sampler, vertex array)
    // those functions will get inserted by the shader creation pipeline
    vec3 vertex_position = tovec3(get_position());
    frag_normal = $(normals);
    frag_uv = get_texturecoordinates();

    vec3 lightpos = vec3(20);
    vec4 position_world = modelMatrix * vec4(vertex_position, 1);
    frag_lightdir = normalize(lightpos - position_world.xyz);
    // direction to camera
    frag_position = -position_world.xyz;
    frag_uv = vec2(1.0 - frag_uv.y, frag_uv.x);
    frag_color = tovec4(get_color());
    // screen space coordinates of the vertex
    gl_Position = projectionMatrix * viewMatrix * position_world;
}
"""
