using CairoMakie

# https://github.com/JuliaLang/julia-logo-graphics
const RED = "#CB3C33"
const GREEN = "#389826"
const PURPLE = "#9558B2"
# Other colours used for logo
const GREY = "#555562"
const CARDBG = "#FAFAFA"
const CARDBORDER = "#E4E4E7"

# Build a rounded rectangle.
#    x = left edge
#    y = bottom edge
#    w = width
#    h = height
#    r = corner radius
function roundedrect(x, y, w, h, r)
    r = min(r, w / 2, h / 2)
    arc(cx, cy, θ0, θ1) =
        [Point2f(cx + r * cos(t), cy + r * sin(t)) for t in range(θ0, θ1; length = 16)]
    pts = Point2f[]
    append!(pts, arc(x + r, y + r, 1.0π, 1.5π))  # bottom-left
    append!(pts, arc(x + w - r, y + r, 1.5π, 2.0π))  # bottom-right
    append!(pts, arc(x + w - r, y + h - r, 0.0, 0.5π))  # top-right
    append!(pts, arc(x + r, y + h - r, 0.5π, 1.0π))  # top-left
    return pts
end

fig = Figure(; size = (512, 512), backgroundcolor = :transparent)
ax = Axis(fig[1, 1]; aspect = DataAspect(), backgroundcolor = :transparent)
hidedecorations!(ax)
hidespines!(ax)
SIZE = 100
limits!(ax, 0, SIZE, 0, SIZE)

RADIUS = 6
DOT_X = 27
Y_SEPARATION = 18
RED_DOT_Y = (SIZE / 2) + Y_SEPARATION
GREEN_DOT_Y = (SIZE / 2)
PURPLE_DOT_Y = (SIZE / 2) - Y_SEPARATION

# Rounded background
poly!(
    ax,
    roundedrect(6, 6, 88, 88, 10);
    color = CARDBG,
    strokecolor = CARDBORDER,
    strokewidth = 1,
)

# Dashed left margin
lines!(
    ax,
    [DOT_X - RADIUS, DOT_X - RADIUS],
    [PURPLE_DOT_Y - 10, RED_DOT_Y + 10];
    color = GREY,
    linewidth = 2,
    linestyle = :dash,
)

# Trailing code lines
CODE_X = DOT_X + (2 * RADIUS)
MAX_WIDTH = SIZE - CODE_X - (DOT_X - RADIUS) # last term is the right margin
for (cy, w) in
    [(RED_DOT_Y, MAX_WIDTH), (GREEN_DOT_Y, MAX_WIDTH - 20), (PURPLE_DOT_Y, MAX_WIDTH - 10)]
    poly!(ax, roundedrect(DOT_X + (2 * RADIUS), cy - 4, w, 8, 4); color = GREY)
end

# Julia dots
for (cy, col) in [(RED_DOT_Y, RED), (GREEN_DOT_Y, GREEN), (PURPLE_DOT_Y, PURPLE)]
    poly!(ax, Circle(Point2f(DOT_X, cy), 6.0f0); color = col)
end

save("logo.svg", fig)
