class_name PlaneStressFem
extends RefCounted
## A small finite element solver (lab 3): a thin plate in plane stress, meshed with
## rectangular 4-node elements (Q4) of h_x by h_y on a structured grid; cells outside the
## shape are left out.
## Solves K*u = F with a banded Cholesky factorization, then recovers stresses and strains.
## Grid node (i, j) sits at x = i*h_x, y = j*h_y; node k = i*(ny + 1) + j owns dofs 2k (u_x) and
## 2k + 1 (u_y). SI units.
##
## Element stiffness: K_e = integral of B^T*D*B*t dA. The normal part is integrated with 2x2
## Gauss points and the shear part with one point (selective reduced integration), which keeps
## the element from locking in bending without spurious zero-energy modes.

var length: float          ## plate size along x [m]
var height: float          ## plate size along y [m]
var element_size: float    ## h_x [m]
var element_height: float  ## h_y [m]
var thickness: float = 1.0e-3  ## t [m]
var youngs_modulus: float = 200.0e9
var poisson_ratio: float = 0.3

var nx: int = 0            ## elements along x
var ny: int = 0            ## elements along y
var active: PackedByteArray = PackedByteArray()  ## 1 per cell (i*ny + j) inside the shape
var displacements: PackedFloat64Array = PackedFloat64Array()
## Per element (center point): sigma_x, sigma_y, tau_xy [Pa] and eps_x, eps_y, gamma_xy.
var element_stress: PackedVector3Array = PackedVector3Array()
var element_strain: PackedVector3Array = PackedVector3Array()

var _prescribed: Dictionary[int, float] = {}
var _loads: Dictionary[int, float] = {}
var _ke: PackedFloat64Array = PackedFloat64Array()  ## 8x8 element stiffness, row-major


## Builds the grid. inside(x, y) tells whether the cell centered at (x, y) is material.
## divisions_y > 0 sets the number of rows (so that every edge of the shape falls on a grid
## line); otherwise the elements are about square.
func _init(p_length: float, p_height: float, p_element_size: float, inside: Callable, divisions_y: int = 0) -> void:
	length = p_length
	height = p_height
	nx = maxi(1, roundi(length / p_element_size))
	ny = divisions_y if divisions_y > 0 else maxi(1, roundi(height / p_element_size))
	element_size = length / nx
	element_height = height / ny
	active.resize(nx * ny)
	for i: int in nx:
		for j: int in ny:
			active[i * ny + j] = 1 if inside.call((i + 0.5) * element_size, (j + 0.5) * element_height) else 0


func node(i: int, j: int) -> int:
	return i * (ny + 1) + j


func node_count() -> int:
	return (nx + 1) * (ny + 1)


func is_active(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < nx and j < ny and active[i * ny + j] == 1


func element_count() -> int:
	return active.count(1)


## Nodes that belong to at least one element (the mesh ANSYS would report).
func used_node_count() -> int:
	var n: int = 0
	for i: int in nx + 1:
		for j: int in ny + 1:
			if _node_used(i, j):
				n += 1
	return n


func _node_used(i: int, j: int) -> bool:
	return is_active(i, j) or is_active(i - 1, j) or is_active(i, j - 1) or is_active(i - 1, j - 1)


func fix(i: int, j: int) -> void:
	prescribe(i, j, 0, 0.0)
	prescribe(i, j, 1, 0.0)


## Prescribed displacement of node (i, j) in direction 0 (x) or 1 (y).
func prescribe(i: int, j: int, direction: int, value: float) -> void:
	_prescribed[2 * node(i, j) + direction] = value


func add_force(i: int, j: int, direction: int, force: float) -> void:
	var dof: int = 2 * node(i, j) + direction
	_loads[dof] = _loads.get(dof, 0.0) + force


## Fixed support on the left edge and a displacement d along +x on the right edge
## (other directions free), as in lab 3's ANSYS model.
func pull_right_edge(d: float) -> void:
	for j: int in ny + 1:
		if _node_used(0, j):
			fix(0, j)
		if _node_used(nx, j):
			prescribe(nx, j, 0, d)


func solve() -> void:
	_ke = _element_stiffness()
	var n: int = 2 * node_count()
	var bw: int = 2 * (ny + 2) + 1  # largest dof distance inside one element
	var w: int = bw + 1
	var k := PackedFloat64Array()
	k.resize(n * w)  # upper band: k[r*w + (c - r)] = K[r][c], c >= r
	var f := PackedFloat64Array()
	f.resize(n)
	for i: int in nx:
		for j: int in ny:
			if not is_active(i, j):
				continue
			var dofs: PackedInt32Array = _element_dofs(i, j)
			for a: int in 8:
				for b: int in 8:
					var r: int = dofs[a]
					var c: int = dofs[b]
					if c >= r:
						k[r * w + c - r] += _ke[a * 8 + b]
	for dof: int in _loads:
		f[dof] += _loads[dof]
	# Prescribed displacements: move K[:, d]*g to the right-hand side, then make row d an identity.
	for d: int in _prescribed:
		var g: float = _prescribed[d]
		for r: int in range(maxi(0, d - bw), mini(n, d + bw + 1)):
			if r == d:
				continue
			var krd: float = k[r * w + d - r] if d > r else k[d * w + r - d]
			f[r] -= krd * g
			if d > r:
				k[r * w + d - r] = 0.0
			else:
				k[d * w + r - d] = 0.0
		k[d * w] = 1.0
		f[d] = g
	for r: int in n:
		if k[r * w] == 0.0:  # node outside the shape
			k[r * w] = 1.0
			f[r] = 0.0
	_cholesky_solve(k, f, n, bw)
	displacements = f
	_recover_stresses()


## Sum of the x-forces the supports apply on the nodes of grid column i (the reaction force).
func reaction_x(i: int) -> float:
	var total: float = 0.0
	for j: int in ny + 1:
		total += _internal_force(i, j, 0)
	return total


## Element value fields averaged to the nodes (smooth contours, like ANSYS's default plot).
## which: 0 = von Mises stress, 1 = equivalent strain.
func nodal_average(which: int) -> PackedFloat64Array:
	var sums := PackedFloat64Array()
	sums.resize(node_count())
	var counts := PackedInt32Array()
	counts.resize(node_count())
	for i: int in nx:
		for j: int in ny:
			if not is_active(i, j):
				continue
			var e: int = i * ny + j
			var v: float = von_mises(e) if which == 0 else equivalent_strain(e)
			for nd: int in [node(i, j), node(i + 1, j), node(i + 1, j + 1), node(i, j + 1)]:
				sums[nd] += v
				counts[nd] += 1
	for nd: int in sums.size():
		if counts[nd] > 0:
			sums[nd] /= counts[nd]
	return sums


# Plane-stress von Mises: sigma_v = sqrt(sx^2 - sx*sy + sy^2 + 3*txy^2)
func von_mises(e: int) -> float:
	var s: Vector3 = element_stress[e]
	return sqrt(s.x * s.x - s.x * s.y + s.y * s.y + 3.0 * s.z * s.z)


# Equivalent (von Mises) strain as ANSYS reports it, with eps_z = -nu/(1 - nu)*(ex + ey):
#   eps_eq = 1/(1 + nu) * sqrt(((ex - ey)^2 + (ey - ez)^2 + (ez - ex)^2)/2 + 3/4*gxy^2)
# (equals sigma/E under uniaxial stress)
func equivalent_strain(e: int) -> float:
	var s: Vector3 = element_strain[e]
	var nu: float = poisson_ratio
	var ez: float = -nu / (1.0 - nu) * (s.x + s.y)
	var sq: float = 0.5 * (pow(s.x - s.y, 2) + pow(s.y - ez, 2) + pow(ez - s.x, 2)) + 0.75 * s.z * s.z
	return sqrt(sq) / (1.0 + nu)


## Largest element value: 0 = von Mises, 1 = equivalent strain.
func max_value(which: int) -> float:
	var best: float = 0.0
	for e: int in active.size():
		if active[e] == 1:
			best = maxf(best, von_mises(e) if which == 0 else equivalent_strain(e))
	return best


func min_value(which: int) -> float:
	var best: float = INF
	for e: int in active.size():
		if active[e] == 1:
			best = minf(best, von_mises(e) if which == 0 else equivalent_strain(e))
	return best


## Displacement of node (i, j).
func displacement(i: int, j: int) -> Vector2:
	var k: int = node(i, j)
	return Vector2(displacements[2 * k], displacements[2 * k + 1])


## Value of element (i, j)'s von Mises stress, or 0 outside the shape.
func von_mises_at(i: int, j: int) -> float:
	return von_mises(i * ny + j) if is_active(i, j) else 0.0


# Plane stress elasticity: D = E/(1 - nu^2) * [[1, nu, 0], [nu, 1, 0], [0, 0, (1 - nu)/2]]
func _d_matrix() -> PackedFloat64Array:
	var c: float = youngs_modulus / (1.0 - poisson_ratio * poisson_ratio)
	return PackedFloat64Array([c, c * poisson_ratio, 0.0, c * poisson_ratio, c, 0.0, 0.0, 0.0, c * (1.0 - poisson_ratio) / 2.0])


# Q4 shape functions N_i = (1 + xi*xi_i)(1 + eta*eta_i)/4 on an h_x by h_y rectangle:
#   dN_i/dx = xi_i*(1 + eta*eta_i)/(2h_x),  dN_i/dy = eta_i*(1 + xi*xi_i)/(2h_y)
# B (3x8) maps the element dofs [u1 v1 ... u4 v4] to [eps_x, eps_y, gamma_xy].
func _b_matrix(xi: float, eta: float) -> PackedFloat64Array:
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var b := PackedFloat64Array()
	b.resize(24)
	for a: int in 4:
		var c: Vector2 = corners[a]
		var dx: float = c.x * (1.0 + eta * c.y) / (2.0 * element_size)
		var dy: float = c.y * (1.0 + xi * c.x) / (2.0 * element_height)
		b[0 * 8 + 2 * a] = dx
		b[1 * 8 + 2 * a + 1] = dy
		b[2 * 8 + 2 * a] = dy
		b[2 * 8 + 2 * a + 1] = dx
	return b


func _element_stiffness() -> PackedFloat64Array:
	var d: PackedFloat64Array = _d_matrix()
	var ke := PackedFloat64Array()
	ke.resize(64)
	var g: float = 1.0 / sqrt(3.0)
	var jac: float = element_size * element_height / 4.0  # dA = (h_x/2)(h_y/2) dxi deta
	# Normal part (rows 0-1 of D): 2x2 Gauss points, weight 1 each.
	for p: Vector2 in [Vector2(-g, -g), Vector2(g, -g), Vector2(g, g), Vector2(-g, g)]:
		_add_btdb(ke, _b_matrix(p.x, p.y), d, [0, 1], jac * thickness)
	# Shear part: one point at the center, weight 4.
	_add_btdb(ke, _b_matrix(0.0, 0.0), d, [2], 4.0 * jac * thickness)
	return ke


## ke += B^T*D*B*factor, restricted to the strain rows `rows` of D.
func _add_btdb(ke: PackedFloat64Array, b: PackedFloat64Array, d: PackedFloat64Array, rows: Array, factor: float) -> void:
	for a: int in 8:
		for c: int in 8:
			var s: float = 0.0
			for r: int in rows:
				for q: int in rows:
					s += b[r * 8 + a] * d[r * 3 + q] * b[q * 8 + c]
			ke[a * 8 + c] += s * factor


func _element_dofs(i: int, j: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for nd: int in [node(i, j), node(i + 1, j), node(i + 1, j + 1), node(i, j + 1)]:
		out.append(2 * nd)
		out.append(2 * nd + 1)
	return out


## In place: k (upper band) becomes U with K = U^T*U, f becomes the solution of K*x = f.
func _cholesky_solve(k: PackedFloat64Array, f: PackedFloat64Array, n: int, bw: int) -> void:
	var w: int = bw + 1
	for i: int in n:
		var i_end: int = mini(n, i + bw + 1)
		for j: int in range(i, i_end):
			var s: float = k[i * w + j - i]
			for p: int in range(maxi(0, j - bw), i):
				s -= k[p * w + i - p] * k[p * w + j - p]
			if j == i:
				k[i * w] = sqrt(s)
			else:
				k[i * w + j - i] = s / k[i * w]
	# U^T*y = f (forward), then U*x = y (backward).
	for i: int in n:
		var s: float = f[i]
		for p: int in range(maxi(0, i - bw), i):
			s -= k[p * w + i - p] * f[p]
		f[i] = s / k[i * w]
	for i: int in range(n - 1, -1, -1):
		var s: float = f[i]
		for j: int in range(i + 1, mini(n, i + bw + 1)):
			s -= k[i * w + j - i] * f[j]
		f[i] = s / k[i * w]


func _recover_stresses() -> void:
	var d: PackedFloat64Array = _d_matrix()
	var b: PackedFloat64Array = _b_matrix(0.0, 0.0)
	element_stress.resize(nx * ny)
	element_strain.resize(nx * ny)
	for i: int in nx:
		for j: int in ny:
			if not is_active(i, j):
				continue
			var dofs: PackedInt32Array = _element_dofs(i, j)
			var eps := Vector3.ZERO
			for r: int in 3:
				var s: float = 0.0
				for a: int in 8:
					s += b[r * 8 + a] * displacements[dofs[a]]
				eps[r] = s
			var sig := Vector3(d[0] * eps.x + d[1] * eps.y, d[3] * eps.x + d[4] * eps.y, d[8] * eps.z)
			element_strain[i * ny + j] = eps
			element_stress[i * ny + j] = sig


## Internal force K*u at one dof, summed over the elements around node (i, j).
func _internal_force(i: int, j: int, direction: int) -> float:
	var dof: int = 2 * node(i, j) + direction
	var total: float = 0.0
	for ci: int in [i - 1, i]:
		for cj: int in [j - 1, j]:
			if not is_active(ci, cj):
				continue
			var dofs: PackedInt32Array = _element_dofs(ci, cj)
			var a: int = dofs.find(dof)
			for c: int in 8:
				total += _ke[a * 8 + c] * displacements[dofs[c]]
	return total
