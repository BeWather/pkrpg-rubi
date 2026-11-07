class_name FondoBiciCreditos
extends Node2D
## Fondos de la bici de los créditos (intro_credits_graphics.c, sub_8148CB0). Cada hijo es una
## variante con sus capas, generadas desde el decomp y editables en esta escena.

const FPS: float = 60.0
## gUnknown_02039358: desplazamiento vertical fijo de todas las capas.
const VERTICAL: float = 34.0
## Task_BikeScene, caso 0: Sin((t >> 1) & 0x7F, 12), medio seno de 0 a 12 px en 256 fotogramas.
const BOB_AMPLITUD: float = 12.0
const BOB_PERIODO: float = 256.0

var _capas: Array[CapaFondoCreditos] = []
var _fotogramas: float = 0.0


func mostrar(variante: String) -> void:
	_capas.clear()
	for hijo: Node in get_children():
		var activa: bool = hijo.name == variante
		(hijo as CanvasItem).visible = activa
		if activa:
			for capa: Node in hijo.get_children():
				_capas.append(capa as CapaFondoCreditos)
	_actualizar(0.0)


func _process(delta: float) -> void:
	_actualizar(delta * FPS)


func _actualizar(paso: float) -> void:
	_fotogramas += paso
	var bob: float = BOB_AMPLITUD * sin(PI * fposmod(_fotogramas, BOB_PERIODO) / BOB_PERIODO)
	for capa: CapaFondoCreditos in _capas:
		capa.actualizar(paso, _fotogramas, VERTICAL, bob)
