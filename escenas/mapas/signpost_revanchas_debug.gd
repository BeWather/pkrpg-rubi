@tool
extends "res://escenas/mapas/signpost.gd"

## Cartel con menú debug de revanchas (`start_menu_debug.c:1215-1270` de pokeruby):
## con `AdministradorMapa.iniciar_debug` permite dar medallas, llenar el contador
## de pasos y marcar como listos a los entrenadores del mapa; sin ella es un
## cartel normal.

const MenuDebugLista = preload("res://UI/menu_debug_lista.gd")
const MOTIVO_PAUSA: StringName = &"debug_revanchas"
const OPCIONES: PackedStringArray = [
	"DAR 5 MEDALLAS",
	"LLENAR PASOS (255)",
	"SORTEAR MAPA",
	"LISTOS LOS DEL MAPA",
	"LIMPIAR REVANCHAS",
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
	var revanchas := SistemaGuardado.get_revanchas()
	var leer_cartel := false
	while true:
		var opcion: int = await MenuDebugLista.elegir(admin.get_node("Menu"), OPCIONES, _cabecera(revanchas))
		match opcion:
			0:
				_dar_medallas(5)
			1:
				revanchas.debug_llenar_pasos()
			2:
				admin.procesar_revanchas_mapa_actual()
			3:
				for indice in _indices_mapa(admin):
					revanchas.debug_marcar_lista(indice)
			4:
				revanchas.debug_limpiar()
			5:
				leer_cartel = true
				break
			_:
				break
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	if is_instance_valid(admin.jugador):
		admin.jugador.no_control = false
	if leer_cartel:
		super.accionar_cartel()


## Entradas de la tabla de los entrenadores del mapa actual, vencidos o no.
func _indices_mapa(admin: Node) -> Array[int]:
	var indices: Array[int] = []
	for nodo: Node in admin._nodos_grupo_mapa_actual(&"NPC"):
		var id = nodo.get("entrenador_id")
		if id == null:
			continue
		var indice := SistemaGuardado.get_revanchas().indice_por_primer_id(int(id))
		if indice >= 0 and not indices.has(indice):
			indices.append(indice)
	return indices


func _dar_medallas(cantidad: int) -> void:
	var medallas: Array = []
	var actuales: Variant = SistemaGuardado.datos_vivos.jugador.get("medallas", [])
	if actuales is Array:
		medallas = actuales.duplicate()
	medallas.resize(8)
	for i in medallas.size():
		medallas[i] = (medallas[i] == true) or i < cantidad
	SistemaGuardado.datos_vivos.jugador["medallas"] = medallas


func _cabecera(revanchas: SistemaRevanchas) -> PackedStringArray:
	var nombres: PackedStringArray = []
	for indice in revanchas.indices_listos():
		nombres.append(str(revanchas.tabla[indice]["nombre"]))
	return PackedStringArray([
		"PASOS %d/%d  MEDALLAS %d" % [revanchas.pasos, SistemaRevanchas.PASOS_REVANCHA, SistemaGuardado.contar_medallas()],
		"LISTOS: %s" % (", ".join(nombres) if not nombres.is_empty() else "-"),
	])
