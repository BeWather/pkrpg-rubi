@tool
class_name EscaleraCentro
extends TileMapLayer
## fldeff_escalator.c: siete familias actualizadas por fases, ocho ticks/ciclo.
## Solo gráficos: no modifica TPTileDataMap ni colisiones.

signal ciclo_seguro
@export var planta_alta: bool = false
var activo := false
var invertir := false
var fase := 0
var indice := 0
var acumulado := 0.0
var frames: Array[int] = [0, 0, 0, 0, 0, 0, 0]

func iniciar(sentido_inverso: bool) -> void:
	activo = true
	invertir = sentido_inverso
	fase = 0
	indice = 0
	acumulado = 0.0
	frames.fill(0)
	_dibujar()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not activo:
		return
	acumulado += delta
	while acumulado >= 1.0 / 60.0:
		acumulado -= 1.0 / 60.0
		avanzar_tick()

func avanzar_tick() -> void:
	if fase < 7:
		frames[fase] = siguiente_frame(fase, frames[fase], indice, invertir)
	fase = (fase + 1) % 8
	if fase == 0:
		indice = (indice + 1) % 3
		_dibujar()
		if indice == 2:
			ciclo_seguro.emit()

static func siguiente_frame(familia: int, actual: int, paso: int, inverso: bool) -> int:
	var lista: Array = [2, 1, 0] if familia < 4 else [0, 1, 2]
	var buscado: int = lista[2 - paso] if inverso else lista[paso]
	if actual != buscado:
		return actual
	return lista[(1 - paso + 3) % 3] if inverso else lista[(paso + 1) % 3]

func finalizar() -> void:
	if activo and not (fase == 0 and indice == 2):
		await ciclo_seguro
	detener()

func detener() -> void:
	activo = false
	frames.fill(0)
	_dibujar()

func _dibujar() -> void:
	var inicio := 4 if planta_alta else 0
	var cantidad := 3 if planta_alta else 4
	for i in range(cantidad):
		var familia := inicio + i
		set_cell(Vector2i(i % 2, i / 2), 0, Vector2i(frames[familia], familia))
