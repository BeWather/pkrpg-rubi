## reto_torre_batalla.gd
## Lógica de la modalidad de la TORRE BATALLA (pokeruby src/battle_tower.c): estado del reto por nivel, racha y récord,
## elección de entrenadores, equipos rivales, condiciones de inscripción, cintas y premios. Sin nodos: los guiones de
## los mapas (EventoVestibuloTorre, EventoAscensorTorre, EventoPasilloTorre, EventoSalaTorre) la usan.
##
## Sin equivalente: los entrenadores de la mezcla de récords y del lector e-Reader (ChooseSpecialBattleTowerTrainer).
class_name RetoTorreBatalla
extends RefCounted

const RUTA_DATOS: String = "res://BaseDatos/torre_batalla.json"

## gSaveBlock2.battleTower.var_4AE.
enum Estado {
	SIN_RETO = 0,
	INSCRITO = 1,  ## Inscrito y guardado: si se carga así, no se guardó al salir.
	PAUSADO = 2,  ## «Guardar y dejar de jugar» entre combates.
	PREMIADO = 3,  ## La racha sigue al volver.
	GANADO = 4,  ## Siete victorias: falta el premio.
	PERDIDO = 5,
	PREMIO_PENDIENTE = 6,  ## La MOCHILA estaba llena.
}

## Índice del nivel (battleTowerLevelType).
const NIVEL_50: int = 0
const NIVEL_100: int = 1
const COMBATES_POR_RETO: int = 7
const TAMANO_EQUIPO: int = 3
const MAX_RACHA: int = 9999
const MAX_DESAFIOS: int = 1430
const RACHA_CINTAS: int = 55

## FLAG_RECEIVED_SILVER_SHIELD / FLAG_RECEIVED_GOLD_SHIELD.
const BANDERA_ESCUDO_PLATA: String = "torre_batalla_escudo_plata"
const BANDERA_ESCUDO_ORO: String = "torre_batalla_escudo_oro"
## DECOR_SILVER_SHIELD / DECOR_GOLD_SHIELD.
const DECORACION_ESCUDO_PLATA: int = 42
const DECORACION_ESCUDO_ORO: int = 43
## MON_DATA_WINNING_RIBBON / MON_DATA_VICTORY_RIBBON.
const CINTA_NIVEL_50: String = "GANADOR"
const CINTA_NIVEL_100: String = "VICTORIA"

const _NIVEL: String = "torre_batalla_nivel"
const _ULTIMO_NIVEL: String = "torre_batalla_ultimo_nivel"
const _ESTADO: String = "torre_batalla_estado_%d"
const _COMBATE: String = "torre_batalla_combate_%d"
const _DESAFIO: String = "torre_batalla_desafio_%d"
const _RECORD: String = "torre_batalla_record_%d"
const _ULTIMA_RACHA: String = "torre_batalla_ultima_racha_%d"
const _YA_GUARDADO: String = "torre_batalla_ya_guardado"
const _ENTRENADOR: String = "torre_batalla_entrenador"
const _PREMIO: String = "torre_batalla_premio"
const _ELEGIDO: String = "torre_batalla_elegido_%d"
const _VENCIDO: String = "torre_batalla_vencido_%d"
## VAR_BRAVO_TRAINER_BATTLE_TOWER_ON: la reportera puede aparecer en el vestíbulo.
const _BRAVO: String = "torre_batalla_bravo"
## gSaveBlock1.easyChats.unk2B28 (ids de PALABRAS FÁCILES separados por comas).
const _SALUDO: String = "torre_batalla_saludo"
## battleTower.defeatedByTrainerName, defeatedBySpecies, firstMonSpecies y battleOutcome == 1.
const _ULTIMO_RIVAL: String = "torre_batalla_ultimo_rival"
const _ULTIMA_ESPECIE_RIVAL: String = "torre_batalla_ultima_especie_rival"
const _ULTIMA_ESPECIE_PROPIA: String = "torre_batalla_ultima_especie_propia"
const _ULTIMO_GANADO: String = "torre_batalla_ultimo_ganado"
## gUnknown_083DB7F4: ARE, YOU, READY, QUES, HERE_I_COME, EXCL.
const SALUDO_INICIAL: Array[int] = [0x100F, 0x0A02, 0x0E25, 0x0C03, 0x0803, 0x0C00]

static var _datos: Dictionary = {}
## SavePlayerParty: el equipo entero y lo que cambia en combate de cada Pokémon. Vacío si no hay reto en curso en
## esta sesión de juego.
static var _copia_equipo: Array[Dictionary] = []


static func datos() -> Dictionary:
	if _datos.is_empty():
		var archivo := FileAccess.open(RUTA_DATOS, FileAccess.READ)
		if archivo != null:
			var leido: Variant = JSON.parse_string(archivo.get_as_text())
			if leido is Dictionary:
				_datos = leido
	return _datos


## ---------------------------------------------------------------------------
## Estado por nivel
## ---------------------------------------------------------------------------

static func nivel() -> int:
	return SistemaGuardado.get_contador(_NIVEL, NIVEL_50)


static func fijar_nivel(valor: int) -> void:
	SistemaGuardado.set_contador(_NIVEL, valor)


static func nivel_real(tipo: int = -1) -> int:
	return 100 if (nivel() if tipo < 0 else tipo) == NIVEL_100 else 50


static func estado(tipo: int = -1) -> int:
	return SistemaGuardado.get_contador(_ESTADO % _tipo(tipo), Estado.SIN_RETO)


static func fijar_estado(valor: int, tipo: int = -1) -> void:
	SistemaGuardado.set_contador(_ESTADO % _tipo(tipo), valor)


static func combate(tipo: int = -1) -> int:
	return SistemaGuardado.get_contador(_COMBATE % _tipo(tipo), 1)


static func fijar_combate(valor: int, tipo: int = -1) -> void:
	SistemaGuardado.set_contador(_COMBATE % _tipo(tipo), valor)


static func desafio(tipo: int = -1) -> int:
	return SistemaGuardado.get_contador(_DESAFIO % _tipo(tipo), 1)


static func fijar_desafio(valor: int, tipo: int = -1) -> void:
	SistemaGuardado.set_contador(_DESAFIO % _tipo(tipo), valor)


static func record(tipo: int = -1) -> int:
	return SistemaGuardado.get_contador(_RECORD % _tipo(tipo), 0)


static func ultima_racha(tipo: int = -1) -> int:
	return SistemaGuardado.get_contador(_ULTIMA_RACHA % _tipo(tipo), 0)


## SetBattleTowerProperty 13.
static func anotar_ultima_racha() -> void:
	SistemaGuardado.set_contador(_ULTIMA_RACHA % nivel(), racha_actual())


static func ya_guardado() -> bool:
	return SistemaGuardado.get_contador(_YA_GUARDADO, 0) == 1


static func fijar_ya_guardado(valor: bool) -> void:
	SistemaGuardado.set_contador(_YA_GUARDADO, 1 if valor else 0)


static func _tipo(tipo: int) -> int:
	return nivel() if tipo < 0 else tipo


## ResetBattleTowerStreak.
static func reiniciar_racha(tipo: int = -1) -> void:
	fijar_estado(Estado.SIN_RETO, tipo)
	fijar_combate(1, tipo)
	fijar_desafio(1, tipo)


## SetBattleTowerProperty 11: si no quedó PREMIADO, se pierde la racha.
static func cancelar_inscripcion() -> void:
	if estado() != Estado.PREMIADO:
		reiniciar_racha()


## GetCurrentBattleTowerWinStreak.
static func racha_actual(tipo: int = -1) -> int:
	return mini((desafio(tipo) - 1) * COMBATES_POR_RETO - 1 + combate(tipo), MAX_RACHA)


## SaveCurrentWinStreak.
static func anotar_racha() -> void:
	var clave := _RECORD % nivel()
	SistemaGuardado.set_contador(clave, maxi(SistemaGuardado.get_contador(clave, 0), racha_actual()))


## GetBestBattleTowerStreak.
static func mejor_racha() -> int:
	return mini(maxi(record(NIVEL_50), record(NIVEL_100)), MAX_RACHA)


## sub_8110494: «ACTUAL» si el reto sigue; si no, «ANTERIOR».
static func racha_en_curso(tipo: int) -> bool:
	return estado(tipo) in [Estado.PAUSADO, Estado.PREMIADO, Estado.PREMIO_PENDIENTE]


## sub_8134548 (OnFrame del vestíbulo con VAR_TEMP_0 = 0): revisa los dos niveles y devuelve qué guion toca: uno de
## Estado.INSCRITO (no se guardó), GANADO, PERDIDO, PAUSADO, o SIN_RETO si ninguno.
static func revisar_al_entrar() -> int:
	var resultado: int = Estado.SIN_RETO
	var hay_guion := false
	for tipo: int in [NIVEL_50, NIVEL_100]:
		match estado(tipo):
			Estado.INSCRITO:
				reiniciar_racha(tipo)
				resultado = Estado.INSCRITO
				hay_guion = true
			Estado.GANADO, Estado.PERDIDO, Estado.PAUSADO:
				resultado = estado(tipo)
				hay_guion = true
				# BattleTowerUtil y los guiones usan el nivel en curso; el reto pendiente es el de este nivel.
				fijar_nivel(tipo)
			Estado.PREMIADO, Estado.PREMIO_PENDIENTE:
				pass
			_:
				reiniciar_racha(tipo)
	return resultado if hay_guion else Estado.SIN_RETO


## ---------------------------------------------------------------------------
## Entrenadores (ChooseNextBattleTowerTrainer)
## ---------------------------------------------------------------------------

static func entrenador_actual() -> int:
	return SistemaGuardado.get_contador(_ENTRENADOR, 0)


static func elegir_siguiente_entrenador(rng: RandomNumberGenerator) -> int:
	var numero := combate()
	var ronda := desafio()
	var ya_vencidos: Array[int] = []
	for i in numero - 1:
		ya_vencidos.append(SistemaGuardado.get_contador(_VENCIDO % i, -1))
	var elegido := -1
	while elegido < 0 or ya_vencidos.has(elegido):
		var azar := rng.randi() & 0xFF
		if ronda > COMBATES_POR_RETO:
			elegido = ((azar * 30) >> 8) + 70
		elif numero == COMBATES_POR_RETO:
			elegido = ((azar * 5) >> 7) + (ronda - 1) * 10 + 20
		else:
			elegido = ((azar * 5) >> 6) + (ronda - 1) * 10
	SistemaGuardado.set_contador(_ENTRENADOR, elegido)
	if numero < COMBATES_POR_RETO:
		SistemaGuardado.set_contador(_VENCIDO % (numero - 1), elegido)
	return elegido


static func datos_entrenador_torre(id: int) -> Dictionary:
	return datos()["entrenadores"][id]


## get_trainer_class_name_index, get_trainer_class_pic_index, get_trainer_name. Sin frase de derrota ni dinero.
static func crear_entrenador(id: int) -> DatosEntrenador:
	var fila := datos_entrenador_torre(id)
	var entrenador := DatosEntrenador.new()
	entrenador.nombre = str(fila["nombre"])
	entrenador.clase_entrenador = str(fila["clase"])
	entrenador.num_sprite = int(fila["num_sprite"])
	entrenador.sexo = str(fila["sexo"])
	entrenador.ratio_dinero = 0
	entrenador.frase_derrota = ""
	entrenador.musica_id = "BATALLA_ENTRENADOR_1"
	return entrenador


static func clave_saludo(id: int) -> String:
	return "TORRE_BATALLA_SALUDO_%03d" % id


## IVs fijos, primer Pokémon de la tabla y tamaño de la tabla según el entrenador (FillBattleTowerTrainerParty).
static func parametros_grupo(id: int) -> Dictionary:
	if id < 20:
		return {"iv": 6, "inicio": 0, "tamano": 60}
	if id < 30:
		return {"iv": 9, "inicio": 30, "tamano": 60}
	if id < 40:
		return {"iv": 12, "inicio": 60, "tamano": 60}
	if id < 50:
		return {"iv": 15, "inicio": 90, "tamano": 60}
	if id < 60:
		return {"iv": 18, "inicio": 120, "tamano": 60}
	if id < 70:
		return {"iv": 21, "inicio": 150, "tamano": 60}
	if id < 80:
		return {"iv": 31, "inicio": 180, "tamano": 60}
	return {"iv": 31, "inicio": 200, "tamano": 100}


## Índices de la tabla del nivel: tres Pokémon con todas las banderas del entrenador, sin especies ni objetos repetidos.
static func elegir_indices_equipo(id: int, tipo: int, rng: RandomNumberGenerator) -> Array[int]:
	var tabla: Array = datos()["nivel_100" if tipo == NIVEL_100 else "nivel_50"]
	var grupo := parametros_grupo(id)
	var flags: int = int(datos_entrenador_torre(id)["flags"])
	var elegidos: Array[int] = []
	while elegidos.size() < TAMANO_EQUIPO:
		var indice: int = ((rng.randi() & 0xFF) * int(grupo["tamano"])) / 256 + int(grupo["inicio"])
		var candidato: Dictionary = tabla[indice]
		if flags != 0 and (int(candidato["flags"]) & flags) != flags:
			continue
		var valido := true
		for previo: int in elegidos:
			var otro: Dictionary = tabla[previo]
			if otro["especie"] == candidato["especie"] \
					or (int(otro["objeto"]) != 0 and otro["objeto"] == candidato["objeto"]):
				valido = false
				break
		if valido:
			elegidos.append(indice)
	return elegidos


## FillBattleTowerTrainerParty + CreateMonWithEVSpread: la naturaleza y la habilidad salen al azar al crearlo; `.nature`
## de la tabla no se usa, como en Rubí. Con FRUSTRACIÓN la amistad queda a 0 para este y los siguientes.
static func generar_equipo_rival(id: int, tipo: int, rng: RandomNumberGenerator) -> Array[BasePokemon]:
	var tabla: Array = datos()["nivel_100" if tipo == NIVEL_100 else "nivel_50"]
	var objetos: Array = datos()["objetos"]
	var fila := datos_entrenador_torre(id)
	var iv: int = int(parametros_grupo(id)["iv"])
	var nivel_rival := nivel_real(tipo)
	var fabrica := DatosCrianza.new()
	var felicidad := 255
	var equipo: Array[BasePokemon] = []
	for indice in elegir_indices_equipo(id, tipo, rng):
		var entrada: Dictionary = tabla[indice]
		var pokemon := BasePokemon.new(str(entrada["especie"]), nivel_rival, str(fila["clase"]))
		_aplicar_ev(pokemon, int(entrada["ev"]))
		pokemon.aplicar_snapshot({"iv_ps": iv, "iv_ataque": iv, "iv_defensa": iv, "iv_ataque_especial": iv,
				"iv_defensa_especial": iv, "iv_velocidad": iv})
		pokemon.estad_ps_actual = pokemon.estad_ps
		var movimientos: Array[Movimiento] = []
		for nombre: Variant in entrada["movimientos"]:
			var movimiento := fabrica.crear_movimiento(str(nombre))
			if movimiento != null:
				movimientos.append(movimiento)
			if str(nombre) == "FRUSTRACION":
				felicidad = 0
		pokemon.movimientos = movimientos
		pokemon.felicidad = felicidad
		pokemon.objeto = str(objetos[int(entrada["objeto"])])
		equipo.append(pokemon)
	return equipo


## evSpread: 510 repartidos a partes iguales entre las estadísticas marcadas (PS, ATQ, DEF, VEL, ATE, DFE).
static func _aplicar_ev(pokemon: BasePokemon, reparto: int) -> void:
	var cuantas := 0
	for bit in 6:
		if reparto & (1 << bit):
			cuantas += 1
	var valor: int = 510 / maxi(cuantas, 1)
	pokemon.ev_ps = valor if reparto & 1 else 0
	pokemon.ev_ataque = valor if reparto & 2 else 0
	pokemon.ev_defensa = valor if reparto & 4 else 0
	pokemon.ev_velocidad = valor if reparto & 8 else 0
	pokemon.ev_ataque_especial = valor if reparto & 16 else 0
	pokemon.ev_defensa_especial = valor if reparto & 32 else 0


## ---------------------------------------------------------------------------
## Inscripción (CheckPartyBattleTowerBanlist, IsMonAllowedInBattleTower)
## ---------------------------------------------------------------------------

## El Pokémon puede entrar por sí mismo: ni HUEVO, ni vetado, ni por encima de nivel 50 en la sala de nivel 50.
static func pokemon_admitido(pokemon: BasePokemon, tipo: int) -> bool:
	if pokemon == null or pokemon.huevo:
		return false
	if (datos()["vetados"] as Array).has(pokemon.nombre_interno):
		return false
	return tipo != NIVEL_50 or pokemon.nivel <= 50


## Recorre el equipo como CheckMonBattleTowerBanlist: cuenta los que suman sin repetir especie ni objeto.
static func equipo_admitido(equipo: Array, tipo: int) -> bool:
	var seleccion: Array[BasePokemon] = []
	for pokemon: Variant in equipo:
		if pokemon is BasePokemon and pokemon_admitido(pokemon, tipo) and compatible_con(pokemon, seleccion):
			seleccion.append(pokemon)
	return seleccion.size() >= TAMANO_EQUIPO


static func compatible_con(pokemon: BasePokemon, seleccion: Array) -> bool:
	for otro: BasePokemon in seleccion:
		if otro.nombre_interno == pokemon.nombre_interno:
			return false
		if not pokemon.objeto.is_empty() and otro.objeto == pokemon.objeto:
			return false
	return true


## gStringVar1 de CheckPartyBattleTowerBanlist: los vetados atrapados tras «Los HUEVOS», con su separador, y el verbo.
static func texto_vetados() -> String:
	var atrapados: Array[String] = []
	for especie: Variant in datos()["vetados"]:
		if SistemaGuardado.pokemon_atrapado(str(especie)):
			atrapados.append(str(especie))
	var texto := ""
	for i in atrapados.size():
		if i + 1 == atrapados.size():
			texto += " y "
		else:
			texto += ", "
		if i == 1:
			texto += "\\n"
		elif i > 1 and i % 2 == 1:
			texto += "\\w\\n"
		texto += str(DatabaseManager.obtener_datos_pokemon(atrapados[i]).get("nombre", atrapados[i]))
	var verbo := "no pueden"
	if atrapados.is_empty() or atrapados.size() % 2 == 0:
		return texto + " " + verbo
	return texto + "\\w\\n" + verbo


## ---------------------------------------------------------------------------
## Equipo del reto (SavePlayerParty, SetBattleTowerParty, LoadPlayerParty)
## ---------------------------------------------------------------------------

## SetBattleTowerProperty 5.
static func anotar_seleccion(indices: Array) -> void:
	for i in TAMANO_EQUIPO:
		SistemaGuardado.set_contador(_ELEGIDO % i, int(indices[i]))


static func seleccion() -> Array[int]:
	var indices: Array[int] = []
	for i in TAMANO_EQUIPO:
		indices.append(SistemaGuardado.get_contador(_ELEGIDO % i, i))
	return indices


## SavePlayerParty.
static func guardar_copia_equipo() -> void:
	_copia_equipo.clear()
	for pokemon: BasePokemon in SistemaGuardado.datos_vivos.equipo_pokemon:
		var pp: Array[int] = []
		for movimiento: Movimiento in pokemon.movimientos:
			pp.append(movimiento.pp_act if movimiento != null else 0)
		_copia_equipo.append({"pokemon": pokemon, "ps": pokemon.estad_ps_actual, "estado": pokemon.estado,
				"objeto": pokemon.objeto, "felicidad": pokemon.felicidad, "pp": pp})


## SetBattleTowerParty (ReducePlayerPartyToThree): solo los tres elegidos, en el orden elegido.
static func reducir_equipo() -> void:
	var completos: Array[BasePokemon] = []
	for entrada: Dictionary in _copia_equipo:
		completos.append(entrada["pokemon"])
	var reducido: Array[BasePokemon] = []
	for indice in seleccion():
		if indice >= 0 and indice < completos.size():
			reducido.append(completos[indice])
	SistemaGuardado.datos_vivos.equipo_pokemon.assign(reducido)


## LoadPlayerParty: el equipo entero, como estaba al guardar la copia.
static func cargar_copia_equipo() -> void:
	var completos: Array[BasePokemon] = []
	for entrada: Dictionary in _copia_equipo:
		var pokemon: BasePokemon = entrada["pokemon"]
		pokemon.objeto = str(entrada["objeto"])
		pokemon.felicidad = int(entrada["felicidad"])
		pokemon.estado = int(entrada["estado"])
		pokemon.estad_ps_actual = int(entrada["ps"])
		var pp: Array = entrada["pp"]
		for i in mini(pp.size(), pokemon.movimientos.size()):
			if pokemon.movimientos[i] != null:
				pokemon.movimientos[i].pp_act = int(pp[i])
		completos.append(pokemon)
	if not completos.is_empty():
		SistemaGuardado.datos_vivos.equipo_pokemon.assign(completos)


static func hay_copia_equipo() -> bool:
	return not _copia_equipo.is_empty()


static func olvidar_copia_equipo() -> void:
	_copia_equipo.clear()


## ---------------------------------------------------------------------------
## Resultado
## ---------------------------------------------------------------------------

## SetBattleTowerProperty 6. Devuelve el número del siguiente combate (8 = reto ganado).
static func anotar_victoria() -> int:
	fijar_combate(combate() + 1)
	anotar_racha()
	return combate()


## Fin de BattleTower_BattleRoom_EventScript_160A56: reto ganado.
static func anotar_reto_ganado() -> void:
	fijar_estado(Estado.GANADO)
	fijar_combate(1)
	fijar_desafio(mini(desafio() + 1, MAX_DESAFIOS))
	anotar_racha()
	SistemaGuardado.set_contador(_ULTIMO_NIVEL, nivel())


static func anotar_derrota() -> void:
	fijar_estado(Estado.PERDIDO)
	SistemaGuardado.set_contador(_ULTIMO_NIVEL, nivel())


## sub_8135CFC: lo último del combate, para el ENTRENADOR ESTRELLA.
static func anotar_final_combate(rival: String, especie_propia: String, especie_rival: String, ganado: bool) -> void:
	SistemaGuardado.set_texto(_ULTIMO_RIVAL, rival)
	SistemaGuardado.set_texto(_ULTIMA_ESPECIE_PROPIA, especie_propia)
	SistemaGuardado.set_texto(_ULTIMA_ESPECIE_RIVAL, especie_rival)
	SistemaGuardado.set_flag(_ULTIMO_GANADO, ganado)


static func ultimo_rival() -> String:
	return SistemaGuardado.get_texto(_ULTIMO_RIVAL)


static func ultima_especie_propia() -> String:
	return SistemaGuardado.get_texto(_ULTIMA_ESPECIE_PROPIA)


static func ultima_especie_rival() -> String:
	return SistemaGuardado.get_texto(_ULTIMA_ESPECIE_RIVAL)


static func ultimo_ganado() -> bool:
	return SistemaGuardado.get_flag(_ULTIMO_GANADO)


## lastStreakLevelType: nivel del último reto terminado.
static func ultimo_nivel() -> int:
	return SistemaGuardado.get_contador(_ULTIMO_NIVEL, NIVEL_50)


static func activar_bravo() -> void:
	SistemaGuardado.set_contador(_BRAVO, 1)


static func bravo_activo() -> bool:
	return SistemaGuardado.get_contador(_BRAVO, 0) != 0


## TryEnableBravoTrainerBattleTower + sub_80BFD20: inscrito sin guardar, no hay entrevista.
static func revisar_bravo() -> void:
	for tipo: int in [NIVEL_50, NIVEL_100]:
		if estado(tipo) == Estado.INSCRITO:
			SistemaGuardado.set_contador(_BRAVO, 0)


static func saludo() -> Array[int]:
	var ids: Array[int] = []
	var texto := SistemaGuardado.get_texto(_SALUDO)
	if texto.is_empty():
		ids.assign(SALUDO_INICIAL)
		return ids
	for parte: String in texto.split(","):
		ids.append(int(parte))
	return ids


static func fijar_saludo(ids: Array[int]) -> void:
	var partes := PackedStringArray()
	for id_palabra: int in ids:
		partes.append(str(id_palabra))
	SistemaGuardado.set_texto(_SALUDO, ",".join(partes))


## AwardBattleTowerRibbons: por encima de 55 victorias seguidas. Devuelve si alguno la ha recibido. El equipo entero
## debe estar cargado (LoadPlayerParty).
static func conceder_cintas() -> bool:
	if racha_actual() <= RACHA_CINTAS:
		return false
	var cinta := CINTA_NIVEL_100 if nivel() == NIVEL_100 else CINTA_NIVEL_50
	var equipo: Array = SistemaGuardado.get_equipo()
	var alguna := false
	for indice in seleccion():
		if indice >= 0 and indice < equipo.size():
			var pokemon: BasePokemon = equipo[indice]
			if not pokemon.cintas.has(cinta):
				pokemon.cintas.append(cinta)
				alguna = true
	return alguna


## DetermineBattleTowerPrize.
static func determinar_premio(rng: RandomNumberGenerator) -> void:
	var lista: Array = datos()["premios_largos" if desafio() - 1 > 5 else "premios_cortos"]
	SistemaGuardado.set_contador(_PREMIO, rng.randi() % lista.size())


static func premio() -> String:
	var lista: Array = datos()["premios_largos" if desafio() - 1 > 5 else "premios_cortos"]
	return str(lista[clampi(SistemaGuardado.get_contador(_PREMIO, 0), 0, lista.size() - 1)])


## TryInitBattleTowerAwardManObjectEvent y BattleTower_Lobby_EventScript_16029C.
static func dueno_presente() -> bool:
	if SistemaGuardado.get_flag(BANDERA_ESCUDO_ORO):
		return false
	var necesaria := 100 if SistemaGuardado.get_flag(BANDERA_ESCUDO_PLATA) else 50
	return mejor_racha() >= necesaria
