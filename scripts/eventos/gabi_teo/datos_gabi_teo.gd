## datos_gabi_teo.gd
## gSaveBlock1.gabbyAndTyData de pokeruby (include/global.h, src/tv.c) guardado en
## los datos persistentes de SistemaGuardado. Cada campo es una entrada propia con
## prefijo `gabi_teo_`: las partidas sin ellas leen los valores de ResetGabbyAndTy
## (todo a 0 y la cita a «ninguna»), así que las partidas viejas cargan sin migrar.
##
## | ROM            | Aquí                                                    |
## |----------------|---------------------------------------------------------|
## | mon1, mon2     | textos  gabi_teo_pokemon_1/_2 (nombre_interno, "" = 0)  |
## | lastMove       | texto   gabi_teo_ultimo_movimiento (nombre_interno)     |
## | quote          | contador gabi_teo_cita (id de PALABRAS FÁCILES, 0xFFFF) |
## | mapnum         | texto   gabi_teo_lugar (MapaConfiguracion.seccion)      |
## | battleNum      | contador gabi_teo_num_combate (RotacionGabiTeo)         |
## | valA_0..valA_4 | banderas gabi_teo_a0..gabi_teo_a4                       |
## | valB_0..valB_3 | banderas gabi_teo_b0..gabi_teo_b3                       |
##
## valA_0 = el jugador recibió daño, valA_1 = se le debilitó algún Pokémon,
## valA_2 = usó objetos de curación, valA_3 = lanzó balls, valA_4 = el programa
## «OPERACIÓN ENTRENADOR» está en antena. valB_* es la copia de valA_0..3 de la
## última entrevista (GabbyAndTyAfterInterview).
extends RefCounted
class_name DatosGabiTeo

const PREFIJO: String = "gabi_teo_"
const CLAVE_POKEMON_1: String = PREFIJO + "pokemon_1"
const CLAVE_POKEMON_2: String = PREFIJO + "pokemon_2"
const CLAVE_ULTIMO_MOVIMIENTO: String = PREFIJO + "ultimo_movimiento"
const CLAVE_CITA: String = PREFIJO + "cita"
const CLAVE_LUGAR: String = PREFIJO + "lugar"
const CLAVE_A: String = PREFIJO + "a%d"
const CLAVE_B: String = PREFIJO + "b%d"
## valA_4: «OPERACIÓN ENTRENADOR» en antena.
const INDICE_EN_ANTENA: int = 4
## Sin cita (quote = 0xFFFF).
const SIN_CITA: int = PalabrasFaciles.PALABRA_VACIA

## GabbyAndTyGetLastBattleTrivia.
enum Curiosidad { NINGUNA, SIN_DANO, BALLS, OBJETOS, DEBILITADOS }


## ── Campos ──────────────────────────────────────────────────────────────────

static func pokemon_1() -> String:
	return SistemaGuardado.get_texto(CLAVE_POKEMON_1)


static func pokemon_2() -> String:
	return SistemaGuardado.get_texto(CLAVE_POKEMON_2)


static func ultimo_movimiento() -> String:
	return SistemaGuardado.get_texto(CLAVE_ULTIMO_MOVIMIENTO)


static func cita() -> int:
	return SistemaGuardado.get_contador(CLAVE_CITA, SIN_CITA)


static func set_cita(id_palabra: int) -> void:
	SistemaGuardado.set_contador(CLAVE_CITA, id_palabra)


static func lugar() -> String:
	return SistemaGuardado.get_texto(CLAVE_LUGAR)


static func num_combate() -> int:
	return SistemaGuardado.get_contador(RotacionGabiTeo.CONTADOR_COMBATES)


static func valor_a(indice: int) -> bool:
	return SistemaGuardado.get_flag(CLAVE_A % indice)


static func set_valor_a(indice: int, valor: bool) -> void:
	SistemaGuardado.set_flag(CLAVE_A % indice, valor)


static func valor_b(indice: int) -> bool:
	return SistemaGuardado.get_flag(CLAVE_B % indice)


static func set_valor_b(indice: int, valor: bool) -> void:
	SistemaGuardado.set_flag(CLAVE_B % indice, valor)


## ── src/tv.c ────────────────────────────────────────────────────────────────

## ResetGabbyAndTy.
static func reiniciar() -> void:
	SistemaGuardado.set_texto(CLAVE_POKEMON_1, "")
	SistemaGuardado.set_texto(CLAVE_POKEMON_2, "")
	SistemaGuardado.set_texto(CLAVE_ULTIMO_MOVIMIENTO, "")
	set_cita(SIN_CITA)
	SistemaGuardado.set_texto(CLAVE_LUGAR, "")
	SistemaGuardado.set_contador(RotacionGabiTeo.CONTADOR_COMBATES, 0)
	for i in 5:
		set_valor_a(i, false)
	for i in 4:
		set_valor_b(i, false)


## GabbyAndTyBeforeInterview: guarda el último combate, cuenta la victoria (tope
## 0xff) y quita el programa de antena. Devuelve true si no hubo último movimiento
## (la ROM pone FLAG_TEMP_1: no hay entrevista).
static func antes_de_entrevista(resultados: ResultadosCombate) -> bool:
	SistemaGuardado.set_texto(CLAVE_POKEMON_1, resultados.pokemon_1)
	SistemaGuardado.set_texto(CLAVE_POKEMON_2, resultados.pokemon_2)
	SistemaGuardado.set_texto(CLAVE_ULTIMO_MOVIMIENTO, resultados.ultimo_movimiento)
	RotacionGabiTeo.registrar_combate()
	set_valor_a(0, resultados.jugador_danado)
	set_valor_a(1, resultados.debilitados_jugador > 0)
	set_valor_a(2, resultados.curaciones_jugador > 0)
	# La ROM solo pone valA_3 a 1 (nunca lo borra aquí).
	if resultados.uso_balls():
		set_valor_a(3, true)
	quitar_de_antena()
	return resultados.ultimo_movimiento.is_empty()


## GabbyAndTyAfterInterview: copia valA_0..3 en valB_0..3, pone el programa en
## antena y recuerda la sección del mapa (gMapHeader.regionMapSectionId).
## La cita ya la escribió la pantalla de PALABRAS FÁCILES.
static func despues_de_entrevista(seccion_mapa: String) -> void:
	for i in 4:
		set_valor_b(i, valor_a(i))
	set_valor_a(INDICE_EN_ANTENA, true)
	SistemaGuardado.set_texto(CLAVE_LUGAR, seccion_mapa)


## TakeTVShowInSearchOfTrainersOffTheAir.
static func quitar_de_antena() -> void:
	set_valor_a(INDICE_EN_ANTENA, false)


## IsTVShowInSearchOfTrainersAiring.
static func en_antena() -> bool:
	return valor_a(INDICE_EN_ANTENA)


## GabbyAndTyGetLastQuote: la cita anterior (o SIN_CITA). La ROM la borra al
## leerla (quote |= 0xffff).
static func tomar_ultima_cita() -> int:
	var id_palabra := cita()
	if id_palabra != SIN_CITA:
		set_cita(SIN_CITA)
	return id_palabra


## GabbyAndTyGetLastBattleTrivia.
static func ultima_curiosidad() -> Curiosidad:
	if not valor_b(0):
		return Curiosidad.SIN_DANO
	if valor_b(3):
		return Curiosidad.BALLS
	if valor_b(2):
		return Curiosidad.OBJETOS
	if valor_b(1):
		return Curiosidad.DEBILITADOS
	return Curiosidad.NINGUNA
