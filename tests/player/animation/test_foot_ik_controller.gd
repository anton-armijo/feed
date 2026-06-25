## Unit tests for FootIkController pure math + suppression logic.
## Covers the 2-bone IK solver, the -Y aim basis, the engagement rule and the
## pelvis spring — all extracted as static functions so they need no scene.
class_name TestFootIkController
extends GdUnitTestSuite

const EPS := 0.0005
const VEPS := Vector3(0.0005, 0.0005, 0.0005)

# --- 2-bone IK solver --------------------------------------------------------


func test_solve_two_bone_reachable_foot_at_target() -> void:
	var hip := Vector3(0.0, 1.0, 0.0)
	var target := Vector3(0.0, 0.2, 0.0)
	var sol := FootIkController.solve_two_bone(hip, target, Vector3(0.0, 0.0, -1.0), 0.5, 0.5)
	var foot: Vector3 = sol.foot
	assert_vector(foot).is_equal_approx(target, VEPS)


func test_solve_two_bone_knee_on_pole_side() -> void:
	var hip := Vector3(0.0, 1.0, 0.0)
	var target := Vector3(0.0, 0.2, 0.0)
	# pole = -Z (forward); the knee should bulge toward -Z.
	var sol := FootIkController.solve_two_bone(hip, target, Vector3(0.0, 0.0, -1.0), 0.5, 0.5)
	var knee: Vector3 = sol.knee
	assert_float(knee.z).is_less(0.0)


func test_solve_two_bone_knee_distance_from_hip_is_upper_len() -> void:
	var hip := Vector3(0.0, 1.0, 0.0)
	var target := Vector3(0.0, 0.2, 0.0)
	var sol := FootIkController.solve_two_bone(hip, target, Vector3(0.0, 0.0, -1.0), 0.5, 0.5)
	var knee: Vector3 = sol.knee
	assert_float(knee.distance_to(hip)).is_equal_approx(0.5, EPS)


func test_solve_two_bone_unreachable_clamps_foot_no_stretch() -> void:
	var hip := Vector3(0.0, 1.0, 0.0)
	var target := Vector3(0.0, -1.0, 0.0)  # 2.0 away, beyond 0.5+0.5 reach
	var sol := FootIkController.solve_two_bone(hip, target, Vector3(0.0, 0.0, -1.0), 0.5, 0.5)
	var foot: Vector3 = sol.foot
	# Foot must NOT reach the target (no bone stretch); it sits at max reach.
	assert_float(foot.distance_to(hip)).is_equal_approx(0.999, EPS)
	assert_float(foot.y).is_greater(target.y)


func test_solve_two_bone_colinear_pole_falls_back_gracefully() -> void:
	# pole parallel to hip->target dir should not NaN; solver picks a fallback.
	var hip := Vector3(0.0, 1.0, 0.0)
	var target := Vector3(0.0, 0.2, 0.0)
	var sol := FootIkController.solve_two_bone(hip, target, Vector3(0.0, -1.0, 0.0), 0.5, 0.5)
	var knee: Vector3 = sol.knee
	assert_bool(is_finite(knee.x)).is_true()
	assert_bool(is_finite(knee.y)).is_true()
	assert_bool(is_finite(knee.z)).is_true()


# --- aim basis ---------------------------------------------------------------


func test_aim_basis_maps_local_axis_to_dir() -> void:
	# This rig's leg bones point along local +Y, so axis_local = +Y.
	var dir := Vector3(1.0, 0.0, 0.0)
	var b := FootIkController.aim_basis(Vector3(0.0, 1.0, 0.0), dir, Vector3(0.0, 0.0, -1.0))
	assert_vector(b * Vector3(0.0, 1.0, 0.0)).is_equal_approx(dir, VEPS)


func test_aim_basis_vertical_dir() -> void:
	var b := FootIkController.aim_basis(
		Vector3(0.0, 1.0, 0.0), Vector3(0.0, -1.0, 0.0), Vector3(0.0, 0.0, -1.0)
	)
	assert_vector(b * Vector3(0.0, 1.0, 0.0)).is_equal_approx(Vector3(0.0, -1.0, 0.0), VEPS)


func test_aim_basis_maps_local_z_to_pole_perp() -> void:
	var b := FootIkController.aim_basis(
		Vector3(0.0, 1.0, 0.0), Vector3(0.0, -1.0, 0.0), Vector3(0.0, 0.0, -1.0)
	)
	# local +Z should map to the pole (perpendicular to the aim dir).
	assert_vector(b * Vector3(0.0, 0.0, 1.0)).is_equal_approx(Vector3(0.0, 0.0, -1.0), VEPS)


func test_aim_basis_is_orthonormal_right_handed() -> void:
	var b := FootIkController.aim_basis(
		Vector3(0.0, 1.0, 0.0), Vector3(0.3, -1.0, -0.2).normalized(), Vector3(0.0, 0.0, -1.0)
	)
	assert_float(b.x.length()).is_equal_approx(1.0, EPS)
	assert_float(b.y.length()).is_equal_approx(1.0, EPS)
	assert_float(b.z.length()).is_equal_approx(1.0, EPS)
	# Right-handed: determinant ≈ +1.
	assert_float(b.determinant()).is_equal_approx(1.0, EPS)
	# Orthogonality.
	assert_float(b.x.dot(b.y)).is_equal_approx(0.0, EPS)
	assert_float(b.y.dot(b.z)).is_equal_approx(0.0, EPS)





# --- Pelvis spring -----------------------------------------------------------


func test_spring_at_rest_stays_at_rest() -> void:
	var r := FootIkController.spring_update(0.0, 0.0, 0.0, 90.0, 12.0, 0.016)
	assert_float(r.x).is_equal(0.0)
	assert_float(r.y).is_equal(0.0)


func test_spring_moves_toward_negative_target() -> void:
	var r := FootIkController.spring_update(0.0, 0.0, -0.1, 90.0, 12.0, 0.016)
	assert_float(r.x).is_less(0.0)
	assert_float(r.x).is_greater(-0.1)


func test_spring_converges_without_exploding() -> void:
	var value := 0.0
	var vel := 0.0
	var target := -0.15
	for _i in 200:
		var r := FootIkController.spring_update(value, vel, target, 90.0, 12.0, 0.016)
		value = r.x
		vel = r.y
	assert_float(value).is_equal_approx(target, 0.01)
	assert_bool(is_finite(value)).is_true()


func test_spring_bounded_for_large_stiffness() -> void:
	var value := 0.0
	var vel := 0.0
	var target := -0.2
	for _i in 300:
		var r := FootIkController.spring_update(value, vel, target, 400.0, 20.0, 0.016)
		value = r.x
		vel = r.y
	assert_bool(is_finite(value)).is_true()
	assert_float(value).is_greater_equal(target - 0.05)
