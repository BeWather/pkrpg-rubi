class_name VentanaEntradaConcurso
extends CanvasLayer
## ShowContestEntryMonPic (src/contest_util.c:274): ventana con el POKéMON de frente de la
## entrada que se presenta en la sala; sub_80C5164 la cierra.


@onready var _pokemon: Sprite2D = $Marco/Pokemon


func mostrar(c: ConcursanteConcurso) -> void:
	_pokemon.texture = PokemonSpriteManager.cargar_sprite_frente(c.especie, c.shiny, c.personalidad)


func especie_mostrada() -> Texture2D:
	return _pokemon.texture
