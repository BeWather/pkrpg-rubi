extends RefCounted
class_name BattlePhaseController
## Etapa 5 (parcial) del cambio SDD `2026-09-14-battle-architecture-split`:
## dueño de la máquina de estados de batalla (fase, subfase de inicio, fase
## de ronda). Cumple la delta de la spec `battle-state-machine`: quien pide
## transiciones ahora es esta clase, no `batalla.gd` directamente — ver
## `openspec/changes/2026-09-14-battle-architecture-split/specs/battle-state-machine/spec.md`.
##
## Alcance de esta etapa (ver tasks.md): SOLO la propiedad de la máquina de
## estados. `ejecutar_ronda()`, `revisar_ronda()`, `turno_jugador()`,
## `turno_enemigo()` y la selección de acción de la IA (~700 líneas,
## territorio de un futuro `BattleTurnController`) y
## victoria/derrota/experiencia/captura/cambio de Pokémon (~600 líneas,
## territorio de un futuro `BattleResultController`) quedan sin extraer en
## `batalla.gd` — están profundamente entrelazadas entre sí y con el resto
## de la lógica de turno, y merecen su propio paso con la misma
## rigurosidad que esta clase, no una extracción apurada dentro de la misma
## sesión que ya cubrió las Etapas 1-4. Ver design.md.

var maquina := MaquinaEstadosBatalla.nueva()

var fase: int:
	get: return maquina.fase_actual

var subfase_inicio: int:
	get: return maquina.subfase_inicio_actual

var fase_ronda: int:
	get: return maquina.fase_ronda_actual


func cambiar_fase(destino: int) -> bool:
	return maquina.cambiar_fase(destino)


func cambiar_fase_ronda(destino: int) -> bool:
	return maquina.cambiar_fase_ronda(destino)


func avanzar_subfase_inicio() -> void:
	maquina.avanzar_subfase_inicio()


func reiniciar_subfase_inicio() -> void:
	maquina.reiniciar_subfase_inicio()
