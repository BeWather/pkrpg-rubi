extends CanvasLayer
## On-screen virtual gamepad para Android touch.
## Estrategia: CanvasLayer > Control + Button pattern (native Godot 4 UI).

enum GamepadMode { AUTO, TOUCH, LEGACY }

@export_enum("Auto", "Touch", "Legacy") var modo: String = "Auto"

const ACTION_MAP := {
	"BtnUp": "btn_arriba",
	"BtnDown": "btn_abajo",
	"BtnLeft": "btn_izquierda",
	"BtnRight": "btn_derecha",
	"BtnAction": "btn_accion",
	"BtnCancel": "btn_cancelar",
	"BtnMenu": "btn_menu",
	"BtnSelect": "btn_select",
}

const BTN_SIZE := Vector2(20, 20)
const BTN_AC_SIZE := Vector2(20, 14)
const COLOR_NORMAL := Color(1, 1, 1, 0.22)
const COLOR_PRESSED := Color(1, 1, 0.5, 0.45)

func _make_normal_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_NORMAL
	s.border_color = Color(1, 1, 1, 0.45)
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	return s

func _make_pressed_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_PRESSED
	s.border_color = Color(1, 1, 0.5, 0.65)
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	return s

func _configure_button(btn: Button, size: Vector2, font_size: int, label: String, action: String) -> void:
	btn.custom_minimum_size = size
	btn.size = size
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	btn.z_index = 10
	btn.text = label
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0, 0, 0))
	btn.add_theme_color_override("font_hover_color", Color(0, 0, 0))
	btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0))
	btn.add_theme_stylebox_override("normal", _make_normal_style())
	btn.add_theme_stylebox_override("hover", _make_normal_style())
	btn.add_theme_stylebox_override("pressed", _make_pressed_style())
	btn.add_theme_stylebox_override("focus", _make_normal_style())
	btn.button_down.connect(_on_pressed.bind(action))
	btn.button_up.connect(_on_released.bind(action))

func _on_pressed(action: String) -> void:
	if action != "":
		Input.action_press(action, 1.0)
		var event := InputEventAction.new()
		event.action = StringName(action)
		event.pressed = true
		event.strength = 1.0
		Input.parse_input_event(event)

func _on_released(action: String) -> void:
	if action != "":
		Input.action_release(action)
		var event := InputEventAction.new()
		event.action = StringName(action)
		event.pressed = false
		Input.parse_input_event(event)

func _resolver_modo() -> GamepadMode:
	match modo:
		"Touch":
			return GamepadMode.TOUCH
		"Legacy":
			return GamepadMode.LEGACY

	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return GamepadMode.TOUCH
	return GamepadMode.LEGACY

func _ready() -> void:
	var modo_resuelto := _resolver_modo()
	if modo_resuelto == GamepadMode.LEGACY:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		print("[GAMEPAD] Modo legacy: overlay tactil desactivado")
		return

	print("[GAMEPAD] TouchGamepad _ready() - instanciando botones")
	var root := Control.new()
	root.name = "GamepadRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	# Anclajes relativos para que los controles permanezcan dentro del viewport
	# aunque el dispositivo tenga otra resolucion fisica.
	var anchors := {
		"BtnUp": [Vector2(0, 1), Vector2(32, -90), Vector2(52, -70)],
		"BtnDown": [Vector2(0, 1), Vector2(32, -50), Vector2(52, -30)],
		"BtnLeft": [Vector2(0, 1), Vector2(12, -70), Vector2(32, -50)],
		"BtnRight": [Vector2(0, 1), Vector2(52, -70), Vector2(72, -50)],
		"BtnAction": [Vector2(1, 1), Vector2(-44, -45), Vector2(-24, -31)],
		"BtnCancel": [Vector2(1, 1), Vector2(-68, -45), Vector2(-48, -31)],
		"BtnMenu": [Vector2(1, 0), Vector2(-56, 20), Vector2(-36, 40)],
		"BtnSelect": [Vector2(1, 0), Vector2(-32, 20), Vector2(-12, 40)],
	}
	var sizes := {
		"BtnUp": BTN_SIZE,
		"BtnDown": BTN_SIZE,
		"BtnLeft": BTN_SIZE,
		"BtnRight": BTN_SIZE,
		"BtnAction": BTN_AC_SIZE,
		"BtnCancel": BTN_AC_SIZE,
		"BtnMenu": BTN_SIZE,
		"BtnSelect": BTN_SIZE,
	}
	var labels := {
		"BtnUp": "^",
		"BtnDown": "v",
		"BtnLeft": "<",
		"BtnRight": ">",
		"BtnAction": "X",
		"BtnCancel": "Z",
		"BtnMenu": "M",
		"BtnSelect": "S",
	}
	for btn_name in ACTION_MAP:
		var btn := Button.new()
		btn.name = btn_name
		_configure_button(btn, sizes[btn_name], 9, labels[btn_name], ACTION_MAP[btn_name])
		btn.anchor_left = anchors[btn_name][0].x
		btn.anchor_top = anchors[btn_name][0].y
		btn.anchor_right = anchors[btn_name][0].x
		btn.anchor_bottom = anchors[btn_name][0].y
		btn.offset_left = anchors[btn_name][1].x
		btn.offset_top = anchors[btn_name][1].y
		btn.offset_right = anchors[btn_name][2].x
		btn.offset_bottom = anchors[btn_name][2].y
		root.add_child(btn)
		print("[GAMEPAD] Button created: %s -> %s" % [btn_name, ACTION_MAP[btn_name]])
	print("[GAMEPAD] All buttons created")
