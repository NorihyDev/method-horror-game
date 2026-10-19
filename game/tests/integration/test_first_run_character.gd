extends TestCase
## First launch asks for a name, a colour and a character, and saves all three.


func test_first_run_saves_the_chosen_character() -> void:
	var before_name := Saves.display_name()
	var before_char := Saves.character()
	var screen: Screen = Session.app.goto("name_entry", {"first_run": false})
	await get_tree().process_frame
	var picker := screen.find_children("*", "CharacterPicker", true, false)[0] as CharacterPicker
	assert_eq(picker.get_child_count(), CharacterCatalog.ids().size(), "a card per character")
	assert_eq(picker.selected, before_char, "starts on the saved character")
	(screen.get("_edit") as LineEdit).text = "Loss Fan"
	picker.call("_on_pick", "loss")
	screen.call("_submit")
	assert_eq(Saves.character(), "loss", "chosen character saved")
	assert_eq(Saves.display_name(), "Loss Fan", "name saved with it")
	Saves.set_character(before_char)
	Saves.set_display_name(before_name)
