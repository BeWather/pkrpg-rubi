@tool
extends MapaConfiguracion
class_name HabitacionJugador

@export var casa: int = 1
@export var mapa_decoracion: MapaDecoracionHabitacion
var sistema: SistemaBasesSecretas
var _preparada: bool = false

func preparar_entrada(contexto: Dictionary) -> bool:
	if not contexto.is_empty() or mapa_decoracion == null or mapa_decoracion.casa != casa:
		return false
	if sistema == null:
		sistema = SistemaGuardado.get_bases_secretas()
	var colocaciones: Array[Dictionary] = []
	if casa == HistoriaVillaRaiz.casa_jugador():
		if not sistema.es_compatible():
			return false
		colocaciones = sistema.obtener_colocaciones(&"habitacion")
	if mapa_decoracion.recomponer(colocaciones) != &"exito":
		return false
	_preparada = true
	return true


func obtener_contexto() -> Dictionary:
	return {"contexto": &"habitacion", "casa": casa, "casa_jugador": HistoriaVillaRaiz.casa_jugador()}


func es_vista_previa() -> bool:
	return false


func pc_activo() -> bool:
	var pc: EventoPCCasa = get_node_or_null("Carteles/PCCasa") as EventoPCCasa
	return _preparada and casa == HistoriaVillaRaiz.casa_jugador() and pc != null and pc._activo


func bloquea_menu() -> bool:
	return pc_activo()


func permite_guardar() -> bool:
	return _preparada and not pc_activo()


## El PC doméstico no altera metatiles (no dibujar atlas de bases); solo se vuelve
## a pintar la pantalla encendida (TileAlterno), que recomponer() restablece.
func reaplicar_pc() -> void:
	for tile: Node in find_children("*", "TileAlterno", true, false):
		(tile as TileAlterno).reaplicar()
