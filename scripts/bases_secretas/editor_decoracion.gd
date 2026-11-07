extends Control
class_name EditorDecoracion

## DECORAR/GUARDAR/TIRAR. Mutación solo tras confirmar y cotejar estado fresco.
signal entrada(indice: int)
signal cursor_accion(confirmar: bool)
@export var lista: Control
@export var filas: Array[Label]
@export var selector: Control
@export var descripcion: Label
@export var preview: PreviewDecoracion
@export var foco: Node2D
var activo: bool = false
var fase: StringName = &""
var ancla: Vector2i
var copia_id: int = -1
var ultimo_resultado: StringName = &""
var _mapa: Node2D  # InteriorBaseSecreta o HabitacionJugador: contrato de decoración.
var _admin: Node2D
var _dialogo: Node
var _jugador: Node2D
var _sistema: SistemaBasesSecretas
var _contexto: Dictionary
var _seleccion: Dictionary = {}
var _grupo_guardar: Array[Dictionary] = []
var _operacion: StringName = &"decorar"
var _tipo_contexto: StringName = &"base"
var _foco_previo: Node2D
var _indice: int = 0
var _scroll: int = 0
var _items: Array[Dictionary] = []
var _soltar: bool = true
var _sesion: int = 0
var _repeticion: float = 0
const PAUSA: StringName = &"editor_decoracion"


func abrir_operacion(operacion: StringName, interior: Node2D, admin: Node2D) -> void:
	if not (interior is InteriorBaseSecreta or interior is HabitacionJugador):
		return
	if operacion not in [&"decorar", &"guardar", &"tirar"] or activo or interior == null or admin == null or not interior.pc_activo():
		return
	_mapa = interior
	_admin = admin
	_sistema = interior.sistema
	_contexto = interior.obtener_contexto()
	_tipo_contexto = &"habitacion" if interior is HabitacionJugador else &"base"
	_dialogo = admin.get("dialogo_bases") as Node
	_jugador = admin.get("jugador") as Node2D
	if _jugador == null or _dialogo == null or not _vigente():
		return
	activo = true
	_operacion = operacion
	_seleccion.clear()
	_sesion += 1
	var sesion: int = _sesion
	_foco_previo = Singleton.foco_camara
	Singleton.mantener_pausa(PAUSA, true)
	if operacion == &"guardar":
		await _guardar(sesion)
	else:
		await _inventario(sesion)
	if sesion == _sesion:
		_finalizar()


func _inventario(sesion: int) -> void:
	if _sistema.obtener_inventario().is_empty():
		await _mensaje("BASES_EDITOR_VACIO")
		return
	while _actual(sesion):
		var categorias: Array[Dictionary] = categorias_visibles()
		var categoria: int = await _elegir(categorias)
		if not _actual(sesion) or categoria < 0 or categoria == categorias.size() - 1:
			break
		var id_categoria: StringName = StringName(categorias[categoria]["id"])
		while _actual(sesion):
			var copias: Array[Dictionary] = copias_visibles(id_categoria)
			if copias.size() == 1:
				await _mensaje("BASES_EDITOR_VACIO")
				break
			var indice: int = await _elegir(copias)
			if not _actual(sesion) or indice < 0 or indice == copias.size() - 1:
				break
			copia_id = int(copias[indice]["copia_id"])
			if _operacion == &"tirar":
				await _tirar(sesion)
				continue
			var preflight: StringName = _preflight(copia_id)
			if preflight != &"exito":
				await _rechazo(preflight)
				continue
			await _colocar(sesion)


func _tirar(sesion: int) -> void:
	_seleccion = _sistema.obtener_copia(copia_id)
	if not _sistema.copia_disponible(copia_id):
		ultimo_resultado = &"en_uso"
		await _mensaje("BASES_TIRAR_EN_USO")
		return
	fase = &"dialogo"
	var texto: String = DatosPCBase.texto("BASES_TIRAR_CONFIRMAR").format({"cantidad": DatosTextosDecoracion.nombre(int(_seleccion["decoracion_id"]))})
	var acepta: bool = await _dialogo.call("preguntar", texto)
	if not _actual(sesion):
		return
	if acepta:
		ultimo_resultado = confirmar_tirar()
		await _mensaje("BASES_TIRAR_FIN" if ultimo_resultado == &"exito" else "BASES_TIRAR_EN_USO")
	if sesion == _sesion:
		_seleccion.clear()


func confirmar_tirar() -> StringName:
	if not activo or _operacion != &"tirar":
		return &"sesion_inactiva"
	if not _vigente():
		return &"contexto_invalido"
	if _seleccion.is_empty() or _sistema.obtener_copia(copia_id) != _seleccion:
		return &"copia_invalida"
	return _sistema.tirar_decoracion(copia_id)  # Rechaza uso base/habitación fresco.


func grupo_guardar_actual() -> Array[Dictionary]:
	if not _vigente():
		return []
	return SeleccionGuardarDecoracion.seleccionar(_sistema.obtener_colocaciones(_tipo_contexto), ancla, snapshot_fresco()["celdas"])


func confirmar_guardar() -> StringName:
	if not activo or _operacion != &"guardar":
		return &"sesion_inactiva"
	if not _vigente():
		return &"contexto_invalido"
	var grupo: Array[Dictionary] = grupo_guardar_actual()
	if grupo.is_empty() or grupo != _grupo_guardar:
		return &"seleccion_cambiada"
	var ids: Array[int] = []
	for colocacion: Dictionary in grupo:
		var id: int = int(colocacion["copia_id"])
		if _sistema.obtener_copia(id).get("decoracion_id", -1) != colocacion["decoracion_id"]:
			return &"copia_invalida"
		ids.append(id)
	var anteriores: Array[Dictionary] = _sistema.obtener_colocaciones(_tipo_contexto)
	var restantes: Array[Dictionary] = []
	for colocacion: Dictionary in anteriores:
		if not ids.has(int(colocacion["copia_id"])):
			restantes.append(colocacion)
	# Planificar/componer primero; ante fallo ni una copia se ha liberado.
	var resultado: StringName = _mapa.mapa_decoracion.recomponer(restantes)
	if resultado == &"exito":
		resultado = _sistema.guardar_decoraciones(ids, _tipo_contexto)
		if resultado != &"exito":
			_mapa.mapa_decoracion.recomponer(anteriores)
	_reaplicar_pc()
	return resultado


func _guardar(sesion: int) -> void:
	var colocaciones: Array[Dictionary] = _sistema.obtener_colocaciones(_tipo_contexto)
	if colocaciones.is_empty():
		await _mensaje("BASES_GUARDAR_VACIO")
		return
	ancla = _mapa.global_to_map_cell(_jugador.global_position)
	preview.limpiar()
	preview.mapa = _mapa
	preview.solo_cursor = true
	preview.show()
	while _actual(sesion):
		_cursor()
		var confirma: bool = await cursor_accion
		if not _actual(sesion):
			break
		fase = &"dialogo"
		_grupo_guardar = grupo_guardar_actual()
		var celda: Dictionary = _mapa.mapa_decoracion.obtener_celda(ancla)
		var en_pc: bool = int(celda.get("metatile_id", -1)) in [0x220, 0x224] if _tipo_contexto == &"base" else ancla == (_mapa.get_node("Carteles/PCCasa") as EventoPCCasa).coord_tile
		if not confirma or (_grupo_guardar.is_empty() and en_pc):
			var cancela: bool = await _dialogo.call("preguntar", DatosPCBase.texto("BASES_GUARDAR_CANCELAR"))
			if not _actual(sesion) or cancela:
				break
			continue
		if _grupo_guardar.is_empty():
			await _mensaje("BASES_GUARDAR_NADA")
			continue
		var acepta: bool = await _dialogo.call("preguntar", DatosPCBase.texto("BASES_GUARDAR_CONFIRMAR"))
		if not _actual(sesion):
			break
		if acepta:
			ultimo_resultado = confirmar_guardar()
			await _mensaje("BASES_GUARDAR_FIN" if ultimo_resultado == &"exito" else "BASES_GUARDAR_NADA")
	if sesion == _sesion:
		preview.limpiar()
		_grupo_guardar.clear()
		Singleton.foco_camara = _foco_previo


func _vigente() -> bool:
	var comun: bool = is_instance_valid(_mapa) and is_instance_valid(_admin) and is_instance_valid(_jugador) \
		and _admin.get("jugador") == _jugador \
		and _admin.get("mapa_actual") == _mapa and int(_admin.get("coneccion")) == 0 \
		and _mapa.sistema == _sistema and _sistema != null and _sistema.es_compatible() \
		and _mapa.obtener_contexto() == _contexto and not _mapa.es_vista_previa() and _mapa.pc_activo()
	if not comun:
		return false
	if _tipo_contexto == &"habitacion":
		return _mapa is HabitacionJugador and _mapa.casa == HistoriaVillaRaiz.casa_jugador()
	return _mapa is InteriorBaseSecreta and _sistema.id_base() == int(_contexto.get("entrada_id", 0))


func _reaplicar_pc() -> void:
	if _tipo_contexto == &"base":
		(_mapa.get_node("PC") as PCBaseSecreta)._dibujar(0x224)
	else:
		_mapa.reaplicar_pc()


func _actual(sesion: int) -> bool:
	return activo and sesion == _sesion and _vigente()


func categorias_visibles() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for categoria: Dictionary in DatosBasesSecretas.categorias():
		var id: String = str(categoria["id"])
		resultado.append({"id": id, "texto": "%s %d/%d" % [DatosPCBase.texto("BASES_CAT_" + id), _sistema.cantidad_categoria(StringName(id)), int(categoria["capacidad"])], "descripcion": "",
			"en_uso": _tipo_contexto == &"habitacion" and _operacion == &"decorar" and id not in ["MUNECOS", "COJINES"]})
	resultado.append({"texto": DatosPCBase.texto("BASES_PC_SALIR_DECORACION"), "descripcion": DatosPCBase.texto("BASES_PC_AYUDA_SALIR")})
	return resultado


func copias_visibles(categoria: StringName) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for copia: Dictionary in _sistema.obtener_inventario():
		var id: int = int(copia["decoracion_id"])
		if StringName(DatosBasesSecretas.decoracion(id)["categoria"]) != categoria:
			continue
		resultado.append({"copia_id": copia["copia_id"], "texto": DatosTextosDecoracion.nombre(id),
			"descripcion": DatosTextosDecoracion.descripcion(id), "en_uso": not _sistema.copia_disponible(int(copia["copia_id"])) \
				or (_tipo_contexto == &"habitacion" and _operacion == &"decorar" and categoria not in [&"MUNECOS", &"COJINES"])})
	resultado.append({"texto": DatosPCBase.texto("BASES_PC_SALIR_DECORACION"), "descripcion": DatosPCBase.texto("BASES_PC_AYUDA_SALIR")})
	return resultado


func _elegir(items: Array[Dictionary]) -> int:
	_items = items
	_indice = 0
	_scroll = 0
	_soltar = true
	fase = &"lista"
	show()
	(get_parent() as CanvasItem).show()
	lista.show()
	_actualizar_lista()
	var elegido: int = await entrada
	lista.hide()
	fase = &""
	return elegido


func _actualizar_lista() -> void:
	_scroll = clampi(_scroll, maxi(0, _indice - filas.size() + 1), _indice)
	for i: int in filas.size():
		var indice: int = _scroll + i
		filas[i].visible = indice < _items.size()
		if indice < _items.size():
			filas[i].text = str(_items[indice]["texto"])
			filas[i].modulate = Color(0.55, 0.55, 0.55) if bool(_items[indice].get("en_uso", false)) else Color.WHITE
	selector.position.y = 7 + (_indice - _scroll) * 12
	descripcion.text = str(_items[_indice]["descripcion"])


func _preflight(id: int) -> StringName:
	var candidato: SistemaBasesSecretas = SistemaBasesSecretas.new()
	candidato.from_dict(_sistema.to_dict())
	return candidato.registrar_colocacion_validada(id, Vector2i(0, 0), _tipo_contexto)


## Activos de cualquier elevación (GBA z=0), no solo capa activa del jugador.
func objetos_activos() -> Array[Vector2i]:
	var objetos: Array[Vector2i] = []
	var nodos: Array[Node] = []
	var raiz: Node = _mapa.get_node_or_null("NPCs")
	if raiz != null:
		nodos.append_array(raiz.get_children())
	for grupo: String in ["NPC", "objetos_bases_secretas"]:
		for nodo: Node in get_tree().get_nodes_in_group(grupo):
			if _mapa.is_ancestor_of(nodo) and not nodos.has(nodo):
				nodos.append(nodo)
	for nodo: Node in nodos:
		if not nodo is Node2D or nodo == _jugador or not (nodo as Node2D).is_visible_in_tree() \
			or nodo == _mapa.mapa_decoracion.contenedor_sprites \
			or _mapa.mapa_decoracion.contenedor_sprites.is_ancestor_of(nodo):
			continue
		var celda: Vector2i = nodo.get("coord_celda") if "coord_celda" in nodo else _mapa.global_to_map_cell((nodo as Node2D).global_position)
		if not objetos.has(celda):
			objetos.append(celda)
	return objetos


func snapshot_fresco() -> Dictionary:
	if not _vigente():
		return {}
	var snapshot: Dictionary = _mapa.mapa_decoracion.snapshot_validacion(_mapa.global_to_map_cell(_jugador.global_position), objetos_activos())
	if _tipo_contexto == &"habitacion" and not snapshot.is_empty():
		snapshot["casa_jugador"] = _contexto["casa_jugador"]
	return snapshot  # El validador puro recibe propiedad, nunca consulta la partida.


func validar_actual() -> StringName:
	if not _vigente():
		return &"contexto_invalido"
	if not _seleccion.is_empty() and _sistema.obtener_copia(copia_id) != _seleccion:
		return &"copia_invalida"
	return ValidadorDecoracion.validar_colocacion(_sistema, copia_id, ancla, snapshot_fresco(), _tipo_contexto)["resultado"]


## Se invoca SOLO después del SÍ. No await entre revalidación, registro/composición.
func confirmar_actual() -> StringName:
	if not activo or _operacion != &"decorar":
		return &"sesion_inactiva"
	var resultado: StringName = validar_actual()
	if resultado != &"exito":
		return resultado
	var anteriores: Array[Dictionary] = _sistema.obtener_colocaciones(_tipo_contexto)
	resultado = _sistema.registrar_colocacion_validada(copia_id, ancla, _tipo_contexto)
	if resultado != &"exito":
		return resultado
	resultado = _mapa.mapa_decoracion.recomponer(_sistema.obtener_colocaciones(_tipo_contexto))
	if resultado != &"exito":
		_sistema.guardar_decoracion(copia_id, _tipo_contexto)
		# El compositor planifica antes de mutar; las capas anteriores siguen intactas.
		assert(_sistema.obtener_colocaciones(_tipo_contexto) == anteriores)
	_reaplicar_pc()
	return resultado


func _colocar(sesion: int) -> void:
	_seleccion = _sistema.obtener_copia(copia_id)
	var id: int = int(_seleccion["decoracion_id"])
	var tamano: Vector2i = ValidadorDecoracion.tamano_forma(ValidadorDecoracion.forma_decoracion(id))
	var limites: Rect2i = snapshot_fresco()["limites"]
	ancla = _mapa.global_to_map_cell(_jugador.global_position)
	ancla.x = clampi(ancla.x, 0, mini(15, limites.size.x - tamano.x))
	ancla.y = clampi(ancla.y, tamano.y - 1, mini(15, limites.size.y - 1))
	preview.preparar(_mapa, id)
	while _actual(sesion):
		_cursor()
		var confirma: bool = await cursor_accion
		if not _actual(sesion):
			break
		fase = &"dialogo"
		if not confirma:
			var cancela: bool = await _dialogo.call("preguntar", DatosPCBase.texto("BASES_EDITOR_CANCELAR"))
			if not _actual(sesion) or cancela:
				break
			continue
		var resultado: StringName = validar_actual()
		if resultado != &"exito":
			await _rechazo(resultado)
			continue
		var acepta: bool = await _dialogo.call("preguntar", DatosPCBase.texto("BASES_EDITOR_COLOCAR"))
		if not _actual(sesion):
			break
		if acepta:
			ultimo_resultado = confirmar_actual()
			if ultimo_resultado == &"exito":
				break
			await _rechazo(ultimo_resultado)
	if sesion != _sesion:
		return
	preview.limpiar()
	_seleccion.clear()
	if sesion == _sesion:
		Singleton.foco_camara = _foco_previo


func _cursor() -> void:
	fase = &"cursor"
	_soltar = true
	_repeticion = 0
	show()
	(get_parent() as CanvasItem).show()
	preview.ancla = ancla
	preview.permitido = validar_actual() == &"exito" if _operacion == &"decorar" else false
	foco.global_position = _mapa.to_global(Vector2(ancla) * 16 + Vector2(8, 14))
	Singleton.foco_camara = foco


func mover(direccion: Vector2i) -> bool:
	if not activo or fase != &"cursor" or not _vigente():
		return false
	if _operacion == &"guardar":
		if not (snapshot_fresco()["limites"] as Rect2i).has_point(ancla + direccion):
			return false
		ancla += direccion
		preview.ancla = ancla
		foco.global_position = _mapa.to_global(Vector2(ancla) * 16 + Vector2(8, 14))
		return true
	var id: int = int(_sistema.obtener_copia(copia_id).get("decoracion_id", -1))
	var plan: Dictionary = ValidadorDecoracion.preparar_huella(id, ancla + direccion)
	if plan["resultado"] != &"huella_preparada":
		return false
	var limites: Rect2i = snapshot_fresco()["limites"]
	if (ancla + direccion).x > 15 or (ancla + direccion).y > 15:
		return false
	for celda: Vector2i in plan["huella_grafica"]:
		if not limites.has_point(celda):
			return false
	ancla += direccion
	preview.ancla = ancla
	preview.permitido = validar_actual() == &"exito"
	foco.global_position = _mapa.to_global(Vector2(ancla) * 16 + Vector2(8, 14))
	return true


func _mensaje(clave: String) -> void:
	fase = &"dialogo"
	await _dialogo.call("mensaje", DatosPCBase.texto(clave).format({"cantidad": 12 if _tipo_contexto == &"habitacion" else 16}))


func _rechazo(resultado: StringName) -> void:
	ultimo_resultado = resultado
	var clave: String = "BASES_EDITOR_INVALIDO"
	if resultado == &"en_uso":
		clave = "BASES_EDITOR_EN_USO"
	elif resultado == &"limite_colocaciones":
		clave = "BASES_EDITOR_LIMITE"
	elif resultado == &"no_admitida":
		clave = "BASES_EDITOR_HABITACION"
	Singleton.play_sound.emit("SE_FAILURE")
	await _mensaje(clave)


func _process(delta: float) -> void:
	if not activo:
		return
	if not _vigente():
		cancelar()
		return
	if fase != &"lista" and fase != &"cursor":
		return
	if _soltar:
		if not Input.is_action_pressed("btn_accion") and not Input.is_action_pressed("btn_cancelar"):
			_soltar = false
		return
	if Input.is_action_just_pressed("btn_cancelar") or Input.is_action_just_pressed("btn_accion"):
		var confirma: bool = Input.is_action_just_pressed("btn_accion")
		Singleton.play_sound.emit("SE_SELECT")
		if fase == &"lista":
			fase = &""
			entrada.emit(_indice if confirma else -1)
		else:
			fase = &"dialogo"
			cursor_accion.emit(confirma)
		return
	_repeticion -= delta
	for accion: String in ["btn_arriba", "btn_abajo", "btn_izquierda", "btn_derecha"]:
		var nueva: bool = Input.is_action_just_pressed(accion)
		if nueva or (Input.is_action_pressed(accion) and _repeticion <= 0):
			_repeticion = 0.25 if nueva else 0.08
			if fase == &"lista" and accion in ["btn_arriba", "btn_abajo"]:
				_indice = clampi(_indice + (-1 if accion == "btn_arriba" else 1), 0, _items.size() - 1)
				_actualizar_lista()
			elif fase == &"cursor":
				mover({"btn_arriba": Vector2i.UP, "btn_abajo": Vector2i.DOWN, "btn_izquierda": Vector2i.LEFT, "btn_derecha": Vector2i.RIGHT}[accion])
			break


func cancelar() -> void:
	if not activo:
		return
	activo = false
	_sesion += 1
	var anterior: StringName = fase
	_finalizar()
	if anterior == &"lista":
		entrada.emit(-1)
	elif anterior == &"cursor":
		cursor_accion.emit(false)
	elif is_instance_valid(_dialogo):
		_dialogo.call("cancelar")


func _finalizar() -> void:
	activo = false
	fase = &""
	_seleccion.clear()
	_grupo_guardar.clear()
	lista.hide()
	preview.limpiar()
	hide()
	Singleton.mantener_pausa(PAUSA, false)
	if Singleton.foco_camara == foco:
		Singleton.foco_camara = _foco_previo if is_instance_valid(_foco_previo) else null


func _exit_tree() -> void:
	cancelar()
