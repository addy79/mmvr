class_name LinearFit
extends RefCounted
## Least-squares straight line through measured points, as a spreadsheet trendline does.
## y = slope*x + intercept, or y = slope*x when forced through the origin.

var slope: float = 0.0
var intercept: float = 0.0
var r_squared: float = 0.0
var count: int = 0


## Fits y = m*x + b:  m = (n*Sxy - Sx*Sy)/(n*Sxx - Sx^2),  b = (Sy - m*Sx)/n.
## through_origin: m = Sxy/Sxx, b = 0.
static func of(points: PackedVector2Array, through_origin: bool = false) -> LinearFit:
	var fit := LinearFit.new()
	var n: int = points.size()
	fit.count = n
	if n == 0:
		return fit
	var sx: float = 0.0
	var sy: float = 0.0
	var sxx: float = 0.0
	var sxy: float = 0.0
	for p: Vector2 in points:
		sx += p.x
		sy += p.y
		sxx += p.x * p.x
		sxy += p.x * p.y
	if through_origin:
		fit.slope = sxy / sxx if sxx > 0.0 else 0.0
	else:
		var den: float = n * sxx - sx * sx
		fit.slope = (n * sxy - sx * sy) / den if den != 0.0 else 0.0
		fit.intercept = (sy - fit.slope * sx) / n
	fit.r_squared = fit._r_squared(points, sy / n)
	return fit


func at(x: float) -> float:
	return slope * x + intercept


# R^2 = 1 - SS_res/SS_tot (spreadsheet definition, about the mean of y)
func _r_squared(points: PackedVector2Array, mean_y: float) -> float:
	var ss_res: float = 0.0
	var ss_tot: float = 0.0
	for p: Vector2 in points:
		ss_res += pow(p.y - at(p.x), 2)
		ss_tot += pow(p.y - mean_y, 2)
	return 1.0 - ss_res / ss_tot if ss_tot > 0.0 else 1.0
