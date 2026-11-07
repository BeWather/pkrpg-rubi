extends "res://UI/pokedex/subpantalla_pokedex.gd"
## Pestaña TAM. de la ficha (solo capturados). Basado en
## Task_InitSizeScreenMultistep / Task_HandleSizeScreenInput de
## pokeruby/src/pokedex.c: siluetas negras del POKéMON (izquierda) y del
## jugador (derecha) a escala con pokemonScale/trainerScale de la entrada.
## B vuelve a la ficha (SE_PC_OFF) e izquierda pasa a GRITO (SE_DEX_PAGE).

const ENTRADAS = preload("res://UI/pokedex/entradas_pokedex_es.json")
const RUTA_FRENTE: String = "res://graficos/pokemon/front/%s.png"
const ENTRENADOR_CHICO: Texture2D = preload("res://graficos/trainers64/001.png")
const ENTRENADOR_CHICA: Texture2D = preload("res://graficos/trainers64/002.png")
## gDexText_SizeComparedTo de la ROM ES (con el espacio final).
const TEXTO_COMPARADO: String = "TAMAÑO COMPARADO CON "
## Escala 256 = tamaño real; mayor = más pequeño (matriz afín inversa).
const ESCALA_BASE: float = 256.0

@onready var _pokemon: Sprite2D = $SiluetaPokemon
@onready var _entrenador: Sprite2D = $SiluetaEntrenador
@onready var _texto: Label = $Texto


func _preparar() -> void:
	var ficha: Dictionary = ENTRADAS.data.get(str(int(entrada.get("nacional", 0))), {})
	_pokemon.texture = _obtener_frente()
	_colocar(_pokemon, Vector2(88, 56), int(ficha.get("escala_pokemon", 256)), int(ficha.get("desplazamiento_pokemon", 0)))
	_entrenador.texture = ENTRENADOR_CHICA if es_chica else ENTRENADOR_CHICO
	_colocar(_entrenador, Vector2(152, 56), int(ficha.get("escala_entrenador", 256)), int(ficha.get("desplazamiento_entrenador", 0)))
	_texto.text = TEXTO_COMPARADO + _nombre_jugador()


## Sprite de 64×64 centrado, reducido sobre su centro; el desplazamiento es y2.
func _colocar(sprite: Sprite2D, centro: Vector2, escala: int, desplazamiento: int) -> void:
	sprite.position = centro + Vector2(0, desplazamiento)
	sprite.scale = Vector2.ONE * (ESCALA_BASE / maxf(1.0, escala))


func _obtener_frente() -> Texture2D:
	var ruta := str(entrada.get("sprite", RUTA_FRENTE % str(entrada.get("nombre", "")).to_upper()))
	return load(ruta) as Texture2D if ResourceLoader.exists(ruta) else null


func _nombre_jugador() -> String:
	if SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.jugador:
		return str(SistemaGuardado.datos_vivos.jugador.get("nombre", ""))
	return ""


func _al_pulsar(evento: InputEvent) -> void:
	if evento.is_action_pressed(&"btn_cancelar"):
		salir(Destino.PAGINA, "SE_PC_OFF")
	elif evento.is_action_pressed(&"btn_izquierda"):
		salir(Destino.GRITO, "SE_DEX_PAGE")
