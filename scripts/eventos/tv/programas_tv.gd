## programas_tv.gd
## Los programas grabados de la tele de pokeruby (src/tv.c, gSaveBlock1.tvShows) que
## se emiten en la propia partida: los cinco primeros huecos, donde van las
## entrevistas y el brote masivo. Cada programa se emite una vez (DoTVShow) y queda
## inactivo; una entrevista nueva del mismo tipo lo sustituye.
##
## | Tipo (TVSHOW_*)              | Quién lo graba                                       |
## |------------------------------|------------------------------------------------------|
## | 1 FAN_CLUB_LETTER (carta)    | REPORTERA del CLUB de FANS de PORTUAL, sin mote       |
## | 2 RECENT_HAPPENINGS          | REPORTERO del MUSEO OCEÁNICO de PORTUAL               |
## | 3 PKMN_FAN_CLUB_OPINIONS     | REPORTERA del CLUB de FANS, con mote                 |
## | 5 NAME_RATER_SHOW            | INSPECTOR de MOTES de PORTUAL al cambiar un mote      |
## | 6 BRAVO_TRAINER_POKEMON      | REPORTERO del vestíbulo tras un CONCURSO              |
## | 41 MASS_OUTBREAK (brote)     | tras la LIGA, al acabar un combate (sub_80BE778)     |
##
## Sin equivalente en el proyecto: el programa 7 (ENTRENADOR ESTRELLA de la TORRE
## BATALLA, que no existe) y los huecos 5..23, donde se apuntan POKéMON HOY (captura
## y fallo), COMPRADOR INTELIGENTE, el PESCADOR y EL MUNDO DE LOS MAESTROS: esos se
## crean inactivos y solo se emiten en otra partida tras MEZCLAR RÉCORDS.
##
## Textos: gTVBravoTrainerText*, gTVFanClubText*, gTVFanClubOpinionsText*,
## gTVRecentHappeningsText*, gTVPokemonOutbreakText y gTVNameRaterText* (CSV
## `TV_*`); {var1}..{var3} son gStringVar1..3, que cada estado rellena y que se
## conservan entre estados como en la ROM.
extends RefCounted
class_name ProgramasTV

enum Tipo {
	NINGUNO = 0,
	CARTA_CLUB = 1,
	NOVEDADES = 2,
	OPINIONES_CLUB = 3,
	VACIO = 4,
	INSPECTOR_MOTES = 5,
	ENTRENADOR_ESTRELLA = 6,
	ENTRENADOR_ESTRELLA_TORRE = 7,
	BROTE = 41,
}

## tvShows[0..4]: los que se emiten en la propia partida.
const HUECOS: int = 5
const CLAVE_PROGRAMAS: String = "tv_programas"
## tvShows[24].bravoTrainer: el CONCURSO a la espera del REPORTERO.
const CLAVE_CONCURSO: String = "tv_concurso_pendiente"
## gSaveBlock1.outbreak*: el brote en curso.
const CLAVE_BROTE: String = "tv_brote"
## VAR_LINK_CONTEST_ROOM_STATE == 2 y VAR_CONTEST_LOCATION: se acaba de volver de un
## CONCURSO a este vestíbulo (escena del concurso).
const TEXTO_VESTIBULO: String = "tv_concurso_vestibulo"
const BANDERA_JUEGO_COMPLETADO: String = "SYS_GAME_CLEAR"
## FLAG_HIDE_CONTEST_REPORTER_*: bandera_mostrar del REPORTERO de cada vestíbulo.
const BANDERAS_REPORTERO: Dictionary = {
	"pueblo_verdegal_concurso": "concurso_verdegal_reportero_visible",
	"pueblo_pardal_concurso": "concurso_pardal_reportero_visible",
	"ciudad_portual_concurso": "concurso_portual_reportero_visible",
	"ciudad_calagua_concurso": "calagua_concurso_reportero_visible",
}

## gPokeOutbreakSpeciesList.
const BROTES: Array[Dictionary] = [
	{"especie": "SURSKIT", "movimientos": ["BURBUJA", "ATRAPIDO"], "nivel": 3, "mapa": "ruta_102"},
	{"especie": "SURSKIT", "movimientos": ["BURBUJA", "ATRAPIDO"], "nivel": 15, "mapa": "ruta_114"},
	{"especie": "SURSKIT", "movimientos": ["BURBUJA", "ATRAPIDO"], "nivel": 15, "mapa": "ruta_117"},
	{"especie": "SURSKIT", "movimientos": ["BURBUJA", "ATRAPIDO"], "nivel": 28, "mapa": "ruta_120"},
	{"especie": "SKITTY", "movimientos": ["GRUNIDO", "PLACAJE"], "nivel": 15, "mapa": "ruta_116"},
]
## sub_80BF77C(0x147): hay brote si Random() <= 0x147.
const UMBRAL_BROTE: int = 0x147
## massOutbreak->probability.
const PROBABILIDAD_BROTE: int = 50
## outbreakUnk5: días que dura el brote una vez anunciado.
const DIAS_BROTE: int = 2

## Pantalla de PALABRAS FÁCILES de cada entrevista: palabras que se guardan.
const PALABRAS_CARTA: int = 4
const PALABRAS_NOVEDADES: int = 4

## Códigos de carácter de la GBA (charmap.txt) para sub_80BF7E8, que suma los bytes
## del mote; los que no están cuentan 0.
const CODIGOS_GBA: Dictionary = {
	" ": 0x00, "À": 0x01, "Á": 0x02, "Â": 0x03, "Ç": 0x04, "È": 0x05, "É": 0x06, "Ê": 0x07,
	"Ë": 0x08, "Ì": 0x09, "Î": 0x0B, "Ï": 0x0C, "Ò": 0x0D, "Ó": 0x0E, "Ô": 0x0F, "Œ": 0x10,
	"Ù": 0x11, "Ú": 0x12, "Û": 0x13, "Ñ": 0x14, "ß": 0x15, "à": 0x16, "á": 0x17, "ç": 0x19,
	"è": 0x1A, "é": 0x1B, "ê": 0x1C, "ë": 0x1D, "ì": 0x1E, "î": 0x20, "ï": 0x21, "ò": 0x22,
	"ó": 0x23, "ô": 0x24, "œ": 0x25, "ù": 0x26, "ú": 0x27, "û": 0x28, "ñ": 0x29, "º": 0x2A,
	"ª": 0x2B, "&": 0x2D, "+": 0x2E, "=": 0x35, ";": 0x36, "¿": 0x51, "¡": 0x52, "Í": 0x5A,
	"%": 0x5B, "(": 0x5C, ")": 0x5D, "â": 0x68, "í": 0x6F, "<": 0x85, ">": 0x86, "0": 0xA1,
	"1": 0xA2, "2": 0xA3, "3": 0xA4, "4": 0xA5, "5": 0xA6, "6": 0xA7, "7": 0xA8, "8": 0xA9,
	"9": 0xAA, "!": 0xAB, "?": 0xAC, ".": 0xAD, "-": 0xAE, "·": 0xAF, "…": 0xB0, "‥": 0xB0,
	"“": 0xB1, "”": 0xB2, "‘": 0xB3, "♂": 0xB5, "♀": 0xB6, "¥": 0xB7, ",": 0xB8, "×": 0xB9,
	"/": 0xBA, "A": 0xBB, "B": 0xBC, "C": 0xBD, "D": 0xBE, "E": 0xBF, "F": 0xC0, "G": 0xC1,
	"H": 0xC2, "I": 0xC3, "J": 0xC4, "K": 0xC5, "L": 0xC6, "M": 0xC7, "N": 0xC8, "O": 0xC9,
	"P": 0xCA, "Q": 0xCB, "R": 0xCC, "S": 0xCD, "T": 0xCE, "U": 0xCF, "V": 0xD0, "W": 0xD1,
	"X": 0xD2, "Y": 0xD3, "Z": 0xD4, "a": 0xD5, "b": 0xD6, "c": 0xD7, "d": 0xD8, "e": 0xD9,
	"f": 0xDA, "g": 0xDB, "h": 0xDC, "i": 0xDD, "j": 0xDE, "k": 0xDF, "l": 0xE0, "m": 0xE1,
	"n": 0xE2, "o": 0xE3, "p": 0xE4, "q": 0xE5, "r": 0xE6, "s": 0xE7, "t": 0xE8, "u": 0xE9,
	"v": 0xEA, "w": 0xEB, "x": 0xEC, "y": 0xED, "z": 0xEE, "▶": 0xEF, ":": 0xF0, "Ä": 0xF1,
	"Ö": 0xF2, "Ü": 0xF3, "ä": 0xF4, "ö": 0xF5, "ü": 0xF6,
}


# ─── Guardado ────────────────────────────────────────────────────────────────

static func programas() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var datos: Variant = _leer(SistemaGuardado.get_texto(CLAVE_PROGRAMAS))
	var guardados: Array = datos if datos is Array else []
	for i in HUECOS:
		resultado.append(guardados[i] if i < guardados.size() and guardados[i] is Dictionary else _vacio())
	return resultado


static func guardar(lista: Array[Dictionary]) -> void:
	SistemaGuardado.set_texto(CLAVE_PROGRAMAS, JSON.stringify(lista))


static func _vacio() -> Dictionary:
	return {"tipo": Tipo.NINGUNO, "activo": false}


static func _diccionario(clave: String) -> Dictionary:
	var datos: Variant = _leer(SistemaGuardado.get_texto(clave))
	return datos if datos is Dictionary else {}


## JSON guardado con los números enteros otra vez como int (JSON los devuelve float).
static func _leer(texto: String) -> Variant:
	return _enteros(JSON.parse_string(texto)) if not texto.is_empty() else null


static func _enteros(valor: Variant) -> Variant:
	if valor is float and is_equal_approx(valor, roundf(valor)):
		return int(valor)
	if valor is Array:
		var lista: Array = []
		for elemento: Variant in valor:
			lista.append(_enteros(elemento))
		return lista
	if valor is Dictionary:
		var diccionario: Dictionary = {}
		for clave: Variant in valor:
			diccionario[clave] = _enteros(valor[clave])
		return diccionario
	return valor


## ClearTVShowData (y EndMassOutbreak).
static func borrar() -> void:
	var vacios: Array[Dictionary] = []
	for i in HUECOS:
		vacios.append(_vacio())
	guardar(vacios)
	SistemaGuardado.set_texto(CLAVE_CONCURSO, "")
	SistemaGuardado.set_texto(CLAVE_BROTE, "")


# ─── Qué hay en antena ───────────────────────────────────────────────────────

## special_0x44: empieza en un hueco al azar y recorre hacia atrás (dando la vuelta)
## hasta el primero activo; el brote solo cuando le quedan 0 días. -1 si ninguno.
## Sin MEZCLAR RÉCORDS los huecos 5..23 están vacíos y la vuelta pasa por ellos sin
## encontrar nada.
static func buscar_en_antena() -> int:
	var lista := programas()
	var inicio := randi() % HUECOS
	var j := inicio
	while true:
		var programa: Dictionary = lista[j]
		if bool(programa.get("activo", false)):
			if int(programa.get("tipo", 0)) != Tipo.BROTE or int(programa.get("dias", 0)) == 0:
				return j
		j = HUECOS - 1 if j == 0 else j - 1
		if j == inicio:
			break
	return -1


## FindNonMassOutbreakActiveTVShow.
static func _primero_que_no_es_brote(lista: Array[Dictionary]) -> int:
	for i in HUECOS:
		var tipo := int(lista[i].get("tipo", 0))
		if tipo != Tipo.NINGUNO and tipo != Tipo.BROTE and bool(lista[i].get("activo", false)):
			return i
	return -1


## sub_80BD8B8 / GetNonMassOutbreakActiveTVShow: el elegido, salvo que sea un brote
## con otro ya en curso, que se cambia por el primer programa que no sea un brote.
static func programa_para_ver() -> int:
	var indice := buscar_en_antena()
	if indice < 0:
		return -1
	var lista := programas()
	if int(lista[indice].get("tipo", 0)) == Tipo.BROTE and brote_en_curso():
		return _primero_que_no_es_brote(lista)
	return indice


# ─── Emisión (DoTVShow) ──────────────────────────────────────────────────────

## DoTVShow hasta TVShowDone: los textos del programa del hueco `indice`, que queda
## inactivo. El brote además empieza (StartMassOutbreak).
static func emitir(indice: int) -> Array[String]:
	var lista := programas()
	var programa: Dictionary = lista[indice]
	var textos: Array[String] = []
	if not bool(programa.get("activo", false)):
		return textos
	match int(programa.get("tipo", 0)):
		Tipo.CARTA_CLUB:
			textos = _emitir_carta(programa)
		Tipo.NOVEDADES:
			textos = _emitir_novedades(programa)
		Tipo.OPINIONES_CLUB:
			textos = _emitir_opiniones(programa)
		Tipo.INSPECTOR_MOTES:
			textos = _emitir_inspector(programa)
		Tipo.ENTRENADOR_ESTRELLA:
			textos = _emitir_entrenador_estrella(programa)
		Tipo.ENTRENADOR_ESTRELLA_TORRE:
			textos = _emitir_entrenador_estrella_torre(programa)
		Tipo.BROTE:
			textos = _emitir_brote(programa)
			_iniciar_brote(programa)
	programa["activo"] = false  # TVShowDone
	guardar(lista)
	return textos


## ShowFieldMessage(gTV…Text[n]) con gStringVar1..3.
static func _texto(clave: String, vars: Array) -> String:
	var texto := String(TranslationServer.translate(StringName(clave)))
	for i in vars.size():
		texto = texto.replace("{var%d}" % (i + 1), str(vars[i]))
	return texto.replace("{PN}", SistemaGuardado.get_nombre_jugador())


static func _palabra(id_palabra: int) -> String:
	return PalabrasFaciles.texto(id_palabra)


## ConvertEasyChatWordsToString(…, 2, 2): dos filas de dos palabras; tras la primera
## de cada fila va un espacio si no está vacía.
static func frase_carta(palabras: Array) -> String:
	var lineas: Array[String] = []
	for fila in 2:
		var primera: int = int(palabras[fila * 2]) if fila * 2 < palabras.size() else PalabrasFaciles.PALABRA_VACIA
		var segunda: int = int(palabras[fila * 2 + 1]) if fila * 2 + 1 < palabras.size() else PalabrasFaciles.PALABRA_VACIA
		var linea := _palabra(primera)
		if primera != PalabrasFaciles.PALABRA_VACIA:
			linea += " "
		lineas.append(linea + _palabra(segunda))
	return "\n".join(lineas)


## sub_80BF79C: una palabra al azar de las seis (la primera no vacía desde una
## posición al azar).
static func _palabra_al_azar(palabras: Array) -> String:
	var seis: Array = palabras.duplicate()
	while seis.size() < 6:
		seis.append(PalabrasFaciles.PALABRA_VACIA)
	var i := randi() % 6
	for _vuelta in 6:
		if int(seis[i]) != PalabrasFaciles.PALABRA_VACIA:
			return _palabra(int(seis[i]))
		i = (i + 1) % 6
	return ""


static func _especie(nombre_interno: String) -> String:
	return ProgramaGabiTeo.nombre_especie(nombre_interno)


## DoTVShowPokemonFanClubLetter.
static func _emitir_carta(p: Dictionary) -> Array[String]:
	var textos: Array[String] = []
	var palabras: Array = p.get("palabras", [])
	var vars: Array = [p.get("jugador", ""), _especie(str(p.get("especie", ""))), ""]
	var estado := 0
	while true:
		match estado:
			0:
				textos.append(_texto("TV_CARTA_CLUB_1", vars))
				textos.append(frase_carta(palabras))  # estado 50
				estado = 1
			1:
				textos.append(_texto("TV_CARTA_CLUB_2", vars))
				var azar := randi() % 4 + 1
				if azar == 1:
					textos.append(_texto("TV_CARTA_CLUB_3", vars))  # estado 2
					textos.append(frase_carta(palabras))  # estado 51
					estado = 3
				else:
					estado = azar + 2
			3:
				textos.append(_texto("TV_CARTA_CLUB_4", vars))
				estado += randi() % 3 + 1
			4, 5, 6:
				vars[2] = _palabra_al_azar(palabras)
				textos.append(_texto("TV_CARTA_CLUB_%d" % (estado + 1), vars))
				estado = 7
			7:
				vars[2] = str(randi() % 0x1f + 0x46)
				textos.append(_texto("TV_CARTA_CLUB_8", vars))
				return textos
	return textos


## DoTVShowRecentHappenings.
static func _emitir_novedades(p: Dictionary) -> Array[String]:
	var palabras: Array = p.get("palabras", [])
	var vars: Array = [p.get("jugador", ""), "", _palabra_al_azar(palabras)]
	var textos: Array[String] = [_texto("TV_NOVEDADES_1", vars), frase_carta(palabras),
		_texto("TV_NOVEDADES_2", vars)]
	var estado := 1 + 1 + randi() % 3
	textos.append(_texto("TV_NOVEDADES_%d" % (estado + 1), vars))
	textos.append(_texto("TV_NOVEDADES_6", vars))
	return textos


## DoTVShowPokemonFanClubOpinions.
static func _emitir_opiniones(p: Dictionary) -> Array[String]:
	var palabras: Array = p.get("palabras", [])
	var jugador := str(p.get("jugador", ""))
	var especie := _especie(str(p.get("especie", "")))
	var pregunta := int(p.get("pregunta", 0))
	var vars: Array = [jugador, especie, str(p.get("mote", ""))]
	var textos: Array[String] = [_texto("TV_OPINIONES_CLUB_1", vars)]
	vars = [jugador, especie, _palabra(int(palabras[0]) if palabras.size() > 0 else PalabrasFaciles.PALABRA_VACIA)]
	textos.append(_texto("TV_OPINIONES_CLUB_%d" % (pregunta + 2), vars))
	vars[2] = _palabra(int(palabras[1]) if palabras.size() > 1 else PalabrasFaciles.PALABRA_VACIA)
	textos.append(_texto("TV_OPINIONES_CLUB_5", vars))
	return textos


## DoTVShowTheNameRaterShow. Los estados 13..17 (otros ejemplos de motes) no se
## alcanzan en Rubí: el 12 salta directamente al 18.
static func _emitir_inspector(p: Dictionary) -> Array[String]:
	var entrenador := str(p.get("entrenador", ""))
	var mote := str(p.get("mote", ""))
	var vars: Array = [entrenador, _especie(str(p.get("especie", ""))), mote]
	var textos: Array[String] = [_texto("TV_INSPECTOR_MOTES_1", vars)]
	var estado := suma_mote(mote) + 1
	if estado == 2:
		vars[0] = entrenador
	textos.append(_texto("TV_INSPECTOR_MOTES_%d" % (estado + 1), vars))
	estado = 9 + int(p.get("azar", 0))
	vars = [mote, mote.substr(0, 1), mote.substr(1, 1)]
	textos.append(_texto("TV_INSPECTOR_MOTES_%d" % (estado + 1), vars))
	vars = [mote, entrenador, vars[2]]
	textos.append(_texto("TV_INSPECTOR_MOTES_19", vars))
	return textos


## sub_80BF7E8: suma de los bytes del mote (como mucho 11) & 7.
static func suma_mote(mote: String) -> int:
	var suma := 0
	for i in mini(mote.length(), 11):
		suma += int(CODIGOS_GBA.get(mote[i], 0))
	return suma & 7


## DoTVShowBravoTrainerPokemonProfile.
static func _emitir_entrenador_estrella(p: Dictionary) -> Array[String]:
	var jugador := str(p.get("jugador", ""))
	var especie := _especie(str(p.get("especie", "")))
	var mote := str(p.get("mote", ""))
	var categoria := String(TranslationServer.translate(StringName("CONCURSO_CATEGORIA_%d" % int(p.get("categoria", 0)))))
	var nivel := String(TranslationServer.translate(StringName("CONCURSO_NIVEL_%d" % int(p.get("nivel", 0)))))
	var palabras: Array = p.get("palabras", [])
	var palabra_1 := _palabra(int(palabras[0]) if palabras.size() > 0 else PalabrasFaciles.PALABRA_VACIA)
	var palabra_2 := _palabra(int(palabras[1]) if palabras.size() > 1 else PalabrasFaciles.PALABRA_VACIA)
	var puesto := int(p.get("puesto", 0))
	var vars: Array = [jugador, categoria, nivel]
	var textos: Array[String] = [_texto("TV_ENTRENADOR_ESTRELLA_1", vars)]
	if especie == mote:
		vars[0] = especie
		textos.append(_texto("TV_ENTRENADOR_ESTRELLA_9", vars))
	else:
		vars = [especie, mote, categoria]
		textos.append(_texto("TV_ENTRENADOR_ESTRELLA_2", vars))
	vars[0] = jugador
	textos.append(_texto("TV_ENTRENADOR_ESTRELLA_3", vars))
	vars = [jugador, palabra_1, str(puesto + 1)]
	textos.append(_texto("TV_ENTRENADOR_ESTRELLA_4" if puesto == 0 else "TV_ENTRENADOR_ESTRELLA_5", vars))
	vars = [jugador, categoria, palabra_2]
	textos.append(_texto("TV_ENTRENADOR_ESTRELLA_6", vars))
	var movimiento := str(p.get("movimiento", ""))
	if not movimiento.is_empty():
		vars = [especie, ProgramaGabiTeo.nombre_movimiento(movimiento), palabra_2]
		textos.append(_texto("TV_ENTRENADOR_ESTRELLA_7", vars))
	vars = [jugador, especie, vars[2]]
	textos.append(_texto("TV_ENTRENADOR_ESTRELLA_8", vars))
	return textos


## DoTVShowBravoTrainerBattleTowerProfile. Los textos 8 a 11 de la ROM («Nada») no se usan.
static func _emitir_entrenador_estrella_torre(p: Dictionary) -> Array[String]:
	var jugador := str(p.get("jugador", ""))
	var rival := str(p.get("rival", ""))
	var especie := _especie(str(p.get("especie", "")))
	var especie_rival := _especie(str(p.get("especie_rival", "")))
	var racha := int(p.get("racha", 0))
	var triste := int(p.get("opinion", 0)) != 0
	var palabra := _palabra(int(p.get("palabra", PalabrasFaciles.PALABRA_VACIA)))
	var clave := "TV_ENTRENADOR_ESTRELLA_TORRE_%d"
	var textos: Array[String] = [_texto(clave % 1, [jugador, especie])]
	if racha >= 7:
		textos.append(_texto(clave % 2, [int(p.get("nivel", 50)), racha]))
		var ganado := bool(p.get("ganado", false))
		textos.append(_texto(clave % (4 if ganado else 5), [rival, especie_rival]))
	else:
		textos.append(_texto(clave % 3, [rival, racha + 1]))
	textos.append(_texto(clave % (7 if triste else 6), [rival]))
	textos.append(_texto(clave % 12, [palabra]))
	textos.append(_texto(clave % (14 if triste else 13), [palabra, jugador, rival]))
	textos.append(_texto(clave % 15, [jugador, especie]))
	return textos


## DoTVShowPokemonNewsMassOutbreak.
static func _emitir_brote(p: Dictionary) -> Array[String]:
	var vars: Array = [Lugares.nombre_lugar(str(p.get("mapa", "")).to_upper()), _especie(str(p.get("especie", "")))]
	return [_texto("TV_BROTE", vars)] as Array[String]


# ─── Entrevistas (InterviewBefore / InterviewAfter) ──────────────────────────

## InterviewBefore (sub_80BF25C + sub_80BF6D8): el hueco donde irá la entrevista de
## `tipo`, o -1 (VAR_RESULT = 1) si ya hay una de ese tipo sin emitir o no queda
## sitio. Una ya emitida se borra para dejar sitio a la nueva.
static func antes_de_entrevista(tipo: Tipo) -> int:
	if tipo == Tipo.VACIO:
		return -1  # InterviewBefore_Dummy
	var lista := programas()
	for i in HUECOS:
		if int(lista[i].get("tipo", 0)) != tipo:
			continue
		if bool(lista[i].get("activo", false)):
			return -1
		lista[i] = _vacio()
		_compactar(lista)
		guardar(lista)
		break
	return _hueco_libre(lista)


## sub_80BF720.
static func _hueco_libre(lista: Array[Dictionary]) -> int:
	for i in HUECOS:
		if int(lista[i].get("tipo", 0)) == Tipo.NINGUNO:
			return i
	return -1


## sub_80BF588 (los cinco primeros).
static func _compactar(lista: Array[Dictionary]) -> void:
	for i in HUECOS - 1:
		if int(lista[i].get("tipo", 0)) != Tipo.NINGUNO:
			continue
		for j in range(i + 1, HUECOS):
			if int(lista[j].get("tipo", 0)) != Tipo.NINGUNO:
				lista[i] = lista[j]
				lista[j] = _vacio()
				break


## InterviewAfter: guarda la entrevista en el hueco que dio antes_de_entrevista.
static func _grabar(hueco: int, programa: Dictionary) -> void:
	if hueco < 0 or hueco >= HUECOS:
		return
	var lista := programas()
	programa["activo"] = true
	lista[hueco] = programa
	guardar(lista)
	SistemaGuardado.incrementar_contador("entrevistado")  # GAME_STAT_GOT_INTERVIEWED


## InterviewAfter_FanClubLetter: la carta de 4 palabras sobre el primer POKéMON.
static func grabar_carta_club(hueco: int, lider: BasePokemon, palabras: Array) -> void:
	_grabar(hueco, {"tipo": Tipo.CARTA_CLUB, "jugador": SistemaGuardado.get_nombre_jugador(),
		"especie": lider.nombre_interno, "palabras": palabras.duplicate()})


## InterviewAfter_RecentHappenings: la historia de 4 palabras del MUSEO.
static func grabar_novedades(hueco: int, palabras: Array) -> void:
	_grabar(hueco, {"tipo": Tipo.NOVEDADES, "jugador": SistemaGuardado.get_nombre_jugador(),
		"palabras": palabras.duplicate()})


## InterviewAfter_PkmnFanClubOpinions: `pregunta` 0..2 (VAR_0x8007) y las dos
## respuestas.
static func grabar_opiniones_club(hueco: int, lider: BasePokemon, pregunta: int, palabras: Array) -> void:
	_grabar(hueco, {"tipo": Tipo.OPINIONES_CLUB, "jugador": SistemaGuardado.get_nombre_jugador(),
		"especie": lider.nombre_interno, "mote": lider.get_nombre_mostrar(), "pregunta": pregunta,
		"palabras": palabras.duplicate()})


## TV_PutNameRaterShowOnTheAirIfNicnkameChanged → sub_80BE478: tras cambiar el mote
## en el INSPECTOR, si hay sitio y tanto el nombre del jugador como el mote tienen
## más de una letra.
static func tras_cambiar_mote(pokemon: BasePokemon) -> void:
	var hueco := antes_de_entrevista(Tipo.INSPECTOR_MOTES)
	if hueco < 0:
		return
	var jugador := SistemaGuardado.get_nombre_jugador()
	var mote := pokemon.get_nombre_mostrar()
	if jugador.length() <= 1 or mote.length() <= 1:
		return
	var lista := programas()
	lista[hueco] = {"tipo": Tipo.INSPECTOR_MOTES, "activo": true, "especie": pokemon.nombre_interno,
		"azar": randi() % 3, "entrenador": jugador, "mote": mote}
	guardar(lista)


# ─── ENTRENADOR ESTRELLA (CONCURSOS) ─────────────────────────────────────────

## sub_80BE23C (Task_EndAppeals): al acabar las apelaciones apunta el último
## movimiento del jugador si hay sitio para la entrevista.
static func al_terminar_apelaciones(movimiento: String) -> void:
	if antes_de_entrevista(Tipo.ENTRENADOR_ESTRELLA) < 0:
		return
	SistemaGuardado.set_texto(CLAVE_CONCURSO, JSON.stringify({"tipo": Tipo.ENTRENADOR_ESTRELLA,
		"movimiento": movimiento}))


## sub_80BE284 (resultados): puesto (0 = primero), categoría, nivel y el POKéMON.
## Después el REPORTERO espera en el vestíbulo (VAR_LINK_CONTEST_ROOM_STATE = 2).
static func al_terminar_concurso(puesto: int, categoria: int, nivel: int, pokemon: BasePokemon,
		vestibulo: String) -> void:
	SistemaGuardado.set_texto(TEXTO_VESTIBULO, vestibulo)
	if pokemon == null or _hueco_libre(programas()) < 0:
		return
	var pendiente := _diccionario(CLAVE_CONCURSO)
	pendiente["puesto"] = puesto
	pendiente["categoria"] = categoria
	pendiente["nivel"] = nivel
	pendiente["especie"] = pokemon.nombre_interno
	pendiente["mote"] = pokemon.get_nombre_mostrar()
	SistemaGuardado.set_texto(CLAVE_CONCURSO, JSON.stringify(pendiente))


## Categoría del CONCURSO pendiente (SetContestCategoryStringVarForInterview).
static func categoria_concurso_pendiente() -> String:
	var categoria := int(_diccionario(CLAVE_CONCURSO).get("categoria", 0))
	return String(TranslationServer.translate(StringName("CONCURSO_CATEGORIA_%d" % categoria)))


## InterviewAfter_BravoTrainerPokemonProfile: con el CONCURSO apuntado, la entrevista
## de dos palabras.
static func grabar_entrenador_estrella(hueco: int, palabras: Array) -> void:
	var pendiente := _diccionario(CLAVE_CONCURSO)
	if int(pendiente.get("tipo", 0)) != Tipo.ENTRENADOR_ESTRELLA:
		return
	pendiente["jugador"] = SistemaGuardado.get_nombre_jugador()
	pendiente["palabras"] = palabras.duplicate()
	_grabar(hueco, pendiente)


## InterviewAfter_BravoTrainerBattleTowerProfile: `opinion` 0 alegre, 1 triste (multichoice 45).
static func grabar_entrenador_estrella_torre(hueco: int, palabra: int, opinion: int) -> void:
	var tipo := RetoTorreBatalla.ultimo_nivel()
	_grabar(hueco, {"tipo": Tipo.ENTRENADOR_ESTRELLA_TORRE, "jugador": SistemaGuardado.get_nombre_jugador(),
		"rival": RetoTorreBatalla.ultimo_rival(), "especie": RetoTorreBatalla.ultima_especie_propia(),
		"especie_rival": RetoTorreBatalla.ultima_especie_rival(), "racha": RetoTorreBatalla.racha_actual(tipo),
		"nivel": 50 if tipo == RetoTorreBatalla.NIVEL_50 else 100, "ganado": RetoTorreBatalla.ultimo_ganado(),
		"opinion": opinion, "palabra": palabra})


## Al entrar en un mapa: fuera del vestíbulo del último CONCURSO se olvida
## (OnTransition de la ciudad: VAR_LINK_CONTEST_ROOM_STATE = 0 y setflag
## FLAG_HIDE_CONTEST_REPORTER_*); en él, el REPORTERO aparece si hay sitio para la
## entrevista (LilycoveCity_ContestLobby_EventScript_TryShowContestReporter).
static func al_cambiar_de_mapa(clave_mapa: String) -> void:
	var vestibulo := SistemaGuardado.get_texto(TEXTO_VESTIBULO)
	if not vestibulo.is_empty() and clave_mapa != vestibulo:
		SistemaGuardado.set_texto(TEXTO_VESTIBULO, "")
		vestibulo = ""
	for clave: String in BANDERAS_REPORTERO:
		var visible := clave == vestibulo and clave == clave_mapa \
			and antes_de_entrevista(Tipo.ENTRENADOR_ESTRELLA) >= 0
		SistemaGuardado.set_flag(str(BANDERAS_REPORTERO[clave]), visible)


# ─── Brote masivo ────────────────────────────────────────────────────────────

## sub_80BE778 (desde PutPokemonTodayCaughtOnAir, al acabar un combate): tras la
## LIGA, sin otro brote anunciado, con hueco libre y 1 de cada ~200 veces, un brote
## al azar de BROTES que se emitirá dentro de un día.
static func crear_brote_tras_combate() -> void:
	if not SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO):
		return
	var lista := programas()
	for programa: Dictionary in lista:
		if int(programa.get("tipo", 0)) == Tipo.BROTE:
			return
	if (randi() & 0xFFFF) > UMBRAL_BROTE:
		return
	var hueco := _hueco_libre(lista)
	if hueco < 0:
		return
	var brote: Dictionary = BROTES[randi() % BROTES.size()]
	lista[hueco] = {"tipo": Tipo.BROTE, "activo": true, "especie": brote["especie"],
		"nivel": brote["nivel"], "movimientos": brote["movimientos"], "mapa": brote["mapa"],
		"probabilidad": PROBABILIDAD_BROTE, "dias": 1}
	guardar(lista)


## StartMassOutbreak.
static func _iniciar_brote(programa: Dictionary) -> void:
	SistemaGuardado.set_texto(CLAVE_BROTE, JSON.stringify({"especie": programa.get("especie", ""),
		"nivel": int(programa.get("nivel", 1)), "movimientos": programa.get("movimientos", []),
		"mapa": programa.get("mapa", ""), "probabilidad": int(programa.get("probabilidad", 0)),
		"dias": DIAS_BROTE}))


## gSaveBlock1.outbreakPokemonSpecies != 0.
static func brote_en_curso() -> bool:
	return not str(_diccionario(CLAVE_BROTE).get("especie", "")).is_empty()


## DoMassOutbreakEncounterTest + SetUpMassOutbreakEncounter: en el mapa del brote, el
## `probabilidad` % de los encuentros de tierra es su POKéMON con sus movimientos.
static func pokemon_de_brote(clave_mapa: String) -> BasePokemon:
	var brote := _diccionario(CLAVE_BROTE)
	if str(brote.get("especie", "")).is_empty() or str(brote.get("mapa", "")) != clave_mapa:
		return null
	if randi() % 100 >= int(brote.get("probabilidad", 0)):
		return null
	var pokemon := BasePokemon.new(str(brote["especie"]), int(brote.get("nivel", 1)), "salvaje")
	var movimientos: Array[Movimiento] = []
	var crianza := DatosCrianza.new()
	for nombre: Variant in brote.get("movimientos", []):
		var movimiento := crianza.crear_movimiento(str(nombre))
		if movimiento != null:
			movimientos.append(movimiento)
	if not movimientos.is_empty():
		pokemon.movimientos = movimientos
	return pokemon


## UpdateTVShowsPerDay: el brote anunciado cuenta días hasta emitirse (sub_80BE8EC,
## solo sin otro en curso) y el que está en curso se acaba a los DIAS_BROTE días
## (UpdateMassOutbreakTimeLeft).
static func actualizar_por_dias(dias: int) -> void:
	if not brote_en_curso():
		var lista := programas()
		for programa: Dictionary in lista:
			if int(programa.get("tipo", 0)) == Tipo.BROTE and bool(programa.get("activo", false)):
				programa["dias"] = maxi(int(programa.get("dias", 0)) - dias, 0)
				guardar(lista)
				break
	var brote := _diccionario(CLAVE_BROTE)
	if int(brote.get("dias", 0)) <= dias:
		SistemaGuardado.set_texto(CLAVE_BROTE, "")  # EndMassOutbreak
	else:
		brote["dias"] = int(brote["dias"]) - dias
		SistemaGuardado.set_texto(CLAVE_BROTE, JSON.stringify(brote))
