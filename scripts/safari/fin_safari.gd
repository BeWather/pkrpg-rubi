## fin_safari.gd
## Final de la partida SAFARI (pokeruby `data/scripts/safari_zone.inc` y `SafariZoneRetirePrompt`):
##
##   PASOS / BALLS (gUnknown_081C3448 y gUnknown_081C3459): lockall, SE_DING_DONG, mensaje que
##   espera el botón, releaseall y EventScript_1C341B.
##   RETIRADA (gUnknown_081C342D, opción RETIRARSE del menú de pausa): «¿Quieres salir de la ZONA
##   SAFARI ahora mismo?» con SÍ/NO; NO no cambia nada.
##
## EventScript_1C341B: VAR_SAFARI_ZONE_STATE = 1, ExitSafariMode y warp a la ENTRADA (2,5). Al
## llegar, `EventoSafariEntrada` saca al jugador del pasillo (ON_FRAME del mapa).
##
## Lo crea `AdministradorMapa.finalizar_safari()` (el contador de pasos y, cuando exista el combate
## SAFARI, las BALLS) y se libera solo al acabar.
extends EventoGuionizado
class_name FinSafari

const MOTIVO_PAUSA: StringName = &"fin_safari"
## MAP_ROUTE121_SAFARI_ZONE_ENTRANCE, warp (2,5).
const MAPA_ENTRADA: String = "zona_safari_entrada"
const CELDA_ENTRADA := Vector2(2, 5)
## SE_DING_DONG (SE_PINPON, número 73): Audio/SE-AVXS/073_SE_DING_DONG.wav, registrado en `Singleton.se`
## (ver documentacion/20261019-extraccion-se-tanda3.md).
const SONIDO_FIN: String = "SE_DING_DONG"
const TEXTO_PREGUNTA: String = "SAFARI_SALIR_PREGUNTA"

## Terminó el guion: `salio` es false si el jugador dijo NO al retirarse.
signal finalizado(salio: bool)

## Motivo (SesionSafari.Motivo) con el que se lanzó el guion.
var motivo: int = SesionSafari.Motivo.PASOS


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


## Devuelve true si la partida terminó (el jugador va hacia la ENTRADA).
func iniciar(administrador: Node, motivo_fin: int) -> bool:
	motivo = motivo_fin
	if not comenzar(administrador):  # lockall
		finalizado.emit(false)
		return false
	if motivo == SesionSafari.Motivo.RETIRADA:
		if not await preguntar_si_no(TEXTO_PREGUNTA):
			terminar()  # releaseall
			finalizado.emit(false)
			return false
	else:
		sonar_fin()
		await mensaje(str(SesionSafari.TEXTO_FIN[motivo]))  # message + waitbuttonpress
	await _salir()
	return true


## playse SE_DING_DONG.
func sonar_fin() -> void:
	Singleton.play_sound.emit(SONIDO_FIN)


## EventScript_1C341B: setvar VAR_SAFARI_ZONE_STATE, 1 + ExitSafariMode + warp.
func _salir() -> void:
	SesionSafari.fijar_estado_zona(SesionSafari.Estado.TERMINADA)
	SesionSafari.salir()
	var adm := admin
	terminar()  # releaseall
	adm.conectar_escalera(MAPA_ENTRADA, CELDA_ENTRADA, Vector2.UP)
	finalizado.emit(true)
