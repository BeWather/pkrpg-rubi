@tool
extends "res://escenas/mapas/signpost.gd"

## PC del laboratorio con menú debug: con `AdministradorMapa.iniciar_debug` permite
## activar o quitar POKéDEX, POKéNAV, BICI CARRERA, BICI ACROBAT, las 8 medallas,
## las 8 MO y el juego completado (FLAG_SYS_GAME_CLEAR); sin ella es un cartel normal.

const MenuDebugLista = preload("res://UI/menu_debug_lista.gd")
const MOTIVO_PAUSA: StringName = &"debug_laboratorio"
const BICI_CARRERA: String = "BICICARRERA"
const BICI_ACROBATICA: String = "BICIACROBAT"
const MEDALLAS_TOTAL: int = 8
const MOS: PackedStringArray = ["MO01", "MO02", "MO03", "MO04", "MO05", "MO06", "MO07", "MO08"]
## FLAG_SYS_GAME_CLEAR (se activa en el SALÓN de la FAMA). Los mapas que dependen de ella la leen al activarse.
const BANDERA_JUEGO_COMPLETADO: String = "SYS_GAME_CLEAR"
## ITEM_EON_TICKET + FLAG_SYS_HAS_EON_TICKET (en Rubí llegan por Mystery Event): ferry de CALAGUA a la ISLA SUR.
const OBJETO_TICKET_EON: String = "TICKETEON"
const BANDERA_TICKET_EON: String = "SYS_HAS_EON_TICKET"

enum Opcion { POKEDEX, POKENAV, BICI_CARRERA, BICI_ACROBATICA, MEDALLAS, MOS, JUEGO_COMPLETADO, TICKET_EON, LEER_CARTEL, SALIR }


func accionar_cartel() -> void:
	var admin := get_tree().root.get_node_or_null("AdministradorMapa")
	if admin == null or not admin.has_method("debug_activo") or not admin.debug_activo() \
			or admin.get_node_or_null("Menu") == null:
		super.accionar_cartel()
		return
	_menu_debug(admin)


func _menu_debug(admin: Node) -> void:
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	var leer_cartel := false
	var indice := 0
	while true:
		indice = await MenuDebugLista.elegir(admin.get_node("Menu"), _opciones(), PackedStringArray(), indice)
		match indice:
			Opcion.POKEDEX:
				SistemaGuardado.set_flag(PokedexPartida.BANDERA, not PokedexPartida.obtenida())
			Opcion.POKENAV:
				SistemaGuardado.set_flag(Singleton.BANDERA_POKENAV, not _tiene_pokenav())
			Opcion.BICI_CARRERA:
				_alternar_objeto(BICI_CARRERA)
			Opcion.BICI_ACROBATICA:
				_alternar_objeto(BICI_ACROBATICA)
			Opcion.MEDALLAS:
				_alternar_medallas()
			Opcion.MOS:
				_alternar_mos()
			Opcion.JUEGO_COMPLETADO:
				SistemaGuardado.set_flag(BANDERA_JUEGO_COMPLETADO, not juego_completado())
			Opcion.TICKET_EON:
				_alternar_ticket_eon()
			Opcion.LEER_CARTEL:
				leer_cartel = true
				break
			_:
				break
		_aplicar_menu_pausa()
	_aplicar_menu_pausa()
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	if is_instance_valid(admin.jugador):
		admin.jugador.no_control = false
	if leer_cartel:
		super.accionar_cartel()


func _opciones() -> PackedStringArray:
	return PackedStringArray([
		_linea("POKéDEX", PokedexPartida.obtenida()),
		_linea("POKéNAV", _tiene_pokenav()),
		_linea("BICI CARRERA", _tiene_objeto(BICI_CARRERA)),
		_linea("BICI ACROBAT", _tiene_objeto(BICI_ACROBATICA)),
		"MEDALLAS  %d/%d" % [SistemaGuardado.contar_medallas(), MEDALLAS_TOTAL],
		"MO  %d/%d" % [_contar_mos(), MOS.size()],
		_linea("JUEGO COMPLETADO", juego_completado()),
		_linea("TICKET EÓN", tiene_ticket_eon()),
		"LEER CARTEL",
		"SALIR",
	])


func _linea(nombre: String, activo: bool) -> String:
	return "%s  %s" % [nombre, "SÍ" if activo else "NO"]


static func juego_completado() -> bool:
	return SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO)


func tiene_ticket_eon() -> bool:
	return SistemaGuardado.get_flag(BANDERA_TICKET_EON) and _tiene_objeto(OBJETO_TICKET_EON)


## Da o quita el billete y su bandera a la vez.
func _alternar_ticket_eon() -> void:
	var dar := not tiene_ticket_eon()
	if _tiene_objeto(OBJETO_TICKET_EON) != dar:
		_alternar_objeto(OBJETO_TICKET_EON)
	SistemaGuardado.set_flag(BANDERA_TICKET_EON, dar)


func _tiene_pokenav() -> bool:
	return SistemaGuardado.get_flag(Singleton.BANDERA_POKENAV)


## Refleja las banderas en el menú de pausa sin esperar a un cambio de mapa.
func _aplicar_menu_pausa() -> void:
	Singleton.establecer_opcion_menu_visible("pokedex", PokedexPartida.obtenida())
	Singleton.establecer_opcion_menu_visible("pokenav", _tiene_pokenav())


func _bolsillo(objeto_id: String) -> int:
	return int(SistemaGuardado.obtener_datos_objeto_completos(objeto_id).bolsillo_id)


func _tiene_objeto(objeto_id: String) -> bool:
	return SistemaGuardado.tiene_objeto(objeto_id, 1, _bolsillo(objeto_id))


func _alternar_objeto(objeto_id: String) -> void:
	if _tiene_objeto(objeto_id):
		var bolsillo := _bolsillo(objeto_id)
		SistemaGuardado.quitar_objeto_jugador(objeto_id, SistemaGuardado.get_cantidad_objeto(objeto_id, bolsillo), bolsillo)
	else:
		SistemaGuardado.dar_objeto_jugador(objeto_id)


func _contar_mos() -> int:
	var total := 0
	for mo in MOS:
		if _tiene_objeto(mo):
			total += 1
	return total


## Con todas las MO las quita; si falta alguna, da las que faltan.
func _alternar_mos() -> void:
	var tiene_todas := _contar_mos() == MOS.size()
	for mo in MOS:
		if _tiene_objeto(mo) == tiene_todas:
			_alternar_objeto(mo)


## Con las 8 medallas las quita todas; si falta alguna, las da todas.
func _alternar_medallas() -> void:
	var dar := SistemaGuardado.contar_medallas() < MEDALLAS_TOTAL
	var medallas: Array = []
	medallas.resize(MEDALLAS_TOTAL)
	medallas.fill(dar)
	SistemaGuardado.datos_vivos.jugador["medallas"] = medallas
