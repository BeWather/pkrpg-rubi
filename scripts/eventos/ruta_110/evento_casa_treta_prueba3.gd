## evento_casa_treta_prueba3.gd
## Acertijo 3 de la CASA TRETA (Route110_TrickHousePuzzle3): siete botones, muchos bajo
## rocas rompibles, que alternan dos familias de puertas, ROJAS y AZULES (27 en total,
## no 22 como decía la nota del análisis: 9+5 azules y 5+8 rojas, contadas de
## `SetDoorsState0/1`).
##
## Cada pulsación (`PressButton`): VAR_TEMP_1..7 = 0 salvo el del botón, los siete botones
## vuelven a 0x258 y el pulsado a 0x259, SE_PIN y se alternan todas las puertas
## (VAR_TEMP_9). Un botón se puede pisar de nuevo después de otro, pero no dos veces
## seguidas: `VAR_TEMP_n == 1` desarma su coord_event hasta que se pulse otro.
##
## Estado 0 = el de fábrica (la escena ya está dibujada así, comprobado celda a celda en el
## test); `_estado_puertas` = VAR_TEMP_9. Tablas por familia en vez de 100 filas de
## setmetatile: origen (esquina superior izquierda) de cada puerta y metatiles por estado.
extends "res://scripts/eventos/ruta_110/evento_casa_treta_prueba.gd"
class_name EventoCasaTretaPrueba3

## Botón n (índice n-1): (5,20), (4,12), (11,10), (3,8), (13,7), (1,3), (10,2).
const BOTONES: Array[Vector2i] = [
	Vector2i(5, 20), Vector2i(4, 12), Vector2i(11, 10), Vector2i(3, 8),
	Vector2i(13, 7), Vector2i(1, 3), Vector2i(10, 2),
]
const PLANTILLA_ID: String = "boton_%d"

## Puertas H (2x2, esquina superior izquierda) y V (1x2) de cada familia.
const AZULES_H: Array[Vector2i] = [
	Vector2i(1, 6), Vector2i(4, 9), Vector2i(4, 18), Vector2i(7, 3), Vector2i(7, 9),
	Vector2i(7, 18), Vector2i(13, 3), Vector2i(13, 9), Vector2i(13, 15),
]
const AZULES_V: Array[Vector2i] = [
	Vector2i(3, 13), Vector2i(6, 7), Vector2i(9, 16), Vector2i(12, 4), Vector2i(12, 10),
]
const ROJAS_H: Array[Vector2i] = [
	Vector2i(1, 15), Vector2i(4, 6), Vector2i(7, 12), Vector2i(10, 12), Vector2i(10, 18),
]
const ROJAS_V: Array[Vector2i] = [
	Vector2i(3, 4), Vector2i(6, 10), Vector2i(6, 13), Vector2i(6, 16),
	Vector2i(9, 4), Vector2i(9, 7), Vector2i(12, 13), Vector2i(12, 16),
]

## Una puerta H son 4 metatiles (arriba-izq, arriba-der, abajo-izq, abajo-der) y una V,
## 2 (arriba, abajo). Cada metatile es [id, impasable]. Índice 0 = estado 0.
const H_AZUL: Array = [
	[[0x24B, false], [0x24C, false], [0x253, false], [0x254, false]],  # abierta
	[[0x23B, false], [0x23C, false], [0x243, true], [0x244, true]],    # cerrada
]
const V_AZUL: Array = [
	[[0x24D, true], [0x255, false]],   # retraída + sombra
	[[0x23D, true], [0x245, true]],    # abierta
]
const H_ROJA: Array = [
	[[0x238, false], [0x239, false], [0x240, true], [0x241, true]],    # cerrada
	[[0x248, false], [0x249, false], [0x250, false], [0x251, false]],  # abierta
]
const V_ROJA: Array = [
	[[0x23A, true], [0x242, true]],    # abierta
	[[0x24A, true], [0x252, false]],   # retraída + sombra
]

## VAR_TEMP_9: 0 = estado de fábrica, 1 = alternado.
var _estado_puertas: int = 0
## VAR_TEMP_8: último botón pulsado (0 = ninguno; los VAR_TEMP_1..7 son «es ese botón»).
var _ultimo_boton: int = 0


func _on_disparador(id_evento: StringName) -> void:
	for indice in BOTONES.size():
		if id_evento == StringName(PLANTILLA_ID % (indice + 1)):
			await pulsar_boton(indice + 1)
			return


func estado_puertas() -> int:
	return _estado_puertas


func ultimo_boton() -> int:
	return _ultimo_boton


## `Route110_TrickHousePuzzle3_EventScript_ButtonN` + `PressButton` + `AlternateDoors`.
func pulsar_boton(numero: int) -> void:
	if numero < 1 or numero > BOTONES.size() or numero == _ultimo_boton or _en_curso:
		return
	if not comenzar(_administrador()):
		return
	_ultimo_boton = numero
	_sonido(SONIDO_PIN)
	_actualizar_botones()
	_estado_puertas = 1 - _estado_puertas
	_aplicar_puertas(_estado_puertas)
	terminar()


## UpdateButtonMetatiles: siete botones a 0x258 y el pulsado a 0x259.
func _actualizar_botones() -> void:
	for indice in BOTONES.size():
		var pulsado := indice + 1 == _ultimo_boton
		poner_metatile(BOTONES[indice], METATILE_BOTON_PULSADO if pulsado else METATILE_BOTON_ARRIBA, false)


## SetDoorsState0 / SetDoorsState1.
func _aplicar_puertas(estado: int) -> void:
	for origen in AZULES_H:
		_poner_h(origen, H_AZUL[estado])
	for origen in AZULES_V:
		_poner_v(origen, V_AZUL[estado])
	for origen in ROJAS_H:
		_poner_h(origen, H_ROJA[estado])
	for origen in ROJAS_V:
		_poner_v(origen, V_ROJA[estado])


func _poner_h(origen: Vector2i, tiles: Array) -> void:
	var desplazamientos: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	for i in desplazamientos.size():
		poner_metatile(origen + desplazamientos[i], tiles[i][0], tiles[i][1])


func _poner_v(origen: Vector2i, tiles: Array) -> void:
	poner_metatile(origen, tiles[0][0], tiles[0][1])
	poner_metatile(origen + Vector2i(0, 1), tiles[1][0], tiles[1][1])
