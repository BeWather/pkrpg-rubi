@tool
extends MapaConfiguracion

const DURACION_VIBRACION := 9.33
const DURACION_MEDIA_VIBRACION := 0.06
const DURACION_BLOQUEO_MOVIMIENTO := 14.0
## setdynamicwarp de InsideOfTruck_EventScript_15FC45/68: se sale por la trasera
## del camión aparcado ante la casa del jugador, en (3,10) / (12,10) de Rubí
## (Godot = Rubí + (8,0)). EventoVillaRaiz hace el salto hasta el suelo.
const SALIDA_CHICO := Vector2(11, 10)
const SALIDA_CHICA := Vector2(20, 10)
const SALIDAS: Array[NodePath] = [^"TileSalida1", ^"TileSalida2", ^"TileSalida3"]

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var motor_player: AudioStreamPlayer = $MotorPlayer

var presentacion_iniciada := false
@export var bloquear_menu: bool = true
var movimiento_bloqueado := false

func _ready() -> void:
	if Engine.is_editor_hint():
		animation_player.stop()
		$Cortina.visible = false

func iniciar_presentacion(camera: Camera2D, personaje: Node2D) -> void:
	if presentacion_iniciada:
		return
	presentacion_iniciada = true
	# Partida nueva: al bajar del camión empieza la llegada a Villa Raíz con MAMÁ
	# (VAR_LITTLEROOT_INTRO_STATE 1/2) y no se corre hasta tener las DEPORTIVAS.
	HistoriaVillaRaiz.empezar_intro()
	_fijar_salida()
	movimiento_bloqueado = true
	personaje.no_control = true
	animation_player.play("marcha")
	motor_player.play()
	_vibrar_camion(camera)
	_liberar_movimiento(personaje)

func _fijar_salida() -> void:
	var destino := SALIDA_CHICO if HistoriaVillaRaiz.es_chico() else SALIDA_CHICA
	for ruta in SALIDAS:
		var salida := get_node_or_null(ruta)
		if salida != null:
			salida.posicion_destino = destino

func _liberar_movimiento(personaje: Node2D) -> void:
	await get_tree().create_timer(DURACION_BLOQUEO_MOVIMIENTO).timeout
	if is_instance_valid(personaje):
		movimiento_bloqueado = false
		personaje.no_control = false

func control_bloqueado() -> bool:
	return movimiento_bloqueado

## Sustituye la comprobación ad-hoc get("bloquear_menu") del administrador.
func bloquea_menu() -> bool:
	return bloquear_menu

func _vibrar_camion(camera: Camera2D) -> void:
	var posicion_base := camera.position
	var tiempo := 0.0
	while tiempo < DURACION_VIBRACION and is_instance_valid(camera):
		var vibracion := create_tween()
		vibracion.tween_property(camera, "position:y", posicion_base.y + 1.0, DURACION_MEDIA_VIBRACION)
		vibracion.tween_property(camera, "position:y", posicion_base.y, DURACION_MEDIA_VIBRACION)
		await vibracion.finished
		tiempo += DURACION_MEDIA_VIBRACION * 2.0
	if is_instance_valid(camera):
		camera.position = posicion_base
