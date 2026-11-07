## evento_casa_treta_prueba2.gd
## Acertijo 2 de la CASA TRETA (Route110_TrickHousePuzzle2): cuatro botones del suelo y
## cuatro persianas. Cada botón (coord_event, `VAR_TEMP_n == 0`) se pulsa UNA vez: suena
## SE_PIN, el botón pasa a 0x259 (pulsado) y su persiana 0x269 (pared) pasa a 0x26A
## (`Door_Shuttered`, setmetatile con impasable = 0): la celda se abre.
##
## `VAR_TEMP_n` son estado de ejecución: la escena se instancia de nuevo en cada warp, así
## que `_pulsados` empieza vacío al cargar (OnTransition: VAR_TEMP_1..4 = 0) y las
## persianas vuelven a estar cerradas (OnResume solo repite lo pulsado durante la visita).
extends "res://scripts/eventos/ruta_110/evento_casa_treta_prueba.gd"
class_name EventoCasaTretaPrueba2

## Botón n (índice n-1) y la persiana que abre.
const BOTONES: Array[Vector2i] = [Vector2i(14, 21), Vector2i(8, 17), Vector2i(4, 10), Vector2i(5, 2)]
const PERSIANAS: Array[Vector2i] = [Vector2i(1, 12), Vector2i(12, 13), Vector2i(8, 4), Vector2i(12, 5)]
## METATILE_TrickHousePuzzle_Door_Shuttered.
const METATILE_PERSIANA: int = 0x26A
const PLANTILLA_ID: String = "boton_%d"

## VAR_TEMP_1..4 (índice 0..3).
var _pulsados: Array[bool] = [false, false, false, false]


func _on_disparador(id_evento: StringName) -> void:
	for indice in BOTONES.size():
		if id_evento == StringName(PLANTILLA_ID % (indice + 1)):
			await pulsar_boton(indice + 1)
			return


## `Route110_TrickHousePuzzle2_EventScript_ButtonN`: lockall, VAR_TEMP_n = 1, SE_PIN,
## PressButtonN, DrawWholeMapView, releaseall.
func pulsar_boton(numero: int) -> void:
	var indice := numero - 1
	if indice < 0 or indice >= BOTONES.size() or _pulsados[indice] or _en_curso:
		return
	if not comenzar(_administrador()):
		return
	_pulsados[indice] = true
	_sonido(SONIDO_PIN)
	_aplicar_boton(indice)
	terminar()


## PressButtonN: botón pulsado + persiana abierta.
func _aplicar_boton(indice: int) -> void:
	poner_metatile(BOTONES[indice], METATILE_BOTON_PULSADO, false)
	poner_metatile(PERSIANAS[indice], METATILE_PERSIANA, false)


func boton_pulsado(numero: int) -> bool:
	return numero >= 1 and numero <= _pulsados.size() and _pulsados[numero - 1]
