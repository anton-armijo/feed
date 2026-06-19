## Unit tests for PlayerApi's extension verb registry (Tier 3).
## The registry is independent of setup() — no subsystem refs needed.
class_name TestPlayerApiVerbs
extends GdUnitTestSuite

var _api: PlayerApi

func before_test() -> void:
	_api = PlayerApi.new()

func after_test() -> void:
	if _api:
		_api.free()
	_api = null

func test_register_and_call_verb() -> void:
	_api.register_verb(&"pet", Callable(self, "_pet_response"))
	assert_bool(_api.has_verb(&"pet")).is_true()
	var result: Variant = _api.call_verb(&"pet", [])
	assert_str(str(result)).is_equal("purr")

func test_call_unknown_verb_returns_null() -> void:
	assert_bool(_api.has_verb(&"unknown")).is_false()
	var result: Variant = _api.call_verb(&"unknown", [])
	assert_object(result).is_null()

func test_unregister_verb() -> void:
	_api.register_verb(&"pet", Callable(self, "_pet_response"))
	assert_bool(_api.has_verb(&"pet")).is_true()
	_api.unregister_verb(&"pet")
	assert_bool(_api.has_verb(&"pet")).is_false()

func test_call_verb_with_args() -> void:
	_api.register_verb(&"add", Callable(self, "_add"))
	var result: Variant = _api.call_verb(&"add", [3, 4])
	assert_int(int(result)).is_equal(7)

func test_register_overwrites() -> void:
	_api.register_verb(&"pet", Callable(self, "_pet_response"))
	_api.register_verb(&"pet", Callable(self, "_add"))
	var result: Variant = _api.call_verb(&"pet", [1, 1])
	assert_int(int(result)).is_equal(2)

# --- Callable targets ---------------------------------------------------------

func _pet_response() -> String:
	return "purr"

func _add(a: int, b: int) -> int:
	return a + b
