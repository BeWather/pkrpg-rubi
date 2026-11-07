class_name VenenoCampo
extends RefCounted

## Veneno en el campo (fuera de combate): cada 4 pasos los Pokémon envenenados
## del equipo pierden 1 PS y, si llegan a 0, se debilitan.
##
## Referencia: pokeruby src/field_control_avatar.c (UpdatePoisonStepCounter,
## ClearPoisonStepCounter) y src/field_poison.c (DoPoisonFieldEffect,
## FaintFromFieldPoison, AllMonsFainted).
##
## Lógica pura, sin nodos: el AdministradorMapa decide el efecto visual/sonoro,
## los mensajes y la vuelta al punto de curación a partir del Resultado.

## VAR_POISON_STEP_COUNTER (SistemaGuardado.datos_persistentes.contadores).
const CONTADOR_PASOS: String = "pasos_veneno"
const PASOS_POR_CICLO: int = 4


## Qué pasó en un paso (DoPoisonFieldEffect: 0 nada, 1 solo veneno, 2 alguien
## se debilita).
class Resultado:
	extends RefCounted
	## Pokémon que han perdido 1 PS en este paso (numPoisoned).
	var envenenados: int = 0
	## Pokémon que han llegado a 0 PS por el veneno, en el orden del equipo.
	var debilitados: Array[BasePokemon] = []

	## FldeffPoison_Start: sonido y mosaico si hubo veneno o desmayo.
	func hay_efecto() -> bool:
		return envenenados > 0

	## DoPoisonFieldEffect devuelve 2: el script de desmayo corta el paso.
	func se_debilita_alguno() -> bool:
		return not debilitados.is_empty()


## `UpdatePoisonStepCounter`: cuenta el paso (módulo 4) y, al completar el ciclo,
## aplica `aplicar_efecto` al equipo. En un mapa de base secreta
## (MAP_TYPE_SECRET_BASE) ni siquiera se cuenta el paso.
static func procesar_paso(equipo: Array, en_base_secreta: bool = false) -> Resultado:
	if en_base_secreta:
		return Resultado.new()
	var pasos := (SistemaGuardado.get_contador(CONTADOR_PASOS) + 1) % PASOS_POR_CICLO
	SistemaGuardado.set_contador(CONTADOR_PASOS, pasos)
	if pasos != 0:
		return Resultado.new()
	return aplicar_efecto(equipo)


## `ClearPoisonStepCounter`: se llama al empezar un combate.
static func reiniciar_contador() -> void:
	if SistemaGuardado == null or SistemaGuardado.datos_vivos == null:
		return
	SistemaGuardado.set_contador(CONTADOR_PASOS, 0)


## `DoPoisonFieldEffect`: todo Pokémon no huevo con el estado primario veneno
## (el envenenamiento grave también se guarda como ENVENENADO; "grave" es solo
## un dato de combate) pierde 1 PS. Los que llegan a 0 quedan en `debilitados`;
## el estado y la amistad se resuelven después, uno a uno, en `debilitar`.
## Un envenenado que ya está a 0 PS no cuenta: en pokeruby un Pokémon que se
## debilita en combate pierde el estado, así que no puede darse ese caso.
static func aplicar_efecto(equipo: Array) -> Resultado:
	var resultado := Resultado.new()
	for poke in equipo:
		if not (poke is BasePokemon) or not esta_envenenado(poke) or poke.estad_ps_actual <= 0:
			continue
		poke.estad_ps_actual -= 1
		resultado.envenenados += 1
		if poke.estad_ps_actual == 0:
			resultado.debilitados.append(poke)
	return resultado


## GetPrimaryStatus == STATUS_PRIMARY_POISON con especie válida (no huevo).
static func esta_envenenado(pokemon: BasePokemon) -> bool:
	return pokemon != null and not pokemon.huevo and not pokemon.nombre_interno.is_empty() \
		and pokemon.estado == Singleton.ProblemaEstado.ENVENENADO


## `FaintFromFieldPoison`: FRIENDSHIP_EVENT_FAINT_OUTSIDE_BATTLE y se limpia el
## veneno. El estado queda en DEBILITADO, que es el marcador que usan aquí los
## iconos y la ficha del equipo (pokeruby lo dibuja a partir de HP == 0).
static func debilitar(pokemon: BasePokemon) -> void:
	if pokemon == null:
		return
	Amistad.ajustar(pokemon, Amistad.Evento.DEBILITADO_FUERA_BATALLA)
	pokemon.estado = Singleton.ProblemaEstado.DEBILITADO


## `AllMonsFainted`: ningún Pokémon de especie válida (huevos fuera) con PS.
static func todos_debilitados(equipo: Array) -> bool:
	for poke in equipo:
		if poke is BasePokemon and not poke.huevo and not poke.nombre_interno.is_empty() \
				and poke.estad_ps_actual > 0:
			return false
	return true
