@tool
## Ventana compartida del Editor de Temas Musicales.
## Usada desde el dock Config. Mapa y desde el Editor de Entrenadores.
## Punto de entrada: abrir(clave_inicial: String)
## Señal de salida: temas_guardados(temas: Dictionary) — emitida al guardar el JSON.
## Además, al guardar se llama recargar_temas() en todos los nodos del grupo
## GRUPO_RECEPTORES, sin importar desde dónde se abrió esta ventana.
extends Window

const TEMAS_JSON_PATH := "res://BaseDatos/temas_musicales.json"
## Carpeta por defecto: los temas de aquí solo guardan "archivo"; los de otras
## carpetas guardan además "ruta" (la que usan NuevoAudioStreamPlayer y Fanfarria).
const AUDIO_BASE_PATH := "res://Audio/emerald/"
## Carpetas que se ofrecen en el desplegable de archivo. `music_gba/` es la
## captura del APU de la GBA (la de Rubí) y es la que genera el registro con
## herramientas/generar_temas_musicales.py.
const CARPETAS_AUDIO: PackedStringArray = [
	"res://Audio/emerald/",
	"res://Audio/music_gba/",
]
const EXTENSIONES_AUDIO: PackedStringArray = ["mp3", "ogg", "wav"]
const PREFIJO_AUDIO := "res://Audio/"
## Nodos que deben recargar sus listados de temas cuando se guarda el JSON.
const GRUPO_RECEPTORES := &"receptores_temas_musicales"
## Segundos antes del fin de bucle a los que salta "Probar bucle".
const SEGUNDOS_PREVIOS_BUCLE := 3.0

## Emitida al guardar el JSON. Lleva el diccionario completo actualizado.
signal temas_guardados(temas: Dictionary)

var _temas_registrados: Dictionary = {}

var _lista: ItemList = null
var _clave_edit: LineEdit = null
var _archivo_option: OptionButton = null
var _song_id_spin: SpinBox = null
var _bucle_inicio_edit: LineEdit = null
var _bucle_fin_edit: LineEdit = null
var _volumen_spin: SpinBox = null
var _desc_edit: LineEdit = null
var _play_btn: Button = null
var _audio: AudioStreamPlayer = null
var _clave_original: String = ""
## Rutas completas (res://...) de los archivos del desplegable, en su orden.
var _rutas_audio: Array[String] = []
var _confirmar_dialog: ConfirmationDialog = null
var _clave_confirmacion_pendiente: String = ""
# Puntos de bucle de la reproducción en curso (misma lógica que AudioStreamPlayerMejorado).
var _bucle_inicio_reproduccion: float = 0.0
var _bucle_fin_reproduccion: float = 0.0

func _ready() -> void:
	title = "Editor de Temas Musicales"
	size = Vector2i(1100, 460)
	min_size = Vector2i(800, 380)
	close_requested.connect(_cerrar)
	_construir_ui()
	set_process(false)

# ─── Punto de entrada público ──────────────────────────────────────────────────

## Abre el editor pre-seleccionando clave_inicial (si existe en el JSON).
func abrir(clave_inicial: String = "") -> void:
	_cargar_temas_json()
	_escanear_archivos()
	_refrescar_lista()
	if clave_inicial != "":
		_seleccionar_clave(clave_inicial)
	else:
		_limpiar_formulario()
	popup_centered()

# ─── Cierre ────────────────────────────────────────────────────────────────────

func _cerrar() -> void:
	_detener_audio()
	hide()

# ─── Construcción de la UI ────────────────────────────────────────────────────

func _construir_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	var vbox_raiz := VBoxContainer.new()
	margin.add_child(vbox_raiz)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 8)
	vbox_raiz.add_child(columns)

	# ── Panel izquierdo: lista de temas ────────────────────────────────────────
	var panel_izq := VBoxContainer.new()
	panel_izq.custom_minimum_size = Vector2(220, 0)
	panel_izq.add_theme_constant_override("separation", 4)
	columns.add_child(panel_izq)

	var lbl_lista := Label.new()
	lbl_lista.text = "Temas registrados"
	lbl_lista.add_theme_font_size_override("font_size", 11)
	panel_izq.add_child(lbl_lista)

	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(func(idx: int): _cargar_tema(_lista.get_item_text(idx)))
	panel_izq.add_child(_lista)

	var btn_nuevo := Button.new()
	btn_nuevo.text = "+ Nuevo tema"
	btn_nuevo.pressed.connect(func():
		_lista.deselect_all()
		_limpiar_formulario()
		if is_instance_valid(_clave_edit): _clave_edit.text = "NUEVO_TEMA")
	panel_izq.add_child(btn_nuevo)

	var btn_eliminar := Button.new()
	btn_eliminar.text = "🗑 Eliminar"
	btn_eliminar.pressed.connect(_eliminar_tema)
	panel_izq.add_child(btn_eliminar)

	columns.add_child(VSeparator.new())

	# ── Panel derecho: detalle del tema ────────────────────────────────────────
	var panel_der := VBoxContainer.new()
	panel_der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_der.add_theme_constant_override("separation", 6)
	columns.add_child(panel_der)

	var lbl_det := Label.new()
	lbl_det.text = "Detalle del tema"
	lbl_det.add_theme_font_size_override("font_size", 11)
	panel_der.add_child(lbl_det)

	var row_clave := _crear_fila(panel_der, "Clave (ID):")
	_clave_edit = LineEdit.new()
	_clave_edit.placeholder_text = "NOMBRE_INTERNO"
	_clave_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_clave.add_child(_clave_edit)

	var row_arch := _crear_fila(panel_der, "Archivo:")
	_archivo_option = OptionButton.new()
	_archivo_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_arch.add_child(_archivo_option)

	var row_song := _crear_fila(panel_der, "song_id (Rubí):")
	_song_id_spin = SpinBox.new()
	_song_id_spin.min_value = 0
	_song_id_spin.max_value = 999
	_song_id_spin.step = 1
	_song_id_spin.value = 0
	_song_id_spin.tooltip_text = "Índice del tema en la tabla de songs de Rubí (songs.h). 0 si no aplica."
	_song_id_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_song.add_child(_song_id_spin)

	var row_bi := _crear_fila(panel_der, "Bucle inicio (s):")
	_bucle_inicio_edit = LineEdit.new()
	_bucle_inicio_edit.text = "0.0"
	_bucle_inicio_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bucle_inicio_edit.text_changed.connect(func(_t: String): _leer_puntos_bucle())
	row_bi.add_child(_bucle_inicio_edit)

	var row_bf := _crear_fila(panel_der, "Bucle fin (s):")
	_bucle_fin_edit = LineEdit.new()
	_bucle_fin_edit.text = "0.0"
	_bucle_fin_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bucle_fin_edit.text_changed.connect(func(_t: String): _leer_puntos_bucle())
	row_bf.add_child(_bucle_fin_edit)

	var row_vol := _crear_fila(panel_der, "Volumen:")
	_volumen_spin = SpinBox.new()
	_volumen_spin.min_value = 0.0
	_volumen_spin.max_value = 6.0
	_volumen_spin.step = 0.01
	_volumen_spin.value = 1.0
	_volumen_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_vol.add_child(_volumen_spin)

	var row_desc := _crear_fila(panel_der, "Descripción:")
	_desc_edit = LineEdit.new()
	_desc_edit.placeholder_text = "Descripción legible"
	_desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_desc.add_child(_desc_edit)

	panel_der.add_child(HSeparator.new())

	var row_acc := HBoxContainer.new()
	panel_der.add_child(row_acc)

	_play_btn = Button.new()
	_play_btn.text = "▶ Reproducir"
	_play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_btn.pressed.connect(_on_play_presionado)
	row_acc.add_child(_play_btn)

	var btn_probar_bucle := Button.new()
	btn_probar_bucle.text = "⏩ Probar bucle"
	btn_probar_bucle.tooltip_text = "Salta a %d s antes del fin de bucle para comprobar el empalme" % int(SEGUNDOS_PREVIOS_BUCLE)
	btn_probar_bucle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_probar_bucle.pressed.connect(_on_probar_bucle_presionado)
	row_acc.add_child(btn_probar_bucle)

	var btn_guardar_tema := Button.new()
	btn_guardar_tema.text = "💾 Guardar tema"
	btn_guardar_tema.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_guardar_tema.pressed.connect(_guardar_tema)
	row_acc.add_child(btn_guardar_tema)

	# ── Pie de la ventana ─────────────────────────────────────────────────────
	vbox_raiz.add_child(HSeparator.new())

	var row_final := HBoxContainer.new()
	vbox_raiz.add_child(row_final)

	var btn_guardar_json := Button.new()
	btn_guardar_json.text = "💾 Guardar JSON"
	btn_guardar_json.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_guardar_json.pressed.connect(_guardar_json)
	row_final.add_child(btn_guardar_json)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "Cerrar"
	btn_cerrar.pressed.connect(_cerrar)
	row_final.add_child(btn_cerrar)

	# AudioStreamPlayer para reproducción interna
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_audio.finished.connect(_on_audio_finished)

	# Diálogo de confirmación de sobreescritura
	_confirmar_dialog = ConfirmationDialog.new()
	_confirmar_dialog.title = "Confirmar sobreescritura"
	_confirmar_dialog.confirmed.connect(_confirmar_sobreescritura)
	add_child(_confirmar_dialog)

func _crear_fila(parent: Control, etiqueta: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = etiqueta
	lbl.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(lbl)
	return hbox

# ─── Datos ────────────────────────────────────────────────────────────────────

func _cargar_temas_json() -> void:
	var file := FileAccess.open(TEMAS_JSON_PATH, FileAccess.READ)
	if not file:
		push_warning("[EditorTemas] No se encontró %s" % TEMAS_JSON_PATH)
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) == TYPE_DICTIONARY and data.has("temas"):
		_temas_registrados = data["temas"]
	else:
		push_warning("[EditorTemas] Formato inválido en temas_musicales.json")

## Lista los audios de CARPETAS_AUDIO (EXTENSIONES_AUDIO), carpeta por carpeta
## y ordenados por nombre. Se muestran relativos a res://Audio/.
func _escanear_archivos() -> void:
	_rutas_audio.clear()
	for carpeta: String in CARPETAS_AUDIO:
		if not DirAccess.dir_exists_absolute(carpeta):
			push_warning("[EditorTemas] No se encontró directorio de audio: %s" % carpeta)
			continue
		var nombres: Array[String] = []
		for nombre: String in DirAccess.get_files_at(carpeta):
			if nombre.get_extension().to_lower() in EXTENSIONES_AUDIO:
				nombres.append(nombre)
		nombres.sort()
		for nombre: String in nombres:
			_rutas_audio.append(carpeta + nombre)
	if is_instance_valid(_archivo_option):
		_archivo_option.clear()
		for ruta: String in _rutas_audio:
			_archivo_option.add_item(_texto_ruta(ruta))


## Ruta del audio de un tema: "ruta" si la tiene; si no, AUDIO_BASE_PATH + "archivo".
static func ruta_de_tema(datos: Dictionary) -> String:
	return str(datos.get("ruta", AUDIO_BASE_PATH + str(datos.get("archivo", ""))))


func _texto_ruta(ruta: String) -> String:
	return ruta.trim_prefix(PREFIJO_AUDIO)


## Selecciona `ruta` en el desplegable. Si no está en la lista (archivo borrado
## o en otra carpeta) se añade marcada como no encontrada, para no dejar
## seleccionado el archivo del tema anterior ni perderla al guardar.
func _seleccionar_ruta(ruta: String) -> void:
	if not is_instance_valid(_archivo_option):
		return
	var indice := _rutas_audio.find(ruta)
	if indice < 0:
		_rutas_audio.append(ruta)
		_archivo_option.add_item("⚠ %s (no encontrado)" % _texto_ruta(ruta))
		indice = _rutas_audio.size() - 1
	_archivo_option.select(indice)


## song_id de un tema: el que ya tenía guardado, o el que se deduce del
## prefijo numérico del archivo ("459_batalla_entrenador.ogg" -> 459). 0 si no
## se puede determinar (temas que no vienen de la captura de la GBA).
func _song_id_del_tema(clave_original: String, ruta: String) -> int:
	if _temas_registrados.has(clave_original):
		var guardado: Variant = _temas_registrados[clave_original].get("song_id")
		if guardado is int or guardado is float:
			return int(guardado)
	var nombre := ruta.get_file()
	if nombre.is_valid_int():
		return int(nombre)
	return 0


## Ruta completa seleccionada en el desplegable, o "".
func _ruta_seleccionada() -> String:
	if not is_instance_valid(_archivo_option):
		return ""
	var indice := _archivo_option.selected
	return _rutas_audio[indice] if indice >= 0 and indice < _rutas_audio.size() else ""

func _refrescar_lista() -> void:
	if not is_instance_valid(_lista):
		return
	_lista.clear()
	var claves := _temas_registrados.keys()
	claves.sort()
	for c in claves:
		_lista.add_item(c)

func _seleccionar_clave(clave: String) -> void:
	if not is_instance_valid(_lista):
		return
	for i in _lista.item_count:
		if _lista.get_item_text(i) == clave:
			_lista.select(i)
			_cargar_tema(clave)
			return
	_limpiar_formulario()

func _cargar_tema(clave: String) -> void:
	if not _temas_registrados.has(clave):
		return
	_clave_original = clave
	var datos: Dictionary = _temas_registrados[clave]
	if is_instance_valid(_clave_edit): _clave_edit.text = clave
	_seleccionar_ruta(ruta_de_tema(datos))
	if is_instance_valid(_song_id_spin): _song_id_spin.value = int(datos.get("song_id", 0))
	if is_instance_valid(_bucle_inicio_edit): _bucle_inicio_edit.text = str(datos.get("bucle_inicio", 0.0))
	if is_instance_valid(_bucle_fin_edit): _bucle_fin_edit.text = str(datos.get("bucle_fin", 0.0))
	if is_instance_valid(_volumen_spin): _volumen_spin.value = float(datos.get("volumen", 1.0))
	if is_instance_valid(_desc_edit): _desc_edit.text = datos.get("descripcion", "")

func _limpiar_formulario() -> void:
	_clave_original = ""
	if is_instance_valid(_clave_edit): _clave_edit.text = ""
	if is_instance_valid(_song_id_spin): _song_id_spin.value = 0
	if is_instance_valid(_bucle_inicio_edit): _bucle_inicio_edit.text = "0.0"
	if is_instance_valid(_bucle_fin_edit): _bucle_fin_edit.text = "0.0"
	if is_instance_valid(_volumen_spin): _volumen_spin.value = 1.0
	if is_instance_valid(_desc_edit): _desc_edit.text = ""

func _eliminar_tema() -> void:
	if not is_instance_valid(_lista): return
	var sel := _lista.get_selected_items()
	if sel.is_empty(): return
	var clave := _lista.get_item_text(sel[0])
	_temas_registrados.erase(clave)
	_refrescar_lista()
	_limpiar_formulario()

# ─── Guardar tema (en memoria) ─────────────────────────────────────────────────

func _guardar_tema() -> void:
	if not is_instance_valid(_clave_edit): return
	var clave := _clave_edit.text.strip_edges().to_upper()
	if clave == "":
		push_warning("[EditorTemas] La clave no puede estar vacía")
		return
	if clave == _clave_original:
		_hacer_guardar(clave)
		return
	if _temas_registrados.has(clave):
		_clave_confirmacion_pendiente = clave
		_confirmar_dialog.dialog_text = "Ya existe el tema '%s'.\n¿Deseas sobreescribirlo?" % clave
		_confirmar_dialog.popup_centered()
		return
	if _clave_original != "" and _temas_registrados.has(_clave_original):
		_temas_registrados.erase(_clave_original)
	_hacer_guardar(clave)

func _confirmar_sobreescritura() -> void:
	if _clave_confirmacion_pendiente != "":
		_hacer_guardar(_clave_confirmacion_pendiente)
		_clave_confirmacion_pendiente = ""

func _hacer_guardar(clave: String) -> void:
	var ruta := _ruta_seleccionada()
	if _clave_original != "" and _clave_original != clave and _temas_registrados.has(_clave_original):
		_temas_registrados.erase(_clave_original)
	var datos := {
		"archivo": ruta.get_file(),
		"bucle_inicio": float(_bucle_inicio_edit.text) if is_instance_valid(_bucle_inicio_edit) else 0.0,
		"bucle_fin": float(_bucle_fin_edit.text) if is_instance_valid(_bucle_fin_edit) else 0.0,
		"volumen": _volumen_spin.value if is_instance_valid(_volumen_spin) else 1.0,
		"descripcion": _desc_edit.text if is_instance_valid(_desc_edit) else "",
	}
	# Fuera de la carpeta por defecto el nombre no basta: se guarda la ruta.
	if not ruta.is_empty() and ruta.get_base_dir() + "/" != AUDIO_BASE_PATH:
		datos["ruta"] = ruta
	# `song_id` identifica el tema en la tabla de songs de Rubí: es lo que
	# permite regenerar el registro sin perder la trazabilidad. Se conserva el
	# que ya tuviera el tema; si no, se deduce del prefijo del archivo.
	var song_id := int(_song_id_spin.value) if is_instance_valid(_song_id_spin) else 0
	if song_id <= 0:
		song_id = _song_id_del_tema(_clave_original, ruta)
	if song_id > 0:
		datos["song_id"] = song_id
	_temas_registrados[clave] = datos
	_clave_original = clave
	if is_instance_valid(_clave_edit): _clave_edit.text = clave
	_refrescar_lista()
	_seleccionar_clave(clave)

# ─── Guardar JSON ─────────────────────────────────────────────────────────────

func _guardar_json() -> void:
	var data := {"temas": _temas_registrados}
	var json_str := JSON.stringify(data, "\t")
	var file := FileAccess.open(TEMAS_JSON_PATH, FileAccess.WRITE)
	if not file:
		push_error("[EditorTemas] No se pudo escribir %s" % TEMAS_JSON_PATH)
		return
	file.store_string(json_str)
	file.close()
	print("[EditorTemas] temas_musicales.json guardado (%d temas)" % _temas_registrados.size())
	temas_guardados.emit(_temas_registrados)
	if is_inside_tree():
		get_tree().call_group(GRUPO_RECEPTORES, "recargar_temas")

# ─── Reproducción de audio ─────────────────────────────────────────────────────

func _on_play_presionado() -> void:
	if not is_instance_valid(_audio): return
	if _audio.playing:
		_detener_audio()
		return
	var ruta := _ruta_seleccionada()
	if ruta.is_empty(): return
	if not ResourceLoader.exists(ruta):
		push_warning("[EditorTemas] Archivo no encontrado: %s" % ruta)
		return
	var stream := load(ruta) as AudioStream
	if not stream: return
	_audio.stream = stream
	if is_instance_valid(_volumen_spin):
		_audio.volume_db = linear_to_db(_volumen_spin.value)
	_leer_puntos_bucle()
	_audio.play()
	set_process(true)
	if is_instance_valid(_play_btn): _play_btn.text = "■ Detener"

func _detener_audio() -> void:
	set_process(false)
	if is_instance_valid(_audio) and _audio.playing:
		_audio.stop()
	if is_instance_valid(_play_btn): _play_btn.text = "▶ Reproducir"

## Toma los puntos de bucle del formulario. Se llama al reproducir y al editar
## los campos, para poder ajustar el bucle mientras suena.
func _leer_puntos_bucle() -> void:
	_bucle_inicio_reproduccion = _bucle_inicio_edit.text.to_float() if is_instance_valid(_bucle_inicio_edit) else 0.0
	_bucle_fin_reproduccion = _bucle_fin_edit.text.to_float() if is_instance_valid(_bucle_fin_edit) else 0.0

## Replica AudioStreamPlayerMejorado._process: con inicio y fin > 0 vuelve al
## inicio del bucle al alcanzar el fin; con ambos en 0 reinicia al terminar
## (ver _on_audio_finished); en otro caso no hay bucle.
func _process(_delta: float) -> void:
	if not is_instance_valid(_audio) or not _audio.playing:
		return
	if _bucle_inicio_reproduccion > 0.0 and _bucle_fin_reproduccion > 0.0:
		if _audio.get_playback_position() >= _bucle_fin_reproduccion:
			_audio.seek(_bucle_inicio_reproduccion)

func _on_audio_finished() -> void:
	if is_processing() and _bucle_inicio_reproduccion == 0.0 and _bucle_fin_reproduccion == 0.0:
		_audio.play()
		return
	_detener_audio()

func _on_probar_bucle_presionado() -> void:
	if not is_instance_valid(_audio): return
	if not _audio.playing:
		_on_play_presionado()
		if not _audio.playing: return
	var fin := _bucle_fin_reproduccion
	if fin <= 0.0 and _audio.stream:
		fin = _audio.stream.get_length()
	_audio.seek(maxf(fin - SEGUNDOS_PREVIOS_BUCLE, 0.0))
