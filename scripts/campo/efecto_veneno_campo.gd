class_name EfectoVenenoCampo
extends CanvasLayer

## Efecto del veneno en el campo (`FldeffPoison_Start`, pokeruby
## src/fldeff_poison.c): suena SE_DOKU y la pantalla se pixela y se recompone.
## `Task_FieldPoisonEffect` sube REG_MOSAIC de 2 en 2 hasta 10 y luego baja de
## 2 en 2 hasta 0, un nivel por fotograma (10 fotogramas, ~0,17 s a 60 Hz). No
## pausa nada: el jugador sigue andando mientras dura.
##
## Va en una capa por debajo del menú y los diálogos (CAPA), que no se pixelan.

const SHADER: Shader = preload("res://scripts/campo/mosaico_pantalla.gdshader")
## Por encima del mundo (capa 0) y por debajo de `Menu` del AdministradorMapa (5).
const CAPA: int = 4
## Valor de REG_MOSAIC (nivel) en cada fotograma de la tarea.
const NIVELES: Array[int] = [2, 4, 6, 8, 10, 8, 6, 4, 2, 0]
const FOTOGRAMAS_POR_SEGUNDO: float = 60.0
## Clave de Singleton.se (SE_DOKU, "Overworld Poison Damage").
const SONIDO: String = "SE_DOKU"

var _rect: ColorRect
var _audio: AudioStreamPlayer
## Mosaico y sonido: el efecto se libera al terminar ambos.
var _pendientes: int = 2


## Nivel de mosaico del fotograma `fotograma` (0 fuera de rango).
static func nivel_en_fotograma(fotograma: int) -> int:
	if fotograma < 0 or fotograma >= NIVELES.size():
		return 0
	return NIVELES[fotograma]


## REG_MOSAIC con nivel N agranda cada bloque a N + 1 píxeles.
static func tamano_bloque(nivel: int) -> int:
	return nivel + 1


## `FldeffPoison_Start`: crea el efecto como hijo de `padre` y lo lanza. Se
## libera solo al terminar; no hay que esperarlo.
static func iniciar(padre: Node) -> EfectoVenenoCampo:
	var efecto := EfectoVenenoCampo.new()
	efecto.layer = CAPA
	padre.add_child(efecto)
	efecto.reproducir()
	return efecto


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material_mosaico := ShaderMaterial.new()
	material_mosaico.shader = SHADER
	_rect.material = material_mosaico
	add_child(_rect)
	_aplicar_fotograma(0.0)


func reproducir() -> void:
	# Reproductor propio: el del AdministradorMapa lo pisaría el sonido del cuadro
	# de diálogo que se abre en el mismo paso cuando alguien se debilita.
	_audio = AudioStreamPlayer.new()
	_audio.stream = Singleton.se.get(SONIDO) as AudioStream
	add_child(_audio)
	if _audio.stream != null:
		_audio.play()
		_audio.finished.connect(_al_terminar)
	else:
		push_warning("[VENENO] Falta el sonido %s en Singleton.se" % SONIDO)
		_audio.queue_free()
		_audio = null
		_pendientes -= 1
	var tween := create_tween()
	tween.tween_method(
		_aplicar_fotograma,
		0.0,
		float(NIVELES.size()),
		float(NIVELES.size()) / FOTOGRAMAS_POR_SEGUNDO
	)
	tween.finished.connect(_al_terminar_mosaico)


func _al_terminar_mosaico() -> void:
	# Con el sonido aún sonando no hace falta seguir copiando la pantalla.
	_rect.visible = false
	_al_terminar()


## Se libera cuando acaban el mosaico y el sonido (lo que tarde más).
func _al_terminar() -> void:
	_pendientes -= 1
	if _pendientes <= 0:
		queue_free()


func _aplicar_fotograma(fotograma: float) -> void:
	if _rect == null:
		return
	var nivel := nivel_en_fotograma(mini(int(fotograma), NIVELES.size() - 1))
	(_rect.material as ShaderMaterial).set_shader_parameter(
		"tamano_bloque", float(tamano_bloque(nivel))
	)
