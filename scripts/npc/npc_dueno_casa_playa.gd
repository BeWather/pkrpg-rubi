@tool
## npc_dueno_casa_playa.gd
## SR. MARINO, dueño de la CASA de la PLAYA de la RUTA 109 (pokeruby
## Route109_SeashoreHouse_EventScript_160DD4). lock + faceplayer y, por orden:
## 1. FLAG_RECEIVED_6_SODA_POP: vende REFRESCO (SÍ/NO, `precio`, sin dinero → aviso).
## 2. Los tres ENTRENADORES vencidos (FLAG_DEFEATED_SEASHORE_HOUSE_TRAINERS): regala
##    `cantidad_regalo` REFRESCOS y activa la bandera; con la mochila llena avisa y
##    no la activa, para volver a intentarlo.
## 3. FLAG_TEMP_2 activa: texto breve; si no, presentación y la activa.
## La bandera de «todos vencidos» no se guarda aparte: se deduce de las banderas
## `<npc_id>_combate` de `entrenadores`, que npc_entrenador.gd activa al ganar.
## Diálogo SÍ/NO y bloqueo del jugador: patrón de npc_dialogo_condicional.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const TEXTO_INI: String = "RUTA109_CASA_DUENO_INI"
const TEXTO_REPITE: String = "RUTA109_CASA_DUENO_REPITE"
const TEXTO_REGALO: String = "RUTA109_CASA_DUENO_REGALO"
const TEXTO_REGALO_LLENA: String = "RUTA109_CASA_DUENO_REGALO_LLENA"
const TEXTO_VENTA: String = "RUTA109_CASA_DUENO_VENTA"
const TEXTO_VENTA_NO: String = "RUTA109_CASA_DUENO_VENTA_NO"
const TEXTO_VENTA_AQUI: String = "RUTA109_CASA_DUENO_VENTA_AQUI"
const TEXTO_VENTA_SIN_DINERO: String = "RUTA109_CASA_DUENO_VENTA_SIN_DINERO"
## Text_TooBadBagIsFull.
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

## `npc_id` de los entrenadores de la casa (TRAINER_DWAYNE, _JOHANNA y _SIMON).
@export var entrenadores: PackedStringArray = []
## Nombre interno del objeto que regala y vende (ITEM_SODA_POP).
@export var objeto: String = "REFRESCO"
@export var cantidad_regalo: int = 6
@export var precio: int = 300
## FLAG_RECEIVED_6_SODA_POP.
@export var bandera_regalo: String = "FLAG_RECEIVED_6_SODA_POP"
## FLAG_TEMP_2: ya se presentó en esta visita.
@export var bandera_temporal: String = "FLAG_TEMP_2"


## goto_if_not_defeated TRAINER_DWAYNE / JOHANNA / SIMON.
func todos_vencidos() -> bool:
	if entrenadores.is_empty():
		return false
	for id: String in entrenadores:
		if not SistemaGuardado.get_flag(id + "_combate"):
			return false
	return true


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
	if SistemaGuardado.get_flag(bandera_regalo):
		await _vender()
	elif todos_vencidos():
		await _regalar()
	else:
		var primera_vez: bool = not SistemaGuardado.get_flag_temporal(bandera_temporal)
		SistemaGuardado.set_flag_temporal(bandera_temporal)
		await _mensaje(TEXTO_INI if primera_vez else TEXTO_REPITE)
	nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


func _regalar() -> void:
	await _mensaje(TEXTO_REGALO)
	if not _dar_objeto(cantidad_regalo):
		await _mensaje(TEXTO_REGALO_LLENA)
		return
	await mostrar_objeto_recibido(objeto)
	SistemaGuardado.set_flag(bandera_regalo, true)


func _vender() -> void:
	if not await _preguntar_si_no(TEXTO_VENTA):
		await _mensaje(TEXTO_VENTA_NO, false)
		return
	if SistemaGuardado.get_dinero_jugador() < precio:
		await _mensaje(TEXTO_VENTA_SIN_DINERO, false)
		return
	if not _dar_objeto(1):
		await _mensaje(TEXTO_MOCHILA_LLENA, false)
		return
	SistemaGuardado.quitar_dinero_jugador(precio)
	await _mensaje(TEXTO_VENTA_AQUI, false)
	await mostrar_objeto_recibido(objeto)


func _dar_objeto(cantidad: int) -> bool:
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(objeto, cantidad)
	return bool(resultado.get("exito", false))


## Escribe un mensaje y espera el botón. `continuar` lo encadena en el cuadro ya
## abierto; tras una pregunta SÍ/NO se abre uno nuevo.
func _mensaje(clave: String, continuar: bool = true) -> void:
	if continuar:
		continuar_dialogo(tr(clave), true, _mensaje_terminado.emit)
	else:
		nodo_administrador.cuadro_dialogo.mostrar(tr(clave), true, false, _mensaje_terminado.emit)
	await _mensaje_terminado
