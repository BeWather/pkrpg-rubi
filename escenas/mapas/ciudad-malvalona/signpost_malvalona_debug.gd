@tool
extends "res://escenas/mapas/signpost.gd"

## Cartel del GIMNASIO de CIUDAD MALVALONA (MauvilleCity bg_event (11,6)) con menú debug:
## con `AdministradorMapa.iniciar_debug` (solo en builds de depuración, ver
## `debug_activo()`) abre un menú para forzar el estado de los interiores de la ciudad
## (puzle del GIMNASIO, ERICO, MEDALLA DINAMO, CASINO, BICICLETERÍA y regalos de las
## casas); sin ella es un cartel normal con MALVALONA_GIM. Mismo patrón que el cartel de
## la CASA TRETA.
##
## Las escrituras de estado las hacen HistoriaMalvalona / HistoriaGimnasioMalvalona /
## MonederoFichas y dejan un estado coherente: no hace falta recargar nada, basta con
## entrar de nuevo en el edificio (las escenas se instancian en cada warp). El puzle se
## reinicia al entrar al GIMNASIO: «forzar» deja el estado pedido para la próxima entrada.

const MenuDebugLista = preload("res://UI/menu_debug_lista.gd")
const MOTIVO_PAUSA: StringName = &"debug_malvalona"

const OPCIONES_PRINCIPAL: PackedStringArray = [
	"GIMNASIO...",
	"ERICO...",
	"MEDALLA DINAMO SI/NO",
	"CASINO...",
	"BICI Y CASAS...",
	"LEER CARTEL",
]
## Ninguna lista pasa de 6 opciones: con las dos líneas de cabecera no caben más en los
## 160 px de la pantalla.
const OPCIONES_GIMNASIO: PackedStringArray = [
	"BARRERAS A/B",
	"INTERRUPTOR 0-3",
	"VENCER A LOS 4",
	"REINICIAR A LOS 4",
	"REINICIAR PUZLE",
	"DESACTIVAR (D)",
]
const OPCIONES_ERICO: PackedStringArray = [
	"EN GIMNASIO",
	"EN CIUDAD (NORMAN)",
	"MT24 RECIBIDA",
	"MALVALANOVA HECHA",
	"REINICIAR MT34",
	"LLAVE SOTANO SI/NO",
]
const OPCIONES_CASINO: PackedStringArray = [
	"DAR MONEDERO",
	"FICHAS 0",
	"FICHAS 50",
	"FICHAS 9999",
	"DINERO 100000",
	"REINICIAR REGALOS",
]
const OPCIONES_BICI: PackedStringArray = [
	"REINICIAR ELECCION",
	"QUITAR BICIS",
	"REINICIAR MO06",
	"REINICIAR MONEDERO",
	"DAR CARTA PUERTO",
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
				await _submenu(admin, OPCIONES_GIMNASIO, &"gimnasio")
			1:
				await _submenu(admin, OPCIONES_ERICO, &"erico")
			2:
				aplicar(&"medalla", 0 if SistemaGuardado.tiene_medalla(HistoriaGimnasioMalvalona.INDICE_MEDALLA) else 1)
			3:
				await _submenu(admin, OPCIONES_CASINO, &"casino")
			4:
				await _submenu(admin, OPCIONES_BICI, &"bici")
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


## Submenú: cada opción es `grupo` + índice para `aplicar`; B vuelve.
func _submenu(admin: Node, opciones: PackedStringArray, grupo: StringName) -> void:
	while true:
		var opcion: int = await _elegir(admin, opciones, cabecera())
		if opcion < 0 or opcion >= opciones.size():
			return
		aplicar(StringName("%s_%d" % [grupo, opcion]))


## Escribe el estado que pide una opción del menú. Estático para poder probarlo sin menú.
## `valor` es 0/1 en las alternancias.
static func aplicar(accion: StringName, valor: int = 0) -> void:
	match accion:
		# GIMNASIO...
		&"gimnasio_0":  # BARRERAS A/B
			var pendiente := HistoriaGimnasioMalvalona.pendiente()
			HistoriaGimnasioMalvalona.forzar(not bool(pendiente[0]), int(pendiente[1]))
		&"gimnasio_1":  # INTERRUPTOR 0..3 (cicla)
			var pendiente := HistoriaGimnasioMalvalona.pendiente()
			HistoriaGimnasioMalvalona.forzar(bool(pendiente[0]), (int(pendiente[1]) + 1) % (HistoriaGimnasioMalvalona.INTERRUPTORES + 1))
		&"gimnasio_2":
			EventoGimnasioMalvalona.marcar_entrenadores_vencidos()
		&"gimnasio_3":
			for id_npc in EventoGimnasioMalvalona.ENTRENADORES:
				SistemaGuardado.set_flag(id_npc + "_combate", false)
		&"gimnasio_4":
			HistoriaGimnasioMalvalona.descartar_forzado()
			HistoriaGimnasioMalvalona.reiniciar()
		&"gimnasio_5":  # DESACTIVAR (D): el puzle está apagado con la MEDALLA DINAMO
			EventoGimnasioPetalia.dar_medalla(HistoriaGimnasioMalvalona.INDICE_MEDALLA)
			EventoGimnasioMalvalona.marcar_entrenadores_vencidos()
		&"medalla":
			_poner_medalla(valor != 0)
		# ERICO...
		&"erico_0":
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_ERICO_FUERA, false)
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MT_RAYO, false)
		&"erico_1":
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_ERICO_FUERA, true)
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MT_RAYO, false)
		&"erico_2":
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_ERICO_FUERA, true)
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_NUEVA_MALVALONA, true)
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_LLAVE_SOTANO, true)
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MT_RAYO, true)
		&"erico_3":
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_LLAVE_SOTANO, true)
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_NUEVA_MALVALONA, true)
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MT_RAYO, false)
		&"erico_4":
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MT34, false)
		&"erico_5":
			var con := SistemaGuardado.get_flag(HistoriaMalvalona.BANDERA_LLAVE_SOTANO)
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_LLAVE_SOTANO, not con)
			if con:
				SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_NUEVA_MALVALONA, false)
		# CASINO...
		&"casino_0":
			if not HistoriaMalvalona.tiene(HistoriaMalvalona.OBJETO_MONEDERO):
				SistemaGuardado.dar_objeto_jugador(HistoriaMalvalona.OBJETO_MONEDERO)
		&"casino_1":
			MonederoFichas.establecer(0)
		&"casino_2":
			MonederoFichas.establecer(50)
		&"casino_3":
			MonederoFichas.establecer(MonederoFichas.MAXIMO)
		&"casino_4":
			SistemaGuardado.dar_dinero_jugador(100000)
		&"casino_5":
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MUNECO_INICIAL, false)
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_20_FICHAS, false)
		# BICI Y CASAS...
		&"bici_0":  # REINICIAR ELECCION: Rydel vuelve a ofrecer una BICI
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_BICI_RECIBIDA, false)
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_BICI_RECHAZADA, false)
			_quitar_bicis()
		&"bici_1":
			_quitar_bicis()
		&"bici_2":
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MO06, false)
		&"bici_3":
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MONEDERO, false)
			while HistoriaMalvalona.tiene(HistoriaMalvalona.OBJETO_MONEDERO):
				HistoriaMalvalona.quitar(HistoriaMalvalona.OBJETO_MONEDERO)
		&"bici_4":
			SistemaGuardado.dar_objeto_jugador(HistoriaMalvalona.OBJETO_CARTA_PUERTO)


static func _poner_medalla(activa: bool) -> void:
	var medallas: Array = SistemaGuardado.datos_vivos.jugador.get("medallas", [])
	while medallas.size() < 8:
		medallas.append(false)
	medallas[HistoriaGimnasioMalvalona.INDICE_MEDALLA] = activa
	SistemaGuardado.datos_vivos.jugador["medallas"] = medallas


static func _quitar_bicis() -> void:
	for objeto in [HistoriaMalvalona.OBJETO_BICI_CARRERA, HistoriaMalvalona.OBJETO_BICI_ACROBATICA]:
		while HistoriaMalvalona.tiene(objeto):
			HistoriaMalvalona.quitar(objeto)


## Valores actuales (dos líneas sobre las opciones).
static func cabecera() -> PackedStringArray:
	var pendiente := HistoriaGimnasioMalvalona.pendiente()
	var vencidos := 0
	for id_npc in EventoGimnasioMalvalona.ENTRENADORES:
		if SistemaGuardado.get_flag(id_npc + "_combate"):
			vencidos += 1
	var bici := "NO"
	if HistoriaMalvalona.tiene(HistoriaMalvalona.OBJETO_BICI_CARRERA):
		bici = "CARRERA"
	elif HistoriaMalvalona.tiene(HistoriaMalvalona.OBJETO_BICI_ACROBATICA):
		bici = "ACROBAT"
	return PackedStringArray([
		"PUZLE %s INT %d MED %s 4ENT %d" % [
			"B" if pendiente[0] else "A", pendiente[1],
			"SI" if SistemaGuardado.tiene_medalla(HistoriaGimnasioMalvalona.INDICE_MEDALLA) else "NO", vencidos],
		"FICHAS %d MON %s BICI %s ERICO %s" % [
			MonederoFichas.fichas(), "SI" if HistoriaMalvalona.tiene(HistoriaMalvalona.OBJETO_MONEDERO) else "NO", bici,
			"GIM" if HistoriaGimnasioMalvalona.erico_en_gimnasio() else "CIUDAD"],
	])
