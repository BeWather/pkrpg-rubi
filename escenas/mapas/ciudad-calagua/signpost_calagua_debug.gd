@tool
extends "res://escenas/mapas/signpost.gd"

## Cartel de la CIUDAD (LilycoveCity bg_event 5, (6,15)) de CIUDAD CALAGUA con menú debug: con
## `AdministradorMapa.iniciar_debug` (solo en builds de depuración, ver `debug_activo()`) abre un
## menú para activar o desactivar las banderas de evento más importantes de la ciudad y de la
## guarida del EQUIPO (la entrada de la guarida, el WAILMER, los soldados, el rival...); sin ella es
## un cartel normal con CALAGUA_CARTEL_CIUDAD. Mismo patrón que los carteles de MALVALONA y de la
## CASA TRETA.
##
## Tras cada cambio se reaplica el estado del mapa abierto (`EventoCiudadCalagua.aplicar_estado`:
## WAILMER, roca de la guarida y su bloqueo de paso; y `aplicar_bandera_ocultar` de los NPC), así
## que se ve al instante. Las escenas de la guarida se instancian en cada warp: basta con volver a
## entrar.

const MenuDebugLista = preload("res://UI/menu_debug_lista.gd")
const MOTIVO_PAUSA: StringName = &"debug_calagua"
## MEDALLA 7 (FLAG_BADGE07_GET): índice en `jugador.medallas`.
const INDICE_MEDALLA_7: int = 6

## Ninguna lista pasa de 6 opciones: con las dos líneas de cabecera no caben más en los 160 px de
## la pantalla.
const OPCIONES_PRINCIPAL: PackedStringArray = [
	"GUARIDA...",
	"CIUDAD...",
	"MEDALLA 7 SI/NO",
	"LEER CARTEL",
]
const OPCIONES_GUARIDA: PackedStringArray = [
	"SOLDADOS 1F SI/NO",
	"ORBE ROBADO SI/NO",
	"EQUIPO ESCAPO SI/NO",
	"REINICIAR ENTRENADORES",
	"REINICIAR ELECTRODE",
	"TODO A CERO",
]
const OPCIONES_CIUDAD: PackedStringArray = [
	"SOLDADOS CIUDAD SI/NO",
	"WAILMER 1a VEZ",
	"REINICIAR RIVAL",
	"JUEGO COMPLETO SI/NO",
	"REINICIAR BAYA DIARIA",
]

## `npc_id` de los entrenadores de la guarida (la bandera de combate es `<npc_id>_combate`).
const ENTRENADORES_GUARIDA: PackedStringArray = [
	"guarida_1f_soldado", "guarida_b1f_soldado1", "guarida_b1f_soldado2", "guarida_b1f_soldada",
	"guarida_b2f_tatiano", "guarida_b2f_soldado2", "guarida_b2f_soldada",
]
const BANDERA_RIVAL_CONOCIDO: String = "calagua_rival_conocido"
const BANDERA_RIVAL_RECHAZADO: String = "calagua_rival_rechazado"
const BANDERA_JUEGO_COMPLETO: String = "SYS_GAME_CLEAR"
const CONTADOR_BAYA_DIARIA: String = "calagua_baya_diaria_dia"

## Se emite al leer el texto normal (sin debug o con LEER CARTEL).
signal texto_normal_mostrado

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## (opciones, cabecera) -> índice elegido, o -1. Sustituye al menú en pantalla (tests).
var selector: Callable = Callable()
## No muestra el texto normal del cartel, solo emite `texto_normal_mostrado` (tests).
var omitir_texto: bool = false


func accionar_cartel() -> void:
	var admin := _administrador()
	if admin == null or not admin.has_method("debug_activo") or not admin.debug_activo() \
			or (not selector.is_valid() and admin.get_node_or_null("Menu") == null):
		_leer_cartel()
		return
	await _menu_debug(admin)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _leer_cartel() -> void:
	texto_normal_mostrado.emit()
	if not omitir_texto:
		super.accionar_cartel()


func _menu_debug(admin: Node) -> void:
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	var leer_cartel := false
	while true:
		var opcion: int = await _elegir(admin, OPCIONES_PRINCIPAL, cabecera())
		match opcion:
			0:
				await _submenu(admin, OPCIONES_GUARIDA, &"guarida")
			1:
				await _submenu(admin, OPCIONES_CIUDAD, &"ciudad")
			2:
				aplicar(&"medalla", 0 if SistemaGuardado.tiene_medalla(INDICE_MEDALLA_7) else 1)
				refrescar_mapa()
			3:
				leer_cartel = true
				break
			_:
				break
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	if is_instance_valid(admin.get("jugador")):
		admin.jugador.no_control = false
	if leer_cartel:
		_leer_cartel()


func _elegir(admin: Node, opciones: PackedStringArray, cabecera_menu: PackedStringArray, inicial: int = 0) -> int:
	if selector.is_valid():
		return await selector.call(opciones, cabecera_menu)
	return await MenuDebugLista.elegir(admin.get_node("Menu"), opciones, cabecera_menu, inicial)


## Submenú: cada opción es `grupo` + índice para `aplicar`; B vuelve.
func _submenu(admin: Node, opciones: PackedStringArray, grupo: StringName) -> void:
	var inicial: int = 0
	while true:
		var opcion: int = await _elegir(admin, opciones, cabecera(), inicial)
		if opcion < 0 or opcion >= opciones.size():
			return
		inicial = opcion
		aplicar(StringName("%s_%d" % [grupo, opcion]))
		refrescar_mapa()


## Vuelve a aplicar lo que depende de las banderas en el mapa abierto: los WAILMER y la roca de
## la guarida (visibilidad y bloqueo de paso) y los NPC con `bandera_ocultar` / `bandera_mostrar`.
func refrescar_mapa() -> void:
	var mapa: Node = owner if owner != null else get_parent().get_parent()
	if mapa == null:
		return
	for evento in mapa.find_children("*", "", true, false):
		if evento is EventoCiudadCalagua:
			evento.aplicar_estado()
	var npcs := mapa.get_node_or_null("NPCs")
	if npcs == null:
		return
	for npc in npcs.get_children():
		if npc.has_method("aplicar_bandera_ocultar"):
			npc.aplicar_bandera_ocultar()


## Escribe el estado que pide una opción del menú. Estático para poder probarlo sin menú.
## `valor` es 0/1 en las alternancias de una sola opción (`medalla`).
static func aplicar(accion: StringName, valor: int = 0) -> void:
	match accion:
		# GUARIDA...
		&"guarida_0":  # los dos soldados que tapan el pasillo de la 1F
			_alternar(HistoriaGuaridaCalagua.BANDERA_BLOQUEO_OCULTO)
		&"guarida_1":  # FLAG_MT_PYRE_ORB_STOLEN
			_alternar(HistoriaGuaridaCalagua.BANDERA_ORBE_ROBADO)
		&"guarida_2":  # la fuga de TATIANO en el submarino: WAILMER fuera, soldados fuera
			var escapo := not SistemaGuardado.get_flag(HistoriaGuaridaCalagua.BANDERA_EQUIPO_ESCAPO)
			SistemaGuardado.set_flag(HistoriaGuaridaCalagua.BANDERA_EQUIPO_ESCAPO, escapo)
			SistemaGuardado.set_flag(HistoriaGuaridaCalagua.BANDERA_SOLDADOS_CALAGUA_OCULTOS, escapo)
			SistemaGuardado.set_flag(HistoriaGuaridaCalagua.BANDERA_SUBMARINO_OCULTO, escapo)
		&"guarida_3":  # los siete entrenadores vuelven a combatir
			for id_npc in ENTRENADORES_GUARIDA:
				SistemaGuardado.set_flag(id_npc + "_combate", false)
		&"guarida_4":
			SistemaGuardado.set_flag(HistoriaGuaridaCalagua.BANDERA_ELECTRODE_1_OCULTO, false)
			SistemaGuardado.set_flag(HistoriaGuaridaCalagua.BANDERA_ELECTRODE_2_OCULTO, false)
		&"guarida_5":  # la partida antes de pisar la guarida
			HistoriaGuaridaCalagua.restablecer()
			for id_npc in ENTRENADORES_GUARIDA:
				SistemaGuardado.set_flag(id_npc + "_combate", false)
		# CIUDAD...
		&"ciudad_0":
			_alternar(HistoriaGuaridaCalagua.BANDERA_SOLDADOS_CALAGUA_OCULTOS)
		&"ciudad_1":
			SistemaGuardado.set_flag(EventoCiudadCalagua.BANDERA_ENTRENADOR_CONOCIDO, false)
		&"ciudad_2":
			SistemaGuardado.set_flag(BANDERA_RIVAL_CONOCIDO, false)
			SistemaGuardado.set_flag(BANDERA_RIVAL_RECHAZADO, false)
		&"ciudad_3":
			_alternar(BANDERA_JUEGO_COMPLETO)
		&"ciudad_4":
			SistemaGuardado.datos_vivos.datos_persistentes.contadores.erase(CONTADOR_BAYA_DIARIA)
		&"medalla":
			_poner_medalla(valor != 0)


static func _alternar(bandera: String) -> void:
	SistemaGuardado.set_flag(bandera, not SistemaGuardado.get_flag(bandera))


static func _poner_medalla(activa: bool) -> void:
	var medallas: Array = SistemaGuardado.datos_vivos.jugador.get("medallas", [])
	while medallas.size() < 8:
		medallas.append(false)
	medallas[INDICE_MEDALLA_7] = activa
	SistemaGuardado.datos_vivos.jugador["medallas"] = medallas


static func _si(valor: bool) -> String:
	return "SI" if valor else "NO"


## Valores actuales (dos líneas sobre las opciones).
static func cabecera() -> PackedStringArray:
	return PackedStringArray([
		"ESCAPO %s MED7 %s ORBE %s BLOQ %s" % [
			_si(SistemaGuardado.get_flag(HistoriaGuaridaCalagua.BANDERA_EQUIPO_ESCAPO)),
			_si(SistemaGuardado.tiene_medalla(INDICE_MEDALLA_7)),
			_si(SistemaGuardado.get_flag(HistoriaGuaridaCalagua.BANDERA_ORBE_ROBADO)),
			_si(not SistemaGuardado.get_flag(HistoriaGuaridaCalagua.BANDERA_BLOQUEO_OCULTO))],
		"SOLD %s RIVAL %s COMPLETO %s" % [
			_si(not SistemaGuardado.get_flag(HistoriaGuaridaCalagua.BANDERA_SOLDADOS_CALAGUA_OCULTOS)),
			_si(not SistemaGuardado.get_flag(BANDERA_RIVAL_CONOCIDO)),
			_si(SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETO))],
	])
