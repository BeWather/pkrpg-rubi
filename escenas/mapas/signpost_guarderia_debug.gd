@tool
extends "res://escenas/mapas/signpost.gd"

## Cartel de la Guardería con menú debug: con `AdministradorMapa.iniciar_debug`
## abre un menú para acelerar huevos y sumar pasos; sin ella es un cartel normal.

const MenuDebugLista = preload("res://UI/menu_debug_lista.gd")
const MOTIVO_PAUSA: StringName = &"debug_guarderia"
const PASOS_HUEVO: int = 5
const NOMBRES_ESTADO: PackedStringArray = ["VACIA", "HUEVO PENDIENTE", "UNO", "DOS"]
const OPCIONES: PackedStringArray = [
	"HUEVO EN 5 PASOS",
	"ECLOSION EN 5 PASOS",
	"+100 PASOS",
	"+1000 PASOS",
	"+10000 PASOS",
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
	var dc := SistemaGuardado.get_guarderia()
	var leer_cartel := false
	while true:
		var opcion: int = await MenuDebugLista.elegir(admin.get_node("Menu"), OPCIONES, _cabecera(dc))
		match opcion:
			0:
				dc.debug_huevo_en_pasos(PASOS_HUEVO)
			1:
				dc.debug_eclosion_en_pasos(SistemaGuardado.get_equipo(), PASOS_HUEVO)
			2:
				dc.debug_sumar_pasos(100)
			3:
				dc.debug_sumar_pasos(1000)
			4:
				dc.debug_sumar_pasos(10000)
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


func _cabecera(dc: Guarderia) -> PackedStringArray:
	var equipo := SistemaGuardado.get_equipo()
	var huevos := 0
	for poke in equipo:
		if poke is BasePokemon and (poke as BasePokemon).huevo:
			huevos += 1
	return PackedStringArray([
		"%s  PASOS %d/%d  COMPAT %d" % [NOMBRES_ESTADO[dc.obtener_estado()], dc.pasos[0], dc.pasos[1], dc.compatibilidad()],
		"HUEVOS EQUIPO %d  CICLO %d  FORZADO %s" % [huevos, dc.contador_ciclo, "SI" if dc.debug_forzar_huevo else "NO"],
	])
