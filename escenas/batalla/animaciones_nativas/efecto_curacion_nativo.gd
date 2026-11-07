extends EfectoEstadoNativo
class_name EfectoCuracionNativo
## Componentes de los sub-lotes de §21 (documentacion/piloto_animaciones_nativas.md): curación y
## protección, puños elementales, clima y rayos/ondas. Va en un archivo hermano para que
## efecto_estado_nativo.gd no crezca sin control; hereda todos los componentes anteriores y añade:
##
## - opciones nuevas de sprite_estado() (vía _extra_sprite()):
##   "giros": [[frame, ángulo], ...]: giro por claves interpolado (radianes, caso jugador), para
##     las animaciones afines de giro de ida y vuelta (la botella de Batido); con "fijo", sin reflejar;
##   "fase_detras": [fase, paso, rol]: con la fase (1/256 de vuelta, avanza `paso` por frame)
##     fuera de 64..191 el sprite pasa detrás del battler `rol` (AnimSwirlingFogAnim de Neblina,
##     que gira alrededor del atacante; Polución lo hacía con el defensor).
## - velo_degradado(): el fondo pasa de un color sólido a otro (escritura directa de la paleta del
##   fondo de sub_80CE3EC, Luz Lunar).
##
## Mismas convenciones: frames de 60 Hz desde la clave, posiciones para «ataca el jugador»
## reflejadas en x según `direccion`.


func _extra_sprite(copia: Sprite2D, opciones: Dictionary, i: int) -> void:
	var giros: Array = opciones.get("giros", [])
	if not giros.is_empty():
		copia.rotation = _alfa_en(giros, i) * (1.0 if bool(opciones.get("fijo", false)) else direccion)
	var fase_detras: Array = opciones.get("fase_detras", [])
	if fase_detras.size() == 3:
		var fase: int = posmod(int(fase_detras[0]) + int(fase_detras[1]) * i - 64, 256)
		_detras_de(copia, StringName(fase_detras[2]), fase > 0x7F)


## Pone `copia` detrás del battler `rol` (o la devuelve delante de los dos).
func _detras_de(copia: CanvasItem, rol: StringName, detras: bool) -> void:
	var battler: Sprite2D = sprite_de(rol)
	if not is_instance_valid(battler):
		return
	copia.z_as_relative = not detras
	copia.z_index = z_absoluto(battler) - 1 if detras else 0


## Velo del fondo de `desde` a `hasta` (colores sólidos: cantidad 1) en `frames` escalones, uno por
## frame desde el siguiente a la clave.
func velo_degradado(desde: Color, hasta: Color, frames: int) -> void:
	fijar_tinte(&"fondo", desde, 1.0)
	_cada_frame(frames, func(i: int) -> void:
		if i > 0:
			fijar_tinte(&"fondo", desde.lerp(hasta, float(i) / frames), 1.0))
