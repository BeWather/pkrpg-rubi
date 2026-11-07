## record_tamano.gd
## Récords de tamaño de POKéMON (pokeruby src/pokemon_size_record.c), los de la CASA de los
## hermanos de ARRECÍPOLIS: BARBOACH (VAR_BARBOACH_SIZE_RECORD) y SHROOMISH
## (VAR_SHROOMISH_SIZE_RECORD). Parte pura: el guion vive en EventoCasasArrecipolis.
##
## El tamaño sale de un hash de 16 bits (GetMonSizeHash: personalidad baja y los 4 bits bajos
## de cada IV) que sBigMonSizeTable convierte en un factor sobre la altura de la POKéDEX. Se
## guarda el hash, no el tamaño. El récord de partida es 0x8100 a nombre de MARCO
## (Init*SizeRecord y gOtherText_Marco). Los tamaños van en décimas de centímetro.
class_name RecordTamano
extends RefCounted

enum Resultado {
	CANCELADO = 0,	## gSpecialVar_Result == 0xFF
	OTRA_ESPECIE = 1,
	MAS_PEQUENO = 2,	## newSize <= oldSize
	NUEVO_RECORD = 3,
}

const RECORD_INICIAL: int = 0x8100
const NOMBRE_RECORD_INICIAL: String = "MARCO"
const BARBOACH: String = "BARBOACH"
const SHROOMISH: String = "SHROOMISH"
## Contadores de SistemaGuardado (guardan hash + 1; 0 = sin tocar = RECORD_INICIAL).
const CONTADORES := {
	BARBOACH: "arrecipolis_record_barboach",
	SHROOMISH: "arrecipolis_record_shroomish",
}

## sBigMonSizeTable: {factor base, divisor, umbral}.
const TABLA := [
	[290, 1, 0], [300, 1, 10], [400, 2, 110], [500, 4, 310], [600, 20, 710], [700, 50, 2710],
	[800, 100, 7710], [900, 150, 17710], [1000, 150, 32710], [1100, 100, 47710], [1200, 50, 57710],
	[1300, 20, 62710], [1400, 5, 64710], [1500, 2, 65210], [1600, 1, 65410], [1700, 1, 65510],
]


## GetMonSizeHash (truncado a 16 bits, como el u16 sizeParams de CompareMonSize).
static func hash_tamano(pokemon: BasePokemon) -> int:
	var personalidad: int = pokemon.personalidad & 0xFFFF
	var hp: int = pokemon.iv_ps & 0xF
	var ataque: int = pokemon.iv_ataque & 0xF
	var defensa: int = pokemon.iv_defensa & 0xF
	var velocidad: int = pokemon.iv_velocidad & 0xF
	var ataque_esp: int = pokemon.iv_ataque_especial & 0xF
	var defensa_esp: int = pokemon.iv_defensa_especial & 0xF
	var alto: int = ((ataque ^ defensa) * hp) ^ (personalidad & 0xFF)
	var bajo: int = ((ataque_esp ^ defensa_esp) * velocidad) ^ (personalidad >> 8)
	return ((alto << 8) + bajo) & 0xFFFF


## TranslateBigMonSizeTableIndex.
static func indice_tabla(valor: int) -> int:
	for i in range(1, 15):
		if valor < TABLA[i][2]:
			return i - 1
	return 15


## GetMonSize: altura de la POKéDEX (decímetros) por el factor de la tabla, en décimas de cm.
static func tamano(altura_dm: int, valor: int) -> int:
	var fila: Array = TABLA[indice_tabla(valor)]
	var factor: int = int(fila[0]) + int((valor - int(fila[2])) / int(fila[1]))
	return altura_dm * factor / 10


## Altura de la especie en decímetros (la tabla Pokemon la guarda en metros).
static func altura_dm(nombre_interno: String) -> int:
	var datos: Dictionary = DatabaseManager.obtener_datos_pokemon(nombre_interno)
	return roundi(float(datos.get("altura", 0.0)) * 10.0)


## FormatMonSizeRecord: "40,6" en cm; con `pulgadas` (UNITS_IMPERIAL de la versión inglesa) "16.0".
static func formatear(decimas_cm: int, pulgadas: bool = false) -> String:
	var valor := decimas_cm
	var separador := ","
	if pulgadas:
		valor = int(float(decimas_cm * 10) / (2.54 * 10.0))
		separador = "."
	return "%d%s%d" % [valor / 10, separador, valor % 10]


## Texto del tamaño en las unidades del idioma activo.
static func formatear_local(decimas_cm: int) -> String:
	return formatear(decimas_cm, TranslationServer.get_locale().begins_with("en"))


## Hash del récord guardado de la especie.
static func record(especie: String) -> int:
	var guardado: int = SistemaGuardado.get_contador(CONTADORES[especie])
	return RECORD_INICIAL if guardado <= 0 else guardado - 1


static func fijar_record(especie: String, valor: int) -> void:
	SistemaGuardado.set_contador(CONTADORES[especie], (valor & 0xFFFF) + 1)


## GetMonSizeRecordInfo: {nombre, tamano (décimas de cm)} del récord actual.
static func info_record(especie: String) -> Dictionary:
	var valor := record(especie)
	var nombre: String = NOMBRE_RECORD_INICIAL if valor == RECORD_INICIAL else SistemaGuardado.get_nombre_jugador()
	return {"nombre": nombre, "tamano": tamano(altura_dm(especie), valor)}


## CompareMonSize. Devuelve {resultado: Resultado, tamano: décimas de cm del mostrado}; con un
## récord nuevo lo guarda.
static func comparar(especie: String, pokemon: BasePokemon) -> Dictionary:
	if pokemon == null:
		return {"resultado": Resultado.CANCELADO, "tamano": 0}
	if pokemon.huevo or pokemon.nombre_interno != especie:
		return {"resultado": Resultado.OTRA_ESPECIE, "tamano": 0}
	var altura := altura_dm(especie)
	var valor := hash_tamano(pokemon)
	var nuevo := tamano(altura, valor)
	if nuevo <= tamano(altura, record(especie)):
		return {"resultado": Resultado.MAS_PEQUENO, "tamano": nuevo}
	fijar_record(especie, valor)
	return {"resultado": Resultado.NUEVO_RECORD, "tamano": nuevo}
