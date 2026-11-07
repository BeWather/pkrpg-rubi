## evento_cascada_meteoro.gd
## Guion de la CASCADA METEORO, planta baja 1 (pokeruby data/maps/MeteorFalls_1F_1R/scripts.inc,
## MeteorFalls_1F_1R_EventScript_15C49C). Las celdas de la escena son las de Rubí.
##
## Al pisar (14,18) con VAR_METEOR_FALLS_STATE == 0 (coord_event): dos soldados MAGMA (objetos 5
## y 6) con el METEORITO ven al jugador, llega el EQUIPO AQUA (AQUILES con dos de los suyos,
## objetos 7, 8 y 9), los MAGMA se escapan hacia el este y AQUILES se presenta y los persigue.
## Al final se ocultan los soldados, se activa FLAG_HIDE_GRUNTS_BLOCKING_CABLE_CAR (los soldados
## que cortan el TELEFÉRICO en la RUTA 112) y VAR_METEOR_FALLS_STATE pasa a 1.
##
## El gráfico de los MAGMA/AQUA es el de Rubí (Common_EventScript_SetupEvilTeamGfxIds: VAR_1 =
## MAGMA_MEMBER_M, VAR_4 = AQUA_MEMBER_M, VAR_7 = ARCHIE); los tres del EQUIPO AQUA están ocultos
## (FLAG_HIDE_OTHER_TEAM_METEOR_FALLS_1F) hasta el addobject.
extends EventoGuionizado
class_name EventoCascadaMeteoro

const MOTIVO_PAUSA: StringName = &"cascada_meteoro"
## playse SE_PIN.
const SONIDO_EXCLAMACION: String = "SE_PIN"

const TEXTO_MAGMA_METEORITO: String = "CASCADA_METEORO_MAGMA_METEORITO"
const TEXTO_MAGMA_ENTROMETES: String = "CASCADA_METEORO_MAGMA_ENTROMETES"
const TEXTO_AQUA_ALTO: String = "CASCADA_METEORO_AQUA_ALTO"
const TEXTO_MAGMA_ADIOS: String = "CASCADA_METEORO_MAGMA_ADIOS"
const TEXTO_AQUILES_PRESENTACION: String = "CASCADA_METEORO_AQUILES_PRESENTACION"
const TEXTO_AQUA_PERSEGUIR: String = "CASCADA_METEORO_AQUA_PERSEGUIR"
const TEXTO_AQUILES_SI: String = "CASCADA_METEORO_AQUILES_SI"
const TEXTO_AQUILES_ADIOS: String = "CASCADA_METEORO_AQUILES_ADIOS"

## Celdas de map.json (object_events 5 a 9) y del coord_event.
const CELDA_DISPARADOR := Vector2i(14, 18)
const CELDA_MAGMA_A := Vector2i(12, 20)
const CELDA_MAGMA_B := Vector2i(14, 21)
const CELDA_AQUILES := Vector2i(6, 20)
const CELDA_AQUA_A := Vector2i(6, 20)
const CELDA_AQUA_B := Vector2i(6, 21)

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## Movimientos de MeteorFalls_1F_1R_Movement_* (los repetidos se arman con _repetir).
## 15C5EE: el primer MAGMA se acerca.
const MAGMA_A_SE_ACERCA: Array = [R, R]
## 15C608 / 15C60F / 15C617: el EQUIPO AQUA entra desde la izquierda (los dos últimos tras delay_16 x2).
const AQUILES_ENTRA_ANDANDO: int = 6
const AQUA_ENTRA_ANDANDO: int = 5
const FOTOGRAMAS_ESPERA_AQUA: int = 32
## 15C628: AQUILES sube hasta el jugador y lo mira.
const AQUILES_SE_ACERCA: Array = [R, R, U, U]
## 15C639 / 15C64A: los dos del EQUIPO AQUA se colocan detrás de AQUILES, mirando al norte.
const AQUA_SE_COLOCA: Array = [R, R, R]
## 15C5F1 (walk_fast): el primer MAGMA sube y se va corriendo hacia el este; 15C5FC lo mismo con tres pasos.
const MAGMA_A_HUYE: Array = [U, U]
const MAGMA_B_HUYE: Array = [U, U, U]
const HUIDA_ESTE: int = 8

@export var magma_a: NodePath
@export var magma_b: NodePath
@export var aquiles: NodePath
@export var aqua_a: NodePath
@export var aqua_b: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _on_disparador(id_evento: StringName) -> void:
	if id_evento == &"equipos" and not _en_curso and HistoriaCascadaMeteoro.escena_pendiente():
		escena_equipos()


## MeteorFalls_1F_1R_EventScript_15C49C.
func escena_equipos() -> void:
	var soldado_a := _npc(magma_a)
	var soldado_b := _npc(magma_b)
	var jefe := _npc(aquiles)
	var aqua_1 := _npc(aqua_a)
	var aqua_2 := _npc(aqua_b)
	if soldado_a == null or soldado_b == null or jefe == null or aqua_1 == null or aqua_2 == null:
		push_warning("[CascadaMeteoro] Faltan actores del guion")
		return
	if not comenzar(_administrador()):
		return
	# El jugador se detiene mirando al sur; el primer MAGMA (que ya miraba abajo) habla.
	girar_jugador(D)
	await esperar_fotogramas(30)
	mirar(soldado_a, D)
	await mensaje(TEXTO_MAGMA_METEORITO)
	# Los dos MAGMA se vuelven; el primero se asusta (SE_PIN + "!") y espera 48 fotogramas.
	mirar(soldado_a, U)
	mirar(soldado_b, U)
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)
	await exclamacion(soldado_a)
	await esperar_fotogramas(48)
	await mensaje(TEXTO_MAGMA_ENTROMETES)
	await recorrer(soldado_a, MAGMA_A_SE_ACERCA)
	# Una voz (el EQUIPO AQUA, aún fuera de plano) les planta cara.
	await mensaje(TEXTO_AQUA_ALTO)
	girar_jugador(L)
	mirar(soldado_a, L)
	mirar(soldado_b, L)
	# addobject 7, 8 y 9: el EQUIPO AQUA entra andando desde la izquierda.
	_aparecer(jefe, CELDA_AQUILES, R)
	_aparecer(aqua_1, CELDA_AQUA_A, R)
	_aparecer(aqua_2, CELDA_AQUA_B, R)
	await en_paralelo([
		recorrer.bind(jefe, _repetir(R, AQUILES_ENTRA_ANDANDO)),
		_entra_aqua.bind(aqua_1),
		_entra_aqua.bind(aqua_2),
	])
	mirar(soldado_a, L)
	mirar(soldado_b, L)
	await mensaje(TEXTO_MAGMA_ADIOS)
	# Los MAGMA echan a correr hacia el este (el jugador retrocede un paso, de cara a ellos).
	await en_paralelo([
		_jugador_empujado,
		recorrer.bind(soldado_a, MAGMA_A_HUYE + _repetir(R, HUIDA_ESTE), VelocidadPaso.RAPIDO),
		recorrer.bind(soldado_b, MAGMA_B_HUYE + _repetir(R, HUIDA_ESTE), VelocidadPaso.RAPIDO),
	])
	soldado_a.visible = false  # removeobject 5
	soldado_b.visible = false  # removeobject 6
	await recorrer(jefe, AQUILES_SE_ACERCA)
	mirar(jefe, L)
	await mensaje(TEXTO_AQUILES_PRESENTACION)
	await en_paralelo([_ponerse_detras.bind(aqua_1), _ponerse_detras.bind(aqua_2)])
	await mensaje(TEXTO_AQUA_PERSEGUIR, false)
	mirar(jefe, D)
	await mensaje(TEXTO_AQUILES_SI)
	mirar(jefe, L)
	await mensaje(TEXTO_AQUILES_ADIOS)
	# El EQUIPO AQUA sale detrás de los MAGMA (15C61F, 15C62E y 15C63E).
	await en_paralelo([
		recorrer.bind(jefe, _repetir(R, HUIDA_ESTE)),
		recorrer.bind(aqua_1, [U, U] + _repetir(R, HUIDA_ESTE)),
		recorrer.bind(aqua_2, [U, U, U] + _repetir(R, HUIDA_ESTE)),
	])
	jefe.visible = false  # removeobject 7, 8 y 9
	aqua_1.visible = false
	aqua_2.visible = false
	HistoriaCascadaMeteoro.marcar_equipo_fuera()
	terminar(false, [soldado_a, soldado_b, jefe, aqua_1, aqua_2])


## addobject: el actor aparece en su celda de map.json mirando hacia donde irá.
func _aparecer(npc: Node2D, celda: Vector2i, direccion: Vector2) -> void:
	colocar(npc, celda)
	npc.update_direction(direccion)
	npc.visible = true


## 15C60F / 15C617: delay_16 x2 y cinco pasos a la derecha.
func _entra_aqua(npc: Node2D) -> void:
	await esperar_fotogramas(FOTOGRAMAS_ESPERA_AQUA)
	await recorrer(npc, _repetir(R, AQUA_ENTRA_ANDANDO))


## 15C639 / 15C64A: tres pasos a la derecha y mirar al norte.
func _ponerse_detras(npc: Node2D) -> void:
	await recorrer(npc, AQUA_SE_COLOCA)
	mirar(npc, U)


## MeteorFalls_1F_1R_Movement_15C64F: mira abajo, delay_4, mira a la derecha y, sin dejar de
## mirarla, un paso a la izquierda (le empujan al pasar los MAGMA).
func _jugador_empujado() -> void:
	girar_jugador(D)
	await esperar_fotogramas(4)
	girar_jugador(R)
	await retroceder_jugador(L)


static func _repetir(direccion: Vector2, veces: int) -> Array:
	var pasos: Array = []
	for i in veces:
		pasos.append(direccion)
	return pasos
