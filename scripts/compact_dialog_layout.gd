extends RefCounted

# Shared sizing for text notifications; full-screen books and portrait dialogue
# panels intentionally keep their own layout.
static func bind(panel: Panel, title: Label, body: Label, buttons: Array[Button]) -> void:
	var panel_ref: WeakRef = weakref(panel)
	var title_ref: WeakRef = weakref(title)
	var body_ref: WeakRef = weakref(body)
	var button_refs: Array[WeakRef] = []
	for button: Button in buttons:
		button_refs.append(weakref(button))
	panel.visibility_changed.connect(func() -> void:
		var current_panel: Panel = panel_ref.get_ref()
		if current_panel != null and current_panel.is_visible_in_tree():
			_fit_refs.call_deferred(panel_ref, title_ref, body_ref, button_refs)
	)


static func _fit_refs(panel_ref: WeakRef, title_ref: WeakRef, body_ref: WeakRef, button_refs: Array[WeakRef]) -> void:
	var panel: Panel = panel_ref.get_ref()
	var title: Label = title_ref.get_ref()
	var body: Label = body_ref.get_ref()
	if panel == null or title == null or body == null:
		return
	var buttons: Array[Button] = []
	for button_ref: WeakRef in button_refs:
		var button: Button = button_ref.get_ref()
		if button == null:
			return
		buttons.append(button)
	fit(panel, title, body, buttons)


static func fit(panel: Panel, title: Label, body: Label, buttons: Array[Button]) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(body):
		return
	var row_width := 0.0
	for button: Button in buttons:
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		var width := maxf(140.0, ceilf(font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + 44.0)
		button.custom_minimum_size = Vector2(width, 48)
		button.size = Vector2(width, 48)
		row_width += width
	row_width += 16.0 * maxf(0, buttons.size() - 1)
	var title_width := title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
	var width := maxf(580.0, maxf(row_width, title_width) + 56.0)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.position = Vector2(28, 24)
	title.size = Vector2(width - 56, 0)
	title.size.y = ceilf(title.get_minimum_size().y)
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.position = Vector2(28, title.position.y + title.size.y + 20)
	body.size = Vector2(width - 56, 0)
	body.size.y = ceilf(body.get_minimum_size().y) + 4
	var button_y := body.position.y + body.size.y + 24
	var button_x := (width - row_width) * 0.5
	for button: Button in buttons:
		button.position = Vector2(button_x, button_y)
		button_x += button.size.x + 16
	panel.size = Vector2(width, button_y + 48 + 28)
	panel.position = (panel.get_viewport_rect().size - panel.size) * 0.5
