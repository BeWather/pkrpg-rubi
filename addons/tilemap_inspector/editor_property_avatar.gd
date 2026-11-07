@tool
extends EditorProperty

## Editor de la propiedad `selec_frames` (SpriteFrames) de los NPC (npc_base.gd).
## Muestra miniatura + nombre registrado, botón «Elegir…» (abre la galería) y «✕»
## (limpia). Clic en la miniatura o el nombre también abre la galería. Acepta
## soltar un .tres SpriteFrames desde el FileSystem, como el editor nativo.
## Asigna con emit_changed(): deshacer/rehacer y selección múltiple (MultiNodeEdit)
## los resuelve el inspector.
##
## Al elegir un avatar también ajusta `tamano_sprite` del NPC según el tamaño de
## fotograma del avatar (TAMANOS_FOTOGRAMA) y marca el nombre en naranja cuando el
## `tamano_sprite` actual no coincide con el del avatar.
##
## Para no penalizar mapas con muchos NPC solo lee el registro (cacheado) y la
## miniatura del recurso actual; la galería carga el resto al abrirse.

const RegistroAvatares = preload("res://addons/tilemap_inspector/registro_avatares.gd")
const VentanaGaleriaAvatares = preload("res://addons/tilemap_inspector/ventana_galeria_avatares.gd")

const TAMANO_MINIATURA := 32
const COLOR_ATENUADO := Color(1, 1, 1, 0.55)
const COLOR_ADVERTENCIA := Color(1.0, 0.7, 0.3)
## Valores y nombres de NpcBase.TamanoSprite (npc_base.gd), en el mismo orden del
## enum. No se precarga npc_base.gd para no arrastrar sus dependencias al addon.
const NOMBRES_TAMANO_SPRITE: Array[String] = ["NORMAL_16X22", "ALTO_16X32", "ANCHO_32X32", "OBJETO_16X16"]
## Tamaño de fotograma (px) -> índice de NOMBRES_TAMANO_SPRITE.
const TAMANOS_FOTOGRAMA := {
	Vector2i(16, 22): 0,
	Vector2i(16, 32): 1,
	Vector2i(32, 32): 2,
	Vector2i(16, 16): 3,
}

var _miniatura: TextureRect
var _etiqueta: Label
var _boton_elegir: Button
var _boton_limpiar: Button
var _valor: SpriteFrames = null


func _init() -> void:
	var escala := EditorInterface.get_editor_scale()
	var fila := HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(fila)

	_miniatura = TextureRect.new()
	_miniatura.custom_minimum_size = Vector2.ONE * TAMANO_MINIATURA * escala
	_miniatura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_miniatura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_miniatura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_miniatura.mouse_filter = Control.MOUSE_FILTER_STOP
	_miniatura.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fila.add_child(_miniatura)

	_etiqueta = Label.new()
	_etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_etiqueta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_etiqueta.clip_text = true
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_STOP
	_etiqueta.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fila.add_child(_etiqueta)

	_boton_elegir = Button.new()
	_boton_elegir.text = "Elegir…"
	_boton_elegir.tooltip_text = "Abrir la galería de avatares registrados."
	fila.add_child(_boton_elegir)

	_boton_limpiar = Button.new()
	_boton_limpiar.text = "✕"
	_boton_limpiar.flat = true
	_boton_limpiar.tooltip_text = "Quitar el avatar (dejar vacío)."
	fila.add_child(_boton_limpiar)

	add_focusable(_boton_elegir)
	add_focusable(_boton_limpiar)

	_boton_elegir.pressed.connect(_abrir_galeria)
	_boton_limpiar.pressed.connect(_on_limpiar_pressed)
	_miniatura.gui_input.connect(_on_area_gui_input)
	_etiqueta.gui_input.connect(_on_area_gui_input)
	# Soltar un .tres sobre cualquier parte de la fila (los botones consumen el
	# mouse, así que se les reenvía el drop a este EditorProperty).
	for control: Control in [_miniatura, _etiqueta, _boton_elegir, _boton_limpiar]:
		control.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)


func _update_property() -> void:
	var objeto := get_edited_object()
	if objeto == null:
		return
	var valor: Variant = objeto.get(get_edited_property())
	_valor = valor as SpriteFrames
	_boton_limpiar.disabled = is_read_only() or _valor == null

	if _hay_valores_distintos(objeto):
		_mostrar(null, "— varios valores —", "Los NPC seleccionados tienen avatares distintos.", false)
		_boton_limpiar.disabled = is_read_only()
		return
	if _valor == null:
		_mostrar(null, "— vacío —", "Sin avatar asignado. «Elegir…» o soltar un .tres SpriteFrames.", false)
		return

	var miniatura := RegistroAvatares.miniatura_de_recurso(_valor)
	var ruta := _valor.resource_path
	var entrada := RegistroAvatares.buscar_por_recurso(_valor)
	if not entrada.is_empty():
		var nombre := str(entrada.get("nombre", ""))
		_mostrar(miniatura, nombre, "%s\n%s" % [nombre, ruta], true)
		_anotar_tamano(objeto, nombre, ruta)
	elif ruta.is_empty() or ruta.contains("::"):
		_mostrar(miniatura, "(incrustado, sin registrar)", "SpriteFrames incrustado en la escena: no se puede registrar.", false)
	else:
		_mostrar(miniatura, "%s (sin registrar)" % ruta.get_file(), "%s\nNo está en el registro de avatares: se puede registrar desde la galería." % ruta, false)

func _mostrar(miniatura: Texture2D, texto: String, tooltip: String, registrado: bool) -> void:
	_miniatura.texture = miniatura
	_etiqueta.text = texto
	_etiqueta.tooltip_text = tooltip
	_miniatura.tooltip_text = tooltip
	_etiqueta.modulate = Color.WHITE if registrado else COLOR_ATENUADO
	if not registrado and has_theme_font(&"doc_italic", &"EditorFonts"):
		_etiqueta.add_theme_font_override(&"font", get_theme_font(&"doc_italic", &"EditorFonts"))
	else:
		_etiqueta.remove_theme_font_override(&"font")

## Valor de NpcBase.TamanoSprite que corresponde al fotograma del avatar, o -1 si
## el tamaño no está en TAMANOS_FOTOGRAMA.
func _tamano_sprite_para(frames: SpriteFrames) -> int:
	var tam := RegistroAvatares.tamano_de_frames(frames)
	return int(TAMANOS_FOTOGRAMA.get(tam, -1))

## Añade el tamaño del avatar al nombre y avisa si `tamano_sprite` no coincide.
func _anotar_tamano(objeto: Object, nombre: String, ruta: String) -> void:
	var tam := RegistroAvatares.tamano_de_frames(_valor)
	if tam == Vector2i.ZERO:
		return
	var etiqueta := "%s · %d×%d" % [nombre, tam.x, tam.y]
	var esperado := _tamano_sprite_para(_valor)
	if esperado < 0:
		_etiqueta.text = etiqueta
		_etiqueta.tooltip_text = "%s\n%s\nTamaño de fotograma %d×%d: no hay un TamanoSprite equivalente." % [nombre, ruta, tam.x, tam.y]
		_miniatura.tooltip_text = _etiqueta.tooltip_text
		return
	var actual := int(objeto.get(&"tamano_sprite"))
	var nombre_esperado := NOMBRES_TAMANO_SPRITE[esperado]
	if actual == esperado:
		_etiqueta.text = etiqueta
		return
	_etiqueta.text = "⚠ %s → %s" % [etiqueta, nombre_esperado]
	_etiqueta.modulate = COLOR_ADVERTENCIA
	_etiqueta.tooltip_text = "%s\n%s\nEl fotograma mide %d×%d: `tamano_sprite` debería ser %s (ahora %s). Se ajusta solo al volver a elegir el avatar." % [
		nombre, ruta, tam.x, tam.y, nombre_esperado, NOMBRES_TAMANO_SPRITE[actual] if actual >= 0 and actual < NOMBRES_TAMANO_SPRITE.size() else str(actual)]
	_miniatura.tooltip_text = _etiqueta.tooltip_text

## Emite el cambio del avatar y, si se conoce, el `tamano_sprite` que le corresponde.
func _emitir_avatar(frames: SpriteFrames) -> void:
	emit_changed(get_edited_property(), frames)
	if frames == null:
		return
	var esperado := _tamano_sprite_para(frames)
	if esperado >= 0 and int(get_edited_object().get(&"tamano_sprite")) != esperado:
		emit_changed(&"tamano_sprite", esperado)

## Con varios NPC seleccionados (MultiNodeEdit) indica si no comparten el mismo avatar.
func _hay_valores_distintos(objeto: Object) -> bool:
	if objeto is Node or objeto.get_class() != &"MultiNodeEdit":
		return false
	var propiedad := get_edited_property()
	var primero: Variant = null
	var hay_primero := false
	for nodo in EditorInterface.get_selection().get_selected_nodes():
		var valor: Variant = nodo.get(propiedad)
		if not hay_primero:
			primero = valor
			hay_primero = true
		elif valor != primero:
			return true
	return false

func _set_read_only(solo_lectura: bool) -> void:
	_boton_elegir.disabled = solo_lectura
	_boton_limpiar.disabled = solo_lectura or _valor == null


# ─── Acciones ────────────────────────────────────────────────────────────────────

func _abrir_galeria() -> void:
	if is_read_only():
		return
	VentanaGaleriaAvatares.abrir(_valor, _on_avatar_elegido)

func _on_avatar_elegido(frames: SpriteFrames) -> void:
	_emitir_avatar(frames)

func _on_limpiar_pressed() -> void:
	if is_read_only():
		return
	emit_changed(get_edited_property(), null)

func _on_area_gui_input(evento: InputEvent) -> void:
	var clic := evento as InputEventMouseButton
	if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
		_abrir_galeria()
		accept_event()


# ─── Arrastrar y soltar ──────────────────────────────────────────────────────────

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if is_read_only():
		return false
	var d := data as Dictionary if data is Dictionary else {}
	match str(d.get("type", "")):
		"files":
			return not _primer_archivo_sprite_frames(d.get("files")).is_empty()
		"resource":
			return d.get("resource") is SpriteFrames
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var d := data as Dictionary if data is Dictionary else {}
	var recurso: SpriteFrames = null
	match str(d.get("type", "")):
		"files":
			var ruta := _primer_archivo_sprite_frames(d.get("files"))
			if not ruta.is_empty():
				recurso = ResourceLoader.load(ruta) as SpriteFrames
		"resource":
			recurso = d.get("resource") as SpriteFrames
	if recurso == null:
		return
	var entrada := RegistroAvatares.buscar_por_recurso(recurso)
	if not entrada.is_empty():
		RegistroAvatares.registrar_reciente(RegistroAvatares.clave_de(entrada))
	_emitir_avatar(recurso)

## Primer archivo arrastrado que sea SpriteFrames (usa el tipo que ya conoce el
## FileSystem del editor: _can_drop_data se llama en cada movimiento del mouse).
func _primer_archivo_sprite_frames(archivos: Variant) -> String:
	if not (archivos is PackedStringArray or archivos is Array):
		return ""
	var sistema := EditorInterface.get_resource_filesystem()
	for archivo: Variant in archivos:
		var ruta := str(archivo)
		var tipo := sistema.get_file_type(ruta) if sistema != null else ""
		if tipo == "SpriteFrames":
			return ruta
		if tipo.is_empty() and ruta.get_extension().to_lower() == "tres" and RegistroAvatares.es_sprite_frames(ruta):
			return ruta
	return ""
