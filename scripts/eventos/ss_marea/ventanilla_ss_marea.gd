## ventanilla_ss_marea.gd
## Vista por una ventanilla del S.S. MAREA (pokeruby sub_80C7958 + Task_HandlePorthole de src/field_special_scene.c): warp a
## la ruta y celda que corresponde a los pasos dados (GetSSTidalLocation) con la música y sin cartel; el barco va fijo en el
## centro de la pantalla y el mar se desplaza. Cada casilla cuenta como un paso del viaje. Con A, o al agotarse los pasos,
## vuelve al sitio del pasillo.
##
## Vive como hijo del AdministradorMapa: el warp libera el pasillo. El jugador queda aparcado e invisible en la celda del
## warp y la cámara sigue a un foco propio (el barco), para no pasar por los pasos y colisiones del agua.
class_name VentanillaSSMarea
extends Node

const ESCENA_BARCO: PackedScene = preload("res://escenas/eventos/ss_marea_ventanilla.tscn")
const MOTIVO_PAUSA: StringName = &"ss_marea_ventanilla"
const TAMANO_CASILLA: float = 16.0
## walk_fast (fotogramas por casilla a 60 por segundo).
const FOTOGRAMAS_CASILLA: float = 8.0
## FLAG_HIDE_MAP_NAME_POPUP.
const BANDERA_OCULTAR_CARTEL: String = "ocultar_cartel_lugar"

enum Fase { ENTRANDO, MIRANDO, SALIENDO }

var _admin: Node = null
var _jugador: Node2D = null
var _celda_pasillo: Vector2i
var _mapa_ruta: String = ""
var _fase: Fase = Fase.ENTRANDO
var _foco: Node2D = null
var _direccion: float = 1.0
var _avance: float = 0.0
var _salir: bool = false
var _cartel_previo: bool = false


func abrir(admin: Node, celda_pasillo: Vector2i) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_admin = admin
	_jugador = admin.get("jugador")
	_celda_pasillo = celda_pasillo
	_direccion = 1.0 if CruceroSSMarea.hacia_el_este() else -1.0
	var destino := CruceroSSMarea.ubicacion_ventanilla()
	_mapa_ruta = destino[0]
	_cartel_previo = SistemaGuardado.get_flag(BANDERA_OCULTAR_CARTEL)
	SistemaGuardado.set_flag(BANDERA_OCULTAR_CARTEL, true)
	_admin.set("conservar_musica_warp", true)  # FLAG_DONT_TRANSITION_MUSIC
	_admin.conectar_escalera(_mapa_ruta, Vector2(destino[1]), Vector2.RIGHT if _direccion > 0.0 else Vector2.LEFT, false, true)


func _process(delta: float) -> void:
	match _fase:
		Fase.ENTRANDO:
			_ocultar_jugador()
			if str(_admin.get("mapa_actual_key")) == _mapa_ruta and int(_admin.get("coneccion")) == 0:
				_empezar_vista()
		Fase.MIRANDO:
			_ocultar_jugador()
			_mirar(delta)
		Fase.SALIENDO:
			if str(_admin.get("mapa_actual_key")) == CruceroSSMarea.MAPA_PASILLO and int(_admin.get("coneccion")) == 0:
				_cerrar()


func _ocultar_jugador() -> void:
	_jugador.visible = false
	_jugador.set("no_control", true)


func _empezar_vista() -> void:
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	_foco = ESCENA_BARCO.instantiate()
	_admin.add_child(_foco)
	_foco.global_position = _jugador.global_position
	(_foco.get_node("Barco") as Sprite2D).flip_h = _direccion > 0.0
	Singleton.foco_camara = _foco
	_fase = Fase.MIRANDO


func _mirar(delta: float) -> void:
	if Input.is_action_just_pressed("btn_accion"):
		_salir = true
	var paso := TAMANO_CASILLA * delta * 60.0 / FOTOGRAMAS_CASILLA
	_foco.global_position.x += paso * _direccion
	_avance += paso
	if _avance < TAMANO_CASILLA:
		return
	_avance -= TAMANO_CASILLA
	if CruceroSSMarea.contar_paso():
		CruceroSSMarea.fin_ventanilla()
		_salir = true
	if _salir:
		_volver()


func _volver() -> void:
	_fase = Fase.SALIENDO
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	Singleton.foco_camara = _jugador
	_foco.queue_free()
	_admin.conectar_escalera(CruceroSSMarea.MAPA_PASILLO, Vector2(_celda_pasillo), Vector2.UP, false, true)


func _cerrar() -> void:
	SistemaGuardado.set_flag(BANDERA_OCULTAR_CARTEL, _cartel_previo)
	_admin.set("conservar_musica_warp", false)
	queue_free()
