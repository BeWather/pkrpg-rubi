extends RefCounted
## Datos de 3.ª gen para la POKéDEX que poke.db no tiene o tiene con valores
## actuales. Generado desde pokeruby: include/constants/species.h (HOENN_DEX_*,
## comprobado con gHoennToNationalOrder de src/pokemon_1.c) y
## src/data/pokemon/base_stats.h (type1/type2 y bodyColor). Altura y peso de
## la BD coinciden con src/data/pokedex_entries_en.h. La cuadrícula del mapa
## sale de src/data/region_map/region_map_layout.h.

const TOTAL_HOENN: int = 202

## N.º nacional de cada especie de la POKéDEX de HOENN; índice = n.º Hoenn - 1.
const HOENN_A_NACIONAL: PackedInt32Array = [
	252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263,
	264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275,
	276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287,
	288, 289, 63, 64, 65, 290, 291, 292, 293, 294, 295, 296,
	297, 118, 119, 129, 130, 298, 183, 184, 74, 75, 76, 299,
	300, 301, 41, 42, 169, 72, 73, 302, 303, 304, 305, 306,
	66, 67, 68, 307, 308, 309, 310, 311, 312, 81, 82, 100,
	101, 313, 314, 43, 44, 45, 182, 84, 85, 315, 316, 317,
	318, 319, 320, 321, 322, 323, 218, 219, 324, 88, 89, 109,
	110, 325, 326, 27, 28, 327, 227, 328, 329, 330, 331, 332,
	333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344,
	345, 346, 347, 348, 174, 39, 40, 349, 350, 351, 120, 121,
	352, 353, 354, 355, 356, 357, 358, 359, 37, 38, 172, 25,
	26, 54, 55, 360, 202, 177, 178, 203, 231, 232, 127, 214,
	111, 112, 361, 362, 363, 364, 365, 366, 367, 368, 369, 222,
	170, 171, 370, 116, 117, 230, 371, 372, 373, 374, 375, 376,
	377, 378, 379, 380, 381, 382, 383, 384, 385, 386,
]

## Tipos de Rubí donde la BD tiene los actuales (HADA no existe en 3.ª gen).
## Clave: n.º nacional; valores con Tipos.nombre.
const TIPOS_GEN3: Dictionary = {
	35: ["NORMAL"],
	36: ["NORMAL"],
	39: ["NORMAL"],
	40: ["NORMAL"],
	122: ["PSIQUICO"],
	173: ["NORMAL"],
	174: ["NORMAL"],
	175: ["NORMAL"],
	176: ["NORMAL", "VOLADOR"],
	183: ["AGUA"],
	184: ["AGUA"],
	209: ["NORMAL"],
	210: ["NORMAL"],
	280: ["PSIQUICO"],
	281: ["PSIQUICO"],
	282: ["PSIQUICO"],
	298: ["NORMAL"],
	303: ["ACERO"],
}

## bodyColor de Rubí donde la BD tiene otro color.
const COLORES_GEN3: Dictionary = {
	351: "White",
}

## sRegionMapLayout (src/data/region_map/region_map_layout.h): 28×15 casillas
## del mapa de HOENN con la sección de cada una (claves de
## MapaConfiguracion.seccion; "" = mar o tierra sin sección). Permite iluminar
## secciones con forma irregular (RUTA_114 en L) casilla a casilla.
const ANCHO_CUADRICULA: int = 28
const ALTO_CUADRICULA: int = 15
const CUADRICULA_HOENN: PackedStringArray = [
	"", "RUTA_114", "RUTA_114", "PUEBLO_PARDAL", "RUTA_113", "RUTA_113", "RUTA_113", "RUTA_113", "RUTA_111", "", "", "RUTA_119", "CIUDAD_ARBORADA", "RUTA_120", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
	"", "RUTA_114", "", "", "", "", "MONTE_CENIZO", "MONTE_CENIZO", "RUTA_111", "", "", "RUTA_119", "", "RUTA_120", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
	"RUTA_115", "RUTA_114", "", "", "", "", "MONTE_CENIZO", "MONTE_CENIZO", "RUTA_111", "", "", "RUTA_119", "", "RUTA_120", "", "", "ZONA_SAFARI", "", "", "", "", "", "", "", "", "", "", "",
	"RUTA_115", "", "", "", "", "PUEBLO_LAVACALDA", "RUTA_112", "RUTA_112", "RUTA_111", "", "", "RUTA_119", "", "RUTA_120", "RUTA_121", "RUTA_121", "RUTA_121", "RUTA_121", "CIUDAD_CALAGUA", "CIUDAD_CALAGUA", "RUTA_124", "RUTA_124", "RUTA_124", "RUTA_124", "RUTA_125", "RUTA_125", "", "",
	"RUTA_115", "", "", "", "", "", "", "", "RUTA_111", "", "", "RUTA_119", "", "", "", "", "RUTA_122", "", "", "", "RUTA_124", "RUTA_124", "RUTA_124", "RUTA_124", "RUTA_125", "RUTA_125", "", "",
	"CIUDAD_FERRICA", "RUTA_116", "RUTA_116", "RUTA_116", "RUTA_116", "", "", "", "RUTA_111", "", "", "RUTA_119", "", "", "", "", "RUTA_122", "", "", "", "RUTA_124", "RUTA_124", "RUTA_124", "RUTA_124", "CIUDAD_ALGARIA", "CIUDAD_ALGARIA", "", "",
	"CIUDAD_FERRICA", "", "", "", "PUEBLO_VERDEGAL", "RUTA_117", "RUTA_117", "RUTA_117", "CIUDAD_MALVALONA", "CIUDAD_MALVALONA", "RUTA_118", "RUTA_118", "RUTA_123", "RUTA_123", "RUTA_123", "RUTA_123", "RUTA_123", "", "", "", "RUTA_126", "RUTA_126", "RUTA_126", "RUTA_127", "RUTA_127", "RUTA_127", "", "",
	"RUTA_104", "", "", "", "", "", "", "", "RUTA_110", "", "", "", "", "", "", "", "", "", "", "", "RUTA_126", "ARRECIPOLIS", "RUTA_126", "RUTA_127", "RUTA_127", "RUTA_127", "", "",
	"RUTA_104", "", "", "", "RUTA_103", "RUTA_103", "RUTA_103", "RUTA_103", "RUTA_110", "", "", "", "", "", "", "", "", "", "", "", "RUTA_126", "RUTA_126", "RUTA_126", "RUTA_127", "RUTA_127", "RUTA_127", "", "CIUDAD_COLOSALIA",
	"RUTA_104", "CIUDAD_PETALIA", "RUTA_102", "RUTA_102", "PUEBLO_ESCASO", "", "", "", "RUTA_110", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "RUTA_128", "RUTA_128", "RUTA_128", "RUTA_128", "CIUDAD_COLOSALIA",
	"RUTA_105", "", "", "", "RUTA_101", "", "", "", "CIUDAD_PORTUAL", "RUTA_134", "RUTA_134", "RUTA_134", "RUTA_133", "RUTA_133", "RUTA_133", "RUTA_132", "RUTA_132", "PUEBLO_OROMAR", "RUTA_131", "RUTA_131", "RUTA_131", "RUTA_130", "RUTA_130", "RUTA_130", "RUTA_129", "RUTA_129", "", "",
	"RUTA_105", "", "", "", "VILLA_RAIZ", "", "", "", "CIUDAD_PORTUAL", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
	"RUTA_105", "", "", "", "", "", "", "", "RUTA_109", "", "", "", "", "", "", "", "", "", "", "", "", "", "FRENTE_BATALLA", "", "", "", "", "",
	"RUTA_106", "RUTA_106", "RUTA_106", "", "", "", "", "", "RUTA_109", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
	"", "", "PUEBLO_AZULIZA", "RUTA_107", "RUTA_107", "RUTA_107", "RUTA_108", "RUTA_108", "RUTA_109", "", "", "", "ISLA_SUR", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
]
