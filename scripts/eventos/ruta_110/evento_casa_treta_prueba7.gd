## evento_casa_treta_prueba7.gd
## Acertijo 7 de la CASA TRETA (Route110_TrickHousePuzzle7): flechas del suelo, cinco
## palancas y una plataforma de teletransporte.
##
## El suelo con flechas (36 MB_SLIDE_SOUTH, 50 SLIDE_WEST, 18 SLIDE_EAST, 46 SLIDE_NORTH,
## flechas rojas MB_WALK_* y 2 celdas resbaladizas) no lo gestiona este evento: son
## banderas de tile (EMPUJE_*, RESBALADIZO) que character.gd aplica al terminar cada paso
## (SueloForzado). Aquí solo se cambian cuando una palanca altera una flecha.
##
## PALANCAS (bg_events `sign` PLAYER_FACING_ANY, `Route110_TrickHousePuzzle7_EventScript_
## Switch1..5`): lockall, delay 32, cambia el par palanca/flecha, SE_CLICK, alterna
## FLAG_TRICK_HOUSE_PUZZLE_7_SWITCH_n. La palanca (0x23E apagada / 0x23F encendida) es
## impasable; la flecha cambia de metatile Y de comportamiento (setmetatile hace las dos
## cosas en Rubí; aquí, atlas + banderas de tile).
##
## PLATAFORMA (9,2) (coord_event `VAR_TEMP_1 == 0`, metatile 0x246 MB_AQUA_HIDEOUT_WARP):
## PUZZLE_7_STATE_2 = 1 y `warpteleport` al MISMO mapa, a (3,19). Los interruptores solo
## sobreviven a ese warp: OnTransition de Rubí los borra si STATE_2 != 1, y OnFrame
## vuelve a poner STATE_2 = 0. Aquí es lo mismo, con la escena recargada por
## `conectar_escalera` (fundido, SE_WARP_IN, como `sub_8080F68`).
##
## El pad (9,2) lleva 0x246 y el destino (3,19) 0x247; los metatiles 0x24E/0x24F/0x256
## (flechas deslizantes al norte/sur) y 0x257 (suelo liso entre ellas) quedaron
## ambiguos en la fase 1A: se resolvieron con `metatile_attributes.bin` del decomp, ver
## documentacion/20261014-casa-treta-fase1.md (fase 1C).
extends "res://scripts/eventos/ruta_110/evento_casa_treta_prueba.gd"
class_name EventoCasaTretaPrueba7

const NUMERO_INTERRUPTORES: int = 5
## Palanca n (índice n-1): bg_events Switch1..5.
const PALANCAS: Array[Vector2i] = [
	Vector2i(12, 16), Vector2i(12, 11), Vector2i(5, 10), Vector2i(4, 4), Vector2i(7, 5),
]
## Flecha que cambia cada palanca (setmetatile de SetSwitchNMetatilesOn/Off).
const FLECHAS: Array[Vector2i] = [
	Vector2i(13, 17), Vector2i(12, 13), Vector2i(7, 12), Vector2i(6, 6), Vector2i(8, 4),
]
## METATILE_TrickHousePuzzle_Arrow_RedOnBlack_*: abajo 0x263, izquierda 0x261, arriba
## 0x262, derecha 0x260, y las «Alt» 0x27B (izquierda) y 0x27C (derecha).
const FLECHA_APAGADA: Array[int] = [0x263, 0x261, 0x263, 0x27B, 0x260]
const FLECHA_ENCENDIDA: Array[int] = [0x262, 0x262, 0x262, 0x27C, 0x261]
## Dirección que empuja cada metatile de flecha (MB_WALK_*).
const DIRECCION_FLECHA: Dictionary = {
	0x260: Vector2.RIGHT, 0x261: Vector2.LEFT, 0x262: Vector2.UP, 0x263: Vector2.DOWN,
	0x27B: Vector2.LEFT, 0x27C: Vector2.RIGHT,
}
const METATILE_PALANCA_APAGADA: int = 0x23E
const METATILE_PALANCA_ENCENDIDA: int = 0x23F

const ID_PAD: StringName = &"pad_teletransporte"
const CELDA_PAD: Vector2i = Vector2i(9, 2)
## `warpteleport MAP_ROUTE110_TRICK_HOUSE_PUZZLE7, 255, 3, 19`.
const CELDA_DESTINO_PAD: Vector2i = Vector2i(3, 19)
const ESCENA: String = "ruta_110_casa_treta_prueba7"
## delay 32 (fotogramas a 60 por segundo) antes de cambiar la palanca.
const ESPERA_PALANCA: int = 32
## SE_CLICK (id 36 de songs.h), extraído del APU de la GBA.
const SONIDO_CLICK: String = "SE_CLICK"
const SONIDO_TELETRANSPORTE: String = "SE_WARP_IN"

## Las cinco palancas, en orden Switch1..5 (CartelEvento).
@export var palancas: Array[NodePath] = []

## Veces que se teletransportó el jugador en esta visita (tests y depuración).
var teletransportes: int = 0


func _preparar() -> void:
	var viene_del_pad := SistemaGuardado.get_contador(HistoriaCasaTreta.CONTADOR_P7_TELETRANSPORTE) == 1
	if viene_del_pad:
		# OnLoad: UpdateSwitchMetatiles repinta palancas y flechas de los activos.
		for numero in range(1, NUMERO_INTERRUPTORES + 1):
			if HistoriaCasaTreta.interruptor_p7(numero):
				_aplicar_interruptor(numero, true)
	else:
		# OnTransition: clearflag FLAG_TRICK_HOUSE_PUZZLE_7_SWITCH_1..5.
		for numero in range(1, NUMERO_INTERRUPTORES + 1):
			HistoriaCasaTreta.fijar_interruptor_p7(numero, false)
	# OnFrame: ClearState2.
	SistemaGuardado.set_contador(HistoriaCasaTreta.CONTADOR_P7_TELETRANSPORTE, 0)
	for indice in palancas.size():
		var cartel := get_node_or_null(palancas[indice])
		if cartel is CartelEvento:
			cartel.accionado.connect(_on_palanca.bind(indice + 1))


func _on_palanca(_cartel: CartelEvento, numero: int) -> void:
	await accionar_palanca(numero)


func _on_disparador(id_evento: StringName) -> void:
	if id_evento == ID_PAD:
		await teletransportar()


## `Route110_TrickHousePuzzle7_EventScript_SwitchN`.
func accionar_palanca(numero: int) -> void:
	if numero < 1 or numero > NUMERO_INTERRUPTORES or _en_curso or not comenzar(_administrador()):
		return
	await esperar_fotogramas(ESPERA_PALANCA)
	var activa := not HistoriaCasaTreta.interruptor_p7(numero)
	_aplicar_interruptor(numero, activa)
	_sonido(SONIDO_CLICK)
	HistoriaCasaTreta.fijar_interruptor_p7(numero, activa)
	terminar()


## SetSwitchNMetatilesOn / Off: palanca y flecha (metatile + banderas de empuje).
func _aplicar_interruptor(numero: int, activa: bool) -> void:
	var indice := numero - 1
	poner_metatile(PALANCAS[indice], METATILE_PALANCA_ENCENDIDA if activa else METATILE_PALANCA_APAGADA, true)
	var flecha := FLECHA_ENCENDIDA[indice] if activa else FLECHA_APAGADA[indice]
	poner_metatile(FLECHAS[indice], flecha, false)
	# Los dos MB_WALK_* de la flecha: la celda deja de empujar a un lado y empuja al otro.
	SueloForzado.fijar_cinta(get_node_or_null(datos_tiles) as TPTileDataMap, FLECHAS[indice],
			DIRECCION_FLECHA[flecha], false)


## Interruptor n encendido en la escena (por su palanca).
func interruptor_activo(numero: int) -> bool:
	return atlas_en_celda(PALANCAS[numero - 1]) == atlas_de_metatile(METATILE_PALANCA_ENCENDIDA)


## `Route110_TrickHousePuzzle7_EventScript_1632A8`: lockall; STATE_2 = 1;
## warpteleport al mismo mapa, (3,19); waitstate; releaseall.
func teletransportar() -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	var adm := _administrador()
	teletransportes += 1
	SistemaGuardado.set_contador(HistoriaCasaTreta.CONTADOR_P7_TELETRANSPORTE, 1)
	_sonido(SONIDO_TELETRANSPORTE)
	var mirada := Vector2.UP
	var jugador: Node = adm.get("jugador")
	if jugador != null and jugador.get("facing_direction") is Vector2:
		mirada = jugador.facing_direction
	terminar()
	adm.conectar_escalera(ESCENA, Vector2(CELDA_DESTINO_PAD), mirada)
