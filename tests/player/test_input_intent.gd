## Unit tests for InputIntent (jump buffer mechanics, pure RefCounted).
class_name TestInputIntent
extends GdUnitTestSuite

func test_buffer_jump_sets_window() -> void:
	var intent := InputIntent.new()
	intent.buffer_jump(0.1)
	assert_bool(intent.has_buffered_jump()).is_true()

func test_tick_decrements_buffer() -> void:
	var intent := InputIntent.new()
	intent.buffer_jump(0.1)
	intent.tick(0.04)
	assert_bool(intent.has_buffered_jump()).is_true()
	intent.tick(0.04)
	assert_bool(intent.has_buffered_jump()).is_true()
	intent.tick(0.04)
	assert_bool(intent.has_buffered_jump()).is_false()

func test_consume_jump_clears_buffer() -> void:
	var intent := InputIntent.new()
	intent.buffer_jump(0.5)
	assert_bool(intent.has_buffered_jump()).is_true()
	intent.consume_jump()
	assert_bool(intent.has_buffered_jump()).is_false()

func test_tick_never_goes_negative() -> void:
	var intent := InputIntent.new()
	intent.buffer_jump(0.05)
	intent.tick(1.0)
	assert_bool(intent.has_buffered_jump()).is_false()

func test_clear_resets_all_fields() -> void:
	var intent := InputIntent.new()
	intent.move_dir = Vector2(1, 1)
	intent.wish_dir = Vector3(1, 0, 0)
	intent.run_held = true
	intent.jump_held = true
	intent.buffer_jump(0.5)
	intent.clear()
	assert_vector(intent.move_dir).is_equal(Vector2.ZERO)
	assert_vector(intent.wish_dir).is_equal(Vector3.ZERO)
	assert_bool(intent.run_held).is_false()
	assert_bool(intent.jump_held).is_false()
	assert_bool(intent.has_buffered_jump()).is_false()
