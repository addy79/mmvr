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
