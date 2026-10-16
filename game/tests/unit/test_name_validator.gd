extends TestCase
## Display-name validation: lengths, whitespace, control/bidi/markup chars.


func test_normalize_trims_and_collapses() -> void:
	assert_eq(NameValidator.normalize("   Mary    Ann  "), "Mary Ann")
	assert_eq(NameValidator.normalize("\tA\u00a0\u00a0B"), "A B")


func test_lengths() -> void:
	assert_eq(NameValidator.validate("A"), NameValidator.Result.TOO_SHORT)
	assert_eq(NameValidator.validate("   A   "), NameValidator.Result.TOO_SHORT)
	assert_eq(NameValidator.validate("AB"), NameValidator.Result.OK)
	assert_eq(NameValidator.validate("x".repeat(20)), NameValidator.Result.OK)
	assert_eq(NameValidator.validate("x".repeat(21)), NameValidator.Result.TOO_LONG)


func test_rejects_control_and_invisible_characters() -> void:
	assert_eq(NameValidator.validate("ab\u0007cd"), NameValidator.Result.INVALID_CHARACTERS)
	assert_eq(NameValidator.validate("ab\u200bcd"), NameValidator.Result.INVALID_CHARACTERS)
	assert_eq(NameValidator.validate("admin\u202ecba"), NameValidator.Result.INVALID_CHARACTERS)
	assert_eq(NameValidator.validate("ab\ufeffcd"), NameValidator.Result.INVALID_CHARACTERS)


func test_rejects_markup_characters() -> void:
	assert_eq(NameValidator.validate("[b]bold[/b]"), NameValidator.Result.INVALID_CHARACTERS)
	assert_eq(NameValidator.validate("<script>"), NameValidator.Result.INVALID_CHARACTERS)
	assert_eq(NameValidator.validate("{name}"), NameValidator.Result.INVALID_CHARACTERS)


func test_accepts_international_names() -> void:
	assert_eq(NameValidator.validate("Zoé Lefèvre"), NameValidator.Result.OK)
	assert_eq(NameValidator.validate("Ндрю"), NameValidator.Result.OK)
	assert_eq(NameValidator.validate("山田太郎"), NameValidator.Result.OK)
	assert_eq(NameValidator.validate("O'Brien-2"), NameValidator.Result.OK)


func test_escape_bbcode() -> void:
	assert_eq(NameValidator.escape_bbcode("[x]"), "[lb]x[rb]")
