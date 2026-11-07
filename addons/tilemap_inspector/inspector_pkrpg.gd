@tool
extends EditorInspectorPlugin

signal solicitar_editor_warps(warp: Node)
## Abrir la definición del entrenador (lista_entrenadores.json) en el editor de entrenadores.
signal solicitar_editor_entrenador(entrenador_id: int)

const DialogosCSV = preload("res://addons/tilemap_inspector/editores/editor_dialogos/dialogos_csv.gd")
const EditorTextoRapidoScene := preload("res://addons/tilemap_inspector/editores/editor_dialogos/editor_texto_rapido.tscn")
const EditorDialogosScene := preload("res://addons/tilemap_inspector/editores/editor_dialogos/editor_dialogos.tscn")
const EditorPropertyAvatar = preload("res://addons/tilemap_inspector/editor_property_avatar.gd")
const EditorPropertyBaya = preload("res://addons/tilemap_inspector/editor_property_baya.gd")
const EditorPropertyEstiloWarp = preload("res://addons/tilemap_inspector/editor_property_estilo_warp.gd")

## Script base de los NPC: sus nodos (y los de scripts que heredan de él) usan el
## selector de avatares para `selec_frames`.
const RUTA_SCRIPT_NPC_BASE := "res://scripts/npc/npc_base.gd"
## Árbol de bayas: `baya_inicial` se elige con la galería de bayas.
const RUTA_SCRIPT_BAYA := "res://graficos/bayas/controlador_baya.gd"
## NPC entrenador: `entrenador_id` lleva un botón para abrir su definición.
const RUTA_SCRIPT_NPC_ENTRENADOR := "res://scripts/npc/npc_entrenador.gd"

const RUTA_BASE_DATOS := "res://BaseDatos/poke.db"
const RUTA_ESCENAS_MAPAS := "res://escenas/mapas/"
## Milisegundos mínimos entre re-escaneos de los .tscn al comprobar id_item repetidos
## (el botón ↻ fuerza el re-escaneo). El escaneo lee ~5 MB de texto: barato, pero
## no hace falta repetirlo en cada repintado del inspector.
const TTL_INDICE_IDS_MS := 5000

var botones_validacion: Dictionary = {}

## Cache de la tabla Objetos (para objeto_a_entregar de ItemOverworld). Cada entrada:
## {nombre_interno (MAYÚSCULAS), nombre, descripcion, bolsillo, valido}. `valido` = tiene bolsillo
## activo (sin él SistemaGuardado no puede entregarlo). Se lee de poke.db, se cierra la
## conexión enseguida y se refresca al abrir el selector o al pulsar el botón de estado.
var _objetos_lista: Array[Dictionary] = []
var _objetos_por_nombre: Dictionary = {}
var _objetos_cargados: bool = false
var _objetos_bd_ok: bool = false

## Índice id_item -> Array[ruta .tscn] de los mapas (ver _obtener_indice_ids_items).
var _indice_ids_items: Dictionary = {}
var _indice_ids_items_ms: int = -1

func _can_handle(object: Object) -> bool:
	if object == null:
		return false

	return _es_warp(object) or _es_item(object) or _tiene_id_texto(object) or _es_npc(object) or _es_baya(object)

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	# NPC (o varios NPC seleccionados): selector de avatares con miniatura y galería.
	if name == "selec_frames" and _es_npc(object):
		add_property_editor(name, EditorPropertyAvatar.new())
		return true

	# Árbol de bayas (o varios): selector con icono y galería en lugar de la lista.
	if name == "baya_inicial" and _es_baya(object):
		add_property_editor(name, EditorPropertyBaya.new())
		return true

	if name == "id_texto":
		var hb = HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label = Label.new()
		label.text = "ID Texto"
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		# capturar click sobre la etiqueta del inspector
		label.gui_input.connect(Callable(self, "_on_inspector_label_gui_input").bind(object, name))
		var line = LineEdit.new()
		line.text = str(object.get(name))
		line.focus_mode = Control.FOCUS_ALL
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# cuando el usuario cambia el valor en el inspector, propagarlo
		line.text_changed.connect(Callable(self, "_on_inspector_value_changed").bind(object, name))
		hb.add_child(label)
		hb.add_child(line)

		var boton_editar := Button.new()
		boton_editar.custom_minimum_size = Vector2(28, 0)
		boton_editar.pressed.connect(Callable(self, "_on_boton_editar_texto_pressed").bind(object, name))
		hb.add_child(boton_editar)
		_actualizar_boton_editar_texto(str(object.get(name)), boton_editar)
		# el LineEdit y el botón deben quedar en sync si el usuario teclea a mano
		line.text_changed.connect(Callable(self, "_actualizar_boton_editar_texto").bind(boton_editar))

		add_custom_control(hb)
		return true

	# Warp: vista previa (animación «cerrada») bajo el desplegable de estilo_warp.
	if _es_warp(object) and name == "estilo_warp":
		add_property_editor(name, EditorPropertyEstiloWarp.new(), true, "Vista previa")
		return false

	if _es_warp(object) and name == "ruta_mapa_destino":
		var boton_conexion := Button.new()
		boton_conexion.text = "Editar conexión…"
		boton_conexion.tooltip_text = "Abre el editor de la conexión del warp (Ctrl+M). Funciona también si el destino aún no está definido."
		boton_conexion.pressed.connect(func():
			if is_instance_valid(object):
				solicitar_editor_warps.emit(object)
		, CONNECT_DEFERRED)
		add_custom_control(boton_conexion)

	# NPC entrenador (un solo nodo): botón sobre `entrenador_id` que abre su registro
	# en el editor de entrenadores. El ID se lee al pulsar, así vale tras editarlo.
	if name == "entrenador_id" and object is Node and _es_de_script(object, RUTA_SCRIPT_NPC_ENTRENADOR):
		var boton_entrenador := Button.new()
		boton_entrenador.text = "Abrir en el editor de entrenadores…"
		boton_entrenador.tooltip_text = "Abre lista_entrenadores.json en el editor de entrenadores (Ctrl+E) con este entrenador seleccionado."
		boton_entrenador.pressed.connect(func():
			if is_instance_valid(object):
				solicitar_editor_entrenador.emit(int(object.get("entrenador_id")))
		, CONNECT_DEFERRED)
		add_custom_control(boton_entrenador)

	# ItemOverworld: id_texto ya lo cubre la rama de arriba (el nombre coincide).
	if _es_item(object) and name == "objeto_a_entregar":
		add_custom_control(_crear_control_objeto(object, name))
		return true

	if _es_item(object) and name == "id_item":
		add_custom_control(_crear_control_id_item(object, name))
		return true

	return false

func actualizar_validaciones() -> void:
	var entradas_invalidas: Array[int] = []
	for instance_id in botones_validacion:
		var entrada: Dictionary = botones_validacion[instance_id]
		var warp = instance_from_id(int(entrada.get("warp_id", 0)))
		var boton = instance_from_id(int(entrada.get("button_id", 0)))
		if not is_instance_valid(warp) or not is_instance_valid(boton):
			entradas_invalidas.append(instance_id)
			continue
		_actualizar_validacion(warp, boton)
	for instance_id in entradas_invalidas:
		botones_validacion.erase(instance_id)

func _actualizar_validacion(warp: Object, boton: Button) -> void:
	var destino := str(warp.get("ruta_mapa_destino")).strip_edges()
	if destino.is_empty():
		boton.text = "No definido"
		boton.disabled = true
		return
	if _buscar_escena_mapa("res://escenas/mapas/", destino).is_empty():
		boton.text = "No encontrado"
		boton.disabled = true
		return
	boton.text = "Abrir mapa destino"
	boton.disabled = false

func _on_inspector_label_gui_input(event: InputEvent, object: Object, property_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		DisplayServer.clipboard_set(str(object.get(property_name)))

func _on_inspector_value_changed(text: String, object: Object, property_name: String) -> void:
	if not is_instance_valid(object):
		return
	object.set(property_name, text)
	EditorInterface.mark_scene_as_unsaved()
	# No forzar un refresco del inspector mientras se escribe: hacerlo reconstruye
	# este control personalizado, destruye el LineEdit y le quita el foco después
	# de cada carácter. El botón de estado se actualiza por su propia conexión a
	# text_changed y el valor del objeto ya queda actualizado con set().

func _es_warp(object: Object) -> bool:
	if not object is Node:
		return false
	var script = object.get_script()
	return script != null and script.resource_path.ends_with("/scripts/warp.gd")

## ItemOverworld (objeto recogible): tiene id_item, objeto_a_entregar e id_texto.
func _es_item(object: Object) -> bool:
	if not object is Node:
		return false
	var script = object.get_script()
	return script != null and script.resource_path.ends_with("/scripts/ItemOverworld.gd")

## Nodo cuyo script es npc_base.gd o hereda de él. Con selección múltiple el inspector
## recibe un MultiNodeEdit: se acepta si TODOS los nodos seleccionados son NPC.
func _es_npc(object: Object) -> bool:
	return _es_de_script(object, RUTA_SCRIPT_NPC_BASE)

## Árbol de bayas (controlador_baya.gd), también con selección múltiple.
func _es_baya(object: Object) -> bool:
	return _es_de_script(object, RUTA_SCRIPT_BAYA)

## El nodo (o todos los de un MultiNodeEdit) usa ese script o uno que hereda de él.
func _es_de_script(object: Object, ruta_script: String) -> bool:
	if object is Node:
		return _script_hereda_de(object.get_script(), ruta_script)
	if object.get_class() != "MultiNodeEdit":
		return false
	var nodos := EditorInterface.get_selection().get_selected_nodes()
	if nodos.is_empty():
		return false
	for nodo in nodos:
		if not _script_hereda_de(nodo.get_script(), ruta_script):
			return false
	return true

func _script_hereda_de(script_objeto: Variant, ruta_script: String) -> bool:
	var actual := script_objeto as Script
	while actual != null:
		if actual.resource_path == ruta_script:
			return true
		actual = actual.get_base_script()
	return false

func _tiene_id_texto(object: Object) -> bool:
	for p in object.get_property_list():
		if p.name == "id_texto":
			return true
	return false

## Una clave real solo usa A-Z, 0-9 y "_" (ej. CARTEL_VILLA_RAIZ); cualquier otra cosa
## (espacios, minúsculas, puntuación) es texto escrito directamente, que tr() devuelve tal cual.
func _es_texto_literal(valor: String) -> bool:
	if valor.is_empty():
		return false
	for c in valor:
		if not (c == "_" or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")):
			return true
	return false

## Verde = la clave existe en dialogos.csv, amarillo = texto directo sin traducción,
## rojo = vacía o clave que no se encontró ("clave rota").
func _actualizar_boton_editar_texto(valor: String, boton: Button) -> void:
	if not valor.is_empty() and DialogosCSV.existe_clave(valor):
		boton.text = "✎"
		boton.tooltip_text = "Editar el texto de '%s'" % valor
		boton.modulate = Color(0.75, 1.0, 0.75)
	elif _es_texto_literal(valor):
		boton.text = "✎ (texto)"
		boton.tooltip_text = "Texto directo, sin traducción (se muestra tal cual). Click para convertirlo en una clave."
		boton.modulate = Color(1.0, 0.95, 0.6)
	else:
		boton.text = "✎ (rota)"
		boton.tooltip_text = "'%s' no existe en dialogos.csv. Elegir o crear una clave." % valor
		boton.modulate = Color(1.0, 0.75, 0.75)

func _on_boton_editar_texto_pressed(object: Object, property_name: String) -> void:
	var valor := str(object.get(property_name))
	if not valor.is_empty() and DialogosCSV.existe_clave(valor):
		_abrir_editor_rapido_para_clave(valor)
	else:
		_abrir_selector_de_clave(object, property_name)

## editor_texto_rapido.tscn ya es una Window (igual que el resto de ventanas de
## esta suite): se agrega directo al base control, sin envolverla en otra.
func _abrir_editor_rapido_para_clave(id: String) -> void:
	var editor_rapido: Window = EditorTextoRapidoScene.instantiate()
	EditorInterface.get_base_control().add_child(editor_rapido)
	editor_rapido.close_requested.connect(func(): editor_rapido.queue_free())
	editor_rapido.call("abrir_para_clave", id)

## editor_dialogos.tscn es un Control (para poder embeberse en otros lados),
## así que aquí sí hace falta una Window transitoria propia.
func _abrir_selector_de_clave(object: Object, property_name: String) -> void:
	var ventana := Window.new()
	ventana.title = "Elegir o crear clave de diálogo"
	ventana.size = Vector2i(1000, 680)
	ventana.min_size = Vector2i(760, 480)

	# sin tipar: PackedScene.instantiate() devuelve Node y necesitamos acceder
	# a la señal/metodo propios de editor_dialogos.gd (Control) sin choque de tipos
	var selector = EditorDialogosScene.instantiate()
	ventana.add_child(selector)
	selector.activar_modo_selector()
	selector.clave_elegida.connect(func(id: String):
		if is_instance_valid(object):
			object.set(property_name, id)
			EditorInterface.mark_scene_as_unsaved()
			object.notify_property_list_changed()
		ventana.queue_free()
	)
	ventana.close_requested.connect(func(): ventana.queue_free())

	EditorInterface.get_base_control().add_child(ventana)
	var valor_actual := str(object.get(property_name))
	if _es_texto_literal(valor_actual):
		selector.call("abrir", "")
		selector.call("precargar_texto_nuevo", valor_actual)
	else:
		selector.call("abrir", valor_actual)
	ventana.popup_centered()
	ventana.grab_focus()

func _abrir_mapa_destino(warp: Object) -> void:
	var destino := str(warp.get("ruta_mapa_destino")).strip_edges()
	if destino.is_empty():
		push_warning("[PKRPG] El Warp no tiene ruta_mapa_destino configurada")
		return

	var escena_destino := _buscar_escena_mapa("res://escenas/mapas/", destino)
	if escena_destino.is_empty():
		push_warning("[PKRPG] No se encontró el mapa destino: %s" % destino)
		return

	var posicion_destino := Vector2(warp.get("posicion_destino"))
	var punto_destino := posicion_destino * 16.0 + Vector2(8.0, 8.0)
	EditorInterface.open_scene_from_path(escena_destino)
	_centrar_escena_destino(escena_destino, punto_destino)

func _centrar_escena_destino(escena_destino: String, punto_destino: Vector2) -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return
	for _i in range(20):
		await scene_tree.process_frame
		var raiz := EditorInterface.get_edited_scene_root()
		if raiz != null and raiz.scene_file_path == escena_destino:
			var viewport_2d := EditorInterface.get_editor_viewport_2d()
			if viewport_2d != null:
				var canvas_transform := viewport_2d.global_canvas_transform
				canvas_transform.origin = viewport_2d.size * 0.5 - canvas_transform.basis_xform(punto_destino)
				viewport_2d.global_canvas_transform = canvas_transform
			return

func _buscar_escena_mapa(base_path: String, nombre_mapa: String) -> String:
	var dir := DirAccess.open(base_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if file_name == "." or file_name == "..":
			continue
		if dir.current_is_dir():
			var encontrada := _buscar_escena_mapa(base_path + file_name + "/", nombre_mapa)
			if not encontrada.is_empty():
				dir.list_dir_end()
				return encontrada
		elif file_name.get_extension().to_lower() == "tscn" and file_name.get_basename().to_lower() == nombre_mapa.to_lower():
			dir.list_dir_end()
			return base_path + file_name
	dir.list_dir_end()
	return ""


# ─── ItemOverworld: objeto_a_entregar (validación contra la tabla Objetos) ──────

## Lee la tabla Objetos de poke.db en la cache del plugin. Devuelve false (y deja el
## inspector funcionando sin validación) si la BD no existe o no abre.
func _cargar_objetos(forzar: bool = false) -> bool:
	if _objetos_cargados and not forzar:
		return _objetos_bd_ok
	_objetos_cargados = true
	_objetos_bd_ok = false
	_objetos_lista.clear()
	_objetos_por_nombre.clear()

	if not FileAccess.file_exists(RUTA_BASE_DATOS):
		return false
	var db := SQLite.new()
	db.path = RUTA_BASE_DATOS
	if not db.open_db():
		return false
	# LEFT JOIN a bolsillos activos: sin bolsillo (NULL o inactivo) el objeto existe
	# pero SistemaGuardado no puede entregarlo.
	var consulta_ok: bool = db.query("SELECT o.nombre_interno AS nombre_interno, o.nombre AS nombre, o.descripcion AS descripcion, b.nombre AS bolsillo FROM Objetos o LEFT JOIN Bolsillos b ON b.id = o.bolsillo_id AND b.activo = 1 ORDER BY o.nombre_interno")
	if consulta_ok:
		for fila in db.query_result:
			var interno := str(fila.get("nombre_interno", "")).strip_edges().to_upper()
			if interno.is_empty():
				continue
			var bolsillo := "" if fila.get("bolsillo") == null else str(fila.get("bolsillo"))
			var entrada := {
				"nombre_interno": interno,
				"nombre": str(fila.get("nombre", "")),
				"descripcion": "" if fila.get("descripcion") == null else str(fila.get("descripcion")),
				"bolsillo": bolsillo,
				"valido": not bolsillo.is_empty(),
			}
			_objetos_lista.append(entrada)
			_objetos_por_nombre[interno] = entrada
	db.close_db()
	_objetos_bd_ok = consulta_ok
	return _objetos_bd_ok

func _crear_control_objeto(object: Object, property_name: String) -> Control:
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = "Objeto"
	label.tooltip_text = "nombre_interno del objeto en la tabla Objetos de poke.db (se guarda en MAYÚSCULAS)."
	hb.add_child(label)

	var line := LineEdit.new()
	line.text = str(object.get(property_name))
	line.placeholder_text = "NOMBRE-INTERNO"
	line.focus_mode = Control.FOCUS_ALL
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(line)

	var boton_estado := Button.new()
	boton_estado.custom_minimum_size = Vector2(28, 0)
	hb.add_child(boton_estado)

	var boton_elegir := Button.new()
	boton_elegir.text = "Elegir…"
	hb.add_child(boton_elegir)

	_cargar_objetos()
	_actualizar_boton_objeto(line.text, boton_estado)
	boton_elegir.disabled = not _objetos_bd_ok
	if not _objetos_bd_ok:
		boton_elegir.tooltip_text = "No se pudo leer poke.db: selector y validación desactivados."

	# Al teclear solo se asigna (sin notify_property_list_changed: reconstruiría el
	# inspector y el LineEdit perdería el foco a mitad de escritura).
	line.text_changed.connect(func(texto: String) -> void:
		if not is_instance_valid(object):
			return
		object.set(property_name, texto)
		EditorInterface.mark_scene_as_unsaved()
		_actualizar_boton_objeto(texto, boton_estado)
	)
	# Al salir del campo se muestra el valor normalizado por el setter (MAYÚSCULAS).
	line.focus_exited.connect(func() -> void:
		if is_instance_valid(object):
			line.text = str(object.get(property_name))
	)
	boton_estado.pressed.connect(func() -> void:
		_cargar_objetos(true)
		boton_elegir.disabled = not _objetos_bd_ok
		_actualizar_boton_objeto(line.text, boton_estado)
	)
	boton_elegir.pressed.connect(_abrir_selector_de_objeto.bind(object, property_name))
	return hb

## Verde = existe en Objetos con bolsillo, amarillo = existe sin bolsillo válido (no se
## puede entregar), rojo = vacío o inexistente, gris = BD no disponible (sin validar).
func _actualizar_boton_objeto(valor: String, boton: Button) -> void:
	var interno := valor.strip_edges().to_upper()
	if not _objetos_bd_ok:
		boton.text = "?"
		boton.tooltip_text = "poke.db no disponible: no se puede validar el objeto."
		boton.modulate = Color.WHITE
	elif interno.is_empty():
		boton.text = "✖"
		boton.tooltip_text = "Sin objeto: el item no entregará nada."
		boton.modulate = Color(1.0, 0.75, 0.75)
	elif not _objetos_por_nombre.has(interno):
		boton.text = "✖"
		boton.tooltip_text = "'%s' no existe en la tabla Objetos. Usa «Elegir…». (Click: releer la BD)" % interno
		boton.modulate = Color(1.0, 0.75, 0.75)
	else:
		var entrada: Dictionary = _objetos_por_nombre[interno]
		if entrada.get("valido", false):
			boton.text = "✔"
			boton.tooltip_text = "%s — %s (bolsillo: %s). (Click: releer la BD)" % [interno, entrada.get("nombre", ""), entrada.get("bolsillo", "")]
			boton.modulate = Color(0.75, 1.0, 0.75)
		else:
			boton.text = "⚠"
			boton.tooltip_text = "'%s' existe pero no tiene bolsillo activo: el juego no puede entregarlo." % interno
			boton.modulate = Color(1.0, 0.95, 0.6)

## Diálogo con filtro y lista "NOMBRE_INTERNO — nombre — bolsillo" leída de poke.db.
func _abrir_selector_de_objeto(object: Object, property_name: String) -> void:
	if not _cargar_objetos(true):
		push_warning("[PKRPG] No se pudo leer la tabla Objetos de %s" % RUTA_BASE_DATOS)
		return

	var dialogo := ConfirmationDialog.new()
	dialogo.title = "Elegir objeto (tabla Objetos)"
	dialogo.ok_button_text = "Elegir"
	dialogo.min_size = Vector2i(640, 520)
	dialogo.max_size = Vector2i(640, 900)

	var caja := VBoxContainer.new()
	dialogo.add_child(caja)
	var fila_filtro := HBoxContainer.new()
	caja.add_child(fila_filtro)
	var filtro := LineEdit.new()
	filtro.placeholder_text = "Filtrar por nombre interno o nombre…"
	filtro.clear_button_enabled = true
	filtro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_filtro.add_child(filtro)
	var boton_recargar := Button.new()
	boton_recargar.text = "↻ Recargar BD"
	boton_recargar.tooltip_text = "Vuelve a leer la tabla Objetos de poke.db y descarta los datos cacheados (nombres, descripciones, bolsillos)."
	fila_filtro.add_child(boton_recargar)
	var lista := ItemList.new()
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.custom_minimum_size = Vector2(0, 340)
	caja.add_child(lista)
	# Descripción del objeto seleccionado (tal como está ahora en la BD) y estado de la lectura
	var detalle := Label.new()
	detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.custom_minimum_size = Vector2(0, 44)
	caja.add_child(detalle)
	var estado_carga := Label.new()
	estado_carga.modulate = Color(1, 1, 1, 0.6)
	caja.add_child(estado_carga)

	var boton_ok := dialogo.get_ok_button()
	boton_ok.disabled = true

	var rellenar := func(texto_filtro: String) -> void:
		lista.clear()
		var f := texto_filtro.strip_edges().to_lower()
		for entrada in _objetos_lista:
			var interno: String = entrada["nombre_interno"]
			var nombre: String = entrada["nombre"]
			if not f.is_empty() and not interno.to_lower().contains(f) and not nombre.to_lower().contains(f):
				continue
			var bolsillo: String = entrada["bolsillo"] if entrada["valido"] else "sin bolsillo"
			var indice := lista.add_item("%s — %s — %s" % [interno, nombre, bolsillo])
			lista.set_item_metadata(indice, interno)
			if not entrada["valido"]:
				lista.set_item_disabled(indice, true)
		boton_ok.disabled = true

	var aplicar := func(indice: int) -> void:
		var interno := str(lista.get_item_metadata(indice))
		if is_instance_valid(object):
			object.set(property_name, interno)
			EditorInterface.mark_scene_as_unsaved()
			object.notify_property_list_changed()
		dialogo.queue_free()

	var mostrar_detalle := func(indice: int) -> void:
		var entrada: Dictionary = _objetos_por_nombre.get(str(lista.get_item_metadata(indice)), {})
		var texto: String = str(entrada.get("descripcion", ""))
		detalle.text = texto if not texto.is_empty() else "(sin descripción)"

	boton_recargar.pressed.connect(func() -> void:
		var seleccionado := ""
		var elegidos := lista.get_selected_items()
		if not elegidos.is_empty():
			seleccionado = str(lista.get_item_metadata(elegidos[0]))
		if not _cargar_objetos(true):
			estado_carga.text = "No se pudo leer %s" % RUTA_BASE_DATOS
			push_warning("[PKRPG] No se pudo releer la tabla Objetos de %s" % RUTA_BASE_DATOS)
			return
		rellenar.call(filtro.text)
		detalle.text = ""
		for i in lista.item_count:
			if str(lista.get_item_metadata(i)) == seleccionado:
				lista.select(i)
				lista.ensure_current_is_visible()
				mostrar_detalle.call(i)
				boton_ok.disabled = false
				break
		estado_carga.text = "Recargado desde poke.db: %d objetos (%s)" % [_objetos_lista.size(), Time.get_time_string_from_system()]
	)
	filtro.text_changed.connect(rellenar)
	lista.item_selected.connect(func(i: int) -> void:
		boton_ok.disabled = false
		mostrar_detalle.call(i)
	)
	lista.item_activated.connect(aplicar)
	dialogo.confirmed.connect(func() -> void:
		var elegidos := lista.get_selected_items()
		if not elegidos.is_empty():
			aplicar.call(elegidos[0])
		else:
			dialogo.queue_free()
	)
	dialogo.canceled.connect(func() -> void: dialogo.queue_free())
	dialogo.close_requested.connect(func() -> void: dialogo.queue_free())

	rellenar.call("")
	# Preselecciona el valor actual si existe
	var actual := str(object.get(property_name)).strip_edges().to_upper()
	for i in lista.item_count:
		if str(lista.get_item_metadata(i)) == actual:
			lista.select(i)
			lista.ensure_current_is_visible()
			mostrar_detalle.call(i)
			boton_ok.disabled = false
			break

	EditorInterface.get_base_control().add_child(dialogo)
	dialogo.popup_centered()
	filtro.grab_focus()


# ─── ItemOverworld: id_item (indicador de unicidad) ──────────────────────────────

func _crear_control_id_item(object: Object, property_name: String) -> Control:
	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var fila := HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(fila)

	var label := Label.new()
	label.text = "Id Item"
	label.tooltip_text = "Identificador único del item. La partida guarda la bandera \"item_\" + id_item."
	fila.add_child(label)

	var line := LineEdit.new()
	line.text = str(object.get(property_name))
	line.placeholder_text = "mapa_objeto_nn"
	line.focus_mode = Control.FOCUS_ALL
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(line)

	var boton_revisar := Button.new()
	boton_revisar.text = "↻"
	boton_revisar.tooltip_text = "Revisar: vuelve a escanear los mapas en busca de id_item repetidos."
	fila.add_child(boton_revisar)

	var estado := Label.new()
	estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	estado.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caja.add_child(estado)

	_actualizar_estado_id_item(object, line.text, estado, false)
	line.text_changed.connect(func(texto: String) -> void:
		if not is_instance_valid(object):
			return
		object.set(property_name, texto)
		EditorInterface.mark_scene_as_unsaved()
		_actualizar_estado_id_item(object, texto, estado, false)
	)
	boton_revisar.pressed.connect(func() -> void:
		if is_instance_valid(object):
			_actualizar_estado_id_item(object, line.text, estado, true)
	)
	return caja

func _actualizar_estado_id_item(object: Object, id: String, estado: Label, forzar: bool) -> void:
	id = id.strip_edges()
	if id.is_empty():
		estado.text = "⚠ vacío: el item reaparece al recargar el mapa"
		estado.tooltip_text = "Sin id_item no se guarda bandera en la partida."
		estado.modulate = Color(1.0, 0.95, 0.6)
		return

	var repetidos: Array[String] = []
	var escena_actual := ""
	var raiz := EditorInterface.get_edited_scene_root()
	if raiz != null:
		escena_actual = raiz.scene_file_path
		# La escena abierta puede tener cambios sin guardar: se cuenta en vivo y su
		# copia en disco se ignora en el índice.
		var en_escena := _contar_items_con_id(raiz, id, object)
		if en_escena > 0:
			repetidos.append("esta escena (%d)" % en_escena)
	var indice := _obtener_indice_ids_items(forzar)
	var rutas: Array = indice.get(id, [])
	for ruta in rutas:
		var corta := str(ruta).trim_prefix(RUTA_ESCENAS_MAPAS)
		if str(ruta) != escena_actual and not repetidos.has(corta):
			repetidos.append(corta)

	if repetidos.is_empty():
		estado.text = "✔ único"
		estado.tooltip_text = "Ningún otro item de res://escenas/mapas/ usa este id."
		estado.modulate = Color(0.75, 1.0, 0.75)
	else:
		estado.text = "⚠ repetido en: " + ", ".join(repetidos)
		estado.tooltip_text = "Recoger uno de estos items marcaría la misma bandera y ocultaría los demás:\n" + "\n".join(repetidos)
		estado.modulate = Color(1.0, 0.75, 0.75)

## Items (ItemOverworld) de la escena abierta con ese id_item, sin contar `excluir`.
func _contar_items_con_id(nodo: Node, id: String, excluir: Object) -> int:
	var total := 0
	if nodo != excluir and _es_item(nodo) and str(nodo.get("id_item")).strip_edges() == id:
		total += 1
	for hijo in nodo.get_children():
		total += _contar_items_con_id(hijo, id, excluir)
	return total

## id_item -> Array de rutas de .tscn bajo res://escenas/mapas/ (lectura de texto +
## regex, sin cargar las escenas). Se recalcula como mucho cada TTL_INDICE_IDS_MS
## salvo que se fuerce (botón ↻).
func _obtener_indice_ids_items(forzar: bool = false) -> Dictionary:
	var ahora := Time.get_ticks_msec()
	if not forzar and _indice_ids_items_ms >= 0 and ahora - _indice_ids_items_ms < TTL_INDICE_IDS_MS:
		return _indice_ids_items
	_indice_ids_items = {}
	var regex := RegEx.new()
	regex.compile("(?m)^id_item = \"(.*)\"\\s*$")
	_escanear_ids_items(RUTA_ESCENAS_MAPAS, regex, _indice_ids_items)
	_indice_ids_items_ms = Time.get_ticks_msec()
	return _indice_ids_items

func _escanear_ids_items(base_path: String, regex: RegEx, indice: Dictionary) -> void:
	var dir := DirAccess.open(base_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if file_name.begins_with("."):
			continue
		if dir.current_is_dir():
			_escanear_ids_items(base_path + file_name + "/", regex, indice)
		elif file_name.get_extension().to_lower() == "tscn":
			var ruta := base_path + file_name
			var archivo := FileAccess.open(ruta, FileAccess.READ)
			if archivo == null:
				continue
			var texto := archivo.get_as_text()
			archivo.close()
			if not texto.contains("id_item"):
				continue
			for m in regex.search_all(texto):
				var id := m.get_string(1).strip_edges()
				if id.is_empty():
					continue
				if not indice.has(id):
					indice[id] = []
				indice[id].append(ruta)
	dir.list_dir_end()
