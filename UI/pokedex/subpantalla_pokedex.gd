extends Control
## Base de las pestañas de la ficha que tapan su contenido: ÁREA, GRITO y TAM.
## Cada una entra fundiéndose desde negro y sale fundiéndose a negro (sin la
## barra superior, máscara 0xFFFFFFEB de Rubí); al salir emite cerrada con la
## pestaña a la que hay que ir, o PAGINA para volver a la ficha.
## La escena necesita un ColorRect "Fundido" de 240×160.

signal cerrada(destino: int)

## Mismo orden que PaginaPokedex.Seccion.
enum Destino { PAGINA, AREA, GRITO, TAMANO }

const TAMANO_BASE: Vector2 = Vector2(240, 160)
const DURACION_FUNDIDO: float = 0.3

@onready var _fundido: ColorRect = $Fundido

## Registro de la Pokédex (nacional, nombre, nombre_interno, atrapado...).
var entrada: Dictionary = {}
var es_chica: bool = false
var aceptando_controles: bool = false
var _configurada: bool = false
var _saliendo: bool = false
var _reproducir: Callable
var _reproductor_se: AudioStreamPlayer


func configurar(p_entrada: Dictionary, p_es_chica: bool, reproducir: Callable = Callable()) -> void:
	_configurada = true
	entrada = p_entrada
	es_chica = p_es_chica
	_reproducir = reproducir


func _ready() -> void:
	if not _configurada:
		entrada = _entrada_vista_previa()
	_preparar()
	call_deferred("_ajustar_vista_previa")
	_entrar.call_deferred()


## F6: especie de prueba.
func _entrada_vista_previa() -> Dictionary:
	return {"nacional": 263, "nombre": "ZIGZAGOON", "nombre_interno": "ZIGZAGOON", "visto": true, "atrapado": true}


## Construye la pantalla con `entrada` (antes del fundido de entrada).
func _preparar() -> void:
	pass


## Controles con la pantalla ya visible.
func _al_pulsar(_evento: InputEvent) -> void:
	pass


## Justo al pulsar el botón que sale (antes del fundido).
func _al_salir() -> void:
	pass


func _ajustar_vista_previa() -> void:
	if get_tree().current_scene != self:
		return
	var tamano := get_viewport_rect().size
	var factor := minf(tamano.x / TAMANO_BASE.x, tamano.y / TAMANO_BASE.y)
	scale = Vector2.ONE * factor
	position = (tamano - TAMANO_BASE * factor) / 2.0


func _reproducir_efecto(clave: String) -> void:
	if _reproducir.is_valid():
		_reproducir.call(clave)
	elif get_tree().current_scene == self:
		if not is_instance_valid(_reproductor_se):
			_reproductor_se = AudioStreamPlayer.new()
			_reproductor_se.bus = &"Master"
			add_child(_reproductor_se)
		_reproductor_se.stream = Singleton.se[clave]
		_reproductor_se.play()
	else:
		Singleton.play_sound.emit(clave)


func _entrar() -> void:
	aceptando_controles = false
	_fundido.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fundido, "modulate:a", 0.0, DURACION_FUNDIDO)
	await tween.finished
	aceptando_controles = true


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	get_viewport().set_input_as_handled()
	if aceptando_controles and not event.is_echo():
		_al_pulsar(event)


## Fundido a negro y cerrada(destino). B usa SE_PC_OFF; cambiar de pestaña,
## SE_DEX_PAGE.
func salir(destino: int, sonido: String) -> void:
	if _saliendo:
		return
	_saliendo = true
	aceptando_controles = false
	_al_salir()
	_reproducir_efecto(sonido)
	var tween := create_tween()
	tween.tween_property(_fundido, "modulate:a", 1.0, DURACION_FUNDIDO)
	await tween.finished
	cerrada.emit(destino)
	if get_tree().current_scene == self:
		get_tree().quit()
