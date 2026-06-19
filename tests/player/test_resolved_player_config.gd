## Unit tests for ResolvedPlayerConfig resolver (pure logic, no nodes).
class_name TestResolvedPlayerConfig
extends GdUnitTestSuite


func test_reference_weight_gives_base_turn_speed() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.weight = 70.0  # reference weight
	var r := ResolvedPlayerConfig.resolve(cfg)
	assert_float(r.locomotion.model_turn_speed).is_equal(cfg.locomotion.base_model_turn_speed)


func test_teto_weight_increases_turn_speed() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.weight = 47.0  # Teto
	var r := ResolvedPlayerConfig.resolve(cfg)
	# factor = (70/47)^1.0 * 1.0 = ~1.489
	assert_float(r.locomotion.model_turn_speed).is_equal_approx(
		cfg.locomotion.base_model_turn_speed * (70.0 / 47.0), 0.001
	)


func test_heavier_weight_reduces_turn_speed() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.weight = 100.0
	var r := ResolvedPlayerConfig.resolve(cfg)
	# factor = (70/100)^1.0 = 0.7
	assert_float(r.locomotion.model_turn_speed).is_equal_approx(
		cfg.locomotion.base_model_turn_speed * 0.7, 0.0001
	)


func test_weight_turn_disabled_uses_base() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.weight = 200.0
	cfg.locomotion.weight_turn_enabled = false
	var r := ResolvedPlayerConfig.resolve(cfg)
	assert_float(r.locomotion.model_turn_speed).is_equal(cfg.locomotion.base_model_turn_speed)


func test_weight_turn_exponent_changes_curve() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.weight = 47.0
	cfg.locomotion.weight_turn_exponent = 2.0
	var r := ResolvedPlayerConfig.resolve(cfg)
	# factor = (70/47)^2.0 ≈ 2.218
	var expected := cfg.locomotion.base_model_turn_speed * pow(70.0 / 47.0, 2.0)
	assert_float(r.locomotion.model_turn_speed).is_equal_approx(expected, 0.001)


func test_weight_turn_scale_applies() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.weight = 47.0
	cfg.locomotion.weight_turn_scale = 0.5
	var r := ResolvedPlayerConfig.resolve(cfg)
	# factor = (70/47)^1.0 * 0.5
	assert_float(r.locomotion.model_turn_speed).is_equal_approx(
		cfg.locomotion.base_model_turn_speed * (70.0 / 47.0) * 0.5, 0.001
	)


func test_extreme_weight_clamped() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.weight = 1000.0
	var r := ResolvedPlayerConfig.resolve(cfg)
	# factor = (70/1000)^1.0 = 0.07, clamped to 0.2
	assert_float(r.locomotion.model_turn_speed).is_equal_approx(
		cfg.locomotion.base_model_turn_speed * 0.2, 0.0001
	)


func test_default_height_gives_base_step_up() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	var r := ResolvedPlayerConfig.resolve(cfg)
	assert_float(r.stair.max_step_up).is_equal(cfg.stair.base_max_step_up)


func test_taller_character_steps_higher() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.body_height = 3.18  # double the reference
	var r := ResolvedPlayerConfig.resolve(cfg)
	assert_float(r.stair.max_step_up).is_equal_approx(cfg.stair.base_max_step_up * 2.0, 0.0001)


func test_shorter_character_steps_lower() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.body_height = 0.795  # half the reference
	var r := ResolvedPlayerConfig.resolve(cfg)
	assert_float(r.stair.max_step_up).is_equal_approx(cfg.stair.base_max_step_up * 0.5, 0.0001)


func test_locomotion_passthroughs() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.locomotion.walk_speed = 4.0
	cfg.locomotion.run_speed = 7.0
	cfg.locomotion.air_control = 0.5
	cfg.locomotion.backwalk_speed_multiplier = 0.5
	var r := ResolvedPlayerConfig.resolve(cfg)
	assert_float(r.locomotion.walk_speed).is_equal(4.0)
	assert_float(r.locomotion.run_speed).is_equal(7.0)
	assert_float(r.locomotion.air_control).is_equal(0.5)
	assert_float(r.locomotion.backwalk_speed_multiplier).is_equal(0.5)


func test_backwalk_speed_multiplier_default() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	var r := ResolvedPlayerConfig.resolve(cfg)
	assert_float(r.locomotion.backwalk_speed_multiplier).is_equal(0.6)


func test_jump_passthroughs() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.jump.jump_velocity = 5.0
	cfg.jump.coyote_time = 0.2
	var r := ResolvedPlayerConfig.resolve(cfg)
	assert_float(r.jump.jump_velocity).is_equal(5.0)
	assert_float(r.jump.coyote_time).is_equal(0.2)


func test_probe_passthroughs() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.probe.short_factor = 0.1
	cfg.probe.medium_factor = 0.2
	cfg.probe.collision_mask = 7
	var r := ResolvedPlayerConfig.resolve(cfg)
	assert_float(r.probe.short_factor).is_equal(0.1)
	assert_float(r.probe.medium_factor).is_equal(0.2)
	assert_int(r.probe.collision_mask).is_equal(7)


func test_stair_passthroughs() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	cfg.stair.step_check_iterations = 10
	cfg.stair.min_horizontal_motion = 0.005
	var r := ResolvedPlayerConfig.resolve(cfg)
	assert_int(r.stair.step_check_iterations).is_equal(10)
	assert_float(r.stair.min_horizontal_motion).is_equal(0.005)


func test_ensure_defaults_called() -> void:
	var cfg := PlayerConfig.new()
	# Don't call ensure_defaults — resolve() should do it.
	var r := ResolvedPlayerConfig.resolve(cfg)
	assert_object(r.locomotion).is_not_null()
	assert_object(r.jump).is_not_null()
	assert_object(r.camera).is_not_null()
	assert_object(r.stair).is_not_null()
	assert_object(r.probe).is_not_null()
