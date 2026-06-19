## Unit tests for YSmoother (pure math, no node dependencies).
class_name TestYSmoother
extends GdUnitTestSuite

func test_first_frame_snaps_to_target() -> void:
	var s := YSmoother.new(14.0)
	s.process_smoothing(0.016, 10.0)
	assert_float(s.get_smoothed_y()).is_equal(10.0)

func test_subsequent_frame_lerps_toward_target() -> void:
	var s := YSmoother.new(14.0)
	s.process_smoothing(0.016, 0.0)
	s.process_smoothing(0.016, 10.0)
	var y := s.get_smoothed_y()
	assert_float(y).is_greater(0.0).is_less(10.0)

func test_offset_is_smoothed_minus_target() -> void:
	var s := YSmoother.new(14.0)
	s.process_smoothing(0.016, 10.0)
	s.process_smoothing(0.016, 20.0)
	assert_float(s.get_offset(20.0)).is_equal(s.get_smoothed_y() - 20.0)

func test_teleport_resets_to_snap_on_next_process() -> void:
	var s := YSmoother.new(14.0)
	s.process_smoothing(0.016, 10.0)
	s.process_smoothing(0.016, 10.0)
	s.teleport()
	s.process_smoothing(0.016, 42.0)
	assert_float(s.get_smoothed_y()).is_equal(42.0)

func test_higher_speed_converges_faster() -> void:
	var slow := YSmoother.new(5.0)
	var fast := YSmoother.new(50.0)
	slow.process_smoothing(0.016, 0.0)
	fast.process_smoothing(0.016, 0.0)
	slow.process_smoothing(0.016, 100.0)
	fast.process_smoothing(0.016, 100.0)
	assert_float(fast.get_smoothed_y()).is_greater(slow.get_smoothed_y())
