@tool
extends Control
## Dock del editor para editar propiedades de MapaConfiguracion.
## Se instancia desde el plugin tilemap_inspector y se añade al panel inferior
## cuando la escena activa tiene el script MapaConfiguracion.

## Emitida cuando el usuario pulsa "✏️ Editar" en la sección de encuentros.
signal solicitar_editor_encuentros(mapa_id: String)

# ─── Constantes ────────────────────────────────────────────────────────────────

const TEMAS_JSON_PATH := "res://BaseDatos/temas_musicales.json"
const AUDIO_BASE_PATH := "res://Audio/emerald/"
const RUTA_BASE_DATOS := "res://BaseDatos/poke.db"
const RUTA_ICONOS_POKEMON := "res://graficos/Icons/"
const RUTA_ENCUENTROS_JSON := "res://BaseDatos/config_encuentros.json"

## Entrada de los desplegables de música que se guarda vacía: el mapa usa el
## tema del mapa exterior asociado (o ninguno si no lo hay).
const OPCION_MUSICA_HEREDADA := "HEREDADA"

## Anchos mínimos (px) por debajo de los cuales una columna pasa a la línea siguiente
## en lugar de comprimirse más (ver FlowContainer en _construir_ui).
const ANCHO_MIN_COLUMNA := 340
const ANCHO_MIN_COLUMNA_ENCUENTRO := 190


# ─── Estado interno ─────────────────────────────────────────────────────────────

var _mapa_node: Node = null
var _temas_registrados: Dictionary = {}
var _undo_redo: EditorUndoRedoManager = null
var _ignorar_señales: bool = false
var _encuentros_data: Dictionary = {}
var _db = null
var _icon_cache_enc: Dictionary = {}
var _db_cache_enc: Dictionary = {}
# ─── Controles UI (asignados en _construir_ui) ─────────────────────────────────

var _archivo_label: Label
var _nombre_interno_edit: LineEdit
var _seccion_edit: LineEdit
var _es_interior_check: CheckBox
var _mapa_exterior_row: HBoxContainer
var _mapa_exterior_edit: LineEdit
var _musica_mapa_option: OptionButton
var _play_mapa_btn: Button
var _config_mapa_btn: Button
var _musica_batalla_option: OptionButton
var _play_batalla_btn: Button
var _config_batalla_btn: Button
var _escena_batalla_option: OptionButton
var _tipo_mapa_batalla_option: OptionButton
var _fondo_preview: TextureRect
var _suelo_preview: TextureRect
var _encuentros_container: FlowContainer

# ─── Reproducción de audio en el editor ────────────────────────────────────────

var _audio_player: AudioStreamPlayer = null
var _tema_reproduciendo: String = ""
# Puntos de bucle del tema en reproducción (misma lógica que AudioStreamPlayerMejorado).
var _bucle_inicio_reproduccion: float = 0.0
var _bucle_fin_reproduccion: float = 0.0

# ─── Editor de temas musicales (ventana emergente) ───────────────────────────

const _EDITOR_TEMAS_ESCENA := "res://addons/tilemap_inspector/editores/editor_temas_musicales/editor_temas_musicales.tscn"
var _editor_temas: Window = null

# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# El Editor de Temas Musicales llama recargar_temas() en este grupo al guardar,
	# aunque se haya abierto desde el menú o desde el Editor de Entrenadores.
	add_to_group(&"receptores_temas_musicales")
	_cargar_temas_json()
	_cargar_encuentros_json()
	_conectar_base_datos_enc()
	_construir_ui()
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	_audio_player.finished.connect(_on_audio_finished)
	set_process(false)

## Carga los temas directamente del JSON (sin pasar por el autoload del juego).
func _cargar_temas_json() -> void:
	var file := FileAccess.open(TEMAS_JSON_PATH, FileAccess.READ)
	if not file:
		push_warning("[ConfigMapas] No se encontró %s" % TEMAS_JSON_PATH)
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) == TYPE_DICTIONARY and data.has("temas"):
		_temas_registrados = data["temas"]
	else:
		push_warning("[ConfigMapas] Formato inválido en temas_musicales.json")

# ═══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA (llamada desde plugin.gd)
# ═══════════════════════════════════════════════════════════════════════════════

## Carga las propiedades del nodo mapa en todos los controles del dock.
func cargar_mapa(node: Node) -> void:
	_mapa_node = node
	_cargar_temas_json()
	_actualizar_ui()

## Recarga los temas y datos de encuentros desde el JSON.
func recargar_temas() -> void:
	_cargar_temas_json()
	var hay_mapa := is_instance_valid(_mapa_node)
	_ignorar_señales = true
	_poblar_opciones_musica(_musica_mapa_option, str(_mapa_node.get("musica_mapa")) if hay_mapa else "", true)
	_poblar_opciones_musica(_musica_batalla_option, str(_mapa_node.get("musica_batalla")) if hay_mapa else "")
	_ignorar_señales = false
	# Recargar también los datos de encuentros y limpiar caché de iconos.
	# Nota: _db_cache_enc (datos de Pokémon) no se borra — es estable mientras
	# el editor está abierto y fue precargado desde la BD al inicializar.
	_icon_cache_enc.clear()
	_cargar_encuentros_json()
	_actualizar_seccion_encuentros()

## Asigna el EditorUndoRedoManager del plugin para soporte de deshacer/rehacer.
func set_undo_redo(ur: EditorUndoRedoManager) -> void:
	_undo_redo = ur

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA UI
# ═══════════════════════════════════════════════════════════════════════════════

func _construir_ui() -> void:
	custom_minimum_size = Vector2(0, 200)

	# Con el scroll horizontal DESACTIVADO, el ScrollContainer hereda el ancho mínimo
	# de su contenido y, al estar anclado a este Control (no a un Container), se
	# ensancha más que el panel y se sale por el borde derecho. En AUTO su mínimo
	# horizontal es 0: el contenido se adapta al ancho y solo aparece scroll
	# horizontal si ya no cabe ni con el layout más compacto.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	var raiz := VBoxContainer.new()
	raiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raiz.add_theme_constant_override("separation", 6)
	scroll.add_child(raiz)

	# ── Encabezado ────────────────────────────────────────────────────────────
	var header_hbox := HBoxContainer.new()
	raiz.add_child(header_hbox)

	var archivo_lbl_titulo := Label.new()
	archivo_lbl_titulo.text = "📁 Archivo:"
	header_hbox.add_child(archivo_lbl_titulo)

	_archivo_label = Label.new()
	_archivo_label.text = "(ninguna escena)"
	_archivo_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_archivo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_archivo_label.clip_text = true
	header_hbox.add_child(_archivo_label)

	var btn_refrescar := Button.new()
	btn_refrescar.text = "↺"
	btn_refrescar.tooltip_text = "Recargar temas musicales y encuentros desde JSON"
	btn_refrescar.pressed.connect(recargar_temas)
	header_hbox.add_child(btn_refrescar)

	raiz.add_child(HSeparator.new())

	# ── Columnas principales ──────────────────────────────────────────────────
	# FlowContainer: las dos columnas se reparten el ancho y, si el panel es
	# demasiado estrecho para ambas, la segunda pasa debajo de la primera.
	var columnas := FlowContainer.new()
	columnas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columnas.add_theme_constant_override("h_separation", 16)
	columnas.add_theme_constant_override("v_separation", 10)
	raiz.add_child(columnas)

	# Columna izquierda — Identificación + Audio
	var col_izq := VBoxContainer.new()
	col_izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_izq.custom_minimum_size = Vector2(ANCHO_MIN_COLUMNA, 0)
	col_izq.add_theme_constant_override("separation", 6)
	columnas.add_child(col_izq)

	_agregar_seccion(col_izq, "IDENTIFICACIÓN")

	# ID interno
	var row_id := _crear_fila(col_izq, "ID Interno:")
	_nombre_interno_edit = LineEdit.new()
	_nombre_interno_edit.placeholder_text = "ej: ruta_101"
	_nombre_interno_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nombre_interno_edit.text_changed.connect(_on_nombre_interno_cambiado)
	row_id.add_child(_nombre_interno_edit)

	# Sección (clave de lugar, p. ej. RUTA_101; el texto sale de LUGAR_<clave>)
	var row_nombre := _crear_fila(col_izq, "Sección:")
	_seccion_edit = LineEdit.new()
	_seccion_edit.placeholder_text = "ej: RUTA_101"
	_seccion_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seccion_edit.text_changed.connect(_on_seccion_cambiada)
	row_nombre.add_child(_seccion_edit)

	# ¿Es interior?
	var row_interior := _crear_fila(col_izq, "¿Es interior?")
	_es_interior_check = CheckBox.new()
	_es_interior_check.toggled.connect(_on_es_interior_cambiado)
	row_interior.add_child(_es_interior_check)

	# Mapa exterior asociado (visible solo si es interior)
	_mapa_exterior_row = _crear_fila(col_izq, "Mapa exterior:")
	_mapa_exterior_edit = LineEdit.new()
	_mapa_exterior_edit.placeholder_text = "nombre_mapa_exterior"
	_mapa_exterior_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mapa_exterior_edit.text_changed.connect(_on_mapa_exterior_cambiado)
	_mapa_exterior_row.add_child(_mapa_exterior_edit)
	_mapa_exterior_row.visible = false

	# Música del mapa (en sección IDENTIFICACIÓN)
	var row_mus_mapa := _crear_fila(col_izq, "Música mapa:")
	_musica_mapa_option = _crear_option_button()
	_musica_mapa_option.item_selected.connect(_on_musica_mapa_cambiada)
	row_mus_mapa.add_child(_musica_mapa_option)
	_play_mapa_btn = Button.new()
	_play_mapa_btn.text = "▶"
	_play_mapa_btn.tooltip_text = "Reproducir / detener"
	_play_mapa_btn.pressed.connect(_on_play_mapa_presionado)
	row_mus_mapa.add_child(_play_mapa_btn)
	_config_mapa_btn = Button.new()
	_config_mapa_btn.text = "⚙"
	_config_mapa_btn.tooltip_text = "Editar temas musicales"
	_config_mapa_btn.pressed.connect(_on_config_mapa_presionado)
	row_mus_mapa.add_child(_config_mapa_btn)

	# Columna derecha — Batalla + Probabilidad
	var col_der := VBoxContainer.new()
	col_der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_der.custom_minimum_size = Vector2(ANCHO_MIN_COLUMNA, 0)
	col_der.add_theme_constant_override("separation", 6)
	columnas.add_child(col_der)

	_agregar_seccion(col_der, "BATALLA")

	# Música de batalla (en sección BATALLA)
	var row_mus_bat := _crear_fila(col_der, "Música batalla:")
	_musica_batalla_option = _crear_option_button()
	_musica_batalla_option.item_selected.connect(_on_musica_batalla_cambiada)
	row_mus_bat.add_child(_musica_batalla_option)
	_play_batalla_btn = Button.new()
	_play_batalla_btn.text = "▶"
	_play_batalla_btn.tooltip_text = "Reproducir / detener"
	_play_batalla_btn.pressed.connect(_on_play_batalla_presionado)
	row_mus_bat.add_child(_play_batalla_btn)
	_config_batalla_btn = Button.new()
	_config_batalla_btn.text = "⚙"
	_config_batalla_btn.tooltip_text = "Editar temas musicales"
	_config_batalla_btn.pressed.connect(_on_config_batalla_presionado)
	row_mus_bat.add_child(_config_batalla_btn)

	# Escenario de batalla (EscenarioBatalla): escena del mapa y tipo de mapa
	var row_escena := _crear_fila(col_der, "Escena batalla:")
	_escena_batalla_option = _crear_option_button()
	for nombre in EscenarioBatalla.Escena.keys():
		_escena_batalla_option.add_item(nombre)
	_escena_batalla_option.item_selected.connect(_on_escena_batalla_cambiada)
	row_escena.add_child(_escena_batalla_option)
	var row_tipo := _crear_fila(col_der, "Tipo de mapa:")
	_tipo_mapa_batalla_option = _crear_option_button()
	for nombre in EscenarioBatalla.TipoMapa.keys():
		_tipo_mapa_batalla_option.add_item(nombre)
	_tipo_mapa_batalla_option.item_selected.connect(_on_tipo_mapa_batalla_cambiado)
	row_tipo.add_child(_tipo_mapa_batalla_option)

	# Vista previa de imágenes de batalla
	var preview_hbox := HBoxContainer.new()
	preview_hbox.add_theme_constant_override("separation", 8)
	col_der.add_child(preview_hbox)

	var col_fondo := VBoxContainer.new()
	preview_hbox.add_child(col_fondo)
	var lbl_fondo := Label.new()
	lbl_fondo.text = "Fondo"
	lbl_fondo.add_theme_font_size_override("font_size", 10)
	col_fondo.add_child(lbl_fondo)
	_fondo_preview = TextureRect.new()
	_fondo_preview.custom_minimum_size = Vector2(120, 60)
	_fondo_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fondo_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	col_fondo.add_child(_fondo_preview)

	var col_suelo := VBoxContainer.new()
	preview_hbox.add_child(col_suelo)
	var lbl_suelo := Label.new()
	lbl_suelo.text = "Suelo"
	lbl_suelo.add_theme_font_size_override("font_size", 10)
	col_suelo.add_child(lbl_suelo)
	_suelo_preview = TextureRect.new()
	_suelo_preview.custom_minimum_size = Vector2(120, 60)
	_suelo_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_suelo_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	col_suelo.add_child(_suelo_preview)

	col_der.add_child(HSeparator.new())

	# ── Sección inferior: Tarjetas de encuentros ──────────────────────────────
	raiz.add_child(HSeparator.new())

	var enc_header := HBoxContainer.new()
	raiz.add_child(enc_header)
	var enc_lbl := Label.new()
	enc_lbl.text = "POKÉMON DE ENCUENTROS"
	enc_lbl.add_theme_font_size_override("font_size", 10)
	enc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	enc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enc_header.add_child(enc_lbl)
	var btn_editar_enc := Button.new()
	btn_editar_enc.text = "✏️ Editar"
	btn_editar_enc.tooltip_text = "Abrir editor de Pokémon de encuentro"
	btn_editar_enc.add_theme_font_size_override("font_size", 10)
	btn_editar_enc.pressed.connect(_on_editar_encuentros_presionado)
	enc_header.add_child(btn_editar_enc)

	# FlowContainer: cada tipo de encuentro es una columna que se reparte el ancho
	# y baja a la línea siguiente cuando ya no caben todas.
	_encuentros_container = FlowContainer.new()
	_encuentros_container.add_theme_constant_override("h_separation", 12)
	_encuentros_container.add_theme_constant_override("v_separation", 8)
	_encuentros_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raiz.add_child(_encuentros_container)

# ─── Helpers de construcción ───────────────────────────────────────────────────

func _agregar_seccion(parent: Control, titulo: String) -> void:
	var lbl := Label.new()
	lbl.text = titulo
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	parent.add_child(lbl)

## OptionButton que se adapta al ancho disponible. Por defecto el botón mide lo
## que su ítem más largo (fit_to_longest_item), lo que fija un ancho mínimo alto
## y desborda el panel; con clip_text y sin ese ajuste puede encogerse.
func _crear_option_button() -> OptionButton:
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.fit_to_longest_item = false
	ob.clip_text = true
	return ob

func _crear_fila(parent: Control, etiqueta: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = etiqueta
	lbl.custom_minimum_size = Vector2(110, 0)
	hbox.add_child(lbl)
	return hbox

# ═══════════════════════════════════════════════════════════════════════════════
# ACTUALIZACIÓN DE LA UI DESDE EL NODO
# ═══════════════════════════════════════════════════════════════════════════════

func _actualizar_ui() -> void:
	if not _mapa_node:
		return
	_ignorar_señales = true

	# Archivo
	var path: String = _mapa_node.scene_file_path
	_archivo_label.text = path.get_file() if path != "" else "(sin guardar)"

	# Identificación
	_nombre_interno_edit.text = _mapa_node.get("nombre_interno") if _mapa_node.get("nombre_interno") != null else ""
	_seccion_edit.text = _mapa_node.get("seccion") if _mapa_node.get("seccion") != null else ""
	_es_interior_check.button_pressed = bool(_mapa_node.get("esInterior"))
	_mapa_exterior_edit.text = _mapa_node.get("mapa_exterior_asociado") if _mapa_node.get("mapa_exterior_asociado") != null else ""
	_mapa_exterior_row.visible = _es_interior_check.button_pressed

	# Audio — poblar opciones y seleccionar valor actual
	_poblar_opciones_musica(_musica_mapa_option, str(_mapa_node.get("musica_mapa")), true)
	_poblar_opciones_musica(_musica_batalla_option, str(_mapa_node.get("musica_batalla")))

	# Escenario de batalla
	_escena_batalla_option.select(clampi(int(_mapa_node.get("escena_batalla")), 0, EscenarioBatalla.Escena.size() - 1))
	_tipo_mapa_batalla_option.select(clampi(int(_mapa_node.get("tipo_mapa_batalla")), 0, EscenarioBatalla.TipoMapa.size() - 1))
	_actualizar_preview_batalla()

	# Tarjetas de encuentros Pokémon
	_actualizar_seccion_encuentros()

	_ignorar_señales = false

## Índice 0 = HEREDADA (se guarda ""). Con `con_ninguna`, el índice 1 es
## NINGUNA (MapaConfiguracion.MUSICA_NINGUNA: silencio, sin heredar).
func _poblar_opciones_musica(option_btn: OptionButton, seleccion_actual: String, con_ninguna: bool = false) -> void:
	option_btn.clear()
	option_btn.add_item(OPCION_MUSICA_HEREDADA)
	var idx_seleccionado: int = 0
	if con_ninguna:
		option_btn.add_item(MapaConfiguracion.MUSICA_NINGUNA)
		if seleccion_actual.to_upper() == MapaConfiguracion.MUSICA_NINGUNA:
			idx_seleccionado = 1
	var claves: Array = _temas_registrados.keys()
	claves.sort()
	for clave: String in claves:
		option_btn.add_item(clave)
		if clave == seleccion_actual:
			idx_seleccionado = option_btn.item_count - 1
	option_btn.select(idx_seleccionado)

## Valor a guardar para la opción elegida: "" para HEREDADA, el texto en otro caso.
func _valor_opcion_musica(option_btn: OptionButton, idx: int) -> String:
	return "" if idx <= 0 else option_btn.get_item_text(idx)

## Tema registrado elegido (para reproducir o configurar); "" con HEREDADA o NINGUNA.
func _tema_registrado_seleccionado(option_btn: OptionButton) -> String:
	var clave := _valor_opcion_musica(option_btn, option_btn.selected)
	return clave if _temas_registrados.has(clave) else ""

## Vista previa del escenario de un combate salvaje en una celda sin banderas
## (el terreno real depende de la baldosa bajo el jugador).
func _actualizar_preview_batalla() -> void:
	if not _mapa_node or not _mapa_node.has_method("obtener_tipo_mapa_batalla"):
		_fondo_preview.texture = null
		_suelo_preview.texture = null
		return
	var terreno := EscenarioBatalla.resolver_terreno(0, false, _mapa_node.obtener_tipo_mapa_batalla())
	var escena := int(_mapa_node.get("escena_batalla")) as EscenarioBatalla.Escena
	var rutas := EscenarioBatalla.rutas(EscenarioBatalla.resolver_escenario(terreno, escena))
	_fondo_preview.texture = _cargar_textura(rutas["fondo"])
	_suelo_preview.texture = _cargar_textura(rutas["suelo"])

func _cargar_textura(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

# ═══════════════════════════════════════════════════════════════════════════════
# MANEJADORES DE SEÑALES (cambios en controles → propiedad del nodo)
# ═══════════════════════════════════════════════════════════════════════════════

func _aplicar_propiedad(propiedad: String, valor) -> void:
	if _ignorar_señales or not _mapa_node:
		return
	if _undo_redo:
		var valor_anterior = _mapa_node.get(propiedad)
		_undo_redo.create_action("Cambiar %s" % propiedad)
		_undo_redo.add_do_property(_mapa_node, propiedad, valor)
		_undo_redo.add_undo_property(_mapa_node, propiedad, valor_anterior)
		_undo_redo.commit_action()
	else:
		_mapa_node.set(propiedad, valor)

func _on_nombre_interno_cambiado(nuevo_valor: String) -> void:
	_aplicar_propiedad("nombre_interno", nuevo_valor)

func _on_seccion_cambiada(nuevo_valor: String) -> void:
	_aplicar_propiedad("seccion", nuevo_valor)

func _on_es_interior_cambiado(activado: bool) -> void:
	_aplicar_propiedad("esInterior", activado)
	if not _ignorar_señales:
		_mapa_exterior_row.visible = activado

func _on_mapa_exterior_cambiado(nuevo_valor: String) -> void:
	_aplicar_propiedad("mapa_exterior_asociado", nuevo_valor)

func _on_musica_mapa_cambiada(idx: int) -> void:
	if _ignorar_señales:
		return
	_aplicar_propiedad("musica_mapa", _valor_opcion_musica(_musica_mapa_option, idx))

func _on_musica_batalla_cambiada(idx: int) -> void:
	if _ignorar_señales:
		return
	_aplicar_propiedad("musica_batalla", _valor_opcion_musica(_musica_batalla_option, idx))

func _on_escena_batalla_cambiada(idx: int) -> void:
	if _ignorar_señales:
		return
	_aplicar_propiedad("escena_batalla", idx)
	_actualizar_preview_batalla()

func _on_tipo_mapa_batalla_cambiado(idx: int) -> void:
	if _ignorar_señales:
		return
	_aplicar_propiedad("tipo_mapa_batalla", idx)
	_actualizar_preview_batalla()

# ═══════════════════════════════════════════════════════════════════════════════
# REPRODUCCIÓN DE AUDIO EN EL EDITOR
# ═══════════════════════════════════════════════════════════════════════════════

func _on_play_mapa_presionado() -> void:
	_toggle_reproduccion(_tema_registrado_seleccionado(_musica_mapa_option), _play_mapa_btn)

func _on_play_batalla_presionado() -> void:
	_toggle_reproduccion(_tema_registrado_seleccionado(_musica_batalla_option), _play_batalla_btn)

func _toggle_reproduccion(clave: String, btn: Button) -> void:
	# Si ya está sonando esta misma pista → detener y salir
	if _audio_player.playing and _tema_reproduciendo == clave:
		_detener_audio()
		return
	# Estaba sonando otra pista → detenerla antes de empezar la nueva
	if _audio_player.playing:
		_detener_audio()

	if clave == "" or not _temas_registrados.has(clave):
		return

	var datos: Dictionary = _temas_registrados[clave]
	var ruta_audio: String = str(datos.get("ruta", AUDIO_BASE_PATH + str(datos.get("archivo", ""))))
	if not ResourceLoader.exists(ruta_audio):
		push_warning("[ConfigMapas] No se encontró el archivo de audio: %s" % ruta_audio)
		return

	var stream = load(ruta_audio) as AudioStream
	if not stream:
		return

	_audio_player.stream = stream
	_audio_player.volume_db = linear_to_db(float(datos.get("volumen", 1.0)))
	_bucle_inicio_reproduccion = float(datos.get("bucle_inicio", 0.0))
	_bucle_fin_reproduccion = float(datos.get("bucle_fin", 0.0))
	_audio_player.play()
	set_process(true)
	_tema_reproduciendo = clave
	btn.text = "■"

func _detener_audio() -> void:
	set_process(false)
	if _audio_player.playing:
		_audio_player.stop()
	_play_mapa_btn.text = "▶"
	_play_batalla_btn.text = "▶"
	_tema_reproduciendo = ""

## Replica AudioStreamPlayerMejorado._process: con inicio y fin > 0 vuelve al
## inicio del bucle al alcanzar el fin; con ambos en 0 reinicia al terminar
## (ver _on_audio_finished); en otro caso no hay bucle.
func _process(_delta: float) -> void:
	if not _audio_player.playing:
		return
	if _bucle_inicio_reproduccion > 0.0 and _bucle_fin_reproduccion > 0.0:
		if _audio_player.get_playback_position() >= _bucle_fin_reproduccion:
			_audio_player.seek(_bucle_inicio_reproduccion)

func _on_audio_finished() -> void:
	if is_processing() and _bucle_inicio_reproduccion == 0.0 and _bucle_fin_reproduccion == 0.0:
		_audio_player.play()
		return
	_detener_audio()

func _exit_tree() -> void:
	if is_instance_valid(_editor_temas):
		_editor_temas.queue_free()

# ═══════════════════════════════════════════════════════════════════════════════
# EDITOR DE TEMAS MUSICALES — VENTANA EMERGENTE
# ═══════════════════════════════════════════════════════════════════════════════

func _on_config_mapa_presionado() -> void:
	_abrir_editor_temas(_tema_registrado_seleccionado(_musica_mapa_option))

func _on_config_batalla_presionado() -> void:
	_abrir_editor_temas(_tema_registrado_seleccionado(_musica_batalla_option))

func _on_editar_encuentros_presionado() -> void:
	var mapa_id: String = ""
	if _mapa_node:
		mapa_id = str(_mapa_node.get("nombre_interno") if _mapa_node.get("nombre_interno") != null else "")
	solicitar_editor_encuentros.emit(mapa_id)

func _abrir_editor_temas(clave_inicial: String) -> void:
	if not is_instance_valid(_editor_temas):
		var escena = load(_EDITOR_TEMAS_ESCENA)
		if not escena:
			push_error("[ConfigMapas] No se pudo cargar %s" % _EDITOR_TEMAS_ESCENA)
			return
		_editor_temas = escena.instantiate()
		add_child(_editor_temas)
	_editor_temas.abrir(clave_inicial)


# ═══════════════════════════════════════════════════════════════════════════════
# SECCIÓN DE ENCUENTROS POKÉMON
# ═══════════════════════════════════════════════════════════════════════════════

func _cargar_encuentros_json() -> void:
	var file := FileAccess.open(RUTA_ENCUENTROS_JSON, FileAccess.READ)
	if not file:
		push_warning("[ConfigMapas] No se encontró %s" % RUTA_ENCUENTROS_JSON)
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) == TYPE_DICTIONARY:
		_encuentros_data = data
	else:
		push_warning("[ConfigMapas] Formato inválido en config_encuentros.json")

func _conectar_base_datos_enc() -> void:
	if not FileAccess.file_exists(RUTA_BASE_DATOS):
		push_warning("[ConfigMapas] Base de datos no encontrada: %s" % RUTA_BASE_DATOS)
		return
	var db_temp = SQLite.new()
	db_temp.path = RUTA_BASE_DATOS
	if not db_temp.open_db():
		push_warning("[ConfigMapas] No se pudo conectar a la base de datos")
		return
	# Precargar todos los Pokémon en caché de una sola vez y cerrar
	# la conexión inmediatamente para evitar errores SQLITE_NOMEM.
	var ok: bool = db_temp.query(
		"SELECT nombre_interno, numero_nacional, nombre FROM Pokemon"
	)
	if ok:
		for row in db_temp.query_result:
			var ni: String = str(row.get("nombre_interno", ""))
			if ni != "":
				_db_cache_enc[ni] = row
		print("[ConfigMapas] Caché de Pokémon cargada: %d entradas" % _db_cache_enc.size())
	else:
		push_warning("[ConfigMapas] Error al precargar Pokémon desde la BD")
	db_temp.close_db()
	# _db permanece null — todos los lookups se sirven desde _db_cache_enc

func _obtener_datos_poke_db(nombre_interno: String) -> Dictionary:
	if _db_cache_enc.has(nombre_interno):
		return _db_cache_enc[nombre_interno]
	if not _db:
		return {}
	var ok: bool = _db.query_with_bindings(
		"SELECT numero_nacional, nombre FROM Pokemon WHERE nombre_interno = ?",
		[nombre_interno]
	)
	var resultado = _db.query_result
	if resultado.size() > 0:
		_db_cache_enc[nombre_interno] = resultado[0]
		return resultado[0]
	# Solo cachear vacío si la query tuvo éxito (la especie no existe en la BD).
	# Si falló (ej. SQLITE_NOMEM), no cachear para que el siguiente intento reintente.
	if ok:
		_db_cache_enc[nombre_interno] = {}
	return {}

func _obtener_icono_encuentro(nombre_interno: String) -> Texture2D:
	if _icon_cache_enc.has(nombre_interno):
		return _icon_cache_enc[nombre_interno]
	var datos := _obtener_datos_poke_db(nombre_interno)
	if not datos.has("numero_nacional"):
		return null
	var num := int(datos["numero_nacional"])
	var ruta := RUTA_ICONOS_POKEMON + "icon%03d.png" % num
	if not ResourceLoader.exists(ruta):
		_icon_cache_enc[nombre_interno] = null
		return null
	var base_tex := load(ruta) as Texture2D
	if base_tex == null:
		_icon_cache_enc[nombre_interno] = null
		return null
	# Los iconos son 64x32 (2 frames de 32x32 lado a lado). Usamos el frame 0 (izquierda).
	var img := base_tex.get_image()
	var tex: Texture2D
	if img != null and base_tex.get_width() >= 64 and base_tex.get_height() == 32:
		var frame_img := img.get_region(Rect2i(0, 0, 32, 32))
		tex = ImageTexture.create_from_image(frame_img)
	else:
		tex = base_tex
	_icon_cache_enc[nombre_interno] = tex
	return tex

## Agrupa los slots de un tipo de encuentro por especie, calculando rango de niveles.
## Devuelve Array de Dictionaries: {nombre_interno, nombre, nivel_min, nivel_max}
func _agrupar_por_especie(slots: Array) -> Array:
	var mapa: Dictionary = {}
	for slot in slots:
		var ni: String = slot.get("nombre_interno", "")
		if ni == "":
			continue
		var nmin: int = int(slot.get("nivel_min", 1))
		var nmax: int = int(slot.get("nivel_max", 1))
		if mapa.has(ni):
			mapa[ni]["nivel_min"] = mini(mapa[ni]["nivel_min"], nmin)
			mapa[ni]["nivel_max"] = maxi(mapa[ni]["nivel_max"], nmax)
		else:
			var datos_db := _obtener_datos_poke_db(ni)
			var nombre_visible: String = datos_db.get("nombre", ni)
			mapa[ni] = {
				"nombre_interno": ni,
				"nombre": nombre_visible,
				"nivel_min": nmin,
				"nivel_max": nmax,
			}
	var result: Array = mapa.values()
	result.sort_custom(func(a, b): return a["nombre_interno"] < b["nombre_interno"])
	return result

func _construir_tarjeta_poke(nombre_visible: String, nivel_min: int, nivel_max: int, tex: Texture2D) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(56, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if tex:
		icon_rect.texture = tex
	vbox.add_child(icon_rect)

	var nombre_lbl := Label.new()
	nombre_lbl.text = nombre_visible
	nombre_lbl.add_theme_font_size_override("font_size", 9)
	nombre_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre_lbl.clip_text = true
	nombre_lbl.custom_minimum_size = Vector2(52, 0)
	vbox.add_child(nombre_lbl)

	var nivel_text: String
	if nivel_min == nivel_max:
		nivel_text = "Nv.%d" % nivel_min
	else:
		nivel_text = "Nv.%d-%d" % [nivel_min, nivel_max]
	var nivel_lbl := Label.new()
	nivel_lbl.text = nivel_text
	nivel_lbl.add_theme_font_size_override("font_size", 9)
	nivel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(nivel_lbl)

	return card

func _actualizar_seccion_encuentros() -> void:
	if not is_instance_valid(_encuentros_container):
		return
	for child in _encuentros_container.get_children():
		child.queue_free()

	if not _mapa_node:
		return

	var nombre_interno: String = str(_mapa_node.get("nombre_interno") if _mapa_node.get("nombre_interno") != null else "").to_lower()
	if nombre_interno == "" or not _encuentros_data.has(nombre_interno):
		var lbl := Label.new()
		lbl.text = "(sin encuentros configurados)"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_encuentros_container.add_child(lbl)
		return

	var config_mapa: Dictionary = _encuentros_data[nombre_interno]

	# Tipos en orden fijo: hierba → agua → pesca → roca
	var tipos := [
		{"clave": "hierba", "titulo": "🌿 Hierba"},
		{"clave": "agua",   "titulo": "🌊 Agua"},
		{"clave": "pesca",  "titulo": "🎣 Pesca"},
		{"clave": "roca",   "titulo": "🪨 Roca"},
	]

	var alguna_columna := false
	for tipo_info in tipos:
		var clave: String = tipo_info["clave"]
		if not config_mapa.has(clave):
			continue
		var tipo_data: Dictionary = config_mapa[clave]
		var slots: Array = tipo_data.get("encuentros", [])
		if slots.is_empty():
			continue

		alguna_columna = true
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.custom_minimum_size = Vector2(ANCHO_MIN_COLUMNA_ENCUENTRO, 0)
		col.add_theme_constant_override("separation", 4)
		_encuentros_container.add_child(col)

		var ratio: int = int(tipo_data.get("ratio", -1))
		var header_text: String = tipo_info["titulo"]
		if ratio >= 0:
			header_text += "  (ratio %d)" % ratio
		var header_lbl := Label.new()
		header_lbl.text = header_text
		header_lbl.add_theme_font_size_override("font_size", 11)
		col.add_child(header_lbl)

		var flow := FlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		col.add_child(flow)

		var especies := _agrupar_por_especie(slots)
		for especie in especies:
			var tex := _obtener_icono_encuentro(especie["nombre_interno"])
			var tarjeta := _construir_tarjeta_poke(
				especie["nombre"],
				especie["nivel_min"],
				especie["nivel_max"],
				tex
			)
			flow.add_child(tarjeta)

	if not alguna_columna:
		var lbl := Label.new()
		lbl.text = "(sin encuentros configurados)"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_encuentros_container.add_child(lbl)
