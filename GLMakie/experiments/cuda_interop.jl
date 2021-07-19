using CUDA, GLMakie


scene = scatter(rand(Point2f, 10_000), show_axis=false)
screen = display(scene)

buffer = screen.renderlist[1][3][:position]
resource =
cuGraphicsGLRegisterBuffer(&resource, pbo, cudaGraphicsRegisterFlagsReadOnly)

CUDA.cuGraphicsMapResources
