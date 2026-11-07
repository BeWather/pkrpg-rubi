@tool
extends EditorPlugin

var boton_pkrpg: Button
var ventana_posicion: Window
var ventana_posicion_scene := preload("res://addons/tilemap_inspector/ventana_posicion.tscn")
var character_scene := preload("res://escenas/character/girl.tscn")
var current_scene_path: String = ""
var tilemap_nodes: Array[TileMapLayer] = []
var selected_cx: int = -1
var selected_cy: int = -1
var original_cx: int = -1
var original_cy: int = -1
var character_instance: Node = null
var opened_via_plugin: bool = false
var label_extra: Label = null
var mapa_edicion: String = ""

var boton_personalizado: Button
var inspector_plugin: EditorInspectorPlugin

# Lápiz de mapa (NPC / Warp / Cartel): botón + menú junto al botón PKRPG.
# Ver lapiz_mapa.gd; aquí solo se le delegan _handles y la entrada del lienzo.
var lapiz_mapa: HBoxContainer = null

# Editor de entrenadores
var rpg_tools_submenu: PopupMenu
var editor_entrenadores_scene := preload("res://addons/tilemap_inspector/editor_entrenadores.tscn")
var ventana_editor_entrenadores: Window = null
var editor_temas_musicales_scene := preload("res://addons/tilemap_inspector/editores/editor_temas_musicales/editor_temas_musicales.tscn")
var ventana_editor_temas_musicales: Window = null
var editor_encuentros_scene := preload("res://addons/tilemap_inspector/editores/editor_encuentros/editor_encuentros.tscn")
var ventana_editor_encuentros: Window = null
# Editor visual de encuentros (iconos, probabilidades, mapa de región; ambas tablas).
var editor_encuentros_visual_scene := preload("res://addons/tilemap_inspector/editores/editor_encuentros_visual/editor_encuentros_visual.tscn")
var ventana_editor_encuentros_visual: Window = null
# Visor de la POKéDEX (HOENN/Nacional) con iconos y dónde aparece salvaje cada especie.
var visor_pokedex_scene := preload("res://addons/tilemap_inspector/editores/visor_pokedex/visor_pokedex.tscn")
var ventana_visor_pokedex: Window = null
var editor_tabla_tipos_scene := preload("res://addons/tilemap_inspector/editores/editor_tabla_tipos/editor_tabla_tipos.tscn")
var ventana_editor_tabla_tipos: Window = null
# Editor de MT/MO: movimiento de cada máquina (MaquinasMovimientos) y su
# descripción en la mochila (Objetos.descripcion).
var editor_maquinas_scene := preload("res://addons/tilemap_inspector/editores/editor_maquinas/editor_maquinas.tscn")
var ventana_editor_maquinas: Window = null
# Editor de Diálogos: edita BaseDatos/dialogos.csv. Es un Control (como
# editor_instancia_pokemon), por eso se envuelve en una Window propia.
var editor_dialogos_scene := preload("res://addons/tilemap_inspector/editores/editor_dialogos/editor_dialogos.tscn")
var ventana_editor_dialogos: Window = null
var editor_dialogos_ui: Control = null
# Editor de Posiciones de Battlers: edita escenas/batalla/battle_positions.json.
# Control envuelto en una Window propia (mismo patrón que el Editor de Diálogos).
var editor_posiciones_battlers_scene := preload("res://addons/tilemap_inspector/editores/editor_posiciones_battlers/editor_posiciones_battlers.tscn")
var ventana_editor_posiciones_battlers: Window = null
var editor_posiciones_battlers_ui: Control = null
# Editor de POI del mapa regional: edita BaseDatos/region_map_metadata.json.
var editor_poi_scene := preload("res://addons/tilemap_inspector/editores/editor_poi/editor_poi.tscn")
var ventana_editor_poi: Window = null
var editor_poi_ui: Control = null
# Editor de Instancia de Pokémon: edita una fila de PokemonInstancias.
# Otras herramientas pueden abrirlo con una instancia precargada llamando a
# _abrir_editor_instancia_pokemon_ventana(pokemon_id).
var editor_instancia_scene := preload("res://addons/tilemap_inspector/editor_instancia_pokemon.tscn")
var ventana_editor_instancia: Window = null
var editor_instancia_ui: Control = null
# Prueba de batallas: ventana NATIVA del editor (piloto opcion B).
# La instancia de juego se lanza desde la ventana con play_custom_scene
# sobre res://escenas/batalla/debug/lanzador_debug_batalla.tscn.
var ventana_debug_batalla_scene := preload("res://addons/tilemap_inspector/ventana_debug_batalla.tscn")
var ventana_debug_batalla: Window = null
var debug_batalla_ui: Control = null
var debug_partida_scene := preload("res://addons/tilemap_inspector/debug_partida_guardada.gd")
var ventana_debug_partida: Window = null
var debug_partida_ui: Control = null
var ventana_conexiones_warp: Window = null
var ventana_editar_warp: Window = null
var ventana_conexiones_warp_scene := preload("res://addons/tilemap_inspector/ventana_conexiones_warp.gd")
var menu_warp_lienzo: EditorContextMenuPlugin = null
var menu_spawn_debug: EditorContextMenuPlugin = null
## Destino del botón "Seleccionar" del Editor de Instancia: la herramienta que
## lo abrió por última vez (Debug Batalla por defecto, o Debug Partida).
var _receptor_editor_instancia: Object = null

# Dock "Config. Mapa" — se añade al panel inferior cuando hay una escena MapaConfiguracion abierta
var config_mapa_dock_scene := preload("res://addons/tilemap_inspector/editores/config_mapas/config_mapas.tscn")
var config_mapa_dock: Control = null
var config_mapa_dock_en_panel: bool = false
var _timer_escena: Timer = null

func _enter_tree():
	# === Toolbar button in 2D Canvas editor ===
	boton_pkrpg = Button.new()
	boton_pkrpg.text = "📦 PKRPG"
	boton_pkrpg.tooltip_text = "Mostrar/Ocultar panel Tilemap"
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, boton_pkrpg)
	boton_pkrpg.pressed.connect(Callable(self, "_on_tilemap_toolbar_button_pressed"))

	lapiz_mapa = preload("res://addons/tilemap_inspector/lapiz_mapa.gd").new()
	lapiz_mapa.configurar(self)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, lapiz_mapa)

	# === Dock Config. Mapa ===
	config_mapa_dock = config_mapa_dock_scene.instantiate()
	config_mapa_dock.set_undo_redo(get_undo_redo())
	config_mapa_dock.solicitar_editor_encuentros.connect(_on_solicitar_editor_encuentros)

	# Timer para detectar cambios de escena (usado por el dock y el botón PKRPG)
	_timer_escena = Timer.new()
	_timer_escena.wait_time = 0.5
	_timer_escena.autostart = true
	_timer_escena.timeout.connect(Callable(self, "_check_scene_change"))
	add_child(_timer_escena)

	# Forzar primera verificación de visibilidad
	_check_scene_change()

	# === Submenú Proyecto > Herramientas > RPG Tools ===
	rpg_tools_submenu = PopupMenu.new()
	rpg_tools_submenu.add_item("Editor de Entrenadores", 0)
	rpg_tools_submenu.add_item("Prueba de Batallas", 1)
	rpg_tools_submenu.add_item("Editor de Temas Musicales", 2)
	rpg_tools_submenu.add_item("Editor de Encuentros", 3)
	rpg_tools_submenu.add_item("Editor de Tabla de Tipos", 4)
	rpg_tools_submenu.add_item("Editor de Instancia de Pokémon", 5)
	rpg_tools_submenu.add_item("Editor de Diálogos", 6)
	rpg_tools_submenu.add_item("Editor de Posiciones de Battlers", 7)
	rpg_tools_submenu.add_item("Editor de POI del Mapa Regional", 8)
	rpg_tools_submenu.add_item("Debug Partida Guardada", 9)
	rpg_tools_submenu.add_item("Editor de MT/MO", 10)
	rpg_tools_submenu.add_item("Conexiones entre mapas", 11)
	rpg_tools_submenu.add_item("Editor de Encuentros (visual)", 12)
	rpg_tools_submenu.add_item("Pokédex y encuentros", 13)
	rpg_tools_submenu.id_pressed.connect(_on_rpg_tools_submenu_id_pressed)
	add_tool_submenu_item("RPG Tools", rpg_tools_submenu)

	# Creamos el botón intruso en el inspector
	# boton_personalizado = Button.new()
	# boton_personalizado.text = "LOGGEAR"
	# boton_personalizado.connect("pressed", Callable(self, "_on_boton_presionado"))
	# # Añadimos el botón al inspector
	# get_editor_interface().get_inspector().add_child(boton_personalizado)

	inspector_plugin = preload("res://addons/tilemap_inspector/inspector_pkrpg.gd").new()
	inspector_plugin.solicitar_editor_warps.connect(_abrir_editor_warp_minimo)
	inspector_plugin.solicitar_editor_entrenador.connect(_abrir_entrenador_en_editor)
	add_inspector_plugin(inspector_plugin)

	var menu_warp_script := preload("res://addons/tilemap_inspector/menu_contextual_warp.gd")
	menu_warp_lienzo = menu_warp_script.new()
	# Abrir la ventana cuando el menú nativo ya terminó de cerrar su popup.
	menu_warp_lienzo.solicitar_editor_warps.connect(_abrir_editor_warp_minimo, CONNECT_DEFERRED)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_2D_EDITOR, menu_warp_lienzo)
	menu_spawn_debug = preload("res://addons/tilemap_inspector/menu_contextual_spawn_debug.gd").new()
	menu_spawn_debug.colocar_spawn_debug.connect(_colocar_spawn_debug)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_2D_EDITOR, menu_spawn_debug)

func _on_boton_presionado():
	_loggear("Abrir Diálogo / Inspeccionar seleccion")
	var sel = get_editor_interface().get_selection()
	var nodes = sel.get_selected_nodes()
	if nodes.size() == 0:
		_loggear("No hay nodo seleccionado")
		return

	var n = nodes[0]
	_loggear("Seleccionado: %s (%s)" % [n.name, n.get_class()])
	_loggear("Path en escena: %s" % [n.get_path()])
	# Script / recurso asociado
	var scr = n.get_script()
	if scr:
		_loggear("Script: %s" % [str(scr.resource_path)])
	else:
		_loggear("Script: (ninguno)")

	# Propietario (owner) y padre
	_loggear("Owner: %s" % [str(n.owner)])
	_loggear("Parent: %s" % [str(n.get_parent())])
	_loggear("Hijos: %d" % [n.get_child_count()])

	# Grupos
	var grupos = n.get_groups()
	_loggear("Grupos: %s" % [str(grupos)])

	# Metadatos
	var metas = n.get_meta_list()
	if metas.size() > 0:
		for k in metas:
			_loggear("Meta %s = %s" % [k, n.get_meta(k)])
	else:
		_loggear("No tiene metadatos")

	# Listar algunas propiedades exportadas (filtrado simple)
	var props = n.get_property_list()
	var exported = []
	for p in props:
		if p.has("usage") and int(p.usage) & PROPERTY_USAGE_EDITOR != 0:
			exported.append(p.name)
	# Mostrar los primeros para no spamear
	_loggear("Propiedades exportadas (muestra): %s" % [str(exported.slice(0, 12))])

	# Datos según tipo
	if n is Node2D:
		_loggear("Posición (Node2D): %s, Rotación: %s, Escala: %s" % [str(n.position), str(n.rotation_degrees), str(n.scale)])
	if n is Control:
		_loggear("RectPosition: %s, Size: %s" % [str(n.rect_position), str(n.rect_size)])
	# TileMapLayer específico (adaptar según tu clase TileMapLayer)
	if n is TileMapLayer:
		_loggear("TileMapLayer detectado")
		# Ejemplo: tileset y coordenadas usadas
		var ts = n.get_tileset()
		if ts:
			_loggear("Tileset: %s" % [str(ts.resource_path)])
		# Intentar obtener alguna celda usada (si existen APIs)
		# Esto depende de tu versión/clase TileMapLayer; aquí un intento general:
		if n.has_method("get_used_cells"):
			var used = n.get_used_cells()
			_loggear("Celdas usadas: %d" % [used.size()])
	# Recursos enlazados (pequeño muestreo)
	var linked = []
	for p in props:
		if p.has("type") and typeof(n.get(p.name)) == TYPE_OBJECT and n.get(p.name) and n.get(p.name).has_method("get_path"):
			linked.append(p.name)
	if linked.size() > 0:
		_loggear("Propiedades con recursos enlazados: %s" % [str(linked.slice(0, 8))])

	# Opcional: abrir detalles en la ventana propia o enviar datos a ventana_posicion
	if ventana_posicion and is_instance_valid(ventana_posicion):
		# Envía datos mínimos para mostrar en la UI del plugin
		if ventana_posicion.has_method("update_selected_info"):
			var info = {
				"name": n.name,
				"class": n.get_class(),
				"path": str(n.get_path()),
				"pos": n.position if n is Node2D else null
			}
			ventana_posicion.call_deferred("update_selected_info", info)

func _on_tilemap_toolbar_button_pressed():
	_loggear("Botón PKRPG presionado")
	if not Engine.is_editor_hint():
		_loggear("No estamos en el editor, no hacemos nada.")
		return # Solo ejecuta en el editor, no en vista previa de escena
	_loggear("Estamos en el editor, continuamos.")
	var file_path = "res://partida/partida_guardada.json"
	var posicion = {}
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var data = JSON.parse_string(content)
			if typeof(data) == TYPE_DICTIONARY and data.has("posicion"):
				posicion = data["posicion"]
			file.close()
	var texto = "No se encontró información de posición."
	if posicion:
		texto = "Posición actual: %s en %s,%s" % [
			str(posicion.get("mapa_actual", "?")),
			str(int(posicion.get("cx", "?"))),
			str(int(posicion.get("cy", "?"))),
		]

	if not ventana_posicion or not is_instance_valid(ventana_posicion):
		ventana_posicion = ventana_posicion_scene.instantiate()
		add_child(ventana_posicion)
		print("[PKRPG] Ventana de posición creada")

		# Conectar señal de cierre de ventana
		ventana_posicion.close_requested.connect(_on_cancelar_pressed)
		print("[PKRPG] Señal de cierre de ventana conectada")

		# Conectar botones
		var pin_button = ventana_posicion.find_child("PinButton", true, false)
		var aceptar_button = ventana_posicion.find_child("AceptarButton", true, false)
		var cancelar_button = ventana_posicion.find_child("CancelarButton", true, false)

		if pin_button:
			pin_button.pressed.connect(_on_pin_pressed)
			print("[PKRPG] Botón Pin conectado")

		if aceptar_button:
			aceptar_button.pressed.connect(_on_aceptar_pressed)
			print("[PKRPG] Botón Aceptar conectado")

		if cancelar_button:
			cancelar_button.pressed.connect(_on_cancelar_pressed)
			print("[PKRPG] Botón Cancelar conectado")

		# Conectar señales del editor (solo una vez al crear la ventana)
		var editor_selection = get_editor_interface().get_selection()
		if not editor_selection.selection_changed.is_connected(Callable(self, "_on_selection_changed")):
			editor_selection.selection_changed.connect(Callable(self, "_on_selection_changed"))

		# Nota: el timer de detección de escena ya se crea en _enter_tree (_timer_escena).
	else:
		# La ventana ya existe, solo mostrarla de nuevo
		ventana_posicion.show()

	# Resetear coordenadas seleccionadas
	original_cx = posicion.get("cx", -1)
	original_cy = posicion.get("cy", -1)
	selected_cx = original_cx
	selected_cy = original_cy

	# Actualizar labels con los datos de posición
	var label_pos_guardada = ventana_posicion.find_child("LabelMapa", true, false)
	var label_pos_seleccionada = ventana_posicion.find_child("LabelPosicion", true, false)

	if label_pos_guardada and label_pos_guardada is Label:
		var mapa_actual = str(posicion.get("mapa_actual", "?"))
		var cx = posicion.get("cx", "?")
		var cy = posicion.get("cy", "?")
		label_pos_guardada.text = "%s: (%s, %s)" % [mapa_actual, int(cx), int(cy)]
		print("[PKRPG] Label mapa actualizado: ", label_pos_guardada.text)

	if label_pos_seleccionada and label_pos_seleccionada is Label:
		label_pos_seleccionada.text = "%s: (%s, %s)" % [str(posicion.get("mapa_actual", "?")), selected_cx, selected_cy]
		print("[PKRPG] Label posición actualizado: ", label_pos_seleccionada.text)

	# Cargar la escena del mapa guardado
	_cargar_mapa_guardado(str(posicion.get("mapa_actual", "")), posicion.get("cx", 0), posicion.get("cy", 0))

	# Cargar la escena actual del editor (o la misma del mapa guardado si no hay ninguna)
	_cargar_escena_editor(str(posicion.get("mapa_actual", "")))

	# ===========================================

	# Posicionar la ventana en una zona segura de la pantalla
	_posicionar_ventana_segura()

	# Verificar escena inicial
	_check_scene_change()

func _posicionar_ventana_segura():
	"""Posiciona la ventana con un margen seguro respecto al borde superior de la pantalla."""
	if not ventana_posicion:
		return
	var screen_id = DisplayServer.get_primary_screen()
	var screen_pos = DisplayServer.screen_get_position(screen_id)
	var screen_size = DisplayServer.screen_get_size(screen_id)
	var win_size = ventana_posicion.size
	# Centrar horizontalmente, con margen vertical de 80px desde el borde superior
	var margin_top = 80
	var x = screen_pos.x + (screen_size.x - win_size.x) / 2
	var y = screen_pos.y + margin_top
	ventana_posicion.position = Vector2i(x, y)
	print("[PKRPG] Ventana posicionada en: (%d, %d)" % [x, y])

func _on_rpg_tools_submenu_id_pressed(id: int):
	if id == 0:
		_abrir_editor_entrenadores_ventana()
	elif id == 1:
		_abrir_prueba_batalla_ventana()
	elif id == 2:
		_abrir_editor_temas_musicales_ventana()
	elif id == 3:
		_abrir_editor_encuentros_ventana()
	elif id == 4:
		_abrir_editor_tabla_tipos_ventana()
	elif id == 5:
		_abrir_editor_instancia_pokemon_ventana()
	elif id == 6:
		_abrir_editor_dialogos_ventana()
	elif id == 7:
		_abrir_editor_posiciones_battlers_ventana()
	elif id == 8:
		_abrir_editor_poi_ventana()
	elif id == 9:
		_abrir_debug_partida_ventana()
	elif id == 10:
		_abrir_editor_maquinas_ventana()
	elif id == 11:
		_abrir_conexiones_warp()
	elif id == 12:
		_abrir_editor_encuentros_visual_ventana()
	elif id == 13:
		_abrir_visor_pokedex_ventana()


func _abrir_conexiones_warp(warp: Node = null) -> void:
	if not is_instance_valid(ventana_conexiones_warp):
		ventana_conexiones_warp = ventana_conexiones_warp_scene.new()
		ventana_conexiones_warp.configurar(self)
		get_editor_interface().get_base_control().add_child(ventana_conexiones_warp)
	ventana_conexiones_warp.abrir(warp)


## Editor mínimo y modal del warp; se crea una ventana nueva por cada apertura.
func _abrir_editor_warp_minimo(warp: Node) -> void:
	if is_instance_valid(ventana_editar_warp):
		return
	ventana_editar_warp = preload("res://addons/tilemap_inspector/ventana_editar_warp.gd").new()
	ventana_editar_warp.configurar(self)
	get_editor_interface().get_base_control().add_child(ventana_editar_warp)
	ventana_editar_warp.abrir(warp)


func _colocar_spawn_debug(raiz: Node2D, celda: Vector2i) -> void:
	if not is_instance_valid(raiz) or raiz != EditorInterface.get_edited_scene_root():
		return
	var centro := SpawnDebug.posicion_desde_tile(celda)
	var existente: Node2D = raiz.call("_buscar_marcador_spawn") as Node2D
	var ur := get_undo_redo()
	if existente != null:
		var padre := existente.get_parent() as Node2D
		if padre == null:
			return
		var nueva_pos := padre.to_local(raiz.to_global(centro))
		if existente.position != nueva_pos:
			ur.create_action("Mover Spawn Debug a %s" % celda, UndoRedo.MERGE_DISABLE, raiz)
			ur.add_do_property(existente, "position", nueva_pos)
			ur.add_undo_property(existente, "position", existente.position)
			ur.commit_action()
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(existente)
		return
	var nuevo := SpawnDebug.new()
	nuevo.name = "SpawnDebug"
	nuevo.position = centro
	ur.create_action("Crear Spawn Debug en %s" % celda, UndoRedo.MERGE_DISABLE, raiz)
	ur.add_do_method(raiz, &"add_child", nuevo, true)
	ur.add_do_method(nuevo, &"set_owner", raiz)
	ur.add_do_reference(nuevo)
	ur.add_undo_method(raiz, &"remove_child", nuevo)
	ur.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(nuevo)


func _abrir_debug_partida_ventana() -> void:
	if not is_instance_valid(ventana_debug_partida):
		ventana_debug_partida = Window.new()
		ventana_debug_partida.title = "Debug Partida Guardada"
		ventana_debug_partida.size = Vector2i(1240, 800)
		ventana_debug_partida.min_size = Vector2i(960, 640)
		debug_partida_ui = debug_partida_scene.new()
		ventana_debug_partida.add_child(debug_partida_ui)
		# La pestaña Pokémon edita en el Editor de Instancia y recibe de vuelta
		# el resultado de su botón "Seleccionar".
		debug_partida_ui.solicitar_editor_instancia.connect(func(datos: Dictionary):
			_abrir_editor_instancia_pokemon_ventana(-1, datos, debug_partida_ui)
		)
		ventana_debug_partida.close_requested.connect(func(): debug_partida_ui.solicitar_cierre())
		debug_partida_ui.cierre_confirmado.connect(func(): ventana_debug_partida.hide())
		get_editor_interface().get_base_control().add_child(ventana_debug_partida)
	debug_partida_ui.abrir()
	ventana_debug_partida.popup_centered()
	ventana_debug_partida.grab_focus()

func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_E:
			_abrir_editor_entrenadores_ventana()
			get_viewport().set_input_as_handled()
		# Ctrl+M sobre un warp seleccionado (Alt Gr lo captura el editor).
		elif (event.keycode == KEY_M or event.physical_keycode == KEY_M) and event.is_command_or_control_pressed() and not event.alt_pressed and not event.shift_pressed:
			var foco := get_editor_interface().get_base_control().get_viewport().gui_get_focus_owner()
			if foco is LineEdit or foco is TextEdit:
				return
			var warp := _warp_seleccionado()
			if warp != null:
				_abrir_editor_warp_minimo(warp)
				get_viewport().set_input_as_handled()

## Abre un mapa en el editor y, si `punto.x >= 0`, centra la vista 2D en él.
func abrir_mapa_centrado(ruta: String, punto: Vector2) -> void:
	EditorInterface.open_scene_from_path(ruta)
	if punto.x < 0:
		return
	for _i in 20:
		await get_tree().process_frame
		var raiz := EditorInterface.get_edited_scene_root()
		if raiz != null and raiz.scene_file_path == ruta:
			var viewport_2d := EditorInterface.get_editor_viewport_2d()
			if viewport_2d != null:
				var t := viewport_2d.global_canvas_transform
				t.origin = viewport_2d.size * 0.5 - t.basis_xform(punto)
				viewport_2d.global_canvas_transform = t
			return


func _warp_seleccionado() -> Node:
	var raiz := EditorInterface.get_edited_scene_root()
	for nodo in EditorInterface.get_selection().get_selected_nodes():
		var warp := preload("res://addons/tilemap_inspector/menu_contextual_warp.gd")._warp_local(nodo, raiz)
		if warp != null:
			return warp
	return null

## Abre (o trae al frente) el editor de entrenadores con `entrenador_id` seleccionado.
## Lo pide el botón del inspector de los NPC entrenador.
func _abrir_entrenador_en_editor(entrenador_id: int) -> void:
	_abrir_editor_entrenadores_ventana()
	if not is_instance_valid(ventana_editor_entrenadores):
		return
	for hijo in ventana_editor_entrenadores.get_children():
		if hijo.has_method("seleccionar_entrenador_id"):
			hijo.seleccionar_entrenador_id(entrenador_id)
			return

func _abrir_editor_entrenadores_ventana():
	"""Abre el editor de entrenadores en una ventana independiente desde el menú"""
	_loggear("Abriendo editor de entrenadores en ventana independiente")

	# Si ya existe, traer al frente
	if is_instance_valid(ventana_editor_entrenadores):
		ventana_editor_entrenadores.popup()
		ventana_editor_entrenadores.grab_focus()
		return

	# Crear nueva ventana
	ventana_editor_entrenadores = Window.new()
	ventana_editor_entrenadores.title = "Editor de Entrenadores - PKRPG"
	ventana_editor_entrenadores.size = Vector2i(1500, 840)
	ventana_editor_entrenadores.min_size = Vector2i(800, 600)
	ventana_editor_entrenadores.position = Vector2i(100, 100)

	# Crear instancia del editor
	var editor_instance = editor_entrenadores_scene.instantiate()
	ventana_editor_entrenadores.add_child(editor_instance)
	editor_instance.solicitar_debug_batalla.connect(_on_solicitar_debug_batalla_desde_editor)

	# Título con " *" mientras haya cambios sin guardar.
	var ventana := ventana_editor_entrenadores
	var titulo_base := ventana.title
	editor_instance.titulo_cambiado.connect(func(hay_cambios: bool):
		ventana.title = titulo_base + (" *" if hay_cambios else "")
	)
	# Cerrar pide confirmación si hay cambios (Guardar / Descartar / Cancelar).
	ventana.close_requested.connect(editor_instance.solicitar_cierre)
	editor_instance.cierre_confirmado.connect(func():
		ventana.queue_free()
		if ventana_editor_entrenadores == ventana:
			ventana_editor_entrenadores = null
	)

	# Añadir al árbol y mostrar
	get_editor_interface().get_base_control().add_child(ventana_editor_entrenadores)
	ventana_editor_entrenadores.popup_centered()

	_loggear("Editor de entrenadores en ventana creado exitosamente")

func _abrir_editor_temas_musicales_ventana() -> void:
	"""Abre el editor de temas musicales en una ventana independiente desde el menú."""
	_loggear("Abriendo editor de temas musicales en ventana independiente")

	if not is_instance_valid(ventana_editor_temas_musicales):
		ventana_editor_temas_musicales = editor_temas_musicales_scene.instantiate()
		get_editor_interface().get_base_control().add_child(ventana_editor_temas_musicales)

	if ventana_editor_temas_musicales.has_method("abrir"):
		ventana_editor_temas_musicales.call("abrir", "")
	else:
		ventana_editor_temas_musicales.popup_centered()
		ventana_editor_temas_musicales.grab_focus()

	_loggear("Editor de temas musicales creado exitosamente")

func _abrir_editor_encuentros_ventana(mapa_id: String = "") -> void:
	_loggear("Abriendo editor de encuentros")
	if not is_instance_valid(ventana_editor_encuentros):
		ventana_editor_encuentros = editor_encuentros_scene.instantiate()
		get_editor_interface().get_base_control().add_child(ventana_editor_encuentros)
		ventana_editor_encuentros.close_requested.connect(func(): ventana_editor_encuentros.hide())
	ventana_editor_encuentros.call("abrir", mapa_id)


## La ventana gestiona su propio cierre (confirma si hay cambios sin guardar).
func _abrir_editor_encuentros_visual_ventana(mapa_id: String = "") -> void:
	_loggear("Abriendo editor visual de encuentros")
	if not is_instance_valid(ventana_editor_encuentros_visual):
		ventana_editor_encuentros_visual = editor_encuentros_visual_scene.instantiate()
		get_editor_interface().get_base_control().add_child(ventana_editor_encuentros_visual)
	ventana_editor_encuentros_visual.call("abrir", mapa_id)


func _abrir_visor_pokedex_ventana() -> void:
	_loggear("Abriendo visor de Pokédex y encuentros")
	if not is_instance_valid(ventana_visor_pokedex):
		ventana_visor_pokedex = visor_pokedex_scene.instantiate()
		get_editor_interface().get_base_control().add_child(ventana_visor_pokedex)
	ventana_visor_pokedex.call("abrir")


func _on_solicitar_editor_encuentros(mapa_id: String) -> void:
	_abrir_editor_encuentros_ventana(mapa_id)


func _abrir_editor_tabla_tipos_ventana() -> void:
	"""Abre el editor de la tabla de tipos (TiposEficacia) en una ventana."""
	_loggear("Abriendo editor de tabla de tipos")
	if not is_instance_valid(ventana_editor_tabla_tipos):
		ventana_editor_tabla_tipos = editor_tabla_tipos_scene.instantiate()
		get_editor_interface().get_base_control().add_child(ventana_editor_tabla_tipos)
	if ventana_editor_tabla_tipos.has_method("abrir"):
		ventana_editor_tabla_tipos.call("abrir")
	else:
		ventana_editor_tabla_tipos.popup_centered()
		ventana_editor_tabla_tipos.grab_focus()


func _abrir_editor_maquinas_ventana() -> void:
	"""Abre el editor de MT/MO (MaquinasMovimientos + Objetos.descripcion)."""
	_loggear("Abriendo editor de MT/MO")
	if not is_instance_valid(ventana_editor_maquinas):
		ventana_editor_maquinas = editor_maquinas_scene.instantiate()
		get_editor_interface().get_base_control().add_child(ventana_editor_maquinas)
	ventana_editor_maquinas.call("abrir")


func _abrir_editor_dialogos_ventana() -> void:
	"""Abre (o trae al frente) el Editor de Diálogos (BaseDatos/dialogos.csv)."""
	_loggear("Abriendo editor de diálogos")

	if not is_instance_valid(ventana_editor_dialogos):
		ventana_editor_dialogos = Window.new()
		ventana_editor_dialogos.title = "Editor de Diálogos"
		ventana_editor_dialogos.size = Vector2i(1000, 680)
		ventana_editor_dialogos.min_size = Vector2i(760, 480)

		editor_dialogos_ui = editor_dialogos_scene.instantiate()
		ventana_editor_dialogos.add_child(editor_dialogos_ui)

		ventana_editor_dialogos.close_requested.connect(func():
			ventana_editor_dialogos.queue_free()
			ventana_editor_dialogos = null
			editor_dialogos_ui = null
		)

		get_editor_interface().get_base_control().add_child(ventana_editor_dialogos)

	editor_dialogos_ui.call("abrir")
	ventana_editor_dialogos.popup_centered()
	ventana_editor_dialogos.grab_focus()
	_loggear("Editor de diálogos listo")


func _abrir_editor_posiciones_battlers_ventana() -> void:
	"""Abre (o trae al frente) el Editor de Posiciones de Battlers (battle_positions.json)."""
	_loggear("Abriendo editor de posiciones de battlers")

	if not is_instance_valid(ventana_editor_posiciones_battlers):
		ventana_editor_posiciones_battlers = Window.new()
		ventana_editor_posiciones_battlers.title = "Editor de Posiciones de Battlers"
		# Cabe el zoom x4 (lienzo 960x448) junto a la lista; el propio editor ajusta
		# min_size (y agranda la ventana si hace falta) al cambiar de zoom.
		ventana_editor_posiciones_battlers.size = Vector2i(1300, 780)
		ventana_editor_posiciones_battlers.min_size = Vector2i(1120, 600)

		editor_posiciones_battlers_ui = editor_posiciones_battlers_scene.instantiate()
		ventana_editor_posiciones_battlers.add_child(editor_posiciones_battlers_ui)

		# Con cambios sin guardar, la propia UI pide confirmación antes de cerrar.
		ventana_editor_posiciones_battlers.close_requested.connect(func():
			if is_instance_valid(editor_posiciones_battlers_ui):
				editor_posiciones_battlers_ui.call("solicitar_cierre", _cerrar_editor_posiciones_battlers)
			else:
				_cerrar_editor_posiciones_battlers()
		)

		get_editor_interface().get_base_control().add_child(ventana_editor_posiciones_battlers)

	editor_posiciones_battlers_ui.call("abrir")
	ventana_editor_posiciones_battlers.popup_centered()
	ventana_editor_posiciones_battlers.grab_focus()
	_loggear("Editor de posiciones de battlers listo")


func _cerrar_editor_posiciones_battlers() -> void:
	if is_instance_valid(ventana_editor_posiciones_battlers):
		ventana_editor_posiciones_battlers.queue_free()
	ventana_editor_posiciones_battlers = null
	editor_posiciones_battlers_ui = null


func _abrir_editor_poi_ventana() -> void:
	"""Abre el editor visual de POI de BaseDatos/region_map_metadata.json."""
	_loggear("Abriendo editor de POI del mapa regional")
	if not is_instance_valid(ventana_editor_poi):
		ventana_editor_poi = Window.new()
		ventana_editor_poi.title = "Editor de POI del Mapa Regional"
		ventana_editor_poi.size = Vector2i(1320, 800)
		ventana_editor_poi.min_size = Vector2i(980, 650)
		editor_poi_ui = editor_poi_scene.instantiate()
		ventana_editor_poi.add_child(editor_poi_ui)
		ventana_editor_poi.close_requested.connect(func():
			if is_instance_valid(editor_poi_ui):
				editor_poi_ui.call("solicitar_cierre", _cerrar_editor_poi)
			else:
				_cerrar_editor_poi()
		)
		get_editor_interface().get_base_control().add_child(ventana_editor_poi)
	editor_poi_ui.call("abrir")
	ventana_editor_poi.popup_centered()
	ventana_editor_poi.grab_focus()


func _cerrar_editor_poi() -> void:
	if is_instance_valid(ventana_editor_poi):
		ventana_editor_poi.queue_free()
	ventana_editor_poi = null
	editor_poi_ui = null


func _abrir_editor_instancia_pokemon_ventana(pokemon_id: int = -1, datos: Dictionary = {}, receptor: Object = null) -> void:
	"""Abre (o trae al frente) el Editor de Instancia de Pokémon.

	Si se pasa pokemon_id (> 0), precarga esa instancia de PokemonInstancias.
	Punto de enganche para otras herramientas: conectad su señal de "editar
	instancia" a este método, al estilo de solicitar_editor_encuentros.
	receptor: objeto con recibir_datos_pokemon(datos) que recibirá el botón
	"Seleccionar" del editor; null = Debug Batalla (comportamiento histórico).
	"""
	_loggear("Abriendo editor de instancia de Pokémon")

	if not is_instance_valid(ventana_editor_instancia):
		ventana_editor_instancia = Window.new()
		ventana_editor_instancia.title = "Editor de Instancia de Pokémon"
		ventana_editor_instancia.size = Vector2i(1320, 860)
		ventana_editor_instancia.min_size = Vector2i(1080, 720)
		ventana_editor_instancia.position = Vector2i(140, 140)

		editor_instancia_ui = editor_instancia_scene.instantiate()
		ventana_editor_instancia.add_child(editor_instancia_ui)
		# Router único: el botón "Seleccionar" entrega el snapshot del
		# formulario a la herramienta que abrió el editor por última vez.
		editor_instancia_ui.connect("datos_pokemon_solicitados", _on_editor_instancia_datos)

		ventana_editor_instancia.close_requested.connect(func():
			ventana_editor_instancia.queue_free()
			ventana_editor_instancia = null
			editor_instancia_ui = null
			_receptor_editor_instancia = null
		)

		get_editor_interface().get_base_control().add_child(ventana_editor_instancia)

	if is_instance_valid(receptor):
		_receptor_editor_instancia = receptor
	else:
		_receptor_editor_instancia = debug_batalla_ui if is_instance_valid(debug_batalla_ui) else null

	# Prioridad: los datos completos del slot mandan sobre la BBDD; el id es
	# solo informativo y deja esa fila preseleccionada en la lista (lo hace
	# cargar_datos_formulario internamente).
	if not datos.is_empty() and is_instance_valid(editor_instancia_ui) and editor_instancia_ui.has_method("cargar_datos_formulario"):
		editor_instancia_ui.call("cargar_datos_formulario", datos)
	elif pokemon_id > 0 and is_instance_valid(editor_instancia_ui) and editor_instancia_ui.has_method("cargar_instancia"):
		editor_instancia_ui.call("cargar_instancia", pokemon_id)

	ventana_editor_instancia.popup_centered()
	ventana_editor_instancia.grab_focus()
	_loggear("Editor de instancia de Pokémon listo")


## Puente del botón "Seleccionar" del Editor de Instancia: entrega el snapshot
## completo del formulario (guardado o no en la BBDD) al receptor actual
## (Debug Batalla lo coloca en un slot; Debug Partida en el equipo o una caja).
func _on_editor_instancia_datos(datos: Dictionary) -> void:
	if not is_instance_valid(_receptor_editor_instancia):
		_receptor_editor_instancia = debug_batalla_ui if is_instance_valid(debug_batalla_ui) else null
	if is_instance_valid(_receptor_editor_instancia) and _receptor_editor_instancia.has_method("recibir_datos_pokemon"):
		_receptor_editor_instancia.call("recibir_datos_pokemon", datos)


func _abrir_prueba_batalla_ventana() -> void:
	_loggear("Abriendo Debug Batalla (Control dentro de Window nativa, patron editor de instancias)")
	if not is_instance_valid(ventana_debug_batalla):
		ventana_debug_batalla = Window.new()
		ventana_debug_batalla.title = "Debug Batalla"
		ventana_debug_batalla.size = Vector2i(1400, 840)
		ventana_debug_batalla.min_size = Vector2i(1100, 700)
		# Se conecta ANTES de montar la UI para enlazar sus senales al montarse.
		ventana_debug_batalla.child_entered_tree.connect(_al_montar_ui_debug_batalla)
		ventana_debug_batalla.add_child(ventana_debug_batalla_scene.instantiate())
		ventana_debug_batalla.close_requested.connect(func(): ventana_debug_batalla.hide())
		get_editor_interface().get_base_control().add_child(ventana_debug_batalla)
	ventana_debug_batalla.popup_centered()
	ventana_debug_batalla.grab_focus()


func _al_montar_ui_debug_batalla(nodo: Node) -> void:
	if not nodo.has_signal("solicitar_editor_instancia"):
		return
	debug_batalla_ui = nodo
	nodo.connect("solicitar_editor_instancia", _abrir_editor_instancia_pokemon_ventana)
	if nodo.has_signal("solicitar_editor_entrenadores"):
		nodo.connect("solicitar_editor_entrenadores", _abrir_editor_entrenadores_ventana)


## Recibe la peticion del Editor de Entrenadores: abre (o trae al frente) el
## probador de batallas y precarga el registro del entrenador seleccionado.
func _on_solicitar_debug_batalla_desde_editor(registro: Dictionary) -> void:
	_abrir_prueba_batalla_ventana()
	if is_instance_valid(debug_batalla_ui) and debug_batalla_ui.has_method("cargar_entrenador_para_prueba"):
		debug_batalla_ui.call("cargar_entrenador_para_prueba", registro)


func _handles(object: Object) -> bool:
	return is_instance_valid(lapiz_mapa) and lapiz_mapa.maneja(object) \
		and _tiene_script_mapa_config(EditorInterface.get_edited_scene_root())


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if is_instance_valid(menu_spawn_debug) and event is InputEventMouseButton:
		var raton := event as InputEventMouseButton
		if raton.pressed and raton.button_index == MOUSE_BUTTON_RIGHT:
			menu_spawn_debug.registrar_clic(raton.position)
	if event is InputEventMouseMotion:
		update_overlays()  # Refresca la coordenada bajo el cursor.
	return is_instance_valid(lapiz_mapa) and lapiz_mapa.entrada_lienzo(event)


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	_dibujar_coordenada_cursor(overlay)
	if is_instance_valid(menu_spawn_debug):
		menu_spawn_debug.establecer_lienzo(overlay)
	if is_instance_valid(lapiz_mapa):
		lapiz_mapa.dibujar_lienzo(overlay)


## Coordenada de tile bajo el cursor, siempre visible con un mapa abierto
## (esquina inferior izquierda, con fondo). La descripción del pincel del
## TileDataMap se apila justo encima (ver TPTileDataMapPlugin).
func _dibujar_coordenada_cursor(overlay: Control) -> void:
	var raiz := EditorInterface.get_edited_scene_root() as Node2D
	if raiz == null or not _tiene_script_mapa_config(raiz):
		return
	var raton := overlay.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, overlay.size).has_point(raton):
		return
	var xf: Transform2D = raiz.get_viewport().global_canvas_transform * raiz.get_global_transform_with_canvas()
	var celda := Vector2i(((xf.affine_inverse() * raton) / 16.0).floor())
	var fuente: Font = EditorInterface.get_base_control().get_theme_font("font", "Label")
	if fuente == null:
		return
	var texto := "(%d, %d)" % [celda.x, celda.y]
	var medida := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var caja := Rect2(Vector2(12, overlay.size.y - 8 - 24), Vector2(medida.x + 12, 24))
	overlay.draw_rect(caja, Color(0, 0, 0, 0.7))
	overlay.draw_string(fuente, caja.position + Vector2(6, 4 + fuente.get_ascent(14)), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _exit_tree():
	if menu_spawn_debug != null:
		remove_context_menu_plugin(menu_spawn_debug)
		menu_spawn_debug = null
	if menu_warp_lienzo != null:
		remove_context_menu_plugin(menu_warp_lienzo)
		menu_warp_lienzo = null
	if is_instance_valid(ventana_conexiones_warp):
		ventana_conexiones_warp.queue_free()
		ventana_conexiones_warp = null
	if is_instance_valid(ventana_editar_warp):
		ventana_editar_warp.queue_free()
		ventana_editar_warp = null
	if is_instance_valid(boton_pkrpg):
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, boton_pkrpg)
		boton_pkrpg.queue_free()

	if is_instance_valid(lapiz_mapa):
		lapiz_mapa.soltar()
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, lapiz_mapa)
		lapiz_mapa.queue_free()
	lapiz_mapa = null

	# Remover submenu
	remove_tool_menu_item("RPG Tools")

	# Cerrar ventana del editor si está abierta
	if is_instance_valid(ventana_editor_entrenadores):
		ventana_editor_entrenadores.queue_free()
		ventana_editor_entrenadores = null

	if is_instance_valid(ventana_editor_temas_musicales):
		ventana_editor_temas_musicales.queue_free()
		ventana_editor_temas_musicales = null

	if is_instance_valid(ventana_editor_encuentros):
		ventana_editor_encuentros.queue_free()
		ventana_editor_encuentros = null

	if is_instance_valid(ventana_editor_tabla_tipos):
		ventana_editor_tabla_tipos.queue_free()
		ventana_editor_tabla_tipos = null

	if is_instance_valid(ventana_editor_maquinas):
		ventana_editor_maquinas.queue_free()
		ventana_editor_maquinas = null

	if is_instance_valid(ventana_editor_dialogos):
		ventana_editor_dialogos.queue_free()
		ventana_editor_dialogos = null
		editor_dialogos_ui = null

	if is_instance_valid(ventana_editor_posiciones_battlers):
		ventana_editor_posiciones_battlers.queue_free()
		ventana_editor_posiciones_battlers = null
		editor_posiciones_battlers_ui = null

	if is_instance_valid(ventana_editor_poi):
		ventana_editor_poi.queue_free()
		ventana_editor_poi = null
		editor_poi_ui = null

	if is_instance_valid(ventana_editor_encuentros_visual):
		ventana_editor_encuentros_visual.queue_free()
		ventana_editor_encuentros_visual = null

	if is_instance_valid(ventana_visor_pokedex):
		ventana_visor_pokedex.queue_free()
		ventana_visor_pokedex = null

	if is_instance_valid(ventana_editor_instancia):
		ventana_editor_instancia.queue_free()
		ventana_editor_instancia = null
		editor_instancia_ui = null

	if is_instance_valid(ventana_debug_batalla):
		ventana_debug_batalla.queue_free()
		ventana_debug_batalla = null
		debug_batalla_ui = null

	if is_instance_valid(ventana_debug_partida):
		ventana_debug_partida.queue_free()
		ventana_debug_partida = null
		debug_partida_ui = null
	_receptor_editor_instancia = null

	# Quitar el dock Config. Mapa si estaba en el panel
	if config_mapa_dock_en_panel and is_instance_valid(config_mapa_dock):
		remove_control_from_bottom_panel(config_mapa_dock)
		config_mapa_dock_en_panel = false
	if is_instance_valid(config_mapa_dock):
		config_mapa_dock.queue_free()
		config_mapa_dock = null

	# Limpiar timer si existe
	for child in get_children():
		if child is Timer:
			child.queue_free()

	if is_instance_valid(boton_personalizado):
		boton_personalizado.queue_free()

	# Galería de avatares de NPC (instancia única abierta desde el inspector)
	preload("res://addons/tilemap_inspector/ventana_galeria_avatares.gd").liberar()
	# Galería de bayas (baya_inicial del árbol de bayas)
	preload("res://addons/tilemap_inspector/ventana_galeria_bayas.gd").liberar()

	# Desregistrar el EditorInspectorPlugin
	if inspector_plugin:
		remove_inspector_plugin(inspector_plugin)
		inspector_plugin = null
		print("[📦 PKRPG] Inspector plugin desregistrado correctamente")

func _check_scene_change():
	if inspector_plugin != null and inspector_plugin.has_method("actualizar_validaciones"):
		inspector_plugin.call("actualizar_validaciones")

	var current_edited_scene = EditorInterface.get_edited_scene_root()
	var es_mapa: bool = false
	if current_edited_scene:
		es_mapa = _tiene_script_mapa_config(current_edited_scene)

	# Actualizar visibilidad del botón PKRPG según el tipo de escena
	if is_instance_valid(boton_pkrpg):
		boton_pkrpg.visible = es_mapa
		if not es_mapa and ventana_posicion and ventana_posicion.visible:
			ventana_posicion.hide()
	if is_instance_valid(lapiz_mapa):
		lapiz_mapa.set_en_mapa(es_mapa)

	# Gestionar el dock Config. Mapa
	if is_instance_valid(config_mapa_dock):
		if es_mapa:
			if not config_mapa_dock_en_panel:
				add_control_to_bottom_panel(config_mapa_dock, "Config. Mapa")
				config_mapa_dock_en_panel = true
				print("[PKRPG] Dock Config. Mapa añadido al panel inferior")
			# Recargar datos si cambió la escena
			var new_path: String = current_edited_scene.scene_file_path
			if new_path != current_scene_path:
				config_mapa_dock.cargar_mapa(current_edited_scene)
		else:
			if config_mapa_dock_en_panel:
				remove_control_from_bottom_panel(config_mapa_dock)
				config_mapa_dock_en_panel = false
				print("[PKRPG] Dock Config. Mapa removido del panel inferior")

	if current_edited_scene:
		var new_scene_path = current_edited_scene.scene_file_path
		if new_scene_path != current_scene_path:
			current_scene_path = new_scene_path
			if is_instance_valid(lapiz_mapa):
				lapiz_mapa.soltar()  # Al cambiar de mapa el lápiz no sigue activo.
			_scan_for_tilemaps(current_edited_scene)
			print("Escena cargada: ", current_scene_path)
			print("TileMapLayers encontrados: ", tilemap_nodes.size())

			# Si la ventana está abierta, actualizar el segundo viewport
			if ventana_posicion and ventana_posicion.visible:
				print("[PKRPG] Actualizando ventana por cambio de escena")
				_actualizar_escena_editor_en_ventana()
	else:
		if current_scene_path != "":
			current_scene_path = ""
			tilemap_nodes.clear()

			# Si la ventana está abierta, limpiar el segundo viewport
			if ventana_posicion and ventana_posicion.visible:
				print("[PKRPG] Limpiando ventana por cierre de escena")
				_limpiar_escena_editor_en_ventana()

func _tiene_script_mapa_config(node: Node) -> bool:
	if not node: return false
	var script = node.get_script()
	if not script: return false

	# Verificar por class_name o por ruta del archivo
	var code = script.get_source_code()
	if "class_name MapaConfiguracion" in code or "MapaConfiguracion.gd" in script.resource_path:
		# print("[PKRPG] Detectado script de MapaConfiguracion en: ", node.name)
		return true

	# Verificar si hereda de MapaConfiguracion (si el script tiene una clase base)
	var base_script = script.get_base_script()
	while base_script:
		if "MapaConfiguracion.gd" in base_script.resource_path:
			return true
		base_script = base_script.get_base_script()

	return false

func _on_scene_changed(scene_root):
	# Método legacy - ahora usamos _check_scene_change()
	pass

func _scan_for_tilemaps(node: Node):
	tilemap_nodes.clear()
	_recursive_tilemap_scan(node)

func _recursive_tilemap_scan(node: Node):
	if node is TileMapLayer:
		tilemap_nodes.append(node)

	for child in node.get_children():
		_recursive_tilemap_scan(child)

func _on_selection_changed():
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()

	if selected_nodes.is_empty():
		return

	var selected_node = selected_nodes[0]

	if selected_node is TileMapLayer:
		print("TileMapLayer seleccionado: ", selected_node.name)

func get_tile_at_position(tilemap: TileMapLayer, global_pos: Vector2) -> Vector2i:
	var local_pos = tilemap.to_local(global_pos)
	return tilemap.local_to_map(local_pos)

func get_tile_info_at_coords(tilemap: TileMapLayer, coords: Vector2i) -> Dictionary:
	var tile_data = {}

	# Obtener información del tile
	var source_id = tilemap.get_cell_source_id(coords)
	var atlas_coords = tilemap.get_cell_atlas_coords(coords)
	var alternative = tilemap.get_cell_alternative_tile(coords)

	tile_data["source_id"] = source_id
	tile_data["atlas_coords"] = atlas_coords
	tile_data["alternative"] = alternative
	tile_data["coords"] = coords
	tile_data["is_empty"] = (source_id == -1)

	return tile_data

func _cargar_mapa_guardado(mapa_nombre: String, cx: int, cy: int):
	print("[PKRPG] Intentando cargar mapa guardado: ", mapa_nombre)

	var viewport_guardado = ventana_posicion.find_child("MapaGuardadoViewport", true, false)
	if not viewport_guardado:
		print("[PKRPG] ERROR: No se encontró MapaGuardadoViewport")
		return

	var subviewport_guardado = viewport_guardado.get_child(0) as SubViewport
	if not subviewport_guardado:
		print("[PKRPG] ERROR: No se encontró SubViewport en MapaGuardadoViewport")
		return

	# Limpiar viewport anterior
	for child in subviewport_guardado.get_children():
		child.queue_free()

	# Mapear nombre del mapa a archivo de escena
	var escena_path = _buscar_escena_por_nombre_recursivo("res://escenas/mapas/", mapa_nombre)
	print("[PKRPG] Ruta de escena mapeada: ", escena_path)

	if escena_path != "" and FileAccess.file_exists(escena_path):
		var escena_resource = load(escena_path)
		if escena_resource:
			var instancia_mapa = escena_resource.instantiate()
			subviewport_guardado.add_child(instancia_mapa)
			print("[PKRPG] Mapa guardado cargado exitosamente")

			# Centrar la vista en las coordenadas cx, cy
			_centrar_vista_en_coordenadas(subviewport_guardado, cx, cy)

			# Instanciar el personaje en la posición guardada
			_instanciar_personaje_en_mapa(subviewport_guardado, cx, cy)
		else:
			print("[PKRPG] ERROR: No se pudo cargar la escena: ", escena_path)
	else:
		print("[PKRPG] ERROR: Archivo de escena no encontrado: ", escena_path)

func _cargar_escena_editor(mapa_fallback: String):
	print("[PKRPG] Cargando escena del editor")

	var viewport_editor = ventana_posicion.find_child("EscenaEditorViewport", true, false)
	if not viewport_editor:
		print("[PKRPG] ERROR: No se encontró EscenaEditorViewport")
		return

	var subviewport_editor = viewport_editor.get_child(0) as SubViewport
	if not subviewport_editor:
		print("[PKRPG] ERROR: No se encontró SubViewport en EscenaEditorViewport")
		return

	# Limpiar viewport anterior
	for child in subviewport_editor.get_children():
		child.queue_free()

	var current_edited_scene = EditorInterface.get_edited_scene_root()
	var escena_a_cargar = ""

	if current_edited_scene and current_edited_scene.scene_file_path != "":
		escena_a_cargar = current_edited_scene.scene_file_path
		print("[PKRPG] Usando escena actual del editor: ", escena_a_cargar)
	else:
		# No hay escena en el editor, usar la misma del mapa guardado
		escena_a_cargar = _buscar_escena_por_nombre_recursivo("res://escenas/mapas/", mapa_fallback)
		print("[PKRPG] No hay escena en editor, usando mapa guardado: ", escena_a_cargar)

	if escena_a_cargar != "" and FileAccess.file_exists(escena_a_cargar):
		var escena_resource = load(escena_a_cargar)
		if escena_resource:
			var instancia_escena = escena_resource.instantiate()
			subviewport_editor.add_child(instancia_escena)
			print("[PKRPG] Escena del editor cargada exitosamente")

			# Configurar interacción para seleccionar tiles
			_configurar_interaccion_tiles(subviewport_editor)
		else:
			print("[PKRPG] ERROR: No se pudo cargar la escena del editor: ", escena_a_cargar)
	else:
		print("[PKRPG] Usando viewport vacío - no hay escena válida para cargar")
		# No configurar interacción si no hay escena válida

## Buscar escena por nombre recursivo
func _buscar_escena_por_nombre_recursivo(base_path: String, mapa_nombre: String) -> String:
	var dir = DirAccess.open(base_path)
	if not dir:
		return ""
	dir.list_dir_begin()
	var file_name = ""
	while true:
		file_name = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				var found = _buscar_escena_por_nombre_recursivo(base_path + file_name + "/", mapa_nombre)
				if found != "":
					dir.list_dir_end()
					return found
		else:
			if file_name.ends_with(".tscn") and file_name.get_basename().to_lower() == mapa_nombre.to_lower():
				var found_path = base_path + file_name
				dir.list_dir_end()
				return found_path
	dir.list_dir_end()
	return ""

func _centrar_vista_en_coordenadas(viewport: SubViewport, cx: int, cy: int):
	print("[PKRPG] Centrando vista en coordenadas: (", cx, ", ", cy, ")")

	# Buscar el TileMapLayer en la escena cargada
	var tilemap = _buscar_tilemap_en_viewport(viewport)
	if not tilemap:
		print("[PKRPG] No se encontró TileMapLayer para centrar")
		return

	# Calcular la posición en píxeles de las coordenadas del tile
	var tile_position = tilemap.map_to_local(Vector2i(cx, cy))
	print("[PKRPG] Posición del tile en píxeles: ", tile_position)

	# Obtener el tamaño del viewport
	var viewport_size: Vector2 = Vector2(viewport.size)
	var center_offset = viewport_size / 2

	# Calcular la posición de la cámara para centrar el tile
	var camera_position = tile_position - center_offset

	# Aplicar el offset a la escena completa
	var scene_root = viewport.get_child(0)
	if scene_root:
		scene_root.position = -camera_position
		print("[PKRPG] Vista centrada en coordenadas (", cx, ", ", cy, ")")

func _configurar_interaccion_tiles(viewport: SubViewport):
	print("[PKRPG] Configurando interacción con tiles")

	# Aplicar escala x2 y centrar el mapa
	var scene_root = viewport.get_child(0)
	var escala = 2.0
	if scene_root and scene_root.has_method("set_scale"):
		scene_root.scale = Vector2(escala, escala)
		print("[PKRPG] Escala x2 aplicada al mapa del editor")
	else:
		print("[PKRPG] No se pudo aplicar la escala al mapa del editor")
		escala = 1.0

	# Centrar la escena en el viewport
	var viewport_size = viewport.size
	var center_offset = viewport_size / escala
	scene_root.position = center_offset
	print("[PKRPG] Escena centrada en el viewport")

	# Crear un Control que capture eventos de input ARRIBA del SubViewportContainer
	var viewport_container = viewport.get_parent() as SubViewportContainer
	if not viewport_container:
		print("[PKRPG] ERROR: No se encontró SubViewportContainer")
		return

	# Buscar si ya existe un handler
	var existing_handler = null
	for child in viewport_container.get_children():
		if child.has_meta("input_handler"):
			existing_handler = child
			break

	var input_handler = existing_handler
	if not input_handler:
		input_handler = Control.new()
		input_handler.set_meta("input_handler", true)
		input_handler.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		input_handler.mouse_filter = Control.MOUSE_FILTER_PASS
		viewport_container.add_child(input_handler)
		print("[PKRPG] Nuevo handler de input creado")

	# Variables para el arrastre
	var is_dragging = false
	var drag_start_position = Vector2()
	var initial_scene_position = Vector2()

	# Limpiar conexiones anteriores si existen
	if input_handler.gui_input.is_connected(_handle_editor_input):
		input_handler.gui_input.disconnect(_handle_editor_input)

	# Crear función de manejo de input específica para este viewport
	var input_callback = func(event: InputEvent):
		_handle_editor_input(event, viewport, input_handler)

	# Conectar eventos de input
	input_handler.gui_input.connect(input_callback)
	print("[PKRPG] Handler de interacción configurado correctamente")

func _handle_editor_input(event: InputEvent, viewport: SubViewport, input_handler: Control):
	var scene_root = viewport.get_child(0)
	if not scene_root:
		return

	# Actualizar label de coordenadas del cursor en cualquier movimiento del mouse
	if event is InputEventMouseMotion:
		_actualizar_coords_cursor(viewport, event.position)

	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Iniciar arrastre
				input_handler.set_meta("is_dragging", true)
				input_handler.set_meta("drag_start", mouse_event.position)
				input_handler.set_meta("initial_pos", scene_root.position)
				print("[PKRPG] Iniciando arrastre en: ", mouse_event.position)
			else:
				# Terminar arrastre y detectar click en tile
				var was_dragging = input_handler.get_meta("is_dragging", false)
				if was_dragging:
					input_handler.set_meta("is_dragging", false)
					var drag_start = input_handler.get_meta("drag_start", Vector2())
					var drag_distance = (mouse_event.position - drag_start).length()
					if drag_distance < 5.0:  # Si no se arrastró mucho, es un click
						_detectar_click_en_tile(viewport, mouse_event.position)
					print("[PKRPG] Arrastre terminado")

	elif event is InputEventMouseMotion:
		var was_dragging = input_handler.get_meta("is_dragging", false)
		if was_dragging:
			var motion_event = event as InputEventMouseMotion
			var drag_start = input_handler.get_meta("drag_start", Vector2())
			var initial_pos = input_handler.get_meta("initial_pos", Vector2())
			var drag_offset = motion_event.position - drag_start
			scene_root.position = initial_pos + drag_offset

func _buscar_tilemap_en_viewport(viewport: SubViewport) -> TileMapLayer:
	# Buscar recursivamente un TileMapLayer en el viewport
	if viewport.get_child_count() == 0:
		return null

	var root_node = viewport.get_child(0)
	return _buscar_tilemap_recursivo(root_node)

func _buscar_tilemap_recursivo(node: Node) -> TileMapLayer:
	if node is TileMapLayer:
		return node

	for child in node.get_children():
		var result = _buscar_tilemap_recursivo(child)
		if result:
			return result

	return null

func _detectar_click_en_tile(viewport: SubViewport, mouse_pos: Vector2):
	print("[PKRPG] Detectando click en tile en posición: ", mouse_pos)

	var tilemap = _buscar_tilemap_en_viewport(viewport)
	if not tilemap:
		print("[PKRPG] No se encontró tilemap para detectar click")
		return

	var scene_root = viewport.get_child(0)
	if not scene_root:
		return

	# Convertir posición del mouse a coordenadas del mundo, considerando escala y posición
	var world_pos = (mouse_pos + scene_root.position) / scene_root.scale

	# Convertir a coordenadas locales del tilemap
	var local_pos = tilemap.to_local(world_pos)
	var tile_coords = tilemap.local_to_map(local_pos)

	print("[PKRPG] Tile clickeado en coordenadas: ", tile_coords)

	# Actualizar coordenadas seleccionadas
	selected_cx = tile_coords.x
	selected_cy = tile_coords.y

	# Actualizar el segundo label
	_actualizar_label_seleccion()

func _actualizar_label_seleccion():
	if not ventana_posicion:
		print("[PKRPG][LabelSeleccion] ventana_posicion no existe")
		return

	var label_pos_seleccionada = ventana_posicion.find_child("LabelPosicion", true, false)
	if label_pos_seleccionada and label_pos_seleccionada is Label:
		# Obtener el nombre del mapa actual (puede ser diferente al guardado si se cambió de escena)
		mapa_edicion = "mapa_editor"  # Por defecto

		# Intentar obtener el nombre de la escena actual
		var current_edited_scene = EditorInterface.get_edited_scene_root()
		print("[PKRPG][LabelSeleccion] current_edited_scene: ", current_edited_scene)
		if current_edited_scene:
			print("[PKRPG][LabelSeleccion] scene_file_path: ", current_edited_scene.scene_file_path)
			if current_edited_scene.scene_file_path != "":
				var scene_path = current_edited_scene.scene_file_path
				print("[PKRPG][LabelSeleccion] scene_path: ", scene_path)
				var file_name = scene_path.get_file()
				print("[PKRPG][LabelSeleccion] file_name: ", file_name)
				mapa_edicion = file_name.get_basename()

		label_pos_seleccionada.text = "%s: (%s, %s)" % [mapa_edicion, selected_cx, selected_cy]
		print("[PKRPG] Label selección actualizado: ", label_pos_seleccionada.text)

func _instanciar_personaje_en_mapa(viewport: SubViewport, cx: int, cy: int):
	print("[PKRPG] Instanciando personaje en coordenadas: (", cx, ", ", cy, ")")

	# Limpiar instancia anterior del personaje
	if character_instance and is_instance_valid(character_instance):
		character_instance.queue_free()
		character_instance = null

	# Buscar el TileMapLayer para obtener la posición en píxeles
	var tilemap = _buscar_tilemap_en_viewport(viewport)
	if not tilemap:
		print("[PKRPG] No se encontró TileMapLayer para instanciar personaje")
		return

	# Instanciar el personaje
	character_instance = character_scene.instantiate()

	# Calcular la posición en píxeles
	var tile_position = tilemap.map_to_local(Vector2i(cx, cy)) - Vector2(8, 8)
	character_instance.position = tile_position

	# Agregar el personaje a la escena
	var scene_root = viewport.get_child(0)
	if scene_root:
		scene_root.add_child(character_instance)
		print("[PKRPG] Personaje instanciado en posición: ", tile_position)
	else:
		print("[PKRPG] ERROR: No se encontró raíz de escena para agregar personaje")

func _on_pin_pressed():
	print("[PKRPG] Toggle pin pressed")
	if ventana_posicion:
		var pin_button = ventana_posicion.find_child("PinButton", true, false)
		if ventana_posicion.always_on_top:
			ventana_posicion.always_on_top = false
			if pin_button:
				pin_button.text = "📌"
				pin_button.tooltip_text = "Mantener siempre encima"
			print("[PKRPG] Ventana ya no está siempre encima")
		else:
			ventana_posicion.always_on_top = true
			if pin_button:
				pin_button.text = "📍"
				pin_button.tooltip_text = "Quitar de siempre encima"
			print("[PKRPG] Ventana ahora está siempre encima")

func _on_aceptar_pressed():
	print("[PKRPG] Aceptar pressed - Guardando datos de posición...")

	# Actualizar archivo de guardado con las nuevas coordenadas
	var file_path = "res://partida/partida_guardada.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var data = JSON.parse_string(content)
			file.close()

			if typeof(data) == TYPE_DICTIONARY and data.has("posicion"):
				# Actualizar las coordenadas
				data["posicion"]["mapa_actual"] = mapa_edicion
				data["posicion"]["cx"] = selected_cx
				data["posicion"]["cy"] = selected_cy
				print("[PKRPG] Nuevas coordenadas: cx=", selected_cx, ", cy=", selected_cy)

				# Guardar el archivo actualizado
				var save_file = FileAccess.open(file_path, FileAccess.WRITE)
				if save_file:
					save_file.store_string(JSON.stringify(data, "\t"))
					save_file.close()
					print("[PKRPG] Archivo guardado exitosamente")
				else:
					print("[PKRPG] ERROR: No se pudo abrir el archivo para escritura")
			else:
				print("[PKRPG] ERROR: Estructura de datos inválida")
		else:
			print("[PKRPG] ERROR: No se pudo leer el archivo")
	else:
		print("[PKRPG] ERROR: Archivo de guardado no encontrado")

	# Cerrar la ventana
	_cerrar_ventana()

func _on_cancelar_pressed():
	print("[PKRPG] Cancelar pressed - Cerrando sin guardar")
	if ventana_posicion and is_instance_valid(ventana_posicion):
		ventana_posicion.hide()
	opened_via_plugin = false
	# Restaurar coordenadas originales
	selected_cx = original_cx
	selected_cy = original_cy
	_cerrar_ventana()

func _cerrar_ventana():
	print("[PKRPG] Cerrando ventana de posición")
	if ventana_posicion and is_instance_valid(ventana_posicion):
		ventana_posicion.hide()

	# Limpiar instancia del personaje
	if character_instance and is_instance_valid(character_instance):
		character_instance.queue_free()
		character_instance = null

func _actualizar_escena_editor_en_ventana():
	print("[PKRPG] Actualizando escena del editor en ventana")
	if not ventana_posicion:
		return

	# Obtener el mapa actual como fallback
	var file_path = "res://partida/partida_guardada.json"
	var mapa_fallback = ""
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var data = JSON.parse_string(content)
			if typeof(data) == TYPE_DICTIONARY and data.has("posicion"):
				mapa_fallback = str(data["posicion"].get("mapa_actual", ""))
			file.close()

	# Recargar la escena del editor
	_cargar_escena_editor(mapa_fallback)

	# Actualizar el segundo label
	_actualizar_label_seleccion()

func _limpiar_escena_editor_en_ventana():
	print("[PKRPG] Limpiando escena del editor en ventana")
	if not ventana_posicion:
		return

	var viewport_editor = ventana_posicion.find_child("EscenaEditorViewport", true, false)
	if not viewport_editor:
		return

	var subviewport_editor = viewport_editor.get_child(0) as SubViewport
	if not subviewport_editor:
		return

	# Limpiar viewport
	for child in subviewport_editor.get_children():
		child.queue_free()

	# Limpiar label de coordenadas
	var coords_label = ventana_posicion.find_child("CoordsLabel", true, false)
	if coords_label and coords_label is Label:
		coords_label.text = "Tile: (-, -)"

func _actualizar_coords_cursor(viewport: SubViewport, mouse_pos: Vector2):
	if not ventana_posicion:
		return

	var coords_label = ventana_posicion.find_child("CoordsLabel", true, false)
	if not coords_label or not coords_label is Label:
		return

	var tilemap = _buscar_tilemap_en_viewport(viewport)
	if not tilemap:
		coords_label.text = "Tile: (-, -)"
		return

	var scene_root = viewport.get_child(0)
	if not scene_root:
		coords_label.text = "Tile: (-, -)"
		return

	# Convertir posición del mouse a coordenadas del mundo, considerando escala y posición
	# La posición del mouse en el viewport se debe transformar respecto a la escena
	var world_pos = (mouse_pos + scene_root.position) / scene_root.scale

	# Convertir a coordenadas locales del tilemap
	var local_pos = tilemap.to_local(world_pos)
	var tile_coords = tilemap.local_to_map(local_pos)

	# Actualizar el label
	coords_label.text = "Tile: (%d, %d)" % [tile_coords.x, tile_coords.y]

# ═══════════════════════════════════════════════════════════════
# DEBUG DE MAPAS
#
# El tile de arranque directo (F6) se marca con un nodo `SpawnDebug`
# (escenas/mapas/marcador_spawn_debug.gd) añadido al mapa: se arrastra por el
# lienzo y se engancha solo a la rejilla. Solo existe en el editor.
# Icono: res://graficos/editor/editor_tile_spawn.png
# ═══════════════════════════════════════════════════════════════

func _loggear(tag: String):
	print("[📦 PKRPG] %s" % [tag])
