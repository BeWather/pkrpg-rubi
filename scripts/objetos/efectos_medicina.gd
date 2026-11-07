class_name EfectosMedicina
extends RefCounted

## Efectos de los objetos de curación (Objetos.uso_campo = MEDICINA) sobre un
## Pokémon del equipo, dentro y fuera de combate. Funciones estáticas, sin
## nodos: sólo modifican el BasePokemon (y, en combate, los estados volátiles
## de su PokemonEnCombate); el inventario y la UI son cosa de quien llama
## (la pantalla de equipo, como UseMedicine).
##
## Referencia pokeruby:
## - src/data/pokemon/item_effects.h (gItemEffectTable): los datos de cada objeto.
## - src/pokemon_item_effect.c (PokemonUseItemEffects): cómo se aplican.
## - src/party_menu.c (UseMedicine, IsHPRecoveryItem, GetMedicineItemEffectMessage,
##   GetItemEffectType, sub_806F8AC): cuándo no hay efecto y qué mensaje sale.

## Valores especiales de "ps" en EFECTOS (el byte de parámetro del decomp).
const PS_NINGUNO: int = 0     ## No cura PS (IsHPRecoveryItem = FALSE).
const PS_LLENOS: int = -1     ## 0xFF: hasta el máximo.
const PS_MITAD: int = -2      ## 0xFE: la mitad de los PS máximos (mínimo 1), REVIVIR.

## Estados primarios de los bits 0x20/0x10/0x08/0x04/0x02 del byte 3 (sueño,
## veneno —también el grave, máscara 0xF88—, quemadura, hielo y parálisis).
## Se guardan por nombre (Singleton.obtener_nombre_estado) porque un const no
## puede leer el enum del autoload.
const TODOS: Array[String] = ["DORMIDO", "ENVENENADO", "QUEMADO", "CONGELADO", "PARALIZADO"]

## Porción de gItemEffectTable para los objetos soportados, por nombre_interno
## de poke.db. Claves (las que faltan valen su valor por defecto):
## - "ps": int — PS que cura (PS_NINGUNO, PS_LLENOS, PS_MITAD o una cantidad).
## - "estados": Array — nombres de ProblemaEstado que cura (TODOS = 0x3F).
## - "confusion": bool — bit 0x01 del byte 3: quita la confusión, sólo en combate.
## - "enamoramiento": bool — bit 0x80 del byte 0: quita el enamoramiento, sólo en combate.
## - "revive": bool — bit 0x40 del byte 4: sólo tiene efecto sobre un
##   debilitado; sin él un debilitado no se cura.
## - "amistad": Array — cambio de amistad [<100, 100-199, >=200] (bytes 0xE0
##   del byte 5), sólo si el objeto tuvo efecto.
const EFECTOS: Dictionary = {
	"POCION": {"ps": 20},                               # gItemEffect_Potion
	"ANTIDOTO": {"estados": ["ENVENENADO"]},            # gItemEffect_Antidote (0x10)
	"ANTIQUEMAR": {"estados": ["QUEMADO"]},             # gItemEffect_BurnHeal (0x08)
	"ANTIHIELO": {"estados": ["CONGELADO"]},            # gItemEffect_IceHeal (0x04)
	"DESPERTAR": {"estados": ["DORMIDO"]},              # gItemEffect_Awakening (0x20)
	"ANTIPARALIZ": {"estados": ["PARALIZADO"]},         # gItemEffect_ParalyzeHeal (0x02)
	# gItemEffect_FullRestore: 0x3F (todos + confusión) y PS 0xFF.
	"RESTAUTODO": {"ps": PS_LLENOS, "estados": TODOS, "confusion": true},
	"MAXPOCION": {"ps": PS_LLENOS},                     # gItemEffect_MaxPotion
	"HIPERPOCION": {"ps": 200},                         # gItemEffect_HyperPotion
	"SUPERPOCION": {"ps": 50},                          # gItemEffect_SuperPotion
	# gItemEffect_FullHeal: sólo estado (0x3F), no PS.
	"CURATOTAL": {"estados": TODOS, "confusion": true},
	"REVIVIR": {"ps": PS_MITAD, "revive": true},        # gItemEffect_Revive (0x44, 0xFE)
	"MAXREVIVIR": {"ps": PS_LLENOS, "revive": true},    # gItemEffect_MaxRevive (0x44, 0xFF)
	"AGUAFRESCA": {"ps": 50},                           # gItemEffect_FreshWater
	"REFRESCO": {"ps": 60},                             # gItemEffect_SodaPop
	"LIMONADA": {"ps": 80},                             # gItemEffect_Lemonade
	"LECHEMUMU": {"ps": 100},                           # gItemEffect_MoomooMilk
	# Hierbas: bajan la amistad (0xFB = -5, 0xF6 = -10, 0xF1 = -15, 0xEC = -20).
	"POLVOENERGIA": {"ps": 50, "amistad": [-5, -5, -10]},                         # gItemEffect_EnergyPowder
	"RAIZENERGIA": {"ps": 200, "amistad": [-10, -10, -15]},                       # gItemEffect_EnergyRoot
	"POLCURACION": {"estados": TODOS, "confusion": true, "amistad": [-5, -5, -10]},  # gItemEffect_HealPowder
	"HIERBAREV": {"ps": PS_LLENOS, "revive": true, "amistad": [-15, -15, -20]},   # gItemEffect_RevivalHerb
	"GALLETALAVA": {"estados": TODOS, "confusion": true},                         # gItemEffect_LavaCookie
	"ZUMOBAYA": {"ps": 20},                             # gItemEffect_BerryJuice
	# gItemEffect_SacredAsh: revive con todos los PS. Se aplica a todo el equipo
	# a la vez (PantallaEquipoControlador.usar_objeto_en_todos).
	"CENSAGRADA": {"ps": PS_LLENOS, "revive": true},
	# Flautas: la AZUL también fuera de combate; la AMARILLA y la ROJA sólo
	# quitan estados volátiles, así que fuera de combate no tienen efecto (en
	# poke.db son NO_USABLE: ItemUseOutOfBattle_CannotUse).
	"FLAUTAAZUL": {"estados": ["DORMIDO"]},             # gItemEffect_BlueFlute (0x20)
	"FLAMARILLA": {"confusion": true},                  # gItemEffect_YellowFlute (0x01)
	"FLAUTAROJA": {"enamoramiento": true},              # gItemEffect_RedFlute (0x80, byte 0)
	# Bayas. ZANAMA restaura PP (EfectosPP); CAQUIC, como la FL. AMARILLA.
	"BAYACAQUIC": {"confusion": true},                  # gItemEffect_PersimBerry (0x01)
	"BAYAZREZA": {"estados": ["PARALIZADO"]},           # gItemEffect_CheriBerry (0x02)
	"BAYAATANIA": {"estados": ["DORMIDO"]},             # gItemEffect_ChestoBerry (0x20)
	"BAYAMELOC": {"estados": ["ENVENENADO"]},           # gItemEffect_PechaBerry (0x10)
	"BAYASAFRE": {"estados": ["QUEMADO"]},              # gItemEffect_RawstBerry (0x08)
	"BAYAPERASI": {"estados": ["CONGELADO"]},           # gItemEffect_AspearBerry (0x04)
	"BAYAARANJA": {"ps": 10},                           # gItemEffect_OranBerry
	"BAYAZIUELA": {"estados": TODOS, "confusion": true},  # gItemEffect_LumBerry (0x3F)
	"BAYAZIDRA": {"ps": 30},                            # gItemEffect_SitrusBerry
}

## Claves de dialogos.csv. MEDICINA_SIN_EFECTO es el texto del decomp en
## español (gOtherText_WontHaveAnyEffect); el resto son traducción propia
## provisional, porque el decomp español los tiene sin traducir.
const CLAVE_SIN_EFECTO: String = "MEDICINA_SIN_EFECTO"
const CLAVE_PS_RECUPERADOS: String = "MEDICINA_PS_RECUPERADOS"
const CLAVE_REVIVIDO: String = "MEDICINA_REVIVIDO"
## Mensaje de un objeto que cura un único estado (GetMedicineItemEffectMessage).
const CLAVE_ESTADO: Dictionary = {
	"ENVENENADO": "MEDICINA_CURA_VENENO",
	"PARALIZADO": "MEDICINA_CURA_PARALISIS",
	"DORMIDO": "MEDICINA_CURA_SUENO",
	"QUEMADO": "MEDICINA_CURA_QUEMADURA",
	"CONGELADO": "MEDICINA_CURA_HIELO",
}
const CLAVE_CONFUSION: String = "MEDICINA_CURA_CONFUSION"
const CLAVE_ENAMORAMIENTO: String = "MEDICINA_CURA_ENAMORAMIENTO"
const CLAVE_VARIOS: String = "MEDICINA_CURA_VARIOS"


## Resultado de aplicar(): qué pasó y qué mensaje mostrar.
class ResultadoMedicina extends RefCounted:
	## false si el objeto no está en EFECTOS (no se toca el Pokémon).
	var soportado: bool = false
	## true si el objeto hizo algo: hay que gastarlo (y, en combate, el turno).
	var tuvo_efecto: bool = false
	var ps_antes: int = 0
	var ps_despues: int = 0
	## El Pokémon estaba debilitado y ha vuelto (REVIVIR, MÁX. REVIVIR, HIERBA REV.).
	var revivio: bool = false
	## Mensaje ya traducido y con el nombre y la cantidad sustituidos.
	var mensaje: String = ""


## true si `nombre_interno` tiene efecto implementado en EFECTOS.
static func es_soportado(nombre_interno: String) -> bool:
	return EFECTOS.has(nombre_interno.to_upper())


## true si USAR fuera de combate abre el equipo para elegir a quién darle el
## objeto (ItemUseOutOfBattle_Medicine): sólo las MEDICINA de EFECTOS. La FL.
## AMARILLA, la FLAUTA ROJA y la BAYA CAQUIC son de combate (Consejo de PAPÁ) y
## la CEN. SAGRADA se aplica a todo el equipo.
static func se_elige_pokemon_en_campo(item: Dictionary) -> bool:
	return str(item.get("uso_campo", "")) == "MEDICINA" and es_soportado(str(item.get("nombre_interno", "")))


## Aplica el objeto `nombre_interno` a `poke` (PokemonUseItemEffects + la
## parte de UseMedicine que decide si hubo efecto). Sin efecto el Pokémon
## queda igual y el mensaje es "No tendrá ningún efecto.". `en_batalla` y
## `combatiente` (el PokemonEnCombate de `poke` si está en el campo) sólo
## sirven para quitar la confusión, que es un estado volátil del combate.
static func aplicar(nombre_interno: String, poke: BasePokemon, en_batalla: bool = false,
		combatiente: PokemonEnCombate = null) -> ResultadoMedicina:
	var resultado := ResultadoMedicina.new()
	resultado.ps_antes = poke.estad_ps_actual
	resultado.ps_despues = poke.estad_ps_actual
	resultado.mensaje = texto(CLAVE_SIN_EFECTO)
	var nombre: String = nombre_interno.to_upper()
	if not EFECTOS.has(nombre):
		return resultado
	resultado.soportado = true
	# Un huevo nunca llega aquí desde la pantalla de equipo, pero por si acaso.
	if poke.huevo:
		return resultado

	var efecto: Dictionary = EFECTOS[nombre]
	var ps_param: int = int(efecto.get("ps", PS_NINGUNO))
	var revive: bool = bool(efecto.get("revive", false))
	var debilitado: bool = poke.estad_ps_actual <= 0
	# PokemonUseItemEffects (byte 4, bit 0x04): con el bit 0x10 (revivir) sólo
	# se aplica a un debilitado; sin él, nunca a un debilitado. Un debilitado
	# tampoco tiene estados que curar (se borran al debilitarse).
	if debilitado != revive:
		return resultado

	# Estados (byte 3, HealStatusConditions): se actualiza el icono antes que
	# la barra, como PartyMenuUpdateLevelOrStatus en UseMedicine.
	var curo_estado: bool = false
	var nombre_estado: String = Singleton.obtener_nombre_estado(poke.estado)
	if not debilitado and nombre_estado in (efecto.get("estados", []) as Array):
		poke.estado = Singleton.ProblemaEstado.NORMAL
		curo_estado = true
		if combatiente != null:
			if nombre_estado == "ENVENENADO":
				combatiente.envenenamiento_grave = false
				combatiente.contador_veneno_grave = 0
			elif nombre_estado == "DORMIDO":
				combatiente.turnos_dormido = 0
	if bool(efecto.get("confusion", false)) and en_batalla and combatiente != null \
			and combatiente.esta_confuso:
		combatiente.esta_confuso = false
		combatiente.turnos_confuso = 0
		curo_estado = true
	if bool(efecto.get("enamoramiento", false)) and en_batalla and combatiente != null \
			and combatiente.esta_enamorado:
		combatiente.esta_enamorado = false
		combatiente.target_enamorado = null
		curo_estado = true

	# PS (byte 4): con los PS llenos no hay curación de PS (UseMedicine pone
	# r9 = FALSE antes de ExecuteTableBasedItemEffect).
	var curo_ps: bool = ps_param != PS_NINGUNO and poke.estad_ps_actual < poke.estad_ps
	if curo_ps:
		var cantidad: int = ps_param
		match ps_param:
			PS_LLENOS:
				cantidad = poke.estad_ps - poke.estad_ps_actual
			PS_MITAD:
				cantidad = maxi(poke.estad_ps / 2, 1)
		poke.estad_ps_actual = mini(poke.estad_ps_actual + cantidad, poke.estad_ps)
		resultado.ps_despues = poke.estad_ps_actual
		if debilitado:
			resultado.revivio = true
			poke.estado = Singleton.ProblemaEstado.NORMAL
		# PokemonUseItemEffects: gBattleResults.playerHealInBattleCount (en el campo,
		# sin revivir).
		elif en_batalla and combatiente != null:
			ResultadosCombate.registrar_curacion_jugador()

	resultado.tuvo_efecto = curo_ps or curo_estado
	if not resultado.tuvo_efecto:
		return resultado

	_aplicar_amistad(poke, efecto.get("amistad", []) as Array)

	var nombre_mon: String = poke.get_nombre_mostrar()
	if curo_ps:
		# sub_806F8AC: "recuperó la salud" si tenía 0 PS; si no, los puntos curados.
		if resultado.revivio:
			resultado.mensaje = texto(CLAVE_REVIVIDO, {"{mon}": nombre_mon})
		else:
			resultado.mensaje = texto(CLAVE_PS_RECUPERADOS,
				{"{mon}": nombre_mon, "{n}": str(resultado.ps_despues - resultado.ps_antes)})
	else:
		resultado.mensaje = texto(_clave_mensaje_estado(efecto), {"{mon}": nombre_mon})
	return resultado


## Cambio de amistad de las hierbas (byte 5, bits 0xE0): se usa el tramo de
## la amistad actual (<100, 100-199, >=200) y se limita a 0-255. Los bonus de
## la CAMPANA ALIVIO, la LUJO BALL y el lugar de encuentro sólo cuentan para
## subidas, y ninguna medicina sube la amistad.
static func _aplicar_amistad(poke: BasePokemon, cambios: Array) -> void:
	if cambios.size() < 3:
		return
	var tramo: int = 0
	if poke.felicidad >= 200:
		tramo = 2
	elif poke.felicidad >= 100:
		tramo = 1
	poke.felicidad = clampi(poke.felicidad + int(cambios[tramo]), 0, 255)


## Clave del mensaje de un objeto de estado según GetItemEffectType: un solo
## estado tiene su texto; sólo confusión, el suyo; varios, "se ha recuperado".
static func _clave_mensaje_estado(efecto: Dictionary) -> String:
	var estados: Array = efecto.get("estados", [])
	var confusion: bool = bool(efecto.get("confusion", false))
	if bool(efecto.get("enamoramiento", false)):
		return CLAVE_ENAMORAMIENTO
	if estados.size() == 1 and not confusion:
		return str(CLAVE_ESTADO.get(estados[0], CLAVE_VARIOS))
	if estados.is_empty() and confusion:
		return CLAVE_CONFUSION
	return CLAVE_VARIOS


## Texto traducido de `clave` con las sustituciones ({mon}, {n}).
static func texto(clave: String, sustituciones: Dictionary = {}) -> String:
	var resultado: String = String(TranslationServer.translate(StringName(clave)))
	for marca in sustituciones:
		resultado = resultado.replace(str(marca), str(sustituciones[marca]))
	return resultado
