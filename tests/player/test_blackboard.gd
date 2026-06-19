## Unit tests for PlayerBlackboard's facing-locked queries and directional
## anim resolver (pure logic, Node instantiated for state fields).
class_name TestBlackboard
extends GdUnitTestSuite

var _bb: PlayerBlackboard


func before_test() -> void:
	_bb = PlayerBlackboard.new()


func after_test() -> void:
	if _bb:
		_bb.free()
	_bb = null


# --- is_facing_locked ---------------------------------------------------------


func test_facing_unlocked_by_default() -> void:
	assert_bool(_bb.is_facing_locked()).is_false()


func test_first_person_locks_facing() -> void:
	_bb.first_person = true
	assert_bool(_bb.is_facing_locked()).is_true()


func test_lock_on_character_locks_facing() -> void:
	_bb.lock_on_character = true
	assert_bool(_bb.is_facing_locked()).is_true()


func test_lock_mouse_hold_does_not_lock_facing() -> void:
	# Only lock_on_character locks facing; right-click (lock_mouse) does not,
	# because the model still turns toward wish_dir during a mouse lock.
	_bb.lock_mouse = true
	assert_bool(_bb.is_facing_locked()).is_false()


func test_both_locks_cancel_independently() -> void:
	_bb.first_person = true
	_bb.lock_on_character = true
	assert_bool(_bb.is_facing_locked()).is_true()
	_bb.first_person = false
	assert_bool(_bb.is_facing_locked()).is_true()
	_bb.lock_on_character = false
	assert_bool(_bb.is_facing_locked()).is_false()


# --- move_sector --------------------------------------------------------------


func test_move_sector_empty_when_not_locked() -> void:
	# Even a clear "back" direction yields "" when the facing is free.
	assert_str(str(_bb.move_sector(Vector3.FORWARD))).is_equal(str(&""))
	_bb.first_person = true
	_bb.first_person = false
	assert_str(str(_bb.move_sector(Vector3.BACK))).is_equal(str(&""))


func test_move_sector_empty_for_zero_wish() -> void:
	_bb.first_person = true
	assert_str(str(_bb.move_sector(Vector3.ZERO))).is_equal(str(&""))


func test_move_sector_forward_is_empty() -> void:
	_bb.first_person = true
	# Model faces -Z; wish_dir = -Z is forward.
	assert_str(str(_bb.move_sector(Vector3(0.0, 0.0, -1.0)))).is_equal(str(&""))


func test_move_sector_back() -> void:
	_bb.first_person = true
	# +Z is directly behind the model.
	assert_str(str(_bb.move_sector(Vector3(0.0, 0.0, 1.0)))).is_equal(str(&"back"))


func test_move_sector_back_diagonal_counts_as_back() -> void:
	_bb.first_person = true
	# Rear semi-plane (z > 0) collapses to back, including diagonals.
	assert_str(str(_bb.move_sector(Vector3(0.7, 0.0, 0.7)))).is_equal(str(&"back"))
	assert_str(str(_bb.move_sector(Vector3(-0.7, 0.0, 0.7)))).is_equal(str(&"back"))


func test_move_sector_left() -> void:
	_bb.first_person = true
	assert_str(str(_bb.move_sector(Vector3(-1.0, 0.0, 0.0)))).is_equal(str(&"left"))


func test_move_sector_right() -> void:
	_bb.first_person = true
	assert_str(str(_bb.move_sector(Vector3(1.0, 0.0, 0.0)))).is_equal(str(&"right"))


func test_move_sector_forward_diagonal_is_forward() -> void:
	_bb.first_person = true
	# z < 0 and |x| == |z| → forward, not lateral.
	assert_str(str(_bb.move_sector(Vector3(0.7, 0.0, -0.7)))).is_equal(str(&""))


func test_move_sector_respects_model_yaw() -> void:
	_bb.first_person = true
	_bb.model_yaw = PI / 2.0
	# Model now faces -X; world -Z is to its right.
	assert_str(str(_bb.move_sector(Vector3(0.0, 0.0, -1.0)))).is_equal(str(&"right"))
	# World +X is directly behind the model.
	assert_str(str(_bb.move_sector(Vector3(1.0, 0.0, 0.0)))).is_equal(str(&"back"))


# --- is_backpedaling ----------------------------------------------------------


func test_backpedaling_true_for_back() -> void:
	_bb.first_person = true
	assert_bool(_bb.is_backpedaling(Vector3(0.0, 0.0, 1.0))).is_true()


func test_backpedaling_true_for_back_diagonal() -> void:
	_bb.first_person = true
	assert_bool(_bb.is_backpedaling(Vector3(0.7, 0.0, 0.7))).is_true()


func test_backpedaling_false_for_forward() -> void:
	_bb.first_person = true
	assert_bool(_bb.is_backpedaling(Vector3(0.0, 0.0, -1.0))).is_false()


func test_backpedaling_false_when_not_locked() -> void:
	assert_bool(_bb.is_backpedaling(Vector3(0.0, 0.0, 1.0))).is_false()


# --- resolve_anim -------------------------------------------------------------


func test_resolve_anim_returns_base_when_no_sector() -> void:
	_bb.first_person = true
	_bb.directional_anim_states = [&"walk_back"]
	assert_str(str(_bb.resolve_anim(&"walk", Vector3(0.0, 0.0, -1.0)))).is_equal(str(&"walk"))


func test_resolve_anim_returns_directional_when_available() -> void:
	_bb.first_person = true
	_bb.directional_anim_states = [&"walk_back"]
	assert_str(str(_bb.resolve_anim(&"walk", Vector3(0.0, 0.0, 1.0)))).is_equal(str(&"walk_back"))


func test_resolve_anim_falls_back_when_directional_missing() -> void:
	_bb.first_person = true
	# No run_back advertised → run stays run even when backpedaling.
	_bb.directional_anim_states = [&"walk_back"]
	assert_str(str(_bb.resolve_anim(&"run", Vector3(0.0, 0.0, 1.0)))).is_equal(str(&"run"))


func test_resolve_anim_falls_back_when_set_empty() -> void:
	_bb.first_person = true
	_bb.directional_anim_states = []
	assert_str(str(_bb.resolve_anim(&"walk", Vector3(0.0, 0.0, 1.0)))).is_equal(str(&"walk"))


func test_resolve_anim_idle_back_uses_directional_if_advertised() -> void:
	_bb.first_person = true
	_bb.directional_anim_states = [&"idle_back"]
	# idle with a back wish_dir → idle_back (uniform convention; idle has no
	# real effect but the path is consistent).
	assert_str(str(_bb.resolve_anim(&"idle", Vector3(0.0, 0.0, 1.0)))).is_equal(str(&"idle_back"))


func test_resolve_anim_ignores_direction_when_not_locked() -> void:
	_bb.directional_anim_states = [&"walk_back"]
	# Facing free → sector is empty → base regardless of wish_dir.
	assert_str(str(_bb.resolve_anim(&"walk", Vector3(0.0, 0.0, 1.0)))).is_equal(str(&"walk"))
