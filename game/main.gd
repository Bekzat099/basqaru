extends Control

const INK = Color("22242b")
const GOLD = Color("b6c9df")
const PAPER = Color("f1f2f5")
const MUTED = Color("aeb3c0")
const TEAL = Color("667b95")
var body = preload("res://assets/body.ttf")
var display = preload("res://assets/display.ttf")
var background: TextureRect
var ui: Control
var modal: Control
var session = {}
var app_session = {}
var job_is_applicant = false
var current = 0
var busy = false
var generation = false
var job = ""
var last_session = ""
var screen = "menu"
var chat_box: RichTextLabel
var question: LineEdit
var send_button: Button
var quick_buttons: Array[Button] = []
var chat_status: Label
var chat_started_at = 0
var chat_waiting = false
var status_label: Label
var company_input: LineEdit
var description_input: TextEdit
var app_form_last: LineEdit
var app_form_first: LineEdit
var app_form_age: LineEdit
var app_form_position: LineEdit
var app_form_achievements: TextEdit
var app_form_salary: LineEdit
var q_count_label: Label
var app_report_button: Button
var mic_button: Button
var voice_button: Button
var mic: AudioStreamMicrophone
var mic_timer: Timer
var mic_recording = false
var voice_enabled = true
var tts_player: AudioStreamPlayer
var tts_pending = ""
var poll_timer: Timer
var api_url = "http://127.0.0.1:18765"
var textures = {}

func _ready():
	var t = Theme.new()
	t.default_font = body
	t.default_font_size = 18
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("747985"))
	t.set_stylebox("normal", "Button", style(Color("383c48"), 8))
	t.set_stylebox("hover", "Button", style(Color("4b5363"), 8))
	t.set_stylebox("pressed", "Button", style(Color("58677b"), 8))
	t.set_stylebox("disabled", "Button", style(Color("2c2f38"), 8))
	var focus = style(Color.TRANSPARENT, 8)
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	t.set_stylebox("focus", "Button", focus)
	for kind in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", kind, style(Color("2b2e38"), 8))
		t.set_stylebox("focus", kind, focus)
		t.set_color("font_color", kind, PAPER)
		t.set_color("font_placeholder_color", kind, MUTED)
		t.set_color("caret_color", kind, GOLD)
	t.set_color("default_color", "RichTextLabel", PAPER)
	theme = t
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	var cfg = ConfigFile.new()
	if cfg.load("user://progress.cfg") == OK:
		last_session = cfg.get_value("save", "session", "")
	var configured_url = OS.get_environment("BASQARU_API_URL")
	if not configured_url.is_empty(): api_url = configured_url.trim_suffix("/")
	poll_timer = Timer.new()
	poll_timer.wait_time = 2.5
	poll_timer.timeout.connect(poll_job)
	add_child(poll_timer)
	show_menu()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-session="):
			last_session = arg.trim_prefix("--qa-session=")
			await resume_game()
		if arg.begins_with("--capture="):
			await get_tree().create_timer(2.0).timeout
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
		if arg == "--qa-actions":
			await qa_actions()
		if arg == "--qa-dossier":
			show_dossier()
		if arg == "--qa-team":
			show_team()
		if arg == "--qa-quit":
			get_tree().quit()

func style(color: Color, radius: int = 12) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func rect(c: Control, x: float, y: float, w: float, h: float, parent: Node = ui):
	parent.add_child(c)
	c.position = Vector2(x,y)
	c.size = Vector2(w,h)
	return c

func panel(x: float,y: float,w: float,h: float,parent: Node = ui, color: Color = Color("22242bf2")) -> Panel:
	var p = Panel.new()
	p.add_theme_stylebox_override("panel", style(color))
	rect(p,x,y,w,h,parent)
	return p

func label(text: String,x: float,y: float,w: float,h: float,fs: int=18,color: Color=PAPER,parent: Node=ui,serif: bool=false) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",fs)
	l.add_theme_color_override("font_color",color)
	if serif: l.add_theme_font_override("font",display)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rect(l,x,y,w,h,parent)
	return l

func button(text: String,x: float,y: float,w: float,h: float,callback: Callable,parent: Node=ui,accent: bool=false) -> Button:
	var b = Button.new()
	b.text = text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	if accent:
		b.add_theme_stylebox_override("normal",style(GOLD,8))
		b.add_theme_stylebox_override("hover",style(Color("d2dfef"),8))
		b.add_theme_color_override("font_color",INK)
		b.add_theme_color_override("font_hover_color",INK)
	rect(b,x,y,w,h,parent)
	return b

func clear_ui():
	if mic_recording:
		mic_recording = false
		if is_instance_valid(mic_timer): mic_timer.stop()
		if mic != null: mic.stop()
	if is_instance_valid(tts_player):
		tts_player.stop()
	tts_pending = ""
	close_modal()
	for c in ui.get_children():
		ui.remove_child(c)
		c.queue_free()

func photo(id: int = -1):
	var path = "res://assets/office.png" if id < 0 else "res://assets/candidate_%02d.png" % (id+1)
	if not textures.has(path):
		if ResourceLoader.exists(path): textures[path] = load(path)
		else: textures[path] = load("res://assets/office.png")
	background.texture = textures[path]

func photo_director():
	var path = "res://assets/director.jpg"
	if not textures.has(path):
		if ResourceLoader.exists(path): textures[path] = load(path)
		else: textures[path] = load("res://assets/office.png")
	background.texture = textures[path]

func show_menu():
	screen = "menu"
	clear_ui()
	photo()
	panel(50,45,570,810)
	label("B A S Q A R U",85,76,480,38,25,GOLD)
	label("Бәрі дұрыс\nадамдардан\nбасталады.",85,135,485,210,48,PAPER,ui,true)
	label("АЛМАТЫ  /  СІЗДІҢ АЛҒАШҚЫ КОМАНДАҢЫЗ",85,365,485,25,14,GOLD)
	label("Өз компанияңызды ашыңыз. Үміткерлермен сөйлесіп, бес адамнан тұратын команда құрыңыз.",85,409,470,85,21)
	button("Директор ретінде ойнау  →",85,505,495,60,show_setup,ui,true)
	button("Үміткер ретінде ойнау  →",85,577,495,60,show_applicant_form,ui,true)
	button("Шығу",85,649,495,52,func(): get_tree().quit())
	var cont = button("Сақталған ойынды жалғастыру",85,715,300,46,resume_game)
	cont.disabled = last_session.is_empty()
	button("Қалай ойнаймыз?",400,715,180,46,show_rules)
	label("15 үміткер   ·   5 орын   ·   100 ұпай",85,776,495,30,18,MUTED)
	label("ДИРЕКТОР КАБИНЕТІ",1190,54,350,30,16,Color.WHITE)
	label("Қазақстан, Алматы",1190,84,350,30,19,Color.WHITE)
	label("F11 — толық экран",1270,840,280,30,15,PAPER)

func show_setup():
	screen = "setup"
	clear_ui()
	photo()
	panel(70,55,650,790)
	label("BASQARU  /  ЖАҢА БАСТАМА",110,85,560,30,17,GOLD)
	label("Компанияңыз\nқандай болады?",110,135,560,130,42,PAPER,ui,true)
	label("Компания атауы",110,295,540,30)
	company_input = LineEdit.new()
	company_input.placeholder_text = "Мысалы, Qadam Studio"
	company_input.max_length = 60
	rect(company_input,110,337,560,54)
	label("Немен айналысасыз?",110,416,550,30)
	description_input = TextEdit.new()
	description_input.placeholder_text = "Мысалы: Қазақстандағы шағын бизнеске сайт пен мобильді қосымша жасаймыз. Сапа, адалдық және клиентпен түсінікті байланыс маңызды."
	description_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	rect(description_input,110,461,560,160)
	label("Осы сипаттамаға сай 15 үміткердің тәжірибесі мен мінезі қалыптасады. Айлық қор: 2 200 000 ₸.",110,638,555,60,16,MUTED)
	button("Үміткерлерді шақыру  →",110,726,375,62,start_game,ui,true)
	button("Артқа",500,726,170,62,show_menu)
	company_input.grab_focus()

func show_applicant_form():
	screen = "applicant_form"
	clear_ui()
	photo_director()
	panel(70,55,650,790)
	label("BASQARU  /  ҮМІТКЕР АНКЕТАСЫ",110,85,560,30,17,GOLD)
	label("Өзіңізді\ntаныстырыңыз",110,135,560,130,42,PAPER,ui,true)
	label("Тегі",110,285,540,30)
	app_form_last = LineEdit.new()
	app_form_last.placeholder_text = "Мысалы: Серіков"
	app_form_last.max_length = 40
	rect(app_form_last,110,317,560,52)
	label("Аты",110,383,540,30)
	app_form_first = LineEdit.new()
	app_form_first.placeholder_text = "Мысалы: Айдана"
	app_form_first.max_length = 40
	rect(app_form_first,110,415,560,52)
	label("Жасы",110,481,250,30)
	app_form_age = LineEdit.new()
	app_form_age.placeholder_text = "Мысалы: 29"
	app_form_age.max_length = 3
	rect(app_form_age,110,513,260,52)
	label("Қалаған айлық, ₸",390,481,280,30)
	app_form_salary = LineEdit.new()
	app_form_salary.placeholder_text = "Мысалы: 400 000"
	app_form_salary.max_length = 12
	rect(app_form_salary,390,513,280,52)
	label("Қай лауазымға өтініш бересіз?",110,579,540,30)
	app_form_position = LineEdit.new()
	app_form_position.placeholder_text = "Мысалы: Маркетинг менеджері"
	app_form_position.max_length = 80
	rect(app_form_position,110,611,560,52)
	label("Бұл саладағы жетістіктеріңіз (бар болса)",110,677,540,30)
	app_form_achievements = TextEdit.new()
	app_form_achievements.placeholder_text = "Мысалы: CRM жобасын басқардым, конверсия 18%-ға өсті..."
	app_form_achievements.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	rect(app_form_achievements,110,709,560,70)
	button("Анкетаны жіберу  →",110,795,375,50,submit_application,ui,true)
	button("Артқа",500,795,170,50,show_menu)
	app_form_last.grab_focus()

func submit_application():
	if busy: return
	var last_t = app_form_last.text.strip_edges()
	var first_t = app_form_first.text.strip_edges()
	var pos_t = app_form_position.text.strip_edges()
	var age_t = app_form_age.text.strip_edges()
	var sal_t = app_form_salary.text.strip_edges().replace(" ","")
	if last_t.length()<2 or first_t.length()<2 or pos_t.length()<3 or age_t.is_empty() or sal_t.is_empty():
		show_message("Анкетаны толтырыңыз","Тегі, аты, жасы, лауазымы мен қалаған айлықты жазыңыз.")
		return
	if not age_t.is_valid_int() or not sal_t.is_valid_int():
		show_message("Сандар қажет","Жас пен айлықты санмен жазыңыз.")
		return
	busy = true
	var result = await api("/applicant/new",{"last_name":last_t,"first_name":first_t,"age":int(age_t),"position":pos_t,"achievements":app_form_achievements.text.strip_edges(),"salary":int(sal_t)})
	busy = false
	if result.has("error"):
		show_message("Қосылымды тексеріңіз",result.error)
		return
	job = result.job
	job_is_applicant = true
	generation = true
	screen = "loading"
	clear_ui()
	panel(100,250,620,390)
	label("Директор сізбен сөйлесуге\ndайындалып жатыр",140,280,540,115,36,PAPER,ui,true)
	label("Анкетасыңыз оқылып, сұрақтар дайындалуда.",140,414,540,70,20,MUTED)
	status_label = label("Сәл күте тұрыңыз…",140,517,540,35,22,GOLD)
	label("Бұл бірнеше минутқа созылуы мүмкін.",140,576,540,30,16,MUTED)
	poll_timer.start()

func start_game():
	if busy: return
	var name_text = company_input.text.strip_edges()
	var desc = description_input.text.strip_edges()
	if name_text.length()<2 or desc.length()<20 or desc.length()>1500:
		show_message("Атауды және сипаттаманы толтырыңыз", "Атау кемінде 2 таңба, сипаттама 20–1500 таңба болуы керек.")
		return
	busy = true
	var result = await api("/new", {"company":name_text,"description":desc})
	busy = false
	if result.has("error"):
		show_message("Қосылымды тексеріңіз",result.error)
		return
	job = result.job
	job_is_applicant = false
	generation = true
	screen = "loading"
	clear_ui()
	panel(100,250,620,390)
	label("Алғашқы таныстыққа\nдайындалып жатырмыз",140,280,540,115,36,PAPER,ui,true)
	label("Үміткерлер компанияңызбен танысып,\nанкеталарын дайындап жатыр.",140,414,540,70,20,MUTED)
	status_label = label("Дайын анкеталар: 0 / 15",140,517,540,35,22,GOLD)
	label("Бұл бірнеше минутқа созылуы мүмкін.",140,576,540,30,16,MUTED)
	poll_timer.start()

func poll_job():
	if not generation: return
	poll_timer.stop()
	var result = await api("/job",{"job":job})
	if result.has("error") or result.get("status","") == "error":
		generation = false
		if result.get("kind","") == "applicant":
			show_applicant_form()
			show_message("Сұхбат дайындалмады",result.get("error","Қайталап көріңіз."))
		else:
			show_setup()
			show_message("Үміткерлер дайындалмады",result.get("error","Қайталап көріңіз."))
		return
	if result.get("status","") == "ready":
		generation = false
		if result.get("kind","") == "applicant":
			await resume_applicant(result.session)
		else:
			last_session = result.session
			await resume_game()
	else:
		if is_instance_valid(status_label) and not job_is_applicant: status_label.text = "Дайын анкеталар: %d / 15" % result.get("progress",0)
		poll_timer.start()

func resume_game():
	if busy: return
	busy = true
	var result = await api("/load",{"session":last_session})
	busy = false
	if result.has("error"):
		show_message("Ойын ашылмады",result.error)
		return
	session = result
	var cfg = ConfigFile.new()
	cfg.set_value("save","session",last_session)
	cfg.save("user://progress.cfg")
	current = 0
	if session.finished: show_report()
	else: show_interview()

func candidate() -> Dictionary:
	return session.candidates[current]

func resume_applicant(sid: String):
	if busy: return
	busy = true
	var result = await api("/applicant/load",{"session":sid})
	busy = false
	if result.has("error"):
		show_message("Сұхбат ашылмады",result.error)
		return
	app_session = result
	show_applicant_interview()

func show_applicant_interview():
	screen = "applicant"
	clear_ui()
	photo_director()
	panel(24,20,1552,75)
	label("BASQARU  /  СҰХБАТ",46,38,260,36,25,GOLD)
	label(app_session.position,320,35,900,40,24)
	button("Мәзір",1409,34,144,48,func():
		if not busy: show_menu())
	panel(24,122,340,366)
	label("СІЗ  ·  ҮМІТКЕР",47,145,295,30,15,GOLD)
	label(app_session.first_name+" "+app_session.last_name,47,196,295,70,29,PAPER,ui,true)
	label(app_session.position,47,276,295,58,19)
	label(str(app_session.age)+" жас",47,342,295,32,15,MUTED)
	label(money(app_session.salary)+" / ай — қалаған",47,391,295,33,21,GOLD)
	panel(1176,122,400,540)
	label("ДИРЕКТОРМЕН СҰХБАТ",1200,137,270,26,15,GOLD)
	q_count_label = label("Сұрақ 1 / 10",1420,137,130,26,15,GOLD)
	q_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	update_q_count()
	chat_status = label("Жауабыңызды жазыңыз",1200,169,350,25,14,MUTED)
	chat_box = RichTextLabel.new()
	chat_box.bbcode_enabled = false
	chat_box.scroll_following = true
	chat_box.add_theme_font_size_override("normal_font_size",18)
	rect(chat_box,1200,207,350,337)
	refresh_app_chat()
	quick_buttons.clear()
	question = LineEdit.new()
	question.placeholder_text = "Директорға жауабыңызды жазыңыз…"
	question.max_length = 1500
	question.text_submitted.connect(func(_text): ask_app())
	panel(450,699,700,78)
	rect(question,468,715,490,46)
	send_button = button("Жіберу →",974,715,157,46,ask_app,ui,true)
	panel(24,804,1552,76)
	button("Сұхбаттан шығу",44,818,200,48,func():
		if not busy: show_menu())
	app_report_button = button("Қорытындыны алу  →",254,818,220,48,fetch_app_report)
	app_report_button.disabled = true
	mic_button = button("Сөйлеу",494,818,120,48,toggle_mic)
	voice_button = button("Дыбыс: ИА",622,818,120,48,toggle_voice)
	label("Микрофонмен жауап берсеңіз — директор да дауысмен жауап береді",750,826,760,30,16,MUTED)
	if voice_enabled:
		play_director_voice(app_session.get("intro",""))

func update_q_count():
	if not is_instance_valid(q_count_label): return
	if app_session.get("finished",false):
		q_count_label.text = "Сұхбат аяқталды"
		return
	var n = 1
	for m in app_session.histories:
		if m.role=="assistant": n += 1
	q_count_label.text = "Сұрақ %d / 10" % mini(n,10)

func refresh_app_chat():
	chat_box.text = "Директор\n"+app_session.intro+"\n\n"
	for m in app_session.histories:
		chat_box.text += ("Сіз" if m.role=="user" else "Директор")+"\n"+m.content+"\n\n"
	update_q_count()

func ask_app():
	if busy: return
	var message = question.text.strip_edges()
	if message.is_empty(): return
	busy = true
	set_chat_waiting(true)
	chat_box.text += "Сіз\n"+message+"\n\nДиректор ойланып жатыр…\n"
	var result = await api("/applicant/chat",{"session":app_session.id,"message":message})
	busy = false
	set_chat_waiting(false)
	if result.has("error"):
		chat_status.text = "Жауап алынбады. Қайталап көріңіз."
		refresh_app_chat()
		show_message("Жауап алынбады",result.error+"\nЖауабыңыз сақталды. Қайталап жіберуге болады.")
		question.text = message
		return
	app_session.histories.append({"role":"user","content":message})
	app_session.histories.append({"role":"assistant","content":result.answer})
	question.text = ""
	chat_status.text = "Alem AI · жауап алынды"
	refresh_app_chat()
	play_director_voice(result.answer)
	if result.has("finished") and result.finished:
		app_session.finished = true
		chat_status.text = "Сұхбат аяқталды · Қорытынды дайындалуда…"
		question.editable = false
		question.placeholder_text = "Сұхбат аяқталды"
		send_button.disabled = true
		send_button.text = "Аяқталды"
		update_q_count()
		if is_instance_valid(app_report_button): app_report_button.disabled = false
		await fetch_app_report()
		return
	question.grab_focus()

func fetch_app_report():
	if busy: return
	busy = true
	if is_instance_valid(app_report_button):
		app_report_button.disabled = true
		app_report_button.text = "Қорытынды дайындалуда…"
	if is_instance_valid(chat_status): chat_status.text = "Қорытынды дайындалуда…"
	var rep = await api("/applicant/report",{"session":app_session.id})
	busy = false
	if rep.has("error"):
		if is_instance_valid(app_report_button):
			app_report_button.disabled = false
			app_report_button.text = "Қорытындыны алу  →"
		if is_instance_valid(chat_status): chat_status.text = "Қорытынды алынбады. Қайталап көріңіз."
		show_message("Қорытынды дайындалмады",rep.error+"\n«Қорытындыны алу» батырмасымен қайталауға болады.")
		return
	app_session.report = rep.get("report",{})
	show_applicant_report()

func show_applicant_report():
	screen = "applicant_report"
	clear_ui()
	photo_director()
	panel(65,45,1470,810)
	var r: Dictionary = app_session.get("report",{})
	var score: int = int(r.get("score",0))
	var headline: String = str(r.get("headline",""))
	label("BASQARU  /  СҰХБАТ ҚОРЫТЫНДЫСЫ",105,75,900,35,19,GOLD)
	label(headline,105,145,1000,75,40,PAPER,ui,true)
	label(str(score),105,250,270,150,115,GOLD)
	label("/ 100 ұпай",110,405,270,40,25,MUTED)
	label(app_session.first_name+" "+app_session.last_name,105,467,380,50,24)
	label(app_session.position+"  ·  "+str(app_session.age)+" жас",105,520,380,50,18,MUTED)
	button("Жаңа сұхбат  →",105,705,330,60,show_applicant_form,ui,true)
	button("Мәзір",105,778,330,45,show_menu)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rect(scroll,520,160,960,640)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",15)
	scroll.add_child(box)
	var summary: String = str(r.get("summary",""))
	paragraph(box,"ТАЛДАУ",16,MUTED)
	paragraph(box,summary,19)
	paragraph(box,"КҮШТІ ЖАҚТАРЫ",16,MUTED)
	var strengths: Array = r.get("strengths",[])
	for s in strengths: paragraph(box,"+  "+str(s),19)
	paragraph(box,"ҚАТЕЛЕР",16,MUTED)
	var mistakes: Array = r.get("mistakes",[])
	for m in mistakes: paragraph(box,"−  "+str(m),19)
	paragraph(box,"ҰСЫНЫСТАР",16,MUTED)
	var recommendations: Array = r.get("recommendations",[])
	for rec in recommendations: paragraph(box,"•  "+str(rec),19)

func money(value) -> String:
	var v = str(int(value))
	var out = ""
	for i in range(v.length()):
		if i>0 and (v.length()-i)%3==0: out += " "
		out += v[i]
	return out + " ₸"

func spent() -> int:
	var sum_salary = 0
	for c in session.candidates:
		if c.id in session.selected: sum_salary += int(c.salary)
	return sum_salary

func show_interview():
	screen = "interview"
	clear_ui()
	var c = candidate()
	photo(int(c.id))
	panel(24,20,1552,75)
	label("BASQARU",46,38,190,36,25,GOLD)
	label(session.company,244,35,640,40,24)
	button("Команда  %d / 5" % session.selected.size(),1045,34,220,48,show_team)
	button("Ереже",1277,34,120,48,show_rules)
	button("Мәзір",1409,34,144,48,func():
		if not busy: show_menu())
	panel(24,122,340,366)
	label("ҮМІТКЕР  %02d / 15" % (current+1),47,145,295,30,15,GOLD)
	label(c.name,47,196,295,70,29,PAPER,ui,true)
	label(c.role,47,276,295,58,19)
	label(c.group,47,342,295,32,15,MUTED)
	label(money(c.salary)+" / ай",47,391,295,33,21,GOLD)
	button("Анкетаны ашу  ↗",47,440,294,40,show_dossier)
	panel(24,510,340,160)
	label("АЙЛЫҚ ҚОР",47,529,295,25,14,MUTED)
	label(money(spent()),47,565,295,40,28,GOLD)
	label("Бюджет: "+money(session.budget),47,618,295,28,16,MUTED)
	panel(1176,122,400,540)
	label("ӘҢГІМЕЛЕСУ",1200,137,350,26,15,GOLD)
	chat_status = label("Сұрағыңызды қойыңыз",1200,169,350,25,14,MUTED)
	chat_box = RichTextLabel.new()
	chat_box.bbcode_enabled = false
	chat_box.scroll_following = true
	chat_box.add_theme_font_size_override("normal_font_size",18)
	rect(chat_box,1200,207,350,337)
	refresh_chat()
	quick_buttons.clear()
	quick_buttons.append(button("Бір жетістігіңіз туралы айтыңыз",1200,557,350,38,func(): ask("Нақты бір жұмыс жетістігіңіз туралы айтыңыз. Өзіңіз не істедіңіз?")))
	quick_buttons.append(button("Қиындықты қалай шештіңіз?",1200,604,350,38,func(): ask("Жұмыста жіберген қатеңіз және оны қалай түзеткеніңіз туралы нақты мысал келтіріңіз.")))
	question = LineEdit.new()
	question.placeholder_text = "Сұрағыңызды жазыңыз…"
	question.max_length = 1500
	question.text_submitted.connect(func(_text): ask())
	panel(450,699,700,78)
	rect(question,468,715,490,46)
	send_button = button("Жіберу →",974,715,157,46,ask,ui,true)
	panel(24,804,1552,76)
	button("← Алдыңғы",44,818,190,48,func(): navigate(-1))
	button("Келесі →",248,818,180,48,func(): navigate(1))
	button("Үміткерлер",444,818,190,48,show_candidates)
	var hired = c.id in session.selected
	var choose = button("Командадан шығару" if hired else "Командаға қабылдау",890,818,340,48,toggle_hire,ui,not hired)
	choose.disabled = not hired and session.selected.size()>=5
	var finish = button("Қорытынды →",1246,818,307,48,confirm_finish)
	finish.disabled = session.selected.size()!=5

func refresh_chat():
	var c = candidate()
	chat_box.text = c.name+"\n"+c.intro+"\n\n"
	for m in session.histories.get(str(int(c.id)),[]):
		chat_box.text += ("Сіз" if m.role=="user" else c.name)+"\n"+m.content+"\n\n"

func navigate(delta: int):
	if busy: return
	current = posmod(current+delta,15)
	show_interview()

func ask(preset: String=""):
	if busy: return
	var message = preset if not preset.is_empty() else question.text.strip_edges()
	if message.is_empty(): return
	busy = true
	set_chat_waiting(true)
	chat_box.text += "Сіз\n"+message+"\n\nЖауап беріп жатыр…\n"
	var result = await api("/chat",{"session":session.id,"candidate":int(candidate().id),"message":message})
	busy = false
	set_chat_waiting(false)
	if result.has("error"):
		chat_status.text = "Жауап алынбады. Қайталап көріңіз."
		refresh_chat()
		show_message("Жауап алынбады",result.error+"\nСұрағыңыз сақталды. Қайталап жіберуге болады.")
		question.text = message
		return
	var key = str(int(candidate().id))
	if not session.histories.has(key): session.histories[key] = []
	session.histories[key].append({"role":"user","content":message})
	session.histories[key].append({"role":"assistant","content":result.answer})
	question.text = ""
	chat_status.text = "Alem AI · жауап алынды"
	refresh_chat()
	question.grab_focus()

func toggle_hire():
	if busy: return
	var chosen = session.selected.duplicate()
	var id = int(candidate().id)
	if id in chosen: chosen.erase(id)
	elif chosen.size()<5: chosen.append(id)
	else: return
	busy = true
	var result = await api("/team",{"session":session.id,"selected":chosen})
	busy = false
	if result.has("error"): show_message("Таңдау сақталмады",result.error)
	else:
		session = result
		show_interview()

func make_modal(title_text: String, width: int=860, height: int=730) -> VBoxContainer:
	close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var shade = ColorRect.new()
	shade.color = Color(0.025,0.026,0.035,0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var x = (1600-width)/2.0
	var y = (900-height)/2.0
	panel(x,y,width,height,modal,Color("22242b"))
	label(title_text,x+32,y+24,width-125,60,29,PAPER,modal,true)
	button("×",x+width-78,y+25,48,44,close_modal,modal)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rect(scroll,x+32,y+110,width-64,height-140,modal)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",18)
	scroll.add_child(box)
	return box

func paragraph(box: VBoxContainer,text: String,fs: int=19,color: Color=PAPER) -> Label:
	var l = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",fs)
	l.add_theme_color_override("font_color",color)
	box.add_child(l)
	return l

func close_modal():
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = null

func show_message(title_text: String,text: String):
	var box = make_modal(title_text,760,420)
	paragraph(box,text)

func show_dossier():
	var c = candidate()
	var box = make_modal("Үміткердің анкетасы")
	paragraph(box,c.name,32,GOLD)
	paragraph(box,"%d жас  ·  %s\n%s / ай" % [c.age,c.role,money(c.salary)],20)
	paragraph(box,"ӨЗІ ТУРАЛЫ",15,MUTED)
	paragraph(box,c.summary)
	paragraph(box,"ТӘЖІРИБЕ",15,MUTED)
	paragraph(box,c.experience)
	paragraph(box,"БІЛІМ",15,MUTED)
	paragraph(box,c.education)
	paragraph(box,"ДАҒДЫЛАР",15,MUTED)
	paragraph(box,"  ·  ".join(c.skills))
	paragraph(box,"Анкетаны үміткер өзі толтырған. Нақты мысалдар сұрап, тәжірибесін тексеріңіз.",16,GOLD)
	paragraph(box,"ДИРЕКТОРДЫҢ ЖАЗБАСЫ",15,MUTED)
	var note = TextEdit.new()
	note.custom_minimum_size = Vector2(0,110)
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note.placeholder_text = "Не ұнады? Нені нақтылау керек?"
	note.text = session.notes.get(str(int(c.id)),"")
	box.add_child(note)
	var save_button = Button.new()
	save_button.text = "Жазбаны сақтау"
	save_button.custom_minimum_size.y = 48
	box.add_child(save_button)
	save_button.pressed.connect(func():
		if busy: return
		busy = true
		var note_text = note.text.left(2000)
		var result = await api("/note",{"session":session.id,"candidate":int(c.id),"note":note_text})
		busy = false
		if result.has("error"): show_message("Жазба сақталмады",result.error)
		else:
			session.notes[str(int(c.id))] = note_text
			if is_instance_valid(save_button): save_button.text = "Сақталды ✓")

func show_candidates():
	if busy: return
	var box = make_modal("Күту бөлмесі · 15 үміткер",960,790)
	for i in range(15):
		var c = session.candidates[i]
		var b = Button.new()
		b.text = "%02d   %s   /   %s%s" % [i+1,c.name,c.group,"  ✓" if c.id in session.selected else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 50
		box.add_child(b)
		b.pressed.connect(func():
			if busy: return
			current = i
			show_interview())

func show_team():
	var box = make_modal("Сіздің командаңыз · %d / 5" % session.selected.size(),920,750)
	paragraph(box,money(spent())+" / "+money(session.budget),25,GOLD)
	if spent()>int(session.budget): paragraph(box,"Айлық қор бюджеттен асып тұр. Бұл қорытынды бағаға әсер етеді.",17,Color("efb68c"))
	if session.selected.is_empty(): paragraph(box,"Команда әзірге бос. Сұхбаттан кейін лайықты үміткерлерді қабылдаңыз.")
	for c in session.candidates:
		if c.id in session.selected:
			paragraph(box,c.name+" · "+c.role,22)
			paragraph(box,c.group+"  /  "+money(c.salary),17,MUTED)
	var groups = []
	for c in session.candidates:
		if c.id in session.selected and c.group not in groups: groups.append(c.group)
	paragraph(box,"Бағыттар: %d / 5" % groups.size(),22,GOLD)
	paragraph(box,"Өнім және қызмет · Клиенттер · Операциялар · Қаржы · Өсу және маркетинг",18,MUTED)
	paragraph(box,"Құрамды өзгерту үшін үміткерге оралып, «Командадан шығару» батырмасын басыңыз.",17)

func show_rules():
	var box = make_modal("Директордың қысқа нұсқаулығы",900,770)
	paragraph(box,"Мақсат — компанияңызға сай бес адамды таңдау.",26,GOLD)
	paragraph(box,"15 үміткердің анкетасын оқыңыз. Өз сұрақтарыңызды қойыңыз: әрқайсының тәжірибесі мен мінезі бөлек. Жетістік, қате, келіспеушілік туралы нақты мысал сұраңыз.")
	paragraph(box,"Бір бағытқа бірнеше адам алуға болады, бірақ бес бағыттың бәрін қамту командаға көбірек ұпай береді. Айлық бюджет — 2 200 000 ₸.")
	paragraph(box,"100 ҰПАЙ ҚАЛАЙ ЕСЕПТЕЛЕДІ?",17,GOLD)
	paragraph(box,"35 — кәсіби дағды\n20 — сенімділік\n20 — командалық жұмыс\n15 — бес бағыттың қамтылуы\n10 — бюджет тәртібі",21)
	paragraph(box,"Қабілет бағалары команданың орташа көрсеткішінен есептеледі. Әр қамтылған бағыт +3 ұпай. Бюджеттен 25% немесе одан көп асып кетсеңіз, бюджет ұпайы 0 болады.",17,MUTED)
	paragraph(box,"80–100: мықты команда. 60–79: әлеуеті бар команда. 0–59: өзгеріс қажет. Баға жасқа, жынысқа немесе сырт келбетке байланысты емес.",18)
	paragraph(box,"ҮМІТКЕР РЕТІНДЕ ОЙНАУ:",17,GOLD)
	paragraph(box,"Анкета толтырасың: тегі, аты, лауазым, жетістіктер, қалаған айлық — ол сенің профильің. AI-директор осы бағыттың маманы ретінде 10 сұрақ қояды. Жауапты теріп немесе дауысыңмен бере аласың («Сөйлеу» батырмасы — сөйле, ИИ мәтінге айналдырады; «Дыбыс» — директордың дауысын қосу/өшіру). Сұхбат соңында 100 баллдық қорытынды: ұпай, талдау, күшті жақтар, нақты қателер және кеңестер.")
	paragraph(box,"Қорытындыға дейін таңдауды өзгерте аласыз. Сұхбаттар, команда және сақталған жазбалар автоматты сақталады. F11 — толық экран, Esc — терезені жабу / мәзір.",16,MUTED)

func confirm_finish():
	if busy: return
	var box = make_modal("Команда дайын ба?",760,420)
	paragraph(box,"Бес адам таңдалды. Қорытындыдан кейін осы ойындағы құрамды өзгерту мүмкін болмайды. Жаңа компаниямен қайта бастай аласыз.")
	var b = Button.new()
	b.text = "Иә, команданы бағалау"
	b.custom_minimum_size.y = 55
	box.add_child(b)
	b.pressed.connect(finish_game)

func finish_game():
	if busy: return
	busy = true
	var result = await api("/finish",{"session":session.id})
	busy = false
	if result.has("error"): show_message("Қорытынды алынбады",result.error)
	else:
		session = result
		show_report()

func show_report():
	screen = "report"
	clear_ui()
	photo()
	panel(65,45,1470,810)
	var report = session.report
	label("BASQARU  /  "+session.company,105,75,1280,35,19,GOLD)
	label(report.headline,105,145,1000,75,44,PAPER,ui,true)
	label(str(int(report.score)),105,250,270,150,115,GOLD)
	label("/ 100 ұпай",110,405,270,40,25,MUTED)
	label("Командаңыздың алғашқы қадамы",105,467,370,65,24)
	label("Айлық қор\n"+money(report.spent),105,560,380,70,22,GOLD)
	button("Жаңа компания құру  →",105,705,330,60,show_setup,ui,true)
	button("Мәзір",105,778,330,45,show_menu)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rect(scroll,520,247,960,550)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",15)
	scroll.add_child(box)
	for key in report.parts:
		paragraph(box,key+"   ·   "+str(report.parts[key])+" ұпай",23,GOLD)
	paragraph(box,"КЕЛЕСІ ҚАДАМ",16,MUTED)
	for advice in report.advice: paragraph(box,"• "+advice,19)
	paragraph(box,"КОМАНДА ТУРАЛЫ",16,MUTED)
	for member in report.members:
		paragraph(box,member.name+" · "+member.role,22,GOLD)
		paragraph(box,"Күшті жағы: "+member.strength+"\nДамыту керек: "+member.weakness,18)

func toggle_mic():
	if mic_recording:
		stop_mic()
	else:
		start_mic()

func start_mic():
	if mic == null:
		mic = AudioStreamMicrophone.new()
		mic.frequency = 16000
		mic.stereo = false
	var err = mic.start()
	if err != OK:
		if is_instance_valid(chat_status): chat_status.text = "Микрофон қосылмады (код %d)" % err
		show_message("Микрофон қосылмады","Тіркелген микрофонды тексеріңіз. Windows рұқсат сұраса — беріңіз. Немесе қалтырып жауап жазыңыз.")
		return
	mic_recording = true
	if is_instance_valid(mic_button): mic_button.text = "Тоқтату"
	if is_instance_valid(chat_status): chat_status.text = "Дыбыс жазылып жатыр… (ең көбі 30 секунд, соңында «Тоқтату»)"
	mic_timer = Timer.new()
	mic_timer.one_shot = true
	mic_timer.wait_time = 30.0
	mic_timer.timeout.connect(stop_mic)
	add_child(mic_timer)
	mic_timer.start()

func stop_mic():
	if not mic_recording: return
	mic_recording = false
	if is_instance_valid(mic_timer): mic_timer.stop()
	var data: PackedByteArray = mic.stop()
	if is_instance_valid(mic_button): mic_button.text = "Сөйлеу"
	if data.size() < 20000:
		if is_instance_valid(chat_status): chat_status.text = "Жазба қысқа шықты — қайта айтсаңыз"
		return
	if is_instance_valid(chat_status): chat_status.text = "Сөзіңіз танылуда… (алғаш рет 20–30 сек)"
	var res = await api("/stt",{"b64":Marshalls.raw_to_base64(data)})
	if res.has("error"):
		if is_instance_valid(chat_status): chat_status.text = "Дауыс танылмады: " + str(res.error)
		return
	var text: String = str(res.get("text","")).strip_edges()
	if text.is_empty():
		if is_instance_valid(chat_status): chat_status.text = "Еш нәрсе естілмеді — қайта айтсаңыз"
		return
	question.text = text
	question.grab_focus()
	if is_instance_valid(chat_status): chat_status.text = "Жазылып қалды — оқып «Жіберу» басыңыз"

func toggle_voice():
	voice_enabled = not voice_enabled
	if is_instance_valid(voice_button):
		voice_button.text = "Дыбыс: ИА" if voice_enabled else "Дыбыс: ЖОҚ"
	if not voice_enabled and is_instance_valid(tts_player):
		tts_player.stop()

func play_director_voice(text: String):
	if not voice_enabled or text.strip_edges().is_empty(): return
	if is_instance_valid(tts_player) and tts_player.playing:
		tts_pending = text
		return
	_tts_play(text)

func _tts_play(text: String):
	if tts_player == null:
		tts_player = AudioStreamPlayer.new()
		add_child(tts_player)
		var on_done = func():
			if not tts_player.playing and tts_pending != "":
				var t = tts_pending
				tts_pending = ""
				_tts_play(t)
		tts_player.finished.connect(on_done)
	var res = await api_audio("/tts",{"text":text})
	if res.has("error"):
		if is_instance_valid(chat_status): chat_status.text = "Дыбыс қосылмады: " + str(res.error)
		return
	var mp3 = AudioStreamMP3.new()
	mp3.data = res.get("data")
	tts_player.stream = mp3
	tts_player.play()

func api_audio(path: String, payload: Dictionary) -> Dictionary:
	var request = HTTPRequest.new()
	request.timeout = 120
	add_child(request)
	var headers = PackedStringArray(["Content-Type: application/json", "X-Basqaru-Token: "+OS.get_environment("BASQARU_TOKEN")])
	var err = request.request(api_url+path,headers,HTTPClient.METHOD_POST,JSON.stringify(payload))
	if err != OK:
		request.queue_free()
		return {"error":"Қызметке қосылу мүмкін болмады."}
	var response = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"error":"Дауыс қызметі жауап бермеді. Қайталап көріңіз."}
	return {"data": response[3]}

func api(path: String, payload: Dictionary) -> Dictionary:
	var request = HTTPRequest.new()
	request.timeout = 175
	add_child(request)
	var headers = PackedStringArray(["Content-Type: application/json", "X-Basqaru-Token: "+OS.get_environment("BASQARU_TOKEN")])
	var err = request.request(api_url+path,headers,HTTPClient.METHOD_POST,JSON.stringify(payload))
	if err != OK:
		request.queue_free()
		return {"error":"Қызметке қосылу мүмкін болмады. Ойынды run арқылы іске қосыңыз."}
	var response = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"error":"Қызмет жауап бермеді. Интернетті тексеріп, қайталап көріңіз."}
	var parsed = JSON.parse_string(response[3].get_string_from_utf8())
	if not parsed is Dictionary: return {"error":"Қызметтен түсініксіз жауап келді. Қайталап көріңіз."}
	if parsed.has("candidates"):
		for c in parsed.candidates: c.id = int(c.id)
		parsed.selected = parsed.selected.map(func(id): return int(id))
	return parsed

func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var mode = DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		if event.keycode == KEY_ESCAPE and not busy and not generation:
			if is_instance_valid(modal): close_modal()
			elif screen != "menu": show_menu()

func qa_actions():
	assert(screen == "interview")
	assert(session.candidates.size() == 15)
	for index in range(15):
		current = index
		show_interview()
		assert(background.texture != null)
	show_candidates()
	assert(is_instance_valid(modal))
	close_modal()
	show_rules()
	close_modal()
	current = 0
	show_interview()
	var selected_before = session.selected.size()
	await toggle_hire()
	assert(session.selected.size() == selected_before+1)
	await toggle_hire()
	assert(session.selected.size() == selected_before)
	show_dossier()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/home/yernur/basqaru/data/dossier.png")
	close_modal()
	for index in [0,1,2,3,4]:
		current = index
		show_interview()
		await toggle_hire()
	assert(session.selected.size() == 5)
	show_team()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/home/yernur/basqaru/data/team.png")
	close_modal()
	await finish_game()
	assert(screen == "report")
	assert(session.finished)
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/home/yernur/basqaru/data/report.png")
	print("NATIVE UI PASS: all 15 scenes, dossier, team add/remove, persistence, finish and report")

func set_chat_waiting(waiting: bool):
	chat_waiting = waiting
	question.editable = not waiting
	send_button.disabled = waiting
	send_button.text = "Күтіңіз…" if waiting else "Жіберу →"
	for b in quick_buttons: b.disabled = waiting
	if waiting:
		chat_started_at = Time.get_ticks_msec()
		chat_status.text = "Alem AI жауап дайындап жатыр…"

func _process(_delta):
	if chat_waiting and is_instance_valid(chat_status):
		var elapsed = int((Time.get_ticks_msec()-chat_started_at)/1000)
		chat_status.text = "Alem AI · жауап күтілуде · %d с" % elapsed
