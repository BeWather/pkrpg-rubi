class_name EventoConcurso
extends RefCounted
## Un paso de presentación de un concurso. MotorConcurso calcula un turno entero y
## devuelve la lista de eventos en el orden en que pokeruby los muestra
## (Task_DoAppeals, src/contest.c); la escena los reproduce uno a uno con await.
## Los valores que dependen del estado (corazones, estrellas, iconos) van ya
## calculados en `datos`, porque el estado sigue cambiando antes de reproducirlos.

enum Tipo {
	## {apelacion}: «¡Exhibición n.º N!».
	INICIO_APELACION,
	## No puede actuar (gText_MonWasWatchingOthers).
	OBSERVA,
	## El Pokémon entra en escena (sprite de espalda).
	ENTRA,
	## Demasiado nervioso para actuar (ContestString_TooNervous).
	NERVIOSO,
	## {movimiento}: «¡X se exhibió con MOVIMIENTO!».
	APELA,
	## {movimiento, objetivo}: animación del movimiento en modo concurso.
	ANIMACION,
	## {concursantes}: iconos de «sobresaltado» (DrawUnnervedSymbols).
	INTERFERIDOS,
	## {cadena, actor}: texto de resultado (gUnknown_083CC188[cadena]).
	TEXTO_EFECTO,
	## {simbolo}: bocadillo del juez (EventoConcurso.Simbolo).
	BOCADILLO,
	## Muestra los iconos de orden de la siguiente apelación.
	SIGUIENTE_TURNO,
	## {desde, delta, valor}: animación de corazones de la caja.
	CORAZONES,
	## {condicion}: estrellas de condición.
	ESTRELLAS,
	## {icono}: icono de estado de la caja (EventoConcurso.Icono).
	ICONO_ESTADO,
	## {iconos}: icono de estado de los 4 (DrawStatusSymbols tras los textos de los demás).
	ICONOS_ESTADO,
	## Deja de parpadear el ojo de atención del juez.
	ATENCION_RETIRADA,
	## No podrá exhibirse en la siguiente apelación (ContestString_CantAppealNextTurn).
	NO_PODRA_APELAR,
	## {completado}: combo completado (WentOverWell) o juez expectante (JudgeExpectantly2).
	COMBO,
	## Decepciona por repetir (ContestString_DissapointedRepeat).
	REPETICION,
	## {congelador, movimiento}: el público sigue mirando a otro (CrowdWatches + Ignored2).
	PUBLICO_CONGELADO,
	## {cambio, aplausos, lleno, bonus, categoria, movimiento}: reacción del público.
	PUBLICO,
	## El medidor de aplausos llegó a 5 y vuelve a 0.
	MEDIDOR_REINICIADO,
	## El Pokémon sale de escena.
	SALE,
	## {puntos, orden, nivel_atencion}: fin de una apelación (deslizadores y texto del jugador).
	FIN_APELACION,
	## Fin de las 5 apelaciones (gText_AllOutOfAppealTime).
	FIN_CONCURSO,
}

## DoJudgeSpeechBubble.
enum Simbolo {
	REPETICION = 0,
	EXPECTANTE = 2,
	COMBO = 3,
	ANTES = 5,
	DESPUES = 6,
	BARAJADO = 7,
	CONDICION = 8,
}

## DrawStatusSymbol (GetStatusSymbolTileOffset).
enum Icono {
	NINGUNO = -1,
	PROTEGIDO = 0,
	NERVIOSO = 1,
	SALTA_TURNO = 2,
}

var tipo: Tipo = Tipo.APELA
## Concursante al que se refiere (índice 0..3), -1 si no aplica.
var concursante: int = -1
var datos: Dictionary = {}


static func crear(tipo_evento: Tipo, indice: int = -1, datos_evento: Dictionary = {}) -> EventoConcurso:
	var evento := EventoConcurso.new()
	evento.tipo = tipo_evento
	evento.concursante = indice
	evento.datos = datos_evento
	return evento


func _to_string() -> String:
	return "%s(%d, %s)" % [Tipo.keys()[tipo], concursante, datos]
