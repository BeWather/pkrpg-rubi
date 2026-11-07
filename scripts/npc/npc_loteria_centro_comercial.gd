@tool
## npc_loteria_centro_comercial.gd
## DESPACHO de LOTERÍA POKéMON del CENTRO COMERCIAL de CIUDAD CALAGUA
## (pokeruby `LilycoveCity_DepartmentStore_1F`, objeto 2: BEAUTY en (10,2)).
##
## Guion de Rubí (`..._EventScript_LotteryClerk`): lock + faceplayer;
## `dotimebasedevents` (limpia el FLAG_DAILY_PICKED_LOTTO_TICKET al cambiar de
## día); si ya sacaste el BILLETE hoy, avisa; si no, pregunta si quieres sacarlo
## y, con SÍ, saca el número del SORTEO (`RetrieveLotteryNumber` +
## `BufferLottoTicketNumber`), lo muestra y comprueba si coincide con el ID de
## alguno de tus POKéMON (`PickLotteryCornerTicket`).
##
## La comprobación mira el ID de entrenador (`BasePokemon.entrenador_id`, 5 cifras)
## del equipo (sin HUEVOS) y de las 14 cajas del PC, y cuenta las cifras que
## coinciden empezando por la última (`GetMatchingDigits`). Con 2, 3, 4 o 5 cifras el
## premio es MÁS PP, REPARTIR EXP, MÁX. REVIVIR o MASTER BALL (`sLotteryPrizes`).
## Como en Rubí, el número del sorteo cambia cada día (`SetRandomLotteryNumber`) y,
## si no cabe el premio, queda guardado (`VAR_LOTTERY_PRIZE`) hasta la próxima visita.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const SEGUNDOS_DIA: int = 86400
## Contador con el día en que se sacó el BILLETE (FLAG_DAILY_PICKED_LOTTO_TICKET).
const CONTADOR_DIA: String = "calagua_cc_loteria_dia"
## Contador con el número del SORTEO (`VAR_LOTTERY_RND_L/H`, `ResetLotteryCorner`).
const CONTADOR_NUMERO: String = "calagua_cc_loteria_numero"
## Día en que se sorteó el número guardado (el sorteo cambia cada día).
const CONTADOR_NUMERO_DIA: String = "calagua_cc_loteria_numero_dia"
## Premio sin entregar por falta de sitio (`VAR_LOTTERY_PRIZE`): cifras acertadas (1-4)
## de `PREMIOS`, o 0 si no hay ninguno.
const CONTADOR_PREMIO_PENDIENTE: String = "calagua_cc_loteria_premio_pendiente"

## `sLotteryPrizes`: el premio según las cifras acertadas menos una (2 a 5 cifras).
const PREMIOS: Array[String] = ["MASPP", "REPARTIREXP", "MAXREVIVIR", "MASTERBALL"]
const CIFRAS_ID: int = 5

const TEXTO_PREGUNTA: String = "CALAGUA_CC_LOTERIA_PREGUNTA"
const TEXTO_BILLETE: String = "CALAGUA_CC_LOTERIA_BILLETE"
const TEXTO_NUMERO: String = "CALAGUA_CC_LOTERIA_NUMERO"
const TEXTO_NO_COINCIDE: String = "CALAGUA_CC_LOTERIA_NO_COINCIDE"
const TEXTO_COINCIDE_EQUIPO: String = "CALAGUA_CC_LOTERIA_COINCIDE_EQUIPO"
const TEXTO_COINCIDE_PC: String = "CALAGUA_CC_LOTERIA_COINCIDE_PC"
const TEXTO_PREMIO: String = "CALAGUA_CC_LOTERIA_PREMIO_%d"
const TEXTO_SIN_SITIO: String = "CALAGUA_CC_LOTERIA_SIN_SITIO"
const TEXTO_PREMIO_GUARDADO: String = "CALAGUA_CC_LOTERIA_PREMIO_GUARDADO"
const TEXTO_MAÑANA: String = "CALAGUA_CC_LOTERIA_MAÑANA"
const TEXTO_VUELVE: String = "CALAGUA_CC_LOTERIA_VUELVE"

## Brillo alternativo ya dibujado sobre el notebook de la mesa.
@export var notebook_encendida: NodePath

## Sustituye únicamente el reloj de la consulta en tests (ticks de GBA a 60 Hz).
var esperar_fotogramas_consulta: Callable = Callable()

## Día actual; se puede sustituir en tests.
var proveedor_dia: Callable = dia_local_actual
## Sustituye al sorteo del número (tests): devuelve el número de 5 cifras.
var sorteo_numero: Callable = Callable()


## Días transcurridos según la fecha local del sistema (el RTC de Rubí).
static func dia_local_actual() -> int:
	var local := Time.get_datetime_dict_from_system()
	@warning_ignore("integer_division")
	return int(Time.get_unix_time_from_datetime_dict(local)) / SEGUNDOS_DIA


## El número del SORTEO: 5 cifras con ceros a la izquierda (`SetLotteryNumber`). Se
## vuelve a sortear cuando cambia el día (`SetRandomLotteryNumber`, en `clock.c`).
func numero_sorteo() -> int:
	var contadores: Dictionary = SistemaGuardado.datos_vivos.datos_persistentes.contadores
	var hoy := int(proveedor_dia.call())
	if not contadores.has(CONTADOR_NUMERO) or SistemaGuardado.get_contador(CONTADOR_NUMERO_DIA) != hoy:
		var valor := randi() % 100000 if not sorteo_numero.is_valid() else int(sorteo_numero.call())
		SistemaGuardado.set_contador(CONTADOR_NUMERO, valor)
		SistemaGuardado.set_contador(CONTADOR_NUMERO_DIA, hoy)
	return SistemaGuardado.get_contador(CONTADOR_NUMERO)


## `GetMatchingDigits`: cifras iguales entre el número del sorteo y el ID de 5 cifras,
## empezando por la última y parando en la primera que difiere.
static func cifras_coincidentes(numero: int, id: String) -> int:
	var cifras := str(numero).pad_zeros(CIFRAS_ID)
	var coincidentes := 0
	for i in CIFRAS_ID:
		if cifras[CIFRAS_ID - 1 - i] != id[CIFRAS_ID - 1 - i]:
			break
		coincidentes += 1
	return coincidentes


## `PickLotteryCornerTicket`: recorre el equipo (sin HUEVOS) y las cajas y se queda con
## el POKéMON de mayor premio. Rubí compara las cifras con el premio ya encontrado
## (cifras - 1), no con las cifras, y exige más de una cifra. Devuelve
## {"premio": 0-4 (cifras - 1), "nombre": String, "en_pc": bool}.
func buscar_premio(numero: int) -> Dictionary:
	var resultado := {"premio": 0, "nombre": "", "en_pc": false}
	for pokemon: BasePokemon in SistemaGuardado.get_equipo():
		if pokemon == null or pokemon.huevo:
			continue
		_evaluar_pokemon(pokemon, numero, resultado, false)
	for caja: Array in SistemaGuardado.obtener_cajas_pc():
		for pokemon in caja:
			if pokemon == null or pokemon.huevo:
				continue
			_evaluar_pokemon(pokemon, numero, resultado, true)
	return resultado


func _evaluar_pokemon(pokemon: BasePokemon, numero: int, resultado: Dictionary, en_pc: bool) -> void:
	var cifras := cifras_coincidentes(numero, pokemon.get_entrenador_id_formateado())
	if cifras > int(resultado.premio) and cifras > 1:
		resultado.premio = cifras - 1
		resultado.nombre = pokemon.get_nombre_mostrar()
		resultado.en_pc = en_pc


## true si hoy ya sacaste el BILLETE (FLAG_DAILY_PICKED_LOTTO_TICKET).
func sacado_hoy() -> bool:
	if not SistemaGuardado.datos_vivos.datos_persistentes.contadores.has(CONTADOR_DIA):
		return false
	return SistemaGuardado.get_contador(CONTADOR_DIA) == int(proveedor_dia.call())


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_conversar()


func _conversar() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	if SistemaGuardado.get_contador(CONTADOR_PREMIO_PENDIENTE) != 0:
		await _entregar_premio_guardado()
	elif sacado_hoy():
		await _mensaje(TEXTO_MAÑANA)
	else:
		await _sacar_bilete()
	nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


## Pregunta, saca el BILLETE y lo comprueba.
func _sacar_bilete() -> void:
	if not await _preguntar_si_no(TEXTO_PREGUNTA):
		await _mensaje(TEXTO_VUELVE)
		return
	var numero := numero_sorteo()
	SistemaGuardado.set_contador(CONTADOR_DIA, int(proveedor_dia.call()))
	# message + waitmessage: los puntos incluyen PAUSE 0x39 (57/60 s).
	# Avanza automáticamente al número del billete; aquí no se espera botón.
	await _mensaje(TEXTO_BILLETE, false)
	await _mensaje_con_numero(TEXTO_NUMERO, numero)
	await _consultar_notebook()
	var ganador := buscar_premio(numero)
	if int(ganador.premio) == 0:
		await _mensaje(TEXTO_NO_COINCIDE)
		await _mensaje(TEXTO_VUELVE)
		return
	await _mensaje_con_nombre(TEXTO_COINCIDE_PC if ganador.en_pc else TEXTO_COINCIDE_EQUIPO, ganador.nombre)
	var premio: String = PREMIOS[int(ganador.premio) - 1]
	await _mensaje_con_premio(TEXTO_PREMIO % (int(ganador.premio) + 1), premio)
	await _dar_premio(int(ganador.premio))
	await _mensaje(TEXTO_VUELVE)


## `giveitem` del premio; si no cabe, `VAR_LOTTERY_PRIZE` lo guarda para la próxima visita.
func _dar_premio(premio: int) -> void:
	var objeto: String = PREMIOS[premio - 1]
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(objeto, 1)
	if bool(resultado.get("exito", false)):
		await mostrar_objeto_recibido(objeto)
		SistemaGuardado.set_contador(CONTADOR_PREMIO_PENDIENTE, 0)
	else:
		SistemaGuardado.set_contador(CONTADOR_PREMIO_PENDIENTE, premio)
		await _mensaje(TEXTO_SIN_SITIO)


## `GivePrizeFromEarlier`: el premio que no cupo la vez anterior.
func _entregar_premio_guardado() -> void:
	await _mensaje(TEXTO_PREMIO_GUARDADO)
	var premio := SistemaGuardado.get_contador(CONTADOR_PREMIO_PENDIENTE)
	await _dar_premio(premio)


## LotteryClerk: WalkInPlaceFastestRight (4 ticks), SE_PC_ON,
## DoLotteryCornerComputerEffect + delay 220, End... + delay 10, FacePlayer.
func _consultar_notebook() -> void:
	var brillo := get_node_or_null(notebook_encendida) as CanvasItem
	if brillo != null:
		brillo.visible = false
	update_direction(Vector2.RIGHT)
	# Un único paso en el sitio, sin cambiar posición ni coord_celda.
	animated_sprite.frame = 1
	await _esperar_ticks_consulta(2)
	animated_sprite.frame = 0
	await _esperar_ticks_consulta(2)
	Singleton.play_sound.emit("SE_PC_ON")
	# field_specials.c: contador inicial 0, comprobar == 6 antes de incrementar:
	# los cinco cambios son en ticks 7, 13, 19, 25 y 31. El quinto queda encendido.
	await _esperar_ticks_consulta(7)
	for cambio in range(5):
		if brillo != null:
			brillo.visible = cambio % 2 == 0
		if cambio < 4:
			await _esperar_ticks_consulta(6)
	await _esperar_ticks_consulta(220 - 31)
	if brillo != null:
		brillo.visible = false
	await _esperar_ticks_consulta(10)
	mirar_jugador()


func _esperar_ticks_consulta(ticks: int) -> void:
	if esperar_fotogramas_consulta.is_valid():
		await esperar_fotogramas_consulta.call(ticks)
	else:
		await get_tree().create_timer(ticks / 60.0).timeout


func _mensaje(clave: String, esperar_entrada: bool = true) -> void:
	nodo_administrador.cuadro_dialogo.mostrar(tr(clave), esperar_entrada, false, _mensaje_terminado.emit)
	await _mensaje_terminado


## Mensaje con el POKéMON ganador en {nombre}.
func _mensaje_con_nombre(clave: String, nombre: String) -> void:
	nodo_administrador.cuadro_dialogo.mostrar(tr(clave).replace("{nombre}", nombre), true, false,
			_mensaje_terminado.emit)
	await _mensaje_terminado


## Mensaje con el nombre del objeto del premio en {premio}.
func _mensaje_con_premio(clave: String, objeto: String) -> void:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(objeto)
	nodo_administrador.cuadro_dialogo.mostrar(tr(clave).replace("{premio}", str(datos.get("nombre", objeto))),
			true, false, _mensaje_terminado.emit)
	await _mensaje_terminado


## Mensaje con el número del SORTEO en {numero}.
func _mensaje_con_numero(clave: String, numero: int) -> void:
	var texto := tr(clave).replace("{numero}", str(numero).pad_zeros(5))
	nodo_administrador.cuadro_dialogo.mostrar(texto, true, false, _mensaje_terminado.emit)
	await _mensaje_terminado
