## evento_rival.gd
## Parte común de los encuentros con el rival (AURA / BRUNO). Cada mapa tiene una
## subclase con su coreografía (p. ej. evento_rival_ruta_103.gd), que se lee
## línea a línea contra el script del decomp.
##
## Aquí solo va lo que comparten todos los encuentros:
## - textos: "<prefijo_textos>_<AURA|BRUNO>_<sufijo>" en dialogos.csv;
## - combate contra el equipo que toca según el inicial (Rival.entrenador_id);
## - música de encuentro (MUS_ENCOUNTER_MAY / MUS_ENCOUNTER_BRENDAN);
## - bandera que marca el encuentro como completado.
extends EventoGuionizado
class_name EventoRival

## Clave del encuentro en Rival.ENCUENTROS (&"ruta_103", &"ruta_110"…).
@export var encuentro: StringName = &""
## Prefijo de las claves de diálogo, p. ej. "RUTA103_RIVAL".
@export var prefijo_textos: String = ""
## Bandera de SistemaGuardado que se activa al vencer al rival.
@export var bandera_completado: String = ""


func _init() -> void:
	motivo_pausa = &"evento_rival"


func texto(sufijo: String) -> String:
	return "%s_%s_%s" % [prefijo_textos, Rival.clave(), sufijo]


func completado() -> bool:
	return not bandera_completado.is_empty() and SistemaGuardado.get_flag(bandera_completado)


func marcar_completado() -> void:
	SistemaGuardado.set_flag(bandera_completado, true)


## playbgm MUS_ENCOUNTER_MAY / MUS_ENCOUNTER_BRENDAN.
func reproducir_musica_encuentro() -> void:
	reproducir_musica(Rival.musica_encuentro())


## trainerbattle_no_intro contra el equipo del rival según el inicial. Tras
## ganar vuelve la música de encuentro (en Rubí sigue sonando hasta
## fadedefaultbgm).
func combatir_rival() -> StringName:
	var resultado := await combatir(Rival.entrenador_id(encuentro))
	if resultado == &"victoria":
		reproducir_musica_encuentro()
	return resultado
