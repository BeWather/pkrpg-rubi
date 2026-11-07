@tool
extends "res://escenas/mapas/signpost.gd"

## Cartel de la CASA TRETA (Route110, bg_event (8,67)) con menú debug: con
## `AdministradorMapa.iniciar_debug` (solo en builds de depuración, ver `debug_activo()`)
## abre un menú para forzar el estado de la casa, como el depurador de Rubí
## (`tomomichi_debug_menu.c`: ROOMS_COMPLETED y ENTRANCE_STATE_3); sin ella es un cartel
## normal con RUTA110_09_CASA_TRETA. Mismo patrón que el cartel de la guardería.
##
## Las escrituras las hace `HistoriaCasaTreta` y dejan un estado coherente: no hace falta
## recargar nada, basta con entrar de nuevo en la casa (las OnTransition se evalúan al
## cargar la escena).

const MenuDebugLista = preload("res://UI/menu_debug_lista.gd")
const MOTIVO_PAUSA: StringName = &"debug_casa_treta"
const ESCENA_CASA: String = "ruta_110_casa_treta"

const NOMBRES_MAESTRO: PackedStringArray = [
	"ESCONDIDO", "EN ACERTIJO", "PREMIO PEND.", "PENSANDO", "FINALIZADO", "REGRESO", "TIENDA PEND.",
]

const OPCIONES_PRINCIPAL: PackedStringArray = [
	"NIVEL (SALAS HECHAS)",
	"ESTADO DEL MAESTRO",
	"PREMIO PENDIENTE SI/NO",
	"OTROS",
	"REINICIAR CASA TRETA",
	"LEER CARTEL",
]
## Cancelar (B) vuelve al menú anterior o cierra el principal. Ninguna lista pasa de 6
## opciones: con las dos líneas de cabecera, 7 no caben en los 160 px de la pantalla.
## El nivel va en dos pantallas: 0-4 y «MAS...», y 5-8.
const OPCIONES_NIVEL_A: PackedStringArray = ["0", "1", "2", "3", "4", "MAS (5-8)..."]
const OPCIONES_NIVEL_B: PackedStringArray = ["5", "6", "7", "8"]
## Cada una escribe el conjunto coherente de variables (HistoriaCasaTreta.forzar_estado_maestro).
const OPCIONES_MAESTRO: PackedStringArray = [
	"ESCONDIDO", "EN ACERTIJO", "PREMIO PENDIENTE", "PENSANDO", "TERMINADO (NOTA)", "TIENDA PENDIENTE",
]
## Estado de ENTRANCE_STATE_3 de cada opción de OPCIONES_MAESTRO.
const ESTADOS_MAESTRO: Array[int] = [0, 1, 2, 3, 4, 6]
const OPCIONES_OTROS: PackedStringArray = [
	"REARMAR PISTA",
	"APAGAR PISTA",
	"SIMULAR HALLAZGO",
	"SIMULAR REGRESO PASILLO",
	"IGNORAR MEDALLAS SI/NO",
	"PRUEBAS...",
]
const OPCIONES_PRUEBAS: PackedStringArray = [
	"LEER PERGAMINO SIGUIENTE",
	"ABRIR PUERTA SIGUIENTE",
	"LEER Y ABRIR LAS 8",
	"REINICIAR LAS 8 + CARTAS",
	"IR AL FINAL",
]

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
				await _submenu_nivel(admin)
			1:
				await _submenu_maestro(admin)
			2:
				aplicar(&"premio", 0 if HistoriaCasaTreta.premio_pendiente() else 1)
			3:
				await _submenu_otros(admin)
			4:
				aplicar(&"reiniciar")
			5:
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


func _submenu_nivel(admin: Node) -> void:
	var opcion: int = await _elegir(admin, OPCIONES_NIVEL_A, cabecera(),
			mini(HistoriaCasaTreta.salas_completadas(), OPCIONES_NIVEL_A.size() - 1))
	if opcion < 0:
		return
	if opcion < OPCIONES_NIVEL_A.size() - 1:
		aplicar(&"nivel", opcion)
		return
	opcion = await _elegir(admin, OPCIONES_NIVEL_B, cabecera())
	if opcion >= 0:
		aplicar(&"nivel", OPCIONES_NIVEL_A.size() - 1 + opcion)


func _submenu_maestro(admin: Node) -> void:
	var opcion: int = await _elegir(admin, OPCIONES_MAESTRO, cabecera())
	if opcion >= 0 and opcion < ESTADOS_MAESTRO.size():
		aplicar(&"maestro", ESTADOS_MAESTRO[opcion])


func _submenu_otros(admin: Node) -> void:
	while true:
		var opcion: int = await _elegir(admin, OPCIONES_OTROS, cabecera())
		match opcion:
			0:
				aplicar(&"rearmar")
			1:
				aplicar(&"apagar")
			2:
				aplicar(&"hallazgo")
			3:
				aplicar(&"regreso")
			4:
				aplicar(&"ignorar_requisitos", 0 if HistoriaCasaTreta.ignora_requisitos() else 1)
			5:
				await _submenu_pruebas(admin)
			_:
				return


func _submenu_pruebas(admin: Node) -> void:
	while true:
		var opcion: int = await _elegir(admin, OPCIONES_PRUEBAS, cabecera_pruebas())
		match opcion:
			0:
				aplicar(&"leer_pergamino")
			1:
				aplicar(&"abrir_puerta")
			2:
				aplicar(&"abrir_todas")
			3:
				aplicar(&"reiniciar_pruebas")
			4:
				aplicar(&"ir_al_final", 0, admin)
				return
			_:
				return


## Escribe en `HistoriaCasaTreta` lo que pide una opción del menú. Estático para poder
## probarlo sin menú. `valor` es el nivel/estado o 0/1 en las alternancias.
static func aplicar(accion: StringName, valor: int = 0, admin: Node = null) -> void:
	match accion:
		&"nivel":
			HistoriaCasaTreta.forzar_nivel(valor)
		&"maestro":
			HistoriaCasaTreta.forzar_estado_maestro(valor)
		&"premio":
			HistoriaCasaTreta.forzar_premio_pendiente(valor != 0)
		&"rearmar":
			HistoriaCasaTreta.fijar_observado(true)
		&"apagar":
			HistoriaCasaTreta.fijar_observado(false)
		&"hallazgo":
			HistoriaCasaTreta.simular_hallazgo()
		&"regreso":
			HistoriaCasaTreta.simular_regreso_pasillo()
		&"ignorar_requisitos":
			SistemaGuardado.set_flag(HistoriaCasaTreta.BANDERA_IGNORAR_REQUISITOS, valor != 0)
		&"leer_pergamino":
			HistoriaCasaTreta.leer_pergamino(HistoriaCasaTreta.prueba_siguiente())
		&"abrir_puerta":
			var numero := HistoriaCasaTreta.prueba_siguiente()
			HistoriaCasaTreta.leer_pergamino(numero)
			HistoriaCasaTreta.abrir_puerta(numero)
		&"abrir_todas":
			for numero in range(1, HistoriaCasaTreta.PRUEBAS + 1):
				HistoriaCasaTreta.leer_pergamino(numero)
				HistoriaCasaTreta.abrir_puerta(numero)
		&"reiniciar_pruebas":
			HistoriaCasaTreta.reiniciar_pruebas()
			HistoriaCasaTreta.reiniciar_cartas()
		&"reiniciar":
			HistoriaCasaTreta.restablecer()
		&"ir_al_final":
			# Como al salir de una prueba por su puerta: llega a (29,1) y da un paso al sur.
			if admin != null and admin.has_method("conectar_escalera"):
				admin.conectar_escalera(ESCENA_CASA, Vector2(HistoriaCasaTreta.CELDA_PUERTA_FINAL),
						Vector2.DOWN, true)


## Valores actuales (dos líneas sobre las opciones).
static func cabecera() -> PackedStringArray:
	var estado := HistoriaCasaTreta.estado_maestro()
	return PackedStringArray([
		"SALAS %d/8  MAESTRO %s" % [HistoriaCasaTreta.salas_completadas(), NOMBRES_MAESTRO[estado]],
		"OBS %d RETO %d PAS %d PREMIO %s MED %s" % [
			HistoriaCasaTreta.entrada_observada(),
			1 if HistoriaCasaTreta.reto_pendiente() else 0,
			1 if HistoriaCasaTreta.vuelta_pasillo() else 0,
			"SI" if HistoriaCasaTreta.premio_pendiente() else "NO",
			"IGN" if HistoriaCasaTreta.ignora_requisitos() else "OK" if HistoriaCasaTreta.requisito_cumplido() else "NO"],
	])


## Estado de las 8 pruebas y cartas recogidas.
static func cabecera_pruebas() -> PackedStringArray:
	var estados: PackedStringArray = []
	for numero in range(1, HistoriaCasaTreta.PRUEBAS + 1):
		estados.append(str(HistoriaCasaTreta.estado_prueba(numero)))
	var cartas := 0
	for id_item in HistoriaCasaTreta.IDS_CARTAS:
		if SistemaGuardado.get_flag("item_" + id_item):
			cartas += 1
	return PackedStringArray([
		"PRUEBAS (0/1/2) %s" % " ".join(estados),
		"CARTAS %d/%d  SIGUIENTE %d" % [cartas, HistoriaCasaTreta.IDS_CARTAS.size(), HistoriaCasaTreta.prueba_siguiente()],
	])
