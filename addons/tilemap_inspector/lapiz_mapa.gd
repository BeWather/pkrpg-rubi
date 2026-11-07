@tool
extends HBoxContainer
## Lápiz de mapa: coloca un NPC, Warp, Cartel, árbol de bayas, roca de Fuerza, roca rompible, árbol cortable u objeto (visible u oculto) en el tile donde se hace clic.
##
## Vive en la barra del lienzo 2D, junto al botón PKRPG, y solo se muestra con un
## mapa (MapaConfiguracion) abierto. El botón principal activa el lápiz del tipo
## elegido; la flecha abre el menú de tipos y el acceso a su plantilla.
##
## Cada tipo se pega desde su plantilla (plantillas_lapiz/*.tscn): el nodo nuevo
## recibe las propiedades que fija la raíz de la plantilla, igual que si se
## hubiera creado a mano. Para cambiar los valores por defecto basta con editarla.
##
## Clic izq.: colocar (si la celda ya está ocupada, selecciona lo que hay).
## Clic der. o Esc: soltar el lápiz. Cada nodo colocado es un Ctrl+Z.
##
## plugin.gd delega aquí _handles, _forward_canvas_gui_input y
## _forward_canvas_draw_over_viewport.

const TAM_TILE: int = 16
const RUTA_PLANTILLAS: String = "res://addons/tilemap_inspector/plantillas_lapiz/"
const AYUDA: String = "
Clic izq.: colocar (en celda ocupada, selecciona el nodo)
Clic der. o Esc: soltar el lápiz"
const ID_EDITAR_PLANTILLA: int = 100
const COLOR_OCUPADO: Color = Color(1.0, 0.3, 0.3)

## Tipos del lápiz. Para añadir uno: una entrada más y su plantilla .tscn.
## - escena_base: el nodo es una instancia de esta escena (NPC → npc_base.tscn) y
##   la plantilla es una escena heredada de ella. Vacío = nodo plano con el script
##   de la plantilla (convención de Warp y Cartel en los mapas).
## - script: script (o base) que identifica a los nodos de este tipo ya colocados.
## - contenedor: hijo del mapa donde se crea el nodo ("" = raíz del mapa); si falta
##   se crea con las propiedades de contenedor_props.
## - offset: píxeles dentro del tile en que el script engancha el nodo a la rejilla.
## - prop_coord: propiedad exportada con la coordenada en tiles ("" si no tiene).
## - prop_id (opcional): propiedad que se rellena con un id libre del mapa al
##   colocar (ver _id_libre).
## - prefijo_id (opcional, con prop_id): palabra inicial del id ("roca" da
##   "roca_r116_1", "arbol" da "arbol_r116_1"); por defecto "parcela" (bayas:
##   "parcela_r104_3").
const TIPOS: Array = [
	{
		"nombre": "NPC",
		"plantilla": RUTA_PLANTILLAS + "npc.tscn",
		"escena_base": "res://escenas/avatares/npc_base.tscn",
		"script": "res://scripts/npc/npc_base.gd",
		"contenedor": "NPCs",
		"contenedor_props": {"z_index": 1, "y_sort_enabled": true},
		"offset": Vector2(8, 14),
		"prop_coord": "coord",
		"icono": "res://graficos/editor/editor_tile_npc.png",
		"color": Color(0.4, 0.8, 1.0),
	},
	{
		"nombre": "Warp",
		"plantilla": RUTA_PLANTILLAS + "warp.tscn",
		"escena_base": "",
		"script": "res://scripts/warp.gd",
		"contenedor": "",
		"contenedor_props": {},
		"offset": Vector2(8, 6),
		"prop_coord": "",
		"icono": "res://graficos/editor/editor_tile_warp.png",
		"color": Color(0.7, 0.5, 1.0),
	},
	{
		"nombre": "Cartel",
		"plantilla": RUTA_PLANTILLAS + "cartel.tscn",
		"escena_base": "",
		"script": "res://escenas/mapas/signpost.gd",
		"contenedor": "Carteles",
		"contenedor_props": {},
		"offset": Vector2(8, 8),
		"prop_coord": "coord_tile",
		"icono": "res://graficos/editor/editor_tile_cartel.png",
		"color": Color(1.0, 0.8, 0.3),
	},
	{
		"nombre": "Baya",
		"plantilla": RUTA_PLANTILLAS + "baya.tscn",
		"escena_base": "res://graficos/bayas/baya.tscn",
		"script": "res://graficos/bayas/controlador_baya.gd",
		"contenedor": "NPCs",
		"contenedor_props": {"z_index": 1, "y_sort_enabled": true},
		"offset": Vector2(8, 14),
		"prop_coord": "coord",
		"prop_id": "id_parcela",
		"icono": "res://graficos/editor/editor_tile_baya.png",
		"color": Color(0.35, 0.85, 0.45),
	},
	{
		"nombre": "Roca Fuerza",
		"plantilla": RUTA_PLANTILLAS + "roca_fuerza.tscn",
		"escena_base": "res://graficos/roca_fuerza/roca_fuerza.tscn",
		"script": "res://graficos/roca_fuerza/controlador_roca_fuerza.gd",
		"contenedor": "NPCs",
		"contenedor_props": {"z_index": 1, "y_sort_enabled": true},
		"offset": Vector2(8, 14),
		"prop_coord": "coord",
		# El propio sprite de la roca sirve de icono (16x16).
		"icono": "res://graficos/roca-fuerza.png",
		"color": Color(0.85, 0.6, 0.35),
	},
	{
		"nombre": "Roca Romper",
		"plantilla": RUTA_PLANTILLAS + "roca_romper.tscn",
		"escena_base": "res://graficos/roca_romper/roca_romper.tscn",
		"script": "res://graficos/roca_romper/controlador_roca_romper.gd",
		"contenedor": "NPCs",
		"contenedor_props": {"z_index": 1, "y_sort_enabled": true},
		"offset": Vector2(8, 14),
		"prop_coord": "coord",
		"prop_id": "id_roca",
		"prefijo_id": "roca",
		# Primer frame de roca-romper.png recortado a 16x16 (AtlasTexture).
		"icono": "res://graficos/editor/editor_tile_roca_romper.tres",
		"color": Color(0.75, 0.5, 0.45),
	},
	{
		"nombre": "Árbol cortable",
		"plantilla": RUTA_PLANTILLAS + "arbol_cortable.tscn",
		"escena_base": "res://graficos/arbol_cortable/arbol_cortable.tscn",
		"script": "res://graficos/arbol_cortable/controlador_arbol_cortable.gd",
		"contenedor": "NPCs",
		"contenedor_props": {"z_index": 1, "y_sort_enabled": true},
		"offset": Vector2(8, 14),
		"prop_coord": "coord",
		"prop_id": "id_arbol",
		"prefijo_id": "arbol",
		# Primer frame de cuttable_tree.png recortado a 16x16 (AtlasTexture).
		"icono": "res://graficos/editor/editor_tile_arbol_cortable.tres",
		"color": Color(0.35, 0.7, 0.3),
	},
	{
		"nombre": "Objeto",
		"plantilla": RUTA_PLANTILLAS + "item.tscn",
		"escena_base": "res://escenas/ow_item.tscn",
		"script": "res://scripts/ItemOverworld.gd",
		"contenedor": "NPCs",
		"contenedor_props": {"z_index": 1, "y_sort_enabled": true},
		"offset": Vector2(8, 14),
		"prop_coord": "coord",
		"prop_id": "id_item",
		"prefijo_id": "objeto",
		# La propia imagen del objeto sirve de icono (16x16).
		"icono": "res://graficos/item.png",
		"color": Color(1.0, 0.45, 0.4),
	},
	{
		"nombre": "Objeto oculto",
		"plantilla": RUTA_PLANTILLAS + "item_oculto.tscn",
		"escena_base": "res://escenas/ow_item.tscn",
		"script": "res://scripts/ItemOverworld.gd",
		"contenedor": "NPCs",
		"contenedor_props": {"z_index": 1, "y_sort_enabled": true},
		"offset": Vector2(8, 14),
		"prop_coord": "coord",
		"prop_id": "id_item",
		"prefijo_id": "objeto_oculto",
		# Objeto semitransparente con borde punteado.
		"icono": "res://graficos/editor/editor_tile_item_oculto.png",
		"color": Color(0.6, 0.6, 0.8),
	},
]

var _plugin: EditorPlugin = null
var _boton: Button
var _flecha: MenuButton
var _iconos: Array[Texture2D] = []

var _tipo: int = 0
var _activo: bool = false
var _hay_hover: bool = false
var _celda_hover: Vector2i = Vector2i.ZERO
## Nodo de algún tipo del lápiz que ya ocupa la celda bajo el cursor (o null).
var _ocupante: Node2D = null


func configurar(plugin: EditorPlugin) -> void:
	_plugin = plugin
	add_theme_constant_override("separation", 0)
	add_child(VSeparator.new())

	_boton = Button.new()
	_boton.toggle_mode = true
	_boton.flat = true
	_boton.icon = _icono_editor(&"Edit")
	_boton.toggled.connect(_al_alternar)
	add_child(_boton)

	_flecha = MenuButton.new()
	_flecha.flat = true
	_flecha.tooltip_text = "Elegir qué coloca el lápiz"
	_flecha.icon = _icono_editor(&"GuiDropdown")
	if _flecha.icon == null:
		_flecha.text = "▾"
	add_child(_flecha)

	var menu: PopupMenu = _flecha.get_popup()
	for i: int in TIPOS.size():
		var tipo: Dictionary = TIPOS[i]
		var icono: Texture2D = load(tipo.icono) as Texture2D if ResourceLoader.exists(tipo.icono) else null
		_iconos.append(icono)
		if icono != null:
			menu.add_icon_radio_check_item(icono, tipo.nombre, i)
			menu.set_item_icon_max_width(menu.get_item_index(i), TAM_TILE)
		else:
			menu.add_radio_check_item(tipo.nombre, i)
	menu.add_separator()
	menu.add_item("Editar plantilla…", ID_EDITAR_PLANTILLA)
	menu.id_pressed.connect(_al_elegir_menu)

	var guardado: int = EditorInterface.get_editor_settings().get_project_metadata("pkrpg_lapiz", "tipo", 0)
	_elegir_tipo(clampi(guardado, 0, TIPOS.size() - 1))
	visible = false


## Muestra u oculta el lápiz según haya un mapa abierto; sin mapa lo suelta.
func set_en_mapa(en_mapa: bool) -> void:
	visible = en_mapa
	if not en_mapa:
		soltar()


func soltar() -> void:
	if is_instance_valid(_boton) and _boton.button_pressed:
		_boton.button_pressed = false  # Emite toggled → _al_alternar(false).


# ─── Delegados de EditorPlugin ────────────────────────────────────────

## Cualquier nodo del mapa abierto: así el lienzo reenvía la entrada al plugin
## tenga seleccionado lo que tenga (el propio plugin comprueba que sea un mapa).
func maneja(objeto: Object) -> bool:
	if not (objeto is Node):
		return false
	var raiz: Node = EditorInterface.get_edited_scene_root()
	return raiz != null and (objeto == raiz or raiz.is_ancestor_of(objeto))


func entrada_lienzo(event: InputEvent) -> bool:
	if not _activo:
		return false
	var raiz: Node2D = _raiz_mapa()
	if raiz == null:
		return false

	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and not tecla.echo and tecla.keycode == KEY_ESCAPE:
			soltar()
			return true
		return false

	if event is InputEventMouseMotion:
		_actualizar_hover(raiz, _celda_bajo(raiz, (event as InputEventMouseMotion).position))
		return false  # El lienzo sigue recibiendo el movimiento (paneo, reglas...).

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				soltar()
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			# También se consume el soltar, para que no arranque una selección en caja.
			if mb.pressed:
				var celda: Vector2i = _celda_bajo(raiz, mb.position)
				_actualizar_hover(raiz, celda)
				_colocar(raiz, celda)
			return true
	return false


func dibujar_lienzo(overlay: Control) -> void:
	if not _activo or not _hay_hover:
		return
	var raiz: Node2D = _raiz_mapa()
	if raiz == null:
		return
	var tipo: Dictionary = TIPOS[_tipo]
	var ocupado: bool = is_instance_valid(_ocupante)
	var color: Color = COLOR_OCUPADO if ocupado else tipo.color
	var xf: Transform2D = _transform_lienzo(raiz)
	var rect := Rect2(Vector2(_celda_hover * TAM_TILE), Vector2(TAM_TILE, TAM_TILE))

	overlay.draw_set_transform_matrix(xf)
	overlay.draw_rect(rect, Color(color, 0.3))
	if not ocupado and _iconos[_tipo] != null:
		overlay.draw_texture_rect(_iconos[_tipo], rect, false, Color(1.0, 1.0, 1.0, 0.85))
	overlay.draw_rect(rect, color, false, -1.0)
	overlay.draw_set_transform_matrix(Transform2D.IDENTITY)

	var texto: String = "%s (%d, %d)" % [tipo.nombre, _celda_hover.x, _celda_hover.y]
	if ocupado:
		texto = "Ocupado por %s — clic para seleccionarlo" % _ocupante.name
	var pos: Vector2 = xf * (rect.position + Vector2(rect.size.x, 0.0)) + Vector2(6.0, 14.0)
	var fuente: Font = ThemeDB.fallback_font
	overlay.draw_string(fuente, pos + Vector2.ONE, texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.0, 0.0, 0.0, 0.8))
	overlay.draw_string(fuente, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)


# ─── Colocación ───────────────────────────────────────────────────────

func _colocar(raiz: Node2D, celda: Vector2i) -> void:
	if is_instance_valid(_ocupante):
		_seleccionar.call_deferred(_ocupante)
		return

	var tipo: Dictionary = TIPOS[_tipo]
	var nodo: Node2D = _crear_desde_plantilla(tipo)
	if nodo == null:
		return

	var contenedor: Node2D = raiz
	var contenedor_nuevo: Node2D = null
	if tipo.contenedor != "":
		contenedor = raiz.get_node_or_null(NodePath(tipo.contenedor)) as Node2D
		if contenedor == null:
			if raiz.has_node(NodePath(tipo.contenedor)):
				push_warning("[📦 PKRPG] Lápiz: '%s' existe pero no es Node2D; no se coloca el %s." % [tipo.contenedor, tipo.nombre])
				nodo.free()
				return
			contenedor_nuevo = Node2D.new()
			contenedor_nuevo.name = tipo.contenedor
			for prop: String in tipo.contenedor_props:
				contenedor_nuevo.set(prop, tipo.contenedor_props[prop])
			contenedor = contenedor_nuevo

	# Posición en el espacio del contenedor, que es donde los scripts se enganchan
	# a la rejilla (los contenedores de los mapas están en el origen).
	var pos: Vector2 = Vector2(celda * TAM_TILE) + tipo.offset
	if contenedor != raiz and contenedor_nuevo == null:
		pos = contenedor.to_local(raiz.to_global(pos))
	if tipo.prop_coord != "":
		nodo.set(tipo.prop_coord, Vector2i(((pos - tipo.offset) / TAM_TILE).round()))
	if tipo.has("prop_id"):
		nodo.set(tipo.prop_id, _id_libre(raiz, tipo))
	nodo.position = pos
	nodo.name = _nombre_libre(contenedor, nodo.name)

	var ur: EditorUndoRedoManager = _plugin.get_undo_redo()
	ur.create_action("Lápiz: colocar %s en (%d, %d)" % [tipo.nombre, celda.x, celda.y], UndoRedo.MERGE_DISABLE, raiz)
	if contenedor_nuevo != null:
		ur.add_do_method(raiz, &"add_child", contenedor_nuevo, true)
		ur.add_do_method(contenedor_nuevo, &"set_owner", raiz)
		ur.add_do_reference(contenedor_nuevo)
		ur.add_undo_method(raiz, &"remove_child", contenedor_nuevo)
	ur.add_do_method(contenedor, &"add_child", nodo, true)
	ur.add_do_method(nodo, &"set_owner", raiz)
	ur.add_do_reference(nodo)
	ur.add_undo_method(contenedor, &"remove_child", nodo)
	ur.commit_action()

	_ocupante = nodo
	_plugin.update_overlays()
	_seleccionar.call_deferred(nodo)


## Crea el nodo del tipo y le copia las propiedades que fija la raíz de su plantilla.
func _crear_desde_plantilla(tipo: Dictionary) -> Node2D:
	var plantilla := load(tipo.plantilla) as PackedScene
	if plantilla == null:
		push_error("[📦 PKRPG] Lápiz: no se pudo cargar la plantilla %s" % tipo.plantilla)
		return null
	var estado: SceneState = plantilla.get_state()

	# El script va primero: el resto de propiedades son suyas.
	var props: Dictionary = {}
	for i: int in estado.get_node_property_count(0):
		props[String(estado.get_node_property_name(0, i))] = estado.get_node_property_value(0, i)
	var script: Script = props.get("script") as Script

	var nodo: Node
	if tipo.escena_base != "":
		var base := load(tipo.escena_base) as PackedScene
		if base == null:
			push_error("[📦 PKRPG] Lápiz: no se pudo cargar la escena base %s" % tipo.escena_base)
			return null
		nodo = base.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	else:
		# Si el script exige una clase nativa más concreta que la raíz de la
		# plantilla (p. ej. una plantilla en caché aún Node2D con warp.gd ya
		# Sprite2D), manda el script: si no, set_script falla y el nodo queda sin él.
		var clase: StringName = estado.get_node_type(0)
		if script != null and ClassDB.is_parent_class(script.get_instance_base_type(), clase):
			clase = script.get_instance_base_type()
		nodo = ClassDB.instantiate(clase) as Node
	if not (nodo is Node2D):
		push_error("[📦 PKRPG] Lápiz: la plantilla %s no genera un Node2D" % tipo.plantilla)
		if nodo != null:
			nodo.free()
		return null

	if script != null:
		nodo.set_script(script)
		if nodo.get_script() != script:
			push_error("[📦 PKRPG] Lápiz: no se pudo asignar %s a un %s (plantilla %s); no se coloca el %s." % [script.resource_path, nodo.get_class(), tipo.plantilla, tipo.nombre])
			nodo.free()
			return null
	for prop: String in props:
		if prop != "script" and prop != "position":
			nodo.set(prop, props[prop])
	for grupo: String in estado.get_node_groups(0):
		nodo.add_to_group(grupo, true)
	nodo.name = estado.get_node_name(0)
	return nodo as Node2D


## Primer id "<prefijo>N" (N desde 1) que no usa ningún nodo del tipo en el mapa.
## Sigue la convención de las parcelas de bayas: "parcela_r104_3" en ruta_104
## (ver parcelas_hoenn_test.gd) y "parcela_<nombre_interno>_N" en otros mapas.
func _id_libre(raiz: Node2D, tipo: Dictionary) -> String:
	var mapa: String = str(raiz.get("nombre_interno")) if raiz.get("nombre_interno") != null else ""
	if mapa.is_empty():
		mapa = raiz.scene_file_path.get_file().get_basename()
	var palabra: String = str(tipo.get("prefijo_id", "parcela"))
	var prefijo: String = "%s_r%s_" % [palabra, mapa.trim_prefix("ruta_")] if mapa.begins_with("ruta_") else "%s_%s_" % [palabra, mapa]
	var usados: Dictionary = {}
	_recoger_ids(raiz, raiz, tipo, usados)
	var n: int = 1
	while usados.has(prefijo + str(n)):
		n += 1
	return prefijo + str(n)


func _recoger_ids(raiz: Node, nodo: Node, tipo: Dictionary, usados: Dictionary) -> void:
	for hijo: Node in nodo.get_children():
		if hijo.owner != raiz:
			continue
		if _es_del_tipo(hijo, tipo):
			usados[str(hijo.get(tipo.prop_id))] = true
		if hijo.scene_file_path == "":
			_recoger_ids(raiz, hijo, tipo, usados)


func _nombre_libre(padre: Node, base: String) -> String:
	if not padre.has_node(NodePath(base)):
		return base
	var n: int = 2
	while padre.has_node(NodePath("%s%d" % [base, n])):
		n += 1
	return "%s%d" % [base, n]


func _seleccionar(nodo: Node) -> void:
	if not is_instance_valid(nodo) or not nodo.is_inside_tree():
		return
	var seleccion: EditorSelection = EditorInterface.get_selection()
	seleccion.clear()
	seleccion.add_node(nodo)
	EditorInterface.edit_node(nodo)


# ─── Ocupación de celdas ──────────────────────────────────────────────

func _actualizar_hover(raiz: Node2D, celda: Vector2i) -> void:
	if _hay_hover and celda == _celda_hover:
		return
	_hay_hover = true
	_celda_hover = celda
	_ocupante = _buscar_ocupante(raiz, raiz, celda)
	_plugin.update_overlays()


## Primer nodo de cualquier tipo del lápiz (NPC, Warp, Cartel, Baya o derivados) cuya
## posición cae en la celda. No entra en escenas instanciadas: sus hijos no cuentan.
func _buscar_ocupante(raiz: Node2D, nodo: Node, celda: Vector2i) -> Node2D:
	for hijo: Node in nodo.get_children():
		if hijo is TileMapLayer or hijo.owner != raiz:
			continue
		if hijo is Node2D and _es_de_algun_tipo(hijo):
			var local: Vector2 = raiz.to_local((hijo as Node2D).global_position)
			if Vector2i((local / TAM_TILE).floor()) == celda:
				return hijo
		if hijo.scene_file_path == "":
			var encontrado: Node2D = _buscar_ocupante(raiz, hijo, celda)
			if encontrado != null:
				return encontrado
	return null


func _es_de_algun_tipo(nodo: Node) -> bool:
	return TIPOS.any(func(tipo: Dictionary) -> bool: return _es_del_tipo(nodo, tipo))


func _es_del_tipo(nodo: Node, tipo: Dictionary) -> bool:
	var script: Script = nodo.get_script() as Script
	while script != null:
		if script.resource_path == tipo.script:
			return true
		script = script.get_base_script()
	return false


# ─── Botones y estado ─────────────────────────────────────────────────

func _al_alternar(activo: bool) -> void:
	_activo = activo
	_hay_hover = false
	_ocupante = null
	if activo:
		var raiz: Node2D = _raiz_mapa()
		if raiz == null:
			_boton.set_pressed_no_signal(false)
			_activo = false
			return
		# El lienzo solo reenvía la entrada al plugin que maneja lo editado. Sin
		# selección no hay nadie, y con un TileMapLayer el editor de tiles compite
		# por el clic: en ambos casos se pasa a editar la raíz del mapa.
		var seleccionados: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
		if seleccionados.is_empty() or seleccionados.any(func(n: Node) -> bool: return n is TileMapLayer):
			_seleccionar(raiz)
	if _plugin != null:
		_plugin.update_overlays()


func _al_elegir_menu(id: int) -> void:
	if id == ID_EDITAR_PLANTILLA:
		soltar()
		EditorInterface.open_scene_from_path(TIPOS[_tipo].plantilla)
		return
	_elegir_tipo(id)
	if _activo:
		_hay_hover = false
		_plugin.update_overlays()
	else:
		_boton.button_pressed = true  # Elegir un tipo ya activa el lápiz.


func _elegir_tipo(indice: int) -> void:
	_tipo = indice
	var tipo: Dictionary = TIPOS[indice]
	_boton.text = tipo.nombre
	_boton.tooltip_text = "Lápiz: colocar %s en el mapa" % tipo.nombre + AYUDA
	var menu: PopupMenu = _flecha.get_popup()
	for i: int in TIPOS.size():
		menu.set_item_checked(menu.get_item_index(i), i == indice)
	menu.set_item_text(menu.get_item_index(ID_EDITAR_PLANTILLA), "Editar plantilla de %s…" % tipo.nombre)
	EditorInterface.get_editor_settings().set_project_metadata("pkrpg_lapiz", "tipo", indice)


func _icono_editor(nombre: StringName) -> Texture2D:
	var tema: Theme = EditorInterface.get_editor_theme()
	if tema != null and tema.has_icon(nombre, &"EditorIcons"):
		return tema.get_icon(nombre, &"EditorIcons")
	return null


func _raiz_mapa() -> Node2D:
	return EditorInterface.get_edited_scene_root() as Node2D


## Transform de coordenadas locales del mapa a píxeles del lienzo del editor
## (incluye zoom y desplazamiento de la vista 2D, como en lapiz_flores).
func _transform_lienzo(raiz: Node2D) -> Transform2D:
	return raiz.get_viewport().global_canvas_transform * raiz.get_global_transform_with_canvas()


func _celda_bajo(raiz: Node2D, pos_viewport: Vector2) -> Vector2i:
	var local: Vector2 = _transform_lienzo(raiz).affine_inverse() * pos_viewport
	return Vector2i((local / TAM_TILE).floor())
