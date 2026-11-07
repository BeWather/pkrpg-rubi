## cartel_condicional.gd
## Cartel (bg_event de pokeruby) cuyo texto cambia con el progreso, p. ej. el
## del PUERTO de CIUDAD PORTUAL (goto_if_set FLAG_SYS_GAME_CLEAR). Ver
## CondicionTexto; sin ninguna condición cumplida muestra id_texto.
@tool
extends Signpost
class_name CartelCondicional

@export var textos_condicionales: Dictionary[String, String] = {}


func accionar_cartel() -> void:
	Singleton.mostrar_texto(tr(CondicionTexto.resolver(textos_condicionales, id_texto)))
