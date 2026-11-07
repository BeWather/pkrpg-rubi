extends Node2D
class_name MenuPokenav

## Menú principal del POKéNAV (pokeruby src/pokenav.c, src/pokenav_before.c).
## MAPA DE HOENN, CONDICIÓN y ENTRENADORES siempre; CINTAS con FLAG_SYS_RIBBON_GET;
## DESCONEXIÓN o B lo apagan. Sin cursor: la opción elegida se adelanta y brilla.

signal cerrado

enum Opcion { MAPA, CONDICION, ENTRENADORES, CINTAS, APAGAR }

const CLAVES_DESCRIPCION: Array[String] = [
	"POKENAV_DESC_MAPA", "POKENAV_DESC_CONDICION", "POKENAV_DESC_ENTRENADORES",
	"POKENAV_DESC_CINTAS", "POKENAV_DESC_APAGAR",
]
const ESCENA_MAPA: String = "res://UI/mapa_region/region_hoenn.tscn"
const ESCENA_CONDICION: String = "res://UI/pokenav/condicion_pokenav.tscn"
const ESCENA_ENTRENADORES: String = "res://UI/pokenav/entrenadores_pokenav.tscn"
const ESCENA_CINTAS: String = "res://UI/pokenav/cintas_pokenav.tscn"

@onready var contenido: Node2D = $Contenido
@onready var submenu: Node2D = $Submenu
@onready var lista: ListaBotonesPokenav = $Contenido/Botones
@onready var lb_descripcion: Label = $Contenido/Descripcion
@onready var luz: Sprite2D = $Contenido/LuzRevancha
@onready var anim: AnimationPlayer = $Anim

## Mapa actual para la luz de revancha; lo pone quien abre el menú.
var mapa_actual: Node = null
var activo: bool = false
var pantalla: Node = null


func _ready() -> void:
	lista.seleccion_cambiada.connect(_on_seleccion_cambiada)
	lista.botones[Opcion.CINTAS].visible = DatosPokenav.cintas_disponibles()
	luz.visible = DatosPokenav.revancha_en_mapa(mapa_actual)
	lb_descripcion.text = ""


## SE_POKENAV_ON, fundido, logo y botones.
func arrancar() -> void:
	Singleton.play_sound.emit("SE_POKENAV_ON")
	anim.play(&"arranque")
	await anim.animation_finished
	Singleton.play_sound.emit("SE_WIN_OPEN")
	await lista.entrar()
	activo = true


func _input(event: InputEvent) -> void:
	if not activo or not is_inside_tree():
		return
	if event.is_action_pressed("btn_arriba", true):
		if lista.mover(-1):
			Singleton.play_sound.emit("SE_SELECT")
	elif event.is_action_pressed("btn_abajo", true):
		if lista.mover(1):
			Singleton.play_sound.emit("SE_SELECT")
	elif event.is_action_pressed("btn_accion"):
		confirmar()
	elif event.is_action_pressed("btn_cancelar"):
		apagar()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_seleccion_cambiada(indice: int) -> void:
	lb_descripcion.text = tr(CLAVES_DESCRIPCION[indice])


func confirmar() -> void:
	match lista.indice:
		Opcion.MAPA:
			Singleton.play_sound.emit("SE_SELECT")
			_abrir_pantalla(ESCENA_MAPA)
		Opcion.CONDICION:
			Singleton.play_sound.emit("SE_SELECT")
			_abrir_pantalla(ESCENA_CONDICION)
		Opcion.ENTRENADORES:
			if DatosPokenav.entrenadores_registrados().is_empty():
				_fallo("POKENAV_SIN_ENTRENADORES")
			else:
				Singleton.play_sound.emit("SE_SELECT")
				_abrir_pantalla(ESCENA_ENTRENADORES)
		Opcion.CINTAS:
			if DatosPokenav.pokemon_con_cintas().is_empty():
				_fallo("POKENAV_SIN_CINTAS")
			else:
				Singleton.play_sound.emit("SE_SELECT")
				_abrir_pantalla(ESCENA_CINTAS)
		Opcion.APAGAR:
			apagar()


## SE_FAILURE y texto de aviso.
func _fallo(clave: String) -> void:
	Singleton.play_sound.emit("SE_FAILURE")
	lb_descripcion.text = tr(clave)


## Fundido total. La pantalla queda en negro: quien abrió el menú la libera.
func apagar() -> void:
	activo = false
	Singleton.play_sound.emit("SE_POKENAV_OFF")
	anim.play(&"apagar")
	await anim.animation_finished
	cerrado.emit()


## Botones y logo fuera, negro, y la pantalla de la opción elegida.
func _abrir_pantalla(ruta: String) -> void:
	activo = false
	anim.play(&"salida_a_submenu")
	await lista.salir_con_elegido()
	if anim.is_playing():
		await anim.animation_finished
	anim.play(&"a_negro")
	await anim.animation_finished
	contenido.visible = false
	pantalla = (load(ruta) as PackedScene).instantiate()
	if ruta == ESCENA_MAPA:
		pantalla.configurar_como_pokenav()
		pantalla.mapa_cerrado.connect(_on_pantalla_cerrada)
	else:
		pantalla.cerrado.connect(_on_pantalla_cerrada)
	submenu.add_child(pantalla)
	anim.play(&"desde_negro")
	await anim.animation_finished
	if ruta == ESCENA_MAPA:
		pantalla.habilitar_input()
	else:
		pantalla.abrir()


func _on_pantalla_cerrada() -> void:
	anim.play(&"a_negro")
	await anim.animation_finished
	pantalla.queue_free()
	pantalla = null
	contenido.visible = true
	lb_descripcion.text = ""
	anim.play(&"desde_negro")
	await anim.animation_finished
	anim.play(&"entrada_desde_submenu")
	await anim.animation_finished
	Singleton.play_sound.emit("SE_WIN_OPEN")
	await lista.entrar()
	activo = true
