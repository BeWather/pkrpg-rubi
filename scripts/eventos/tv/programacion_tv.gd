## programacion_tv.gd
## Los televisores de pokeruby como funciones puras: Event_TV (data/scripts/tv.inc)
## al pulsar A ante una tele, UpdateTVScreensOnMap (src/tv.c) al cargar el mapa,
## UpdateTVShowsPerDay al pasar los días y PutPokemonTodayCaughtOnAir al acabar un
## combate. Los nodos Television de cada casa solo piden aquí qué mostrar y si la
## pantalla se enciende.
##
## | ROM                          | Aquí                                          |
## |------------------------------|-----------------------------------------------|
## | FLAG_SYS_TV_START            | visitar CIUDAD MALVALONA (MauvilleCity_OnTransition la pone junto a FLAG_VISITED_MAUVILLE_CITY) |
## | FLAG_SYS_TV_WATCH            | bandera `tv_vista`                            |
## | FLAG_SYS_TV_HOME             | HistoriaVillaRaiz.BANDERA_TELE                |
## | FLAG_SYS_TV_LATI             | bandera `tv_lati` (la pone el SALÓN DE LA FAMA) |
## | VAR_TEMP_3 (MAMÁ/PAPÁ)       | banderas temporales `tv_progenitor_*`         |
## | GAME_STAT_WATCHED_TV         | contador `tele_vista`                         |
## | VAR_DAYS                     | contador `tv_dia` (RelojJuego.dias_desde_inicio) |
##
## Qué se emite, por orden (Event_TV): la película o el boletín de LATIOS en el salón
## del jugador; «OPERACIÓN ENTRENADOR» de GABI y TEO (ProgramaGabiTeo); las NOTICIAS
## POKéMON (NoticiasPokemon); los programas grabados (ProgramasTV); si no hay nada, el
## mensaje por defecto.
extends RefCounted
class_name ProgramacionTV

## FLAG_SYS_TV_WATCH: ya se vio lo que había en antena desde que se cargó el mapa.
const BANDERA_TV_VISTA: String = "tv_vista"
## FLAG_SYS_TV_LATI: noticias de emergencia de LATIOS (tras la LIGA).
const BANDERA_TV_LATI: String = "tv_lati"
## GAME_STAT_WATCHED_TV.
const CONTADOR_TELE_VISTA: String = "tele_vista"
## VAR_DAYS: último día (gLocalTime.days) en que se actualizaron los programas.
const CONTADOR_DIA: String = "tv_dia"
## VAR_TEMP_3 = 1 / 2: a quién le gustaría el programa en esta visita al mapa.
const TEMPORAL_MAMA: String = "tv_progenitor_mama"
const TEMPORAL_PAPA: String = "tv_progenitor_papa"
## Donde se pone FLAG_SYS_TV_START.
const MAPA_INICIO_TV: String = "ciudad_malvalona"
## LilycoveCity_CoveLilyMotel_1F: su tele siempre está encendida.
const MAPA_MOTEL: String = "ciudad_calagua_motel"

## UnknownString_81A0E68, PlayersHouse_1F_Text_TheresAMovieOnTV, gOtherText_Mom/Dad.
const TEXTO_NADA: String = "TV_NADA_INTERESANTE"
const TEXTO_PELICULA: String = "TV_PELICULA"
const TEXTO_MAMA: String = "TV_MAMA"
const TEXTO_PAPA: String = "TV_PAPA"
## UnknownString_8172C50: el boletín del POKéMON azul (Rubí).
const TEXTO_NOTICIAS_LATI: String = "TV_NOTICIAS_LATI"

## CheckForBigMovieOrEmergencyNewsOnTV.
enum Especial { NINGUNO, NOTICIAS, PELICULA }


## FLAG_SYS_TV_START.
static func tv_iniciada() -> bool:
	return SistemaGuardado.lugar_visitado(MAPA_INICIO_TV)


static func tv_vista() -> bool:
	return SistemaGuardado.get_flag(BANDERA_TV_VISTA)


## ¿`clave_mapa` es la planta baja de la casa del jugador?
static func es_salon_del_jugador(clave_mapa: String) -> bool:
	return clave_mapa == HistoriaVillaRaiz.mapa_casa_jugador()


## CheckForBigMovieOrEmergencyNewsOnTV: solo en el salón del jugador. La ROM
## también devuelve NOTICIAS antes de FLAG_SYS_TV_HOME; aquí esa tele la lleva el
## guion de la mudanza (EventoCasaVillaRaiz), así que hasta entonces no hay nada.
static func especial(clave_mapa: String) -> Especial:
	if not es_salon_del_jugador(clave_mapa):
		return Especial.NINGUNO
	if SistemaGuardado.get_flag(BANDERA_TV_LATI):
		return Especial.NOTICIAS
	if SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_TELE):
		return Especial.PELICULA
	return Especial.NINGUNO


## Lo que enciende las pantallas en UpdateTVScreensOnMap: un programa grabado
## (sub_80BD8B8), una NOTICIA POKéMON (FindAnyTVNewsOnTheAir) o GABI y TEO
## (IsTVShowInSearchOfTrainersAiring).
static func hay_programa_en_antena() -> bool:
	return ProgramasTV.programa_para_ver() >= 0 or NoticiasPokemon.en_antena() >= 0 \
		or ProgramaGabiTeo.en_antena()


## UpdateTVScreensOnMap al cargar `clave_mapa`. Devuelve true si las pantallas
## se encienden, false si se apagan y null si no se tocan (salón del jugador:
## película o intro, su tele la gobierna EventoCasaVillaRaiz).
static func al_cargar_mapa(clave_mapa: String) -> Variant:
	SistemaGuardado.set_flag(BANDERA_TV_VISTA, true)
	match especial(clave_mapa):
		Especial.NOTICIAS:
			return true
		Especial.PELICULA:
			return null
	if es_salon_del_jugador(clave_mapa):
		return null
	if clave_mapa == MAPA_MOTEL:
		return true
	if tv_iniciada() and hay_programa_en_antena():
		SistemaGuardado.set_flag(BANDERA_TV_VISTA, false)
		return true
	return false


## Event_TV. Devuelve {"texto": lo que se muestra, "apagar": TurnOffTVScreen al
## terminar}. Lo que se emite sale de antena y pone FLAG_SYS_TV_WATCH.
static func ver(clave_mapa: String) -> Dictionary:
	SistemaGuardado.incrementar_contador(CONTADOR_TELE_VISTA)  # incrementgamestat GAME_STAT_WATCHED_TV
	match especial(clave_mapa):
		Especial.PELICULA:
			return {"texto": String(TranslationServer.translate(TEXTO_PELICULA)), "apagar": false}
		Especial.NOTICIAS:
			return {"texto": emitir_noticias_lati(), "apagar": true}
	if not tv_iniciada() or tv_vista():
		return {"texto": texto_nada_interesante(clave_mapa), "apagar": true}  # EventScript_1A6EF1
	var textos: Array[String] = []
	if ProgramaGabiTeo.en_antena():
		textos = ProgramaGabiTeo.emitir()  # DoTVShowInSearchOfTrainers
	else:
		var noticia := NoticiasPokemon.emitir()  # DoPokeNews
		if not noticia.is_empty():
			textos = [noticia]
		else:
			var indice := ProgramasTV.programa_para_ver()  # special_0x44
			if indice >= 0:
				textos = ProgramasTV.emitir(indice)  # DoTVShow
			else:
				textos = [texto_nada_interesante(clave_mapa)]  # EventScript_1A6F3F
	SistemaGuardado.set_flag(BANDERA_TV_VISTA, true)
	return {"texto": "\\p".join(textos), "apagar": true}


## EventScript_1A6F0B: el boletín del POKéMON azul; special InitRoamer suelta a
## LATIOS, se quita FLAG_SYS_TV_LATI y se pone FLAG_LATIOS_OR_LATIAS_ROAMING.
static func emitir_noticias_lati() -> String:
	PokemonErrante.iniciar()
	SistemaGuardado.set_flag(BANDERA_TV_LATI, false)
	SistemaGuardado.set_flag(PokemonErrante.BANDERA_LIBERADO, true)
	return String(TranslationServer.translate(TEXTO_NOTICIAS_LATI))


## DoTimeBasedEvents → UpdatePerDay → UpdateTVShowsPerDay: si han pasado días desde
## la última vez (VAR_DAYS), los descuenta del brote y de las NOTICIAS POKéMON y avanza
## el número de la ISLA ESPEJISMO. Con
## el reloj atrasado no hace nada.
static func actualizar_por_dias() -> void:
	var hoy := RelojJuego.dias_desde_inicio()
	var dia := SistemaGuardado.get_contador(CONTADOR_DIA)
	if dia >= hoy:
		return
	ProgramasTV.actualizar_por_dias(hoy - dia)  # sub_80BE8EC + UpdateMassOutbreakTimeLeft
	NoticiasPokemon.actualizar_por_dias(hoy - dia)  # sub_80BEE84
	IslaEspejismo.actualizar_por_dias(hoy - dia)  # UpdateMirageRnd
	SistemaGuardado.set_contador(CONTADOR_DIA, hoy)


## PutPokemonTodayCaughtOnAir (al acabar cualquier combate salvo el primero, el
## tutorial de BLASCO y los de la ZONA SAFARI): tras la LIGA puede anunciarse una
## NOTICIA POKéMON (sub_80BEB20) o un brote masivo (sub_80BE778). Los demás
## programas que graba (POKéMON HOY, EL MUNDO DE LOS MAESTROS) son para MEZCLAR
## RÉCORDS.
static func tras_combate() -> void:
	NoticiasPokemon.generar_tras_combate()
	ProgramasTV.crear_brote_tras_combate()


## GetMomOrDadStringForTVMessage + UnknownString_81A0E68.
static func texto_nada_interesante(clave_mapa: String) -> String:
	var texto := String(TranslationServer.translate(TEXTO_NADA))
	return texto.replace("{progenitor}", String(TranslationServer.translate(progenitor(clave_mapa))))


## GetMomOrDadStringForTVMessage: MAMÁ en el salón del jugador; si no, el que
## salió en esta visita al mapa (VAR_TEMP_3) o uno al azar que se recuerda.
static func progenitor(clave_mapa: String) -> String:
	if es_salon_del_jugador(clave_mapa):
		_recordar_progenitor(true)
	if SistemaGuardado.get_flag_temporal(TEMPORAL_MAMA):
		return TEXTO_MAMA
	if SistemaGuardado.get_flag_temporal(TEMPORAL_PAPA):
		return TEXTO_PAPA
	var mama := randi() % 2 != 0
	_recordar_progenitor(mama)
	return TEXTO_MAMA if mama else TEXTO_PAPA


static func _recordar_progenitor(mama: bool) -> void:
	SistemaGuardado.set_flag_temporal(TEMPORAL_MAMA, mama)
	SistemaGuardado.set_flag_temporal(TEMPORAL_PAPA, not mama)
