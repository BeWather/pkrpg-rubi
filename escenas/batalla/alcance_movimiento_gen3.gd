extends RefCounted
class_name AlcanceMovimientoGen3

## ObjetivosMovimiento de poke.db (PokeAPI); los overrides fijan la semántica
## de Rubí, no la de generaciones posteriores.
const SELECCIONADO := 10
const USUARIO := 7
const ALIADO := 3
const USUARIO_O_ALIADO := 5
const RIVAL_ALEATORIO := 8
const TODOS_SALVO_USUARIO := 9
const AMBOS_RIVALES := 11
const CAMPO_RIVAL := 6
const CAMPO_PROPIO := 4
const TODO_EL_CAMPO := 12
const USUARIO_Y_ALIADOS := 13
const TODOS := 14

const OVERRIDES_RUBI := {
    "SURF": AMBOS_RIVALES,
    "CHAPOTEOLODO": USUARIO,
    "MUD_SPORT": USUARIO,
    "HIDROCHORRO": USUARIO,
    "WATER_SPORT": USUARIO,
    "VELOSAGRADO": USUARIO,
    "SAFEGUARD": USUARIO,
    "GASVENENOSO": SELECCIONADO, # Ruby selects one target before admission.
    "POISON_GAS": SELECCIONADO,
    # En Gen 3 Aullido solo sube el ATAQUE del usuario (no de los aliados).
    "AULLIDO": USUARIO,
}

static func tipo(movimiento: Movimiento, apunta_usuario: bool = false) -> int:
    if movimiento == null:
        return -1
    # TARGET_SPECIAL needs a queue placeholder; retaliation fixes its BANK before PP.
    if int(movimiento.datos.get("numero_movimiento",0)) in [68,243]:return SELECCIONADO
    if int(movimiento.datos.get("numero_movimiento",0))==270:return USUARIO # Ruby handler chooses its actual partner after PP.
    var nombre := movimiento.get_nombre_interno().to_upper()
    if OVERRIDES_RUBI.has(nombre):
        return OVERRIDES_RUBI[nombre]
    if movimiento.datos.has("objetivo_id") and movimiento.datos["objetivo_id"] != null:
        return movimiento.get_objetivo_id()
    # Datos legacy/debug sin objetivo: conservar el comportamiento anterior.
    return USUARIO if apunta_usuario else SELECCIONADO

static func necesita_selector(tipo_objetivo: int) -> bool:
    return tipo_objetivo == SELECCIONADO or tipo_objetivo == ALIADO or tipo_objetivo == USUARIO_O_ALIADO

static func elegibles(tipo_objetivo: int, actor: BasePokemon, aliados: Array[BasePokemon], rivales: Array[BasePokemon]) -> Array[BasePokemon]:
    var disponibles: Array[BasePokemon] = []
    if tipo_objetivo == SELECCIONADO:
        for rival in rivales:
            if _vivo(rival):
                disponibles.append(rival)
    elif tipo_objetivo == ALIADO or tipo_objetivo == USUARIO_O_ALIADO:
        for aliado in aliados:
            if _vivo(aliado) and (tipo_objetivo == USUARIO_O_ALIADO or aliado != actor):
                disponibles.append(aliado)
    return disponibles

## Cursor de objetivo del jugador en DOBLE (battle_controller_player.c,
## sub_802C2EC): recorre el anillo de posiciones {0, 2, 3, 1} = aliado izq.,
## aliado der., rival der., rival izq.; salta al propio usuario y a las
## posiciones ausentes. MOVE_TARGET_SELECTED también puede elegir al compañero.
## La IA y los movimientos llamados siguen usando `elegibles` (solo rivales).
static func elegibles_cursor(tipo_objetivo: int, actor: BasePokemon, aliados: Array[BasePokemon], rivales: Array[BasePokemon]) -> Array[BasePokemon]:
    if tipo_objetivo != SELECCIONADO:
        return elegibles(tipo_objetivo, actor, aliados, rivales)
    var anillo: Array[BasePokemon] = []
    for candidato: BasePokemon in [_en(aliados, 0), _en(aliados, 1), _en(rivales, 1), _en(rivales, 0)]:
        if _vivo(candidato) and candidato != actor:
            anillo.append(candidato)
    return anillo

## Posición inicial del cursor (HandleAction_ChooseMove): el rival izquierdo,
## o el derecho si el izquierdo está ausente.
static func indice_inicial_cursor(disponibles: Array[BasePokemon], rivales: Array[BasePokemon]) -> int:
    for rival: BasePokemon in [_en(rivales, 0), _en(rivales, 1)]:
        if rival != null and disponibles.has(rival):
            return disponibles.find(rival)
    return 0

static func objetivos(tipo_objetivo: int, actor: BasePokemon, seleccionado: BasePokemon, aliados: Array[BasePokemon], rivales: Array[BasePokemon]) -> Array[BasePokemon]:
    var resultado: Array[BasePokemon] = []
    match tipo_objetivo:
        USUARIO:
            if _vivo(actor):
                resultado.append(actor)
        ALIADO, USUARIO_O_ALIADO:
            if _vivo(seleccionado) and aliados.has(seleccionado) and (tipo_objetivo == USUARIO_O_ALIADO or seleccionado != actor):
                resultado.append(seleccionado)
        SELECCIONADO:
            if _vivo(seleccionado) and seleccionado != actor and (rivales.has(seleccionado) or aliados.has(seleccionado)):
                resultado.append(seleccionado)
            else:
                var reemplazo := _reemplazo_seleccionado(actor, seleccionado, aliados, rivales)
                if reemplazo != null:
                    resultado.append(reemplazo)
        RIVAL_ALEATORIO:
            for rival in rivales:
                if _vivo(rival):
                    resultado.append(rival)
            if resultado.size() > 1:
                var elegido: BasePokemon = resultado.pick_random()
                resultado.clear()
                resultado.append(elegido)
        AMBOS_RIVALES, CAMPO_RIVAL:
            for rival in rivales:
                if _vivo(rival):
                    resultado.append(rival)
        TODOS_SALVO_USUARIO, TODOS:
            for rival in rivales:
                if _vivo(rival):
                    resultado.append(rival)
            for aliado in aliados:
                if _vivo(aliado) and (tipo_objetivo == TODOS or aliado != actor):
                    resultado.append(aliado)
        CAMPO_PROPIO, USUARIO_Y_ALIADOS:
            for aliado in aliados:
                if _vivo(aliado):
                    resultado.append(aliado)
        TODO_EL_CAMPO:
            for pokemon in aliados + rivales:
                if _vivo(pokemon):
                    resultado.append(pokemon)
    return resultado

static func soportado(tipo_objetivo: int) -> bool:
    return [SELECCIONADO, USUARIO, ALIADO, USUARIO_O_ALIADO, RIVAL_ALEATORIO, TODOS_SALVO_USUARIO, AMBOS_RIVALES, CAMPO_RIVAL, CAMPO_PROPIO, TODO_EL_CAMPO, USUARIO_Y_ALIADOS, TODOS].has(tipo_objetivo)

## Objetivo elegido ausente (battle_main.c, elección de gBattlerTarget):
## - rival ausente → su compañero de flanco (el otro rival vivo);
## - aliado ausente → el rival enfrentado al usuario (posición ^ BIT_SIDE) y,
##   si también falta, el otro rival (^ BIT_FLANK).
static func _reemplazo_seleccionado(actor: BasePokemon, seleccionado: BasePokemon, aliados: Array[BasePokemon], rivales: Array[BasePokemon]) -> BasePokemon:
    if seleccionado != null and seleccionado != actor and aliados.has(seleccionado):
        var enfrentado := _en(rivales, aliados.find(actor))
        if _vivo(enfrentado):
            return enfrentado
    for rival in rivales:
        if _vivo(rival):
            return rival
    return null

static func _en(lado: Array[BasePokemon], indice: int) -> BasePokemon:
    return lado[indice] if indice >= 0 and indice < lado.size() else null

static func _vivo(pokemon: BasePokemon) -> bool:
    return pokemon != null and pokemon.estad_ps_actual > 0
