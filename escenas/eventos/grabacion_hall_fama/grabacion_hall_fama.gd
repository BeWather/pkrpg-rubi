class_name GrabacionHallFama
extends Node2D
## FLDEFF_HALL_OF_FAME_RECORD (field_effect.c, PokeballGlowEffect_* y SpriteCB_HallOfFameMonitor):
## una POKé BALL por miembro del equipo entra en la máquina, destellan y los monitores parpadean.

const FOTOGRAMA: float = 1.0 / 60.0
const FOTOGRAMAS_POR_BALL: int = 25
const FOTOGRAMAS_TRAS_BALLS: int = 32
const FOTOGRAMAS_FASE: int = 8
const FASES_POR_DESTELLO: int = 4
const DESTELLOS: int = 3
## PokeballGlowEffect_3: el último destello se apaga en tres fases más.
const FASES_APAGADO: int = 3
const FOTOGRAMAS_FINAL: int = 30
const FOTOGRAMAS_PARPADEO: int = 16
const DURACION_MONITORES: int = 128
## gUnknown_0839F2C0-C8: de amarillo intenso a color normal.
const COLOR_DESTELLO: Array[Color] = [Color(1.6, 1.6, 0.6), Color(1.4, 1.4, 0.7), Color(1.2, 1.2, 0.85), Color.WHITE]

@onready var _balls: Array[Sprite2D] = [$Balls/Ball0, $Balls/Ball1, $Balls/Ball2, $Balls/Ball3, $Balls/Ball4, $Balls/Ball5]
@onready var _monitores: Node2D = $Monitores


func reproducir(cantidad: int) -> void:
	var total: int = mini(cantidad, _balls.size())
	for i in total:
		_balls[i].visible = true
		Singleton.play_sound.emit("SE_BALL")
		await _esperar(FOTOGRAMAS_POR_BALL)
	await _esperar(FOTOGRAMAS_TRAS_BALLS)
	_parpadear_monitores()
	for i in DESTELLOS * FASES_POR_DESTELLO:
		_teñir(COLOR_DESTELLO[i % FASES_POR_DESTELLO])
		await _esperar(FOTOGRAMAS_FASE)
	for i in FASES_APAGADO:
		_teñir(COLOR_DESTELLO[i])
		await _esperar(FOTOGRAMAS_FASE)
	_teñir(Color.WHITE)
	await _esperar(FOTOGRAMAS_FINAL)


func _teñir(color: Color) -> void:
	for ball: Sprite2D in _balls:
		ball.modulate = color


func _parpadear_monitores() -> void:
	var transcurrido: int = 0
	while transcurrido < DURACION_MONITORES and is_inside_tree():
		_monitores.visible = not _monitores.visible
		await _esperar(FOTOGRAMAS_PARPADEO)
		transcurrido += FOTOGRAMAS_PARPADEO
	if is_inside_tree():
		_monitores.visible = false


func _esperar(fotogramas: int) -> void:
	await get_tree().create_timer(fotogramas * FOTOGRAMA).timeout
