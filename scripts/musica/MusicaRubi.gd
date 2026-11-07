class_name MusicaRubi
extends RefCounted

## Resolución de música de clubes y batallas, con el mismo criterio que el
## decomp de Pokémon Ruby.
##
## En la ROM hay dos.select de música distintos para un entrenador, y el
## proyecto los modela igual:
##
##   1. El JINGLE DE ENCUENTRO, que suena en el mapa cuando el entrenador te
##      ve (antes de la transición a batalla). En la ROM lo elige el campo
##      `encounterMusic_gender` del registro del entrenador, que NO es un id de
##      canción sino un índice 0-13 (TRAINER_ENCOUNTER_MUSIC_*, con el bit 7
##      = F_TRAINER_FEMALE). Ver `PlayTrainerEncounterMusic()` en
##      src/battle_setup.c del decomp.
##
##   2. El TEMA DE BATALLA, que suena dentro del combate. En la ROM no está en
##      los datos del entrenador: `GetMUS_ForBattle()` (src/pokemon_3.c) lo
##      deriva de la CLASE del entrenador y de los flags de batalla.
##
## Este módulo traduce ambos a claves del registro `temas_musicales.json`.

## ===== Jingle de encuentro =====

## encounterMusic_gender (índice 0-13) -> clave del registro.
## Índices de include/constants/trainers.h (TRAINER_ENCOUNTER_MUSIC_*).
const JINGLE_POR_INDICE: Dictionary = {
	0: "ENCUENTRO_CHICO",			# MALE
	1: "ENCUENTRO_MUJER",			# FEMALE
	2: "ENCUENTRO_CHICA",			# GIRL
	3: "ENCUENTRO_SOSPECHOSO",	# SUSPICIOUS
	4: "ENCUENTRO_PSIQUICA",		# INTENSE
	5: "ENCUENTRO_GENIAL",			# COOL
	6: "ENCUENTRO_EQUIPO_AQUA",	# AQUA
	7: "ENCUENTRO_EQUIPO_MAGMA",	# MAGMA
	8: "ENCUENTRO_NADADOR",		# SWIMMER
	9: "ENCUENTRO_GEMELOS",		# TWINS
	10: "ENCUENTRO_ALTO_MANDO",	# ELITE FOUR
	11: "ENCUENTRO_MONTANERO",	# HIKER
	12: "ENCUENTRO_ENTREVISTADORES", # INTERVIEWER
	13: "ENCUENTRO_CABALLERO",	# RICH
}

## Un índice fuera de la tabla 0-13 se resuelve al jingle SOSPECHOSO, que es
## el `default` del switch de PlayTrainerEncounterMusic en el decomp.
const JINGLE_FUERA_DE_TABLA: String = "ENCUENTRO_SOSPECHOSO"

## Bit 7 de encounterMusic_gender: marca que el entrenador es mujer.
const FLAG_ENTRENADORA: int = 0x80
## Máscara del índice de jingle (el resto del byte es el flag de género).
const MASCARA_INDICE: int = 0x7F

## Clases de entrenador cuyo jingle se elige por defecto en la ROM cuando el
## registro no aporta uno válido (o para nombres propios como el rival).
const JINGLE_POR_DEFECTO: String = "ENCUENTRO_CHICO"

## Jingle de encuentro de un entrenador, a partir de su índice de la ROM.
## `indice_rom` es el valor de encounterMusic_gender (0-13, sin el bit 7).
## Un índice fuera de tabla cae en SOSPECHOSO, como el `default` del switch del
## decomp (que usa MUS_ENCOUNTER_SUSPICIOUS).
static func jingle_encuentro(indice_rom: int) -> String:
	var clave: String = str(JINGLE_POR_INDICE.get(indice_rom, JINGLE_FUERA_DE_TABLA))
	return clave if Singleton.TEMAS_REGISTRADOS.has(clave) else JINGLE_POR_DEFECTO


## ¿El byte encounterMusic_gender marca un entrenador mujer?
static func es_entrenadora(byte_encounter_music: int) -> bool:
	return (byte_encounter_music & FLAG_ENTRENADORA) != 0


## Índice de jingle (0-13) a partir del byte completo de la ROM.
static func indice_encuentro(byte_encounter_music: int) -> int:
	return byte_encounter_music & MASCARA_INDICE


## ===== Tema de batalla =====

## Tema de batalla por clase de entrenador, replicando el switch de
## GetMUS_ForBattle() (src/pokemon_3.c del decomp). Las claves son las del
## registro; el mapeo es por CLASE en español tal y como las guarda el proyecto
## (DatosEntrenador.clase_entrenador).
const TEMA_BATALLA_POR_CLASE: Dictionary = {
	# Trainer class 0x02 (AQUA LEADER) y 0x31 (MAGMA LEADER)
	"LÍDER AQUA": "BATALLA_ARCHIE_MAXIE",
	"LÍDER MAGMA": "BATALLA_ARCHIE_MAXIE",
	# 0x03 TEAM AQUA, 0x04 AQUA ADMIN, 0x32 TEAM MAGMA, 0x33 MAGMA ADMIN
	"EQUIPO AQUA": "BATALLA_EQUIPO_AQUA_MAGMA",
	"EQUIPO MAGMA": "BATALLA_EQUIPO_AQUA_MAGMA",
	"ADMIN. AQUA": "BATALLA_EQUIPO_AQUA_MAGMA",
	"ADMIN. MAGMA": "BATALLA_EQUIPO_AQUA_MAGMA",
	# 0x19 LEADER
	"LÍDER": "BATALLA_LIDER_GIMNASIO",
	# 0x20 CHAMPION
	"CAMPEÓN": "BATALLA_CAMPEON",
	# 0x18 ELITE FOUR
	"ALTO MANDO": "BATALLA_ALTO_MANDO",
}

## El rival: el decomp lo detecta por NOMBRE porque rival y Wally comparten la
## clase TRAINER_CLASS_POKEMON_TRAINER_3 (0x2E): GetMUS_ForBattle da MUS_VS_TRAINER
## a WALLY (BLASCO en la ROM española) y MUS_VS_RIVAL a todos los demás.
## Incluye los nombres oficiales de la ROM española: BRENDAN = BRUNO, MAY = AURA.
const NOMBRES_RIVAL: Array[String] = ["BRENDAN", "MAY", "MAIA", "BRUNO", "AURA"]

## Tema de batalla por defecto (el "default" del switch del decomp).
const TEMA_BATALLA_DEFECTO: String = "BATALLA_ENTRENADOR"

## Tema del rival.
const TEMA_RIVAL: String = "BATALLA_RIVAL"

## Tema de batalla de un entrenador por su clase, como GetMUS_ForBattle().
## `es_rival` fuerza el tema del rival (el decomp lo decide por el nombre).
static func tema_batalla(clase_entrenador: String, es_rival: bool = false) -> String:
	var clase := clase_entrenador.strip_edges().to_upper()
	var clave: String
	if es_rival:
		clave = TEMA_RIVAL
	else:
		clave = str(TEMA_BATALLA_POR_CLASE.get(clase, TEMA_BATALLA_DEFECTO))
	return clave if Singleton.TEMAS_REGISTRADOS.has(clave) else TEMA_BATALLA_DEFECTO


## ¿El entrenador es el rival? El decomp compara el nombre porque rival y
## Wally comparten clase y sprite base.
static func es_rival(nombre_entrenador: String) -> bool:
	var n := nombre_entrenador.strip_edges().to_upper()
	return NOMBRES_RIVAL.has(n)