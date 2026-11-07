@tool
extends "res://escenas/mapas/signpost.gd"

## Cartel con menú debug del rival: con `AdministradorMapa.iniciar_debug` permite
## cambiar el inicial y el sexo del jugador (qué rival y qué equipo aparecen) y
## reiniciar los encuentros con el rival del mapa; sin ella es un cartel normal.

const MenuDebugLista = preload("res://UI/menu_debug_lista.gd")
const MOTIVO_PAUSA: StringName = &"debug_rival"
const OPCIONES: PackedStringArray = [
	"CAMBIAR INICIAL",
	"CAMBIAR SEXO",
	"REINICIAR RIVAL DEL MAPA",
	"LEER CARTEL",
	"SALIR",
]


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
	while true:
		var opcion: int = await MenuDebugLista.elegir(admin.get_node("Menu"), OPCIONES, _cabecera())
		match opcion:
			0:
				SistemaGuardado.set_inicial((SistemaGuardado.get_inicial() + 1) % SistemaGuardado.INICIALES.size())
			1:
				var jugador: Dictionary = SistemaGuardado.datos_vivos.jugador
				jugador["sexo"] = "F" if str(jugador.get("sexo", "M")) == "M" else "M"
				_reiniciar_rivales(false)
			2:
				_reiniciar_rivales(true)
			3:
				leer_cartel = true
				break
			_:
				break
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	if is_instance_valid(admin.jugador):
		admin.jugador.no_control = false
	if leer_cartel:
		super.accionar_cartel()


## Vuelve a vestir a los rivales del mapa (por si cambió el sexo) y, con
## `borrar_banderas`, deja sus encuentros como no completados.
func _reiniciar_rivales(borrar_banderas: bool) -> void:
	var mapa: Node = owner if owner != null else get_parent()
	for evento in _eventos_rival(mapa):
		if borrar_banderas and not evento.bandera_completado.is_empty():
			SistemaGuardado.set_flag(evento.bandera_completado, false)
		if evento.has_method("preparar"):
			evento.preparar()
	for npc in mapa.find_children("*", "", true, false):
		if npc.has_method("vestir"):
			npc.vestir()


func _eventos_rival(mapa: Node) -> Array[EventoRival]:
	var eventos: Array[EventoRival] = []
	for nodo in mapa.find_children("*", "", true, false):
		if nodo is EventoRival:
			eventos.append(nodo)
	return eventos


func _cabecera() -> PackedStringArray:
	var vencidos: PackedStringArray = []
	var mapa: Node = owner if owner != null else get_parent()
	for evento in _eventos_rival(mapa):
		vencidos.append("%s %s" % [evento.encuentro, "VENCIDO" if evento.completado() else "PENDIENTE"])
	return PackedStringArray([
		"%s  INICIAL %s" % [Rival.clave(), SistemaGuardado.INICIALES[SistemaGuardado.get_inicial()]],
		", ".join(vencidos) if not vencidos.is_empty() else "SIN RIVAL EN EL MAPA",
	])
