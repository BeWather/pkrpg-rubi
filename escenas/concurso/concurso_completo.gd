class_name ConcursoCompleto
extends CanvasLayer
## Encadena las dos pantallas de un concurso por encima del overworld: las apelaciones
## (EscenaConcurso) y los resultados (ResultadosConcurso), con fundidos a negro entre
## ellas como CB2_StartContest / Task_ContestReturnToField. Lo usa la sala del concurso
## y el arnés prueba_concurso.tscn.
##
## Uso: `var motor := await ConcursoCompleto.jugar(self, concursantes, categoria, nivel)`.

const RUTA_ESCENA: String = "res://escenas/concurso/concurso_completo.tscn"
const ESCENA_CONCURSO: PackedScene = preload("res://escenas/concurso/escena_concurso.tscn")
const ESCENA_RESULTADOS: PackedScene = preload("res://escenas/concurso/resultados_concurso.tscn")
const SEGUNDOS_FUNDIDO: float = 16.0 / 60.0

## Qué pantallas muestra: la sala pone sus textos entre las apelaciones y los resultados.
enum Fases { AMBAS, APELACIONES, RESULTADOS }

@export var fases: Fases = Fases.AMBAS
@export var escala_tiempo: float = 1.0
@export var avance_automatico: bool = false
@export var con_musica: bool = true
## Si es válido, elige el movimiento del jugador sin menú (EscenaConcurso.elegir_movimiento).
var elegir_movimiento: Callable = Callable()

@onready var _fundido: ColorRect = $Fundido


## Crea la capa en `anfitrion`, juega el concurso y la libera al terminar.
static func jugar(anfitrion: Node, concursantes: Array[ConcursanteConcurso], categoria: int, nivel: int,
		aleatorio: AleatorioConcurso = null, configurar: Callable = Callable()) -> MotorConcurso:
	var capa: ConcursoCompleto = (load(RUTA_ESCENA) as PackedScene).instantiate()
	if configurar.is_valid():
		configurar.call(capa)
	anfitrion.get_tree().root.add_child(capa)
	var motor := MotorConcurso.new(DatosConcurso.compartido(), aleatorio)
	motor.iniciar(concursantes, categoria, nivel)
	await capa.ejecutar(motor)
	capa.queue_free()
	return motor


## Solo la pantalla de resultados de un motor ya terminado (showcontestresults).
static func mostrar_resultados(anfitrion: Node, motor: MotorConcurso, configurar: Callable = Callable()) -> void:
	var capa: ConcursoCompleto = (load(RUTA_ESCENA) as PackedScene).instantiate()
	capa.fases = Fases.RESULTADOS
	if configurar.is_valid():
		configurar.call(capa)
	anfitrion.get_tree().root.add_child(capa)
	await capa.ejecutar(motor)
	capa.queue_free()


func ejecutar(motor: MotorConcurso) -> void:
	await _fundir(1.0)
	if fases != Fases.RESULTADOS:
		await _apelaciones(motor)
	if fases != Fases.APELACIONES:
		await _resultados(motor)


func _apelaciones(motor: MotorConcurso) -> void:
	if con_musica:
		Singleton.reproducir_tema("CONCURSO_POKEMON")
	var concurso: EscenaConcurso = ESCENA_CONCURSO.instantiate()
	concurso.escala_tiempo = escala_tiempo
	concurso.avance_automatico = avance_automatico
	concurso.elegir_movimiento = elegir_movimiento
	add_child(concurso)
	move_child(concurso, 0)
	await _fundir(0.0)
	await concurso.ejecutar(motor)
	await _fundir(1.0)
	concurso.queue_free()


func _resultados(motor: MotorConcurso) -> void:
	var resultados: ResultadosConcurso = ESCENA_RESULTADOS.instantiate()
	resultados.escala_tiempo = escala_tiempo
	resultados.avance_automatico = avance_automatico
	resultados.con_musica = con_musica
	add_child(resultados)
	move_child(resultados, 0)
	await _fundir(0.0)
	await resultados.mostrar(motor)
	await _fundir(1.0)
	resultados.queue_free()


func _fundir(alfa: float) -> void:
	if escala_tiempo <= 0.0:
		_fundido.color.a = alfa
		await get_tree().process_frame
		return
	var tween := create_tween()
	tween.tween_property(_fundido, "color:a", alfa, SEGUNDOS_FUNDIDO * escala_tiempo)
	await tween.finished
