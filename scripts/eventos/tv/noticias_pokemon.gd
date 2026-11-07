## noticias_pokemon.gd
## NOTICIAS POKéMON (PokeNews) de pokeruby src/tv.c: gSaveBlock1.pokeNews, 16 huecos
## {tipo, estado, días}. Tras la LIGA (FLAG_SYS_GAME_CLEAR), después de cada combate
## puede anunciarse una de tres ofertas (sub_80BEB20); la tele la anuncia mientras
## falten menos de 3 días (DoPokeNews) y el día señalado hay rebaja:
##
## | Tipo (POKENEWS_*)   | Rebaja (GetPriceReduction / IsPriceDiscounted)            |
## |---------------------|------------------------------------------------------------|
## | CURRO (SLATEPORT)   | mitad de precio en la tienda de CURRO, el ENERGY GURU      |
## | CASINO (GAME_CORNER)| TRAGAPERRAS y RULETA más generosas (aún no existen)        |
## | LIQUIDACION (LILYCOVE)| la vendedora de la AZOTEA del CENTRO COMERCIAL de CALAGUA |
##
## Estados: 0 = anunciada sin emitir hoy, 1 = en antena (próxima), 2 = es el día.
## Cada día (UpdateTVShowsPerDay → sub_80BEE84) descuenta días, borra las pasadas y,
## tras la LIGA, vuelve a poner en antena las ya vistas.
extends RefCounted
class_name NoticiasPokemon

enum Tipo { NINGUNA, CURRO, CASINO, LIQUIDACION }
enum Estado { VISTA, EN_ANTENA, HOY }

## POKE_NEWS_COUNT.
const TOTAL: int = 16
## gSaveBlock1.pokeNews (JSON con TOTAL entradas {tipo, estado, dias}).
const CLAVE_GUARDADO: String = "tv_noticias_pokemon"
const BANDERA_JUEGO_COMPLETADO: String = "SYS_GAME_CLEAR"
## bandera_mostrar de la vendedora de la AZOTEA de CALAGUA (el día de la liquidación).
const BANDERA_LIQUIDACION: String = "calagua_azotea_liquidacion"
## sub_80BF77C(0x28f): hay noticia si Random() <= 0x28f.
const UMBRAL_NOTICIA: int = 0x28f
## Una noticia nueva es para dentro de 4 días.
const DIAS_NUEVA: int = 4
## FindAnyTVNewsOnTheAir: solo se anuncia cuando faltan menos de 3 días.
const DIAS_ANUNCIO: int = 3
## DoPokeNews: desde las 20:00 se emite la versión «se acaba el tiempo».
const HORA_TARDE: int = 20

## gTVNewsTextGroup1..3 por tipo (anuncio con días, el día, el día por la tarde).
const TEXTOS: Dictionary = {
	Tipo.CURRO: ["TV_NOTICIAS_CURRO_1", "TV_NOTICIAS_CURRO_2", "TV_NOTICIAS_CURRO_3"],
	Tipo.CASINO: ["TV_NOTICIAS_CASINO_1", "TV_NOTICIAS_CASINO_2", "TV_NOTICIAS_CASINO_3"],
	Tipo.LIQUIDACION: ["TV_NOTICIAS_LIQUIDACION_1", "TV_NOTICIAS_LIQUIDACION_2", "TV_NOTICIAS_LIQUIDACION_3"],
}


static func lista() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var texto := SistemaGuardado.get_texto(CLAVE_GUARDADO)
	var datos: Variant = JSON.parse_string(texto) if not texto.is_empty() else null
	var guardadas: Array = datos if datos is Array else []
	for i in TOTAL:
		var entrada: Dictionary = guardadas[i] if i < guardadas.size() and guardadas[i] is Dictionary else {}
		resultado.append({"tipo": int(entrada.get("tipo", 0)), "estado": int(entrada.get("estado", 0)),
			"dias": int(entrada.get("dias", 0))})
	return resultado


static func guardar(noticias: Array[Dictionary]) -> void:
	SistemaGuardado.set_texto(CLAVE_GUARDADO, JSON.stringify(noticias))


## sub_80BEBF4 (ClearTVShowData).
static func borrar() -> void:
	var vacias: Array[Dictionary] = []
	for i in TOTAL:
		vacias.append(_vacia())
	guardar(vacias)


static func _vacia() -> Dictionary:
	return {"tipo": Tipo.NINGUNA, "estado": Estado.VISTA, "dias": 0}


## sub_80BEB20 (desde PutPokemonTodayCaughtOnAir, al acabar un combate): tras la
## LIGA, con un hueco libre y 1 de cada ~100 veces, una de las tres ofertas al azar
## si no estaba ya anunciada.
static func generar_tras_combate() -> void:
	if not SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO):
		return
	var noticias := lista()
	var hueco := _primer_hueco(noticias)
	if hueco < 0 or (randi() & 0xFFFF) > UMBRAL_NOTICIA:
		return
	var tipo: int = randi() % 3 + 1
	if _indice_de(noticias, tipo) >= 0:
		return
	noticias[hueco] = {"tipo": tipo, "estado": Estado.EN_ANTENA, "dias": DIAS_NUEVA}
	guardar(noticias)


## sub_80BEBC8.
static func _primer_hueco(noticias: Array[Dictionary]) -> int:
	for i in TOTAL:
		if int(noticias[i]["tipo"]) == Tipo.NINGUNA:
			return i
	return -1


static func _indice_de(noticias: Array[Dictionary], tipo: int) -> int:
	for i in TOTAL:
		if int(noticias[i]["tipo"]) == tipo:
			return i
	return -1


## sub_80BEE84: pasan `dias` días.
static func actualizar_por_dias(dias: int) -> void:
	var noticias := lista()
	var completado := SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO)
	for i in TOTAL:
		var noticia: Dictionary = noticias[i]
		if int(noticia["tipo"]) == Tipo.NINGUNA:
			continue
		if int(noticia["dias"]) < dias:
			noticias[i] = _vacia()
			continue
		if int(noticia["estado"]) == Estado.VISTA and completado:
			noticia["estado"] = Estado.EN_ANTENA
		noticia["dias"] = int(noticia["dias"]) - dias
	_compactar(noticias)
	guardar(noticias)


## sub_80BEC40: sube las noticias para cerrar huecos (solo recorre los 15 primeros).
static func _compactar(noticias: Array[Dictionary]) -> void:
	for i in TOTAL - 1:
		if int(noticias[i]["tipo"]) != Tipo.NINGUNA:
			continue
		for j in range(i + 1, TOTAL):
			if int(noticias[j]["tipo"]) != Tipo.NINGUNA:
				noticias[i] = noticias[j]
				noticias[j] = _vacia()
				break


## FindAnyTVNewsOnTheAir: índice de la primera noticia en antena (-1 si ninguna).
static func en_antena() -> int:
	var noticias := lista()
	for i in TOTAL:
		var noticia: Dictionary = noticias[i]
		if int(noticia["tipo"]) != Tipo.NINGUNA and int(noticia["estado"]) == Estado.EN_ANTENA \
				and int(noticia["dias"]) < DIAS_ANUNCIO:
			return i
	return -1


## DoPokeNews: el texto de la noticia en antena ("" si no hay). El día señalado pasa
## a HOY (la rebaja); si no, a VISTA y anuncia los días que faltan.
static func emitir(hora: int = -1) -> String:
	var indice := en_antena()
	if indice < 0:
		return ""
	var noticias := lista()
	var noticia: Dictionary = noticias[indice]
	var textos: Array = TEXTOS[int(noticia["tipo"])]
	var texto: String
	if int(noticia["dias"]) == 0:
		noticia["estado"] = Estado.HOY
		var h := hora if hora >= 0 else RelojJuego.hora_local()
		texto = String(TranslationServer.translate(StringName(textos[1 if h < HORA_TARDE else 2])))
	else:
		noticia["estado"] = Estado.VISTA
		texto = String(TranslationServer.translate(StringName(textos[0]))).replace("{dias}", str(noticia["dias"]))
	guardar(noticias)
	return texto


## LilycoveCity_DepartmentStoreRooftop_OnTransition: la vendedora de la liquidación
## (FLAG_HIDE_ROOFTOP_LADY_LILYCOVE_MART) solo está el día señalado; el hombre de la
## AZOTEA lo consulta al hablar.
static func al_cambiar_de_mapa() -> void:
	SistemaGuardado.set_flag(BANDERA_LIQUIDACION, hay_rebaja(Tipo.LIQUIDACION))


## GetPriceReduction(tipo): la noticia de `tipo` es la de hoy. El lugar
## (IsPriceDiscounted: hablar con CURRO en CIUDAD PORTUAL, estar en la AZOTEA) lo
## pone quien pregunta.
static func hay_rebaja(tipo: Tipo) -> bool:
	if tipo == Tipo.NINGUNA:
		return false
	var noticias := lista()
	var indice := _indice_de(noticias, tipo)
	return indice >= 0 and int(noticias[indice]["estado"]) == Estado.HOY
