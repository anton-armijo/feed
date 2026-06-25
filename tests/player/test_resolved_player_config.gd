## Unit tests for PlayerConfig and its sub-resource methods (pure data, no nodes).
class_name TestPlayerConfig
extends GdUnitTestSuite


func test_default_body_height_and_weight() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	assert_float(cfg.body_height).is_equal(1.59)
	assert_float(cfg.weight).is_equal(47.0)


func test_ensure_defaults_creates_sub_resources() -> void:
	var cfg := PlayerConfig.new()
	cfg.ensure_defaults()
	assert_object(cfg.locomotion).is_not_null()
	assert_object(cfg.jump).is_not_null()
	assert_object(cfg.camera).is_not_null()
	assert_object(cfg.camera_effects).is_not_null()
	assert_object(cfg.stair).is_not_null()
	assert_object(cfg.probe).is_not_null()
	assert_object(cfg.components).is_not_null()
	assert_object(cfg.foot_ik).is_not_null()


func test_locomotion_config_defaults() -> void:
	var c := LocomotionConfig.new()
	assert_float(c.walk_speed).is_equal(3.0)
	assert_float(c.run_speed).is_equal(5.4)
	assert_float(c.model_turn_speed).is_equal(12.0)
	assert_float(c.weight_turn_factor).is_equal(0.01)


func test_model_turn_speed_no_weight_effect_when_factor_zero() -> void:
	var c := LocomotionConfig.new()
	c.weight_turn_factor = 0.0
	assert_float(c.compute_model_turn_speed(100.0)).is_equal(c.model_turn_speed)


func test_model_turn_speed_scales_with_weight() -> void:
	var c := LocomotionConfig.new()
	c.model_turn_speed = 12.0
	c.weight_turn_factor = 0.01
	# heavier = slower
	var light := c.compute_model_turn_speed(47.0)
	var heavy := c.compute_model_turn_speed(100.0)
	assert_bool(light > heavy).is_true()


func test_model_turn_speed_formula() -> void:
	var c := LocomotionConfig.new()
	c.model_turn_speed = 12.0
	c.weight_turn_factor = 0.02
	var expected := 12.0 / (1.0 + 0.02 * 70.0)
	assert_float(c.compute_model_turn_speed(70.0)).is_equal_approx(expected, 0.0001)


func test_max_step_up_from_ratio() -> void:
	var c := StairConfig.new()
	c.max_step_up_ratio = 0.314
	assert_float(c.compute_max_step_up(1.59)).is_equal_approx(0.5, 0.001)


func test_max_step_up_scales_with_body_height() -> void:
	var c := StairConfig.new()
	c.max_step_up_ratio = 0.44
	assert_float(c.compute_max_step_up(3.18)).is_equal_approx(1.4, 0.001)
	assert_float(c.compute_max_step_up(0.795)).is_equal_approx(0.35, 0.001)


func test_stair_config_defaults() -> void:
	var c := StairConfig.new()
	assert_float(c.max_step_up_ratio).is_equal(0.314)
	assert_int(c.step_check_iterations).is_equal(6)
	assert_float(c.min_horizontal_motion).is_equal(0.001)


func test_probe_config_defaults() -> void:
	var c := ProbeConfig.new()
	assert_float(c.short_factor).is_equal(0.06)
	assert_float(c.medium_factor).is_equal(0.17)
	assert_int(c.collision_mask).is_equal(1)


func test_jump_config_defaults() -> void:
	var c := JumpConfig.new()
	assert_float(c.jump_velocity).is_equal(4.2)
	assert_float(c.jump_buffer_time).is_equal(0.1)
	assert_float(c.land_duration).is_equal(0.35)


func test_player_config_weight_default() -> void:
	var c := PlayerConfig.new()
	assert_float(c.weight).is_equal(47.0)
