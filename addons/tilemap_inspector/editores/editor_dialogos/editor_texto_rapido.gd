@tool
## Editor rápido de una sola clave de dialogos.csv (español + inglés).
## Pensado para abrirse desde el inspector (id_texto) o desde editor_dialogos
## sobre una clave puntual, sin pasar por el buscador completo.
## Punto de entrada: abrir_para_clave(id: String)
extends Window

## Emitida al guardar; quien abrió la ventana puede refrescar su propia UI.
signal guardado(id: String)

const DialogosCSV = preload("res://addons/tilemap_inspector/editores/editor_dialogos/dialogos_csv.gd")

var _id_actual: String = ""
var _label_clave: Label = null
var _edit_es: TextEdit = null
var _edit_en: TextEdit = null

func _ready() -> void:
	title = "Editor rápido de diálogo"
	size = Vector2i(560, 440)
	min_size = Vector2i(420, 320)
	close_requested.connect(func(): hide())
	_construir_ui()

func abrir_para_clave(id: String) -> void:
	_id_actual = id
	var fila := DialogosCSV.obtener_fila(id)
	_label_clave.text = "Clave: %s" % id
	_edit_es.text = String(fila.get("es", ""))
	_edit_en.text = String(fila.get("en", ""))
	popup_centered()
	grab_focus()

func _construir_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + lado, 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_label_clave = Label.new()
	_label_clave.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_label_clave)

	var lbl_es := Label.new()
	lbl_es.text = "Español"
	vbox.add_child(lbl_es)
	_edit_es = TextEdit.new()
	_edit_es.custom_minimum_size = Vector2(0, 130)
	_edit_es.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit_es.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(_edit_es)

	var lbl_en := Label.new()
	lbl_en.text = "Inglés"
	vbox.add_child(lbl_en)
	_edit_en = TextEdit.new()
	_edit_en.custom_minimum_size = Vector2(0, 130)
	_edit_en.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit_en.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(_edit_en)

	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 8)
	barra.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(barra)

	var btn_cancelar := Button.new()
	btn_cancelar.text = "Cancelar"
	btn_cancelar.pressed.connect(func(): hide())
	barra.add_child(btn_cancelar)

	var btn_guardar := Button.new()
	btn_guardar.text = "Guardar"
	btn_guardar.pressed.connect(_on_guardar_pressed)
	barra.add_child(btn_guardar)

func _on_guardar_pressed() -> void:
	if _id_actual.is_empty():
		return
	DialogosCSV.guardar_fila(_id_actual, _edit_es.text, _edit_en.text)
	guardado.emit(_id_actual)
	hide()
