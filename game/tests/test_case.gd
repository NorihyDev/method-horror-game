class_name TestCase
extends Node
## Minimal test base. Methods named test_* are run in order; they may await.

var failures: PackedStringArray = []
var current_test := ""
var app_root: Node


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append("%s: %s" % [current_test, message])


func assert_true(cond: bool, message: String = "expected true") -> void:
	if not cond:
		fail(message)


func assert_false(cond: bool, message: String = "expected false") -> void:
	if cond:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if (
		typeof(actual) != typeof(expected)
		and not ((actual is int or actual is float) and (expected is int or expected is float))
	):
		fail(
			(
				"%s expected %s (%s) got %s (%s)"
				% [message, str(expected), type_string(typeof(expected)), str(actual), type_string(typeof(actual))]
			)
		)
	elif actual != expected:
		fail("%s expected %s got %s" % [message, str(expected), str(actual)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if actual == unexpected:
		fail("%s did not expect %s" % [message, str(actual)])


func assert_empty(list: Variant, message: String = "") -> void:
	if (list is Array or list is PackedStringArray or list is Dictionary) and not list.is_empty():
		fail("%s expected empty, got %s" % [message, str(list)])


## Waits for physics frames (integration tests).
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
