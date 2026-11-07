class_name JuezConcurso
extends Node2D
## Juez y su bocadillo (CreateJudgeSprite en (112, 36) y
## CreateJudgeSpeechBubbleSprite en (96, 10), src/contest_2.c). DoJudgeSpeechBubble
## elige el fotograma de judge_symbols.png y el sonido; el bocadillo queda 85 frames.

const FRAMES_BOCADILLO: float = 85.0
## EventoConcurso.Simbolo → fotograma (tileNum + 0, 4, 8... de 4 en 4) y sonido.
const BOCADILLOS: Dictionary = {
	0: [0, "SE_FAILURE"],
	1: [0, "SE_FAILURE"],
	2: [1, "SE_SUCCESS"],
	3: [2, "SE_SUCCESS"],
	4: [3, "SE_WARP_IN"],
	5: [3, "SE_WARP_IN"],
	6: [4, "SE_WARP_IN"],
	7: [5, "SE_WARP_IN"],
	8: [6, "SE_EXP_MAX"],
}

var escala_tiempo: float = 1.0

@onready var _bocadillo: Sprite2D = $Bocadillo


func _ready() -> void:
	_bocadillo.visible = false


func mostrar_bocadillo(simbolo: int) -> void:
	var datos: Array = BOCADILLOS.get(simbolo, [0, "SE_FAILURE"])
	_bocadillo.frame = int(datos[0])
	_bocadillo.visible = true
	TiempoConcurso.sonar(self, str(datos[1]))
	await TiempoConcurso.esperar(self, FRAMES_BOCADILLO, escala_tiempo)
	_bocadillo.visible = false


func bocadillo_visible() -> bool:
	return _bocadillo.visible


func fotograma_bocadillo() -> int:
	return _bocadillo.frame
