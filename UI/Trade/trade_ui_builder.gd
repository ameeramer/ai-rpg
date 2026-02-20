extends RefCounted
## Trade UI builder — constructs the trade UI layout. Under 100 lines.

func build(ui) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color(0.55, 0.45, 0.28, 1)
	style.set_corner_radius_all(12)
	for m in ["content_margin_left", "content_margin_right"]:
		style.set(m, 16)
	for m in ["content_margin_top", "content_margin_bottom"]:
		style.set(m, 12)
	ui.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	ui.add_child(vbox)
	var hdr = HBoxContainer.new()
	vbox.add_child(hdr)
	ui._title = _lbl("", 36, Color(1, 0.9, 0.5), hdr)
	ui._title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var xb = Button.new()
	xb.text = "X"
	xb.custom_minimum_size = Vector2(72, 60)
	xb.add_theme_font_size_override("font_size", 36)
	xb.pressed.connect(Callable(ui, "_on_close"))
	hdr.add_child(xb)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(row)
	row.add_child(_grid_panel("Your Offer", true, ui))
	row.add_child(_grid_panel("Their Offer", false, ui))
	ui._status = _lbl("Tap items to offer", 22, Color(0.8, 0.8, 0.6), vbox)
	ui._status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui._status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var br = HBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_theme_constant_override("separation", 16)
	vbox.add_child(br)
	ui._offer_btn = _mbtn("Send Offer", 220, br, Callable(ui, "_on_offer"))
	ui._accept_btn = _mbtn("Accept Trade", 220, br, Callable(ui, "_on_accept"))
	ui._accept_btn.visible = false
	ui._decline_btn = _mbtn("Decline", 160, br, Callable(ui, "_on_decline"))
	ui._decline_btn.visible = false

func _lbl(t: String, sz: int, c: Color, p: Control) -> Label:
	var l = Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	p.add_child(l)
	return l

func _mbtn(t: String, w: int, p: Control, cb: Callable) -> Button:
	var b = Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, 66)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	p.add_child(b)
	return b

func _grid_panel(title: String, is_p: bool, ui) -> VBoxContainer:
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l = _lbl(title, 28, Color(0.6, 1, 0.6) if is_p else Color(0.4, 0.7, 1.0), vb)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var g = GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	if is_p:
		ui._pgrid = g
	else:
		ui._ngrid = g
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 250)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(g)
	vb.add_child(sc)
	return vb
