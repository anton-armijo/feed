## Unit tests for ProximityFadeController setup and distance mapping.
## Pure logic tests: no physics world or players needed.
class_name TestProximityFadeController
extends GdUnitTestSuite

var _controller: ProximityFadeController
var _presenter: CharacterPresenter


func before_test() -> void:
	_controller = ProximityFadeController.new()
	_presenter = CharacterPresenter.new()


func after_test() -> void:
	if _controller:
		_controller.free()
	if _presenter:
		_presenter.free()
	_controller = null
	_presenter = null


func test_setup_reads_config_values() -> void:
	var cfg := ProximityFadeConfig.new()
	cfg.fade_start_distance = 2.0
	cfg.fade_end_distance = 0.5
	cfg.enabled = false
	cfg.checked_areas = [&"Head", &"Spine"]

	_controller.setup(_presenter, cfg)

	assert_bool(_controller._enabled).is_false()
	assert_float(_controller._fade_start).is_equal_approx(2.0, 0.0001)
	assert_float(_controller._fade_end).is_equal_approx(0.5, 0.0001)
	assert_array(_controller._checked_areas).contains_exactly([&"Head", &"Spine"])


func test_distance_to_fade_mappings() -> void:
	var cfg := ProximityFadeConfig.new()
	cfg.fade_start_distance = 2.0
	cfg.fade_end_distance = 0.5

	_controller.setup(_presenter, cfg)

	# Beyond start -> fully visible (fade 0).
	assert_float(_controller.call("_distance_to_fade", 3.0)).is_equal_approx(0.0, 0.0001)
	assert_float(_controller.call("_distance_to_fade", 2.0)).is_equal_approx(0.0, 0.0001)
	# Closer than end -> fully invisible (fade 1).
	assert_float(_controller.call("_distance_to_fade", 0.5)).is_equal_approx(1.0, 0.0001)
	assert_float(_controller.call("_distance_to_fade", 0.0)).is_equal_approx(1.0, 0.0001)
	# Midpoint -> 0.5 fade.
	assert_float(_controller.call("_distance_to_fade", 1.25)).is_equal_approx(0.5, 0.0001)


func test_set_enabled_clears_fade() -> void:
	var cfg := ProximityFadeConfig.new()
	cfg.enabled = true

	_controller.setup(_presenter, cfg)
	_controller.set_enabled(false)

	assert_bool(_controller._enabled).is_false()
