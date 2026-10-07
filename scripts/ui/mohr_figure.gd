class_name MohrFigure
extends RefCounted
## Draws Mohr's circle in the Beer & Johnston convention: X at (sigma_x, -tau_xy) and Y at
## (sigma_y, +tau_xy), so rotating the element by theta counterclockwise turns the diameter
## by 2*theta counterclockwise. Shows the rotated points X' and Y' and the principal stresses.


static func fill(plot: PlotFigure, state: PlaneStress, theta: float) -> void:
	plot.begin("Mohr's circle", "σ (MPa)", "τ (MPa)")
	plot.equal_aspect = true
	var c: float = state.average() * Units.MPA
	var r: float = state.radius() * Units.MPA
	plot.circle(Vector2(c, 0.0), r, Color(0.6, 0.8, 1.0))
	plot.line(PackedVector2Array([Vector2(state.sigma_x, -state.tau_xy) * Units.MPA,
			Vector2(state.sigma_y, state.tau_xy) * Units.MPA]), Color(0.6, 0.6, 0.7), 1.5)
	var t: Vector3 = state.transformed(theta)
	plot.line(PackedVector2Array([Vector2(t.x, -t.z) * Units.MPA, Vector2(t.y, t.z) * Units.MPA]),
			Color(1.0, 0.8, 0.3), 2.5)
	plot.marker(Vector2(state.sigma_x, -state.tau_xy) * Units.MPA, Color(0.75, 0.75, 0.8), "X")
	plot.marker(Vector2(state.sigma_y, state.tau_xy) * Units.MPA, Color(0.75, 0.75, 0.8), "Y")
	plot.marker(Vector2(t.x, -t.z) * Units.MPA, Color(1.0, 0.8, 0.3), "X'")
	plot.marker(Vector2(t.y, t.z) * Units.MPA, Color(1.0, 0.8, 0.3), "Y'")
	plot.marker(Vector2(c + r, 0.0), Color(1.0, 0.45, 0.4), "σ₁ = %.1f" % (c + r))
	plot.marker(Vector2(c - r, 0.0), Color(0.45, 0.6, 1.0), "σ₂ = %.1f" % (c - r))
	plot.marker(Vector2(c, r), Color(0.4, 0.9, 0.9), "τmax = %.1f" % r)


## The three Mohr circles of a plane-stress state with sigma_z = 0 (a principal stress too):
## the largest circle gives the absolute maximum shear stress.
static func fill_3d(plot: PlotFigure, state: PlaneStress) -> void:
	plot.begin("Three-dimensional Mohr's circles (σ_z = 0)", "σ (MPa)", "τ (MPa)")
	plot.equal_aspect = true
	var s := PackedFloat64Array([state.principal_1() * Units.MPA, state.principal_2() * Units.MPA, 0.0])
	var colors: Array[Color] = [Color(0.6, 0.8, 1.0), Color(1.0, 0.7, 0.4), Color(0.6, 1.0, 0.6)]
	var pairs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
	for i: int in 3:
		var a: float = s[pairs[i].x]
		var b: float = s[pairs[i].y]
		plot.circle(Vector2((a + b) / 2.0, 0.0), absf(a - b) / 2.0, colors[i])
	var tau_abs: float = state.absolute_max_shear() * Units.MPA
	var hi: float = maxf(maxf(s[0], s[1]), 0.0)
	var lo: float = minf(minf(s[0], s[1]), 0.0)
	plot.marker(Vector2((hi + lo) / 2.0, tau_abs), Color(1, 1, 1), "τ_abs,max = %.1f" % tau_abs)
	plot.marker(Vector2(s[0], 0.0), Color(1.0, 0.45, 0.4), "σ_a")
	plot.marker(Vector2(s[1], 0.0), Color(0.45, 0.6, 1.0), "σ_b")
	plot.marker(Vector2.ZERO, Color(0.6, 1.0, 0.6), "σ_c = 0")
