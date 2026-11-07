class_name ConcursanteConcurso
extends RefCounted
## Un participante de un concurso: los datos de entrada (`struct ContestPokemon` de
## pokeruby) y su estado durante las apelaciones (`struct ContestantStatus`,
## include/contest.h). Los nombres de los campos de estado siguen el orden y el
## significado del original; los comentarios dan el nombre de pokeruby.

## Valor de `orden_siguiente` sin orden fijado (0xFF en pokeruby).
const ORDEN_LIBRE: int = 0xFF

# === Entrada (ContestPokemon) ===

## Nombre interno de la especie (Pokemon.nombre_interno).
var especie: String = ""
var mote: String = ""
var entrenador: String = ""
## OBJ_EVENT_GFX_* sin prefijo ("BOY_1"...) para la sala del concurso.
var grafico: String = ""
## Bits de IA (CONTEST_AI_*); 0 para el jugador.
var ia_flags: int = 0
## numero_movimiento de los 4 huecos (0 = vacío).
var movimientos: Array[int] = [0, 0, 0, 0]
var carisma: int = 0
var belleza: int = 0
var dulzura: int = 0
var ingenio: int = 0
var dureza: int = 0
var brillo: int = 0
var personalidad: int = 0
var ot_id: int = 0
var shiny: bool = false
var es_jugador: bool = false
## Id en ConcursoRivales (-1 para el jugador).
var rival_id: int = -1

# === Estado (ContestantStatus) ===

## baseAppeal: appeal de la tabla de efectos (base del bonus de combo).
var atractivo_base: int = 0
## appeal: puntos de esta apelación (puede ser negativo).
var atractivo: int = 0
## pointTotal: acumulado de todas las apelaciones.
var puntos_totales: int = 0
## currMove / prevMove.
var mov_actual: int = 0
var mov_previo: int = 0
## moveCategory.
var categoria_mov: int = 0
## ranking: puesto por puntos acumulados (0 = líder; los empates comparten puesto).
var puesto: int = 0
## moveRepeatCount.
var repeticiones: int = 0
## noMoreTurns.
var sin_mas_turnos: bool = false
## nervous.
var nervioso: bool = false
## numTurnsSkipped.
var turnos_saltados: int = 0
## condition: 0, 10, 20 o 30 (estrellas × 10).
var condicion: int = 0
## jam: interferencia recibida en el turno en curso.
var interferencia_recibida: int = 0
## jamReduction.
var reduccion_interferencia: int = 0
## resistant: las interferencias no le restan puntos (pokeruby pone jam2 = 10 y el
## texto, pero no llama a JamContestant).
var resistente: bool = false
## immune.
var inmune: bool = false
## moreEasilyStartled: la interferencia recibida se duplica.
var mas_asustadizo: bool = false
## conditionMod: 1 = acaba de subir la condición; 2 = la ha perdido.
var mod_condicion: int = 0
## turnOrderMod: 1 = orden fijado; 2 = aleatorio (icono «?»).
var mod_orden: int = 0
## turnOrderModAction: 1 antes, 2 después, 3 barajado (bocadillo del juez).
var accion_orden: int = 0
## turnSkipped: no podrá apelar en la siguiente apelación.
var saltara_turno: bool = false
## exploded: no podrá apelar más a partir de la siguiente apelación.
var exploto: bool = false
## overrideCategoryExcitementMod: emociona al público sea cual sea la categoría.
var emocion_forzada: bool = false
## appealTripleCondition.
var condicion_triple: bool = false
## jamSafetyCount.
var protecciones: int = 0
## effectStringId / effectStringId2 (CadenasConcurso.Cadena, NINGUNA = 255).
var cadena: int = 255
var cadena2: int = 255
## repeatedMove / repeatedPrevMove.
var repitio: bool = false
var repitio_previo: bool = false
## completedComboFlag: alguna vez completó un combo (lo mira la IA).
var completo_combo_alguna_vez: bool = false
## hasJudgesAttention.
var atencion_juez: bool = false
## judgesAttentionWasRemoved (solo para la UI).
var atencion_retirada: bool = false
## usedComboMove: este turno usó un iniciador o completó un combo.
var uso_combo: bool = false
## completedCombo (0 o 1).
var combo_completado: int = 0
## comboAppealBonus.
var bonus_combo: int = 0
## repeatJam.
var castigo_repeticion: int = 0
## nextTurnOrder (ORDEN_LIBRE si no está fijado).
var orden_siguiente: int = ORDEN_LIBRE
## attentionLevel: 0..5, texto de fin de apelación.
var nivel_atencion: int = 0
## contestantAnimTarget: otro concursante (objetivo visual de TRANSFORMACIÓN/ROL).
var objetivo_animacion: int = 0


## ClearContestVars: todo el estado a cero (cadenas sin texto, orden libre).
func reiniciar_estado() -> void:
	atractivo_base = 0
	atractivo = 0
	puntos_totales = 0
	mov_actual = 0
	mov_previo = 0
	categoria_mov = 0
	puesto = 0
	repeticiones = 0
	sin_mas_turnos = false
	nervioso = false
	turnos_saltados = 0
	condicion = 0
	interferencia_recibida = 0
	reduccion_interferencia = 0
	resistente = false
	inmune = false
	mas_asustadizo = false
	mod_condicion = 0
	mod_orden = 0
	accion_orden = 0
	saltara_turno = false
	exploto = false
	emocion_forzada = false
	condicion_triple = false
	protecciones = 0
	cadena = 255
	cadena2 = 255
	repitio = false
	repitio_previo = false
	completo_combo_alguna_vez = false
	atencion_juez = false
	atencion_retirada = false
	uso_combo = false
	combo_completado = 0
	bonus_combo = 0
	castigo_repeticion = 0
	orden_siguiente = ORDEN_LIBRE
	nivel_atencion = 0
	objetivo_animacion = 0


## Condición de concurso de una categoría (Movimiento.CategoriaConcurso).
func condicion_de(categoria: int) -> int:
	match categoria:
		Movimiento.CategoriaConcurso.CARISMA: return carisma
		Movimiento.CategoriaConcurso.BELLEZA: return belleza
		Movimiento.CategoriaConcurso.DULZURA: return dulzura
		Movimiento.CategoriaConcurso.INGENIO: return ingenio
		_: return dureza


## Contest_IsMonsTurnDisabled.
func turno_deshabilitado() -> bool:
	return turnos_saltados != 0 or sin_mas_turnos


## IsContestantAllowedToCombo.
func puede_combo() -> bool:
	return not repitio and not nervioso


## Concursante a partir de una fila de ConcursoRivales.
static func desde_rival(fila: Dictionary) -> ConcursanteConcurso:
	var c := ConcursanteConcurso.new()
	c.rival_id = int(fila.get("id", -1))
	c.especie = str(fila.get("especie", ""))
	c.mote = str(fila.get("mote", ""))
	c.entrenador = str(fila.get("entrenador", ""))
	c.grafico = str(fila.get("grafico", ""))
	c.ia_flags = int(fila.get("ia_flags", 0))
	var lista: Variant = fila.get("movimientos_json", "[]")
	if lista is String:
		lista = JSON.parse_string(lista)
	c.movimientos = [0, 0, 0, 0]
	if lista is Array:
		for i in mini(lista.size(), 4):
			c.movimientos[i] = int(lista[i])
	c.carisma = int(fila.get("carisma", 0))
	c.belleza = int(fila.get("belleza", 0))
	c.dulzura = int(fila.get("dulzura", 0))
	c.ingenio = int(fila.get("ingenio", 0))
	c.dureza = int(fila.get("dureza", 0))
	c.brillo = int(fila.get("brillo", 0))
	c.personalidad = 0
	c.ot_id = 0xFFFF
	return c
