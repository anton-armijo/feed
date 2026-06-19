## Unit tests for StairConfig and ProbeConfig defaults (pure data resources).
class_name TestStairProbeConfig
extends GdUnitTestSuite

func test_stair_config_defaults() -> void:
	var c := StairConfig.new()
	assert_float(c.base_max_step_up).is_equal(0.5)
	assert_int(c.step_check_iterations).is_equal(6)
	assert_float(c.min_horizontal_motion).is_equal(0.001)

func test_probe_config_defaults() -> void:
	var c := ProbeConfig.new()
	assert_float(c.short_factor).is_equal(0.06)
	assert_float(c.medium_factor).is_equal(0.17)
	assert_int(c.collision_mask).is_equal(1)

func test_player_config_has_stair_and_probe() -> void:
	var c := PlayerConfig.new()
	c.ensure_defaults()
	assert_object(c.stair).is_not_null()
	assert_object(c.probe).is_not_null()
	assert_bool(c.stair is StairConfig).is_true()
	assert_bool(c.probe is ProbeConfig).is_true()

func test_player_config_weight_default() -> void:
	var c := PlayerConfig.new()
	assert_float(c.weight).is_equal(47.0)
