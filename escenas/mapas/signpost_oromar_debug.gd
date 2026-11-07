@tool
extends "res://escenas/mapas/signpost.gd"

## Cartel de PUEBLO OROMAR con menú debug: con `AdministradorMapa.iniciar_debug`
## permite activar o desactivar los eventos de alrededor (la ISLA ESPEJISMO de la
## RUTA 130 y la MT semanal del CLUB FAN); sin ella es un cartel normal.

const MenuDebugLista = preload("res://UI/menu_debug_lista.gd")
const MOTIVO_PAUSA: StringName = &"debug_oromar"
const MODOS_ISLA: PackedStringArray = ["NORMAL", "FORZAR VISIBLE", "FORZAR OCULTA"]
const OPCIONES: PackedStringArray = [
	"ISLA ESPEJISMO: CAMBIAR MODO",
	"ISLA: IGUALAR CON 1er POKeMON",
	"ISLA: AVANZAR 1 DIA",
	"MT CLUB FAN: REINICIAR SEMANA",
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
	var indice := 0
	while true:
		indice = await MenuDebugLista.elegir(admin.get_node("Menu"), OPCIONES, _cabecera(), indice)
		match indice:
			0:
				_fijar_modo_isla((_modo_isla() + 1) % MODOS_ISLA.size())
			1:
				IslaEspejismo.igualar_con_primer_pokemon()
			2:
				IslaEspejismo.actualizar_por_dias(1)
			3:
				SistemaGuardado.set_flag(EventoCasasOromar.BANDERA_MT_SEMANA, false)
			4:
				leer_cartel = true
				break
			_:
				break
		IslaEspejismo.refrescar(get_tree())
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	if is_instance_valid(admin.jugador):
		admin.jugador.no_control = false
	if leer_cartel:
		super.accionar_cartel()


## 0 normal, 1 forzada a la vista, 2 forzada oculta.
func _modo_isla() -> int:
	if SistemaGuardado.get_flag(IslaEspejismo.BANDERA_OCULTA):
		return 2
	return 1 if SistemaGuardado.get_flag(IslaEspejismo.BANDERA_FORZADA) else 0


func _fijar_modo_isla(modo: int) -> void:
	SistemaGuardado.set_flag(IslaEspejismo.BANDERA_FORZADA, modo == 1)
	SistemaGuardado.set_flag(IslaEspejismo.BANDERA_OCULTA, modo == 2)


func _cabecera() -> PackedStringArray:
	var equipo := PackedStringArray()
	for poke in SistemaGuardado.get_equipo():
		if poke is BasePokemon:
			equipo.append("%04X" % ((poke as BasePokemon).personalidad & IslaEspejismo.MASCARA_16))
	return PackedStringArray([
		"ISLA %s  MODO %s" % ["VISIBLE" if IslaEspejismo.esta_presente() else "OCULTA", MODOS_ISLA[_modo_isla()]],
		"BUSCA %04X  EQUIPO %s" % [IslaEspejismo.valor_buscado(), " ".join(equipo) if not equipo.is_empty() else "-"],
		"MT CLUB FAN %s" % ["DADA ESTA SEMANA" if SistemaGuardado.get_flag(EventoCasasOromar.BANDERA_MT_SEMANA) else "DISPONIBLE"],
	])
