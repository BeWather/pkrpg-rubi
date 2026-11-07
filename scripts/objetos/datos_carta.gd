class_name DatosCarta
extends RefCounted

## Contenido de una CARTA tal como la lee la pantalla de cartas (PantallaCarta):
## equivalente a struct MailStruct de pokeruby (include/global.h) más el diseño
## que elige HandleReadMail (src/mail.c).
##
## Rubí guarda las cartas en gSaveBlock1.mail con 9 palabras de PALABRAS FÁCILES
## (EASY_CHAT), el nombre de quien la escribió y la especie del Pokémon que la
## lleva. Aquí se guardan en BasePokemon.carta (ver escribir()); una carta
## llevada sin contenido (partidas anteriores) se lee firmada por el jugador.

## Tipos de carta en el orden de ITEM_ORANGE_MAIL..ITEM_RETRO_MAIL (itemId - 0x79
## en HandleReadMail) y nombre de su fondo en graficos/cartas/.
const TIPOS: Array[String] = [
	"orange", "harbor", "glitter", "mech", "wood", "wave",
	"bead", "shadow", "tropic", "dream", "fab", "retro",
]
## nombre_interno (Objetos de poke.db) → índice en TIPOS.
const TIPO_POR_OBJETO: Dictionary = {
	"CARNARANJA": 0, "CARTAPUERTO": 1, "CARTABRILLO": 2, "CARTAIMAN": 3,
	"CARTAMADERA": 4, "CARTAOLA": 5, "CARTAIMAGEN": 6, "CARTASOMBRA": 7,
	"CARTROPIC": 8, "CARTASUENO": 9, "CARTAFAB": 10, "CARTARETRO": 11,
}
const TIPO_IMAGEN: int = 6
const TIPO_SUENO: int = 9
const TIPO_FAB: int = 10

## Palabras por línea (Unknown_3E5790, diseño «overseas» de gUnknown_083E57A4).
const PALABRAS_POR_LINEA: Array[int] = [2, 2, 2, 2, 1]
const TOTAL_PALABRAS: int = 9

## Tipo de carta (índice en TIPOS).
var tipo: int = 0
## 9 palabras ya traducidas; "" = hueco vacío.
var palabras: Array[String] = []
## Nombre de quien la escribió (playerName).
var autor: String = ""
## Número nacional del Pokémon que la lleva (0 = ninguno: sin icono).
var especie: int = 0
## false = solo el fondo (ItemMenu_ReadMail pasa arg2 = 0 al leer desde la mochila).
var con_texto: bool = true


func _init() -> void:
	palabras.resize(TOTAL_PALABRAS)
	palabras.fill("")


## Índice de tipo de una CARTA por nombre_interno. Las cartas que no son de Rubí
## (p. ej. CARTAHIERBA) usan el diseño 0, como HandleReadMail con !IS_ITEM_MAIL.
static func tipo_de_objeto(nombre_interno: String) -> int:
	return int(TIPO_POR_OBJETO.get(nombre_interno.strip_edges().to_upper(), 0))


## ItemMenu_ReadMail: carta vacía de la mochila, solo el fondo.
static func desde_objeto(nombre_interno: String) -> DatosCarta:
	var carta := DatosCarta.new()
	carta.tipo = tipo_de_objeto(nombre_interno)
	carta.con_texto = false
	return carta


## PokemonMenu_ReadMail: la carta que lleva `pokemon`. Si no tiene contenido
## guardado, sin palabras y firmada por `autor_carta`.
static func desde_pokemon(pokemon: BasePokemon, autor_carta: String) -> DatosCarta:
	var carta := DatosCarta.new()
	carta.tipo = tipo_de_objeto(pokemon.objeto)
	carta.autor = str(pokemon.carta.get("autor", autor_carta))
	carta.especie = int(pokemon.carta.get("especie", pokemon.numero_nacional))
	var ids: Array[int] = ids_de(pokemon)
	for i in TOTAL_PALABRAS:
		carta.palabras[i] = PalabrasFaciles.texto(ids[i])
	return carta


## Ids de las 9 palabras de la carta que lleva `pokemon` (vacías si no hay).
static func ids_de(pokemon: BasePokemon) -> Array[int]:
	var ids: Array[int] = []
	ids.resize(TOTAL_PALABRAS)
	ids.fill(PalabrasFaciles.PALABRA_VACIA)
	var guardadas: Variant = pokemon.carta.get("palabras", [])
	if guardadas is Array:
		for i in mini((guardadas as Array).size(), TOTAL_PALABRAS):
			ids[i] = int((guardadas as Array)[i])
	return ids


## Guarda en `pokemon` la carta escrita (GiveMailToMon de mail_data.c y las
## palabras de la PALABRAS FÁCILES: playerName, trainerId y especie).
static func escribir(pokemon: BasePokemon, ids: Array[int], autor_carta: String, id_entrenador: int) -> void:
	var palabras_guardadas: Array = []
	for i in TOTAL_PALABRAS:
		palabras_guardadas.append(ids[i] if i < ids.size() else PalabrasFaciles.PALABRA_VACIA)
	pokemon.carta = {
		"palabras": palabras_guardadas,
		"autor": autor_carta,
		"id_entrenador": id_entrenador,
		"especie": pokemon.numero_nacional,
	}


## Líneas de texto (sub_80F8DA0): las palabras de cada línea separadas por un
## espacio. Las líneas vacías se devuelven como "" (sub_80F8E80 las salta).
func lineas() -> Array[String]:
	var resultado: Array[String] = []
	var indice: int = 0
	for cantidad in PALABRAS_POR_LINEA:
		var partes: PackedStringArray = []
		for i in cantidad:
			var palabra: String = palabras[indice + i] if indice + i < palabras.size() else ""
			if not palabra.is_empty():
				partes.append(palabra)
		resultado.append(" ".join(partes))
		indice += cantidad
	return resultado


## Firma (sub_80F8DA0 con var100 = 1): gOtherText_From («De ») + nombre.
## `plantilla` es el texto CARTA_FIRMA con {autor}.
func firma(plantilla: String) -> String:
	return plantilla.replace("{autor}", autor)


## Hueco del icono del Pokémon (varFB): CARTA IMAGEN y CARTA SUEÑO lo muestran
## si hay especie válida (1..411 internas en Rubí; aquí, número nacional).
## Devuelve la posición del centro o Vector2(-1, -1) si no hay.
func posicion_icono() -> Vector2:
	if not con_texto or especie < 1 or especie > 386:
		return Vector2(-1, -1)
	match tipo:
		TIPO_IMAGEN:
			return Vector2(96, 128)
		TIPO_SUENO:
			return Vector2(40, 128)
	return Vector2(-1, -1)


## Posición de la firma en píxeles (var2, var1 en tiles de gUnknown_083E57A4).
func posicion_firma() -> Vector2:
	var x: int = 16 if tipo in [2, 5, 6] else 15
	var y: int = 16 if tipo == TIPO_FAB else 15
	return Vector2(x * 8, y * 8)


## Fondo según el sexo del jugador (gUnknown_083E562C cambia los colores 10 y 11).
func ruta_fondo(sexo_jugador: String) -> String:
	var sufijo: String = "chica" if sexo_jugador.to_upper() == "F" else "chico"
	return "res://graficos/cartas/carta_%s_%s.png" % [TIPOS[tipo], sufijo]


## Colores del texto (color10 / color12 de gMailGraphicsTable): claro u oscuro.
func texto_claro() -> bool:
	return tipo in [1, 3, 4, 6, 7]
