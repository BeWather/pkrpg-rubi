## programa_gabi_teo.gd
## «OPERACIÓN ENTRENADOR» (In Search of Trainers), el programa de TV de GABI y
## TEO: DoTVShowInSearchOfTrainers de pokeruby (src/tv.c) como función pura sobre
## DatosGabiTeo. No hay televisores todavía: quien los haga pedirá `emitir()`
## cuando `en_antena()` sea true y mostrará los textos en orden.
##
## Estados de la ROM y texto que muestra cada uno (gTVGabbyAndTyText1..9):
##   0 → TV_1 (lugar de la entrevista); si battleNum > 1 sigue en 1, si no en 2.
##   1 → TV_2 (ya habíamos luchado).
##   2 → TV_3 y elige la curiosidad: sin daño → 4 (TV_5), balls → 5 (TV_6),
##       objetos → 6 (TV_7), debilitados → 7 (TV_8), si no → 3 (TV_4).
##   3 → TV_4 (los dos Pokémon y el último movimiento).
##   4..7 → TV_5..TV_8.
##   8 → TV_9 (la cita) y TakeTVShowInSearchOfTrainersOffTheAir.
extends RefCounted
class_name ProgramaGabiTeo

const PREFIJO_TEXTO: String = "GABI_TEO_TV_%d"


## IsTVShowInSearchOfTrainersAiring.
static func en_antena() -> bool:
	return DatosGabiTeo.en_antena()


## Números (1..9) de gTVGabbyAndTyText en el orden en que se emiten.
static func textos_del_programa() -> Array[int]:
	var textos: Array[int] = [1]
	if DatosGabiTeo.num_combate() > 1:
		textos.append(2)
	textos.append(3)
	if not DatosGabiTeo.valor_a(0):
		textos.append(5)
	elif DatosGabiTeo.valor_a(3):
		textos.append(6)
	elif DatosGabiTeo.valor_a(2):
		textos.append(7)
	elif DatosGabiTeo.valor_a(1):
		textos.append(8)
	else:
		textos.append(4)
	textos.append(9)
	return textos


## El programa entero con los marcadores resueltos ({PN}, {lugar}, {especie},
## {especie2}, {mov}, {palabra}). Al terminar el programa sale de antena, como
## el estado 8 de la ROM.
static func emitir() -> Array[String]:
	var reemplazos := sustituciones()
	var textos: Array[String] = []
	for numero: int in textos_del_programa():
		var texto := String(TranslationServer.translate(StringName(PREFIJO_TEXTO % numero)))
		for marcador: String in reemplazos:
			texto = texto.replace(marcador, reemplazos[marcador])
		textos.append(texto)
	DatosGabiTeo.quitar_de_antena()
	return textos


## gStringVar1..3 de cada estado con los datos guardados.
static func sustituciones() -> Dictionary:
	return {
		"{PN}": SistemaGuardado.get_nombre_jugador(),
		"{lugar}": Lugares.nombre_lugar(DatosGabiTeo.lugar()),
		"{especie}": nombre_especie(DatosGabiTeo.pokemon_1()),
		"{especie2}": nombre_especie(DatosGabiTeo.pokemon_2()),
		"{mov}": nombre_movimiento(DatosGabiTeo.ultimo_movimiento()),
		"{palabra}": PalabrasFaciles.texto(DatosGabiTeo.cita()),
	}


## gSpeciesNames: nombre mostrable de la especie ("" sin especie).
static func nombre_especie(nombre_interno: String) -> String:
	if nombre_interno.is_empty():
		return ""
	var datos: Dictionary = DatabaseManager.obtener_datos_pokemon(nombre_interno)
	return str(datos.get("nombre", nombre_interno))


## gMoveNames: nombre mostrable del movimiento ("" sin movimiento).
static func nombre_movimiento(nombre_interno: String) -> String:
	if nombre_interno.is_empty():
		return ""
	var datos: Dictionary = DatabaseManager.obtener_datos_movimiento(nombre_interno)
	return str(datos.get("nombre", nombre_interno))
