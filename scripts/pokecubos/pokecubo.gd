class_name Pokecubo
extends RefCounted
## Un POKéCUBO (`struct Pokeblock` de pokeruby, include/global.h:190-199): color, los
## cinco sabores y la suavidad (`feel`). El color se calcula al licuar
## (ReglasLicuadora.calcular_pokecubo) y no se guarda nada más.
##
## Un hueco del estuche está vacío cuando `color == ColorPokecubo.VACIO`
## (GetFirstFreePokeblockSlot, src/pokeblock.c:1060-1071).
##
## Orden de los sabores en todo el módulo (FLAVOUR_* del decomp):
## 0 picante, 1 seco, 2 dulce, 3 amargo, 4 ácido.

## include/pokeblock.h:4-20 (PBLOCK_CLR_*), mismo valor numérico.
enum ColorPokecubo {
	VACIO,
	ROJO,
	AZUL,
	ROSA,
	VERDE,
	AMARILLO,
	MORADO,
	INDIGO,
	MARRON,
	AZUL_CLARO,
	OLIVA,
	GRIS,
	NEGRO,
	BLANCO,
	DORADO,
}

const NUM_SABORES: int = 5
const VALOR_MAXIMO: int = 255
## sub_810C9E8: la suavidad mostrada nunca pasa de 99.
const SUAVIDAD_MOSTRADA_MAXIMA: int = 99
## Claves de los sabores (y de to_dict) en el orden del decomp.
const CLAVES_SABOR: Array[String] = ["picante", "seco", "dulce", "amargo", "acido"]
## Claves de traducción de los nombres (gPokeblockNames, src/pokeblock.c:129-149),
## indexadas por ColorPokecubo. "" para el hueco vacío (NULL en el decomp).
const CLAVES_NOMBRE: Array[String] = [
	"",
	"POKECUBO_ROJO",
	"POKECUBO_AZUL",
	"POKECUBO_ROSA",
	"POKECUBO_VERDE",
	"POKECUBO_AMARILLO",
	"POKECUBO_MORADO",
	"POKECUBO_INDIGO",
	"POKECUBO_MARRON",
	"POKECUBO_AZUL_CLARO",
	"POKECUBO_OLIVA",
	"POKECUBO_GRIS",
	"POKECUBO_NEGRO",
	"POKECUBO_BLANCO",
	"POKECUBO_DORADO",
]

var color: int = ColorPokecubo.VACIO
var picante: int = 0
var seco: int = 0
var dulce: int = 0
var amargo: int = 0
var acido: int = 0
## `feel` del decomp. Puede valer más de 99; solo se recorta al mostrarlo.
var suavidad: int = 0


## Crea un cubo con `sabores` = [picante, seco, dulce, amargo, ácido]. Los valores se
## recortan a 0..255 (son u8 en el decomp).
static func crear(color_cubo: int, sabores: Array, suavidad_cubo: int) -> Pokecubo:
	var cubo := Pokecubo.new()
	cubo.color = clampi(color_cubo, 0, ColorPokecubo.DORADO)
	for i in NUM_SABORES:
		cubo.establecer_sabor(i, int(sabores[i]) if i < sabores.size() else 0)
	cubo.suavidad = clampi(suavidad_cubo, 0, VALOR_MAXIMO)
	return cubo


## Reconstruye un cubo desde `to_dict()` (el JSON deja los números en float).
static func from_dict(d: Dictionary) -> Pokecubo:
	var sabores: Array = []
	for clave in CLAVES_SABOR:
		sabores.append(int(d.get(clave, 0)))
	return crear(int(d.get("color", ColorPokecubo.VACIO)), sabores, int(d.get("suavidad", 0)))


func to_dict() -> Dictionary:
	return {
		"color": color,
		"picante": picante,
		"seco": seco,
		"dulce": dulce,
		"amargo": amargo,
		"acido": acido,
		"suavidad": suavidad,
	}


func duplicar() -> Pokecubo:
	return Pokecubo.from_dict(to_dict())


func esta_vacio() -> bool:
	return color == ColorPokecubo.VACIO


## Valor del sabor `indice` (0 picante … 4 ácido); 0 si el índice no existe.
func sabor(indice: int) -> int:
	match indice:
		0:
			return picante
		1:
			return seco
		2:
			return dulce
		3:
			return amargo
		4:
			return acido
	return 0


func establecer_sabor(indice: int, valor: int) -> void:
	var v: int = clampi(valor, 0, VALOR_MAXIMO)
	match indice:
		0:
			picante = v
		1:
			seco = v
		2:
			dulce = v
		3:
			amargo = v
		4:
			acido = v


## [picante, seco, dulce, amargo, ácido].
func sabores() -> Array[int]:
	return [picante, seco, dulce, amargo, acido]


## «Nivel» que muestran el estuche y la licuadora: el sabor más alto
## (sub_810C9B0, src/pokeblock.c:1036-1050).
func nivel() -> int:
	return maxi(maxi(maxi(picante, seco), maxi(dulce, amargo)), acido)


## Suavidad que se muestra: min(feel, 99) (sub_810C9E8, src/pokeblock.c:1052-1058).
func suavidad_mostrada() -> int:
	return mini(suavidad, SUAVIDAD_MOSTRADA_MAXIMA)


## Clave de traducción del nombre del color («POKéCUBO ROJO»…); "" si está vacío.
func clave_nombre() -> String:
	return clave_nombre_de_color(color)


static func clave_nombre_de_color(color_cubo: int) -> String:
	if color_cubo < 0 or color_cubo >= CLAVES_NOMBRE.size():
		return ""
	return CLAVES_NOMBRE[color_cubo]
