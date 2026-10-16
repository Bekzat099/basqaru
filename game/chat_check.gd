extends SceneTree
var app
func _initialize():
	call_deferred("run_check")
func fail(message):
	push_error(message)
	quit(1)
func run_check():
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var loaded = await app.api("/load",{"session":OS.get_environment("BASQARU_TEST_SESSION")})
	if loaded.has("error"):
		fail(str(loaded));return
	app.session = loaded
	app.current = 1
	app.show_interview()
	await process_frame
	for method in ["button","enter"]:
		var key = str(int(app.candidate().id))
		var before = app.session.histories.get(key,[]).size()
		app.question.text = "Неге біздің компанияда жұмыс істегіңіз келеді?" if method=="button" else "Алдыңғы жауабыңызды нақты бір мысалмен түсіндіріңіз."
		var began = Time.get_ticks_msec()
		if method == "button":
			for control in app.ui.get_children():
				if control is Button and control.text == "Жіберу →":
					control.pressed.emit()
		else:
			app.question.grab_focus()
			await process_frame
			var event = InputEventKey.new()
			event.keycode = KEY_ENTER
			event.pressed = true
			Input.parse_input_event(event)
			await process_frame
		if not app.busy:
			fail(method+": request did not start");return
		print("CHAT_CHECK ",method," submitted to Alem AI")
		var ticks = 0
		while app.busy and Time.get_ticks_msec()-began<180000:
			await create_timer(1.0).timeout
			ticks += 1
			if ticks%15==0: print("CHAT_CHECK waiting ",ticks," seconds")
		if app.session.histories.get(key,[]).size()!=before+2:
			fail(method+": no new assistant response");return
		var reply = app.session.histories[key][-1].content
		if not app.chat_box.text.contains(reply):
			fail(method+": reply missing in visible chat");return
		print("CHAT_CHECK ",method," PASS seconds=",(Time.get_ticks_msec()-began)/1000.0," reply=",reply)
		await create_timer(0.5).timeout
		root.get_texture().get_image().save_png(OS.get_environment("BASQARU_TEST_CAPTURE")+"-"+method+".png")
	print("CHAT_CHECK ALL PASS")
	quit(0)
