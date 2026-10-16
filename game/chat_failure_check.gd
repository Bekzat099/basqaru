extends SceneTree
var app
func _initialize():
	call_deferred("check")
func check():
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var raw = JSON.parse_string(FileAccess.get_file_as_string("/home/yernur/basqaru/data/3adf2ac53eb2124df5f9812043279875.json"))
	app.session = raw
	app.current = 1
	app.api_url = "http://127.0.0.1:9"
	app.show_interview()
	app.question.text = "Нақты бір мысал келтіріңіз."
	app.send_button.pressed.emit()
	assert(app.busy and app.chat_waiting and app.send_button.disabled)
	assert(not app.question.editable)
	while app.busy: await create_timer(0.1).timeout
	assert(not app.chat_waiting)
	assert(not app.send_button.disabled and app.question.editable)
	assert(app.question.text == "Нақты бір мысал келтіріңіз.")
	assert(is_instance_valid(app.modal))
	print("CHAT_FAILURE_PASS: waiting state, send lock, recovered controls, preserved question, visible error")
	quit()
