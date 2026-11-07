class_name UsoObjetosCampo
extends RefCounted

## Lógica de uso de objetos fuera de combate (desde la mochila abierta en el
## menú de pausa). Funciones estáticas: la UI (mochila.gd) sólo decide qué
## mensaje mostrar y cómo refrescarse; aquí vive el estado de juego.
##
## Referencia: pokeruby src/item_use.c (ItemUseOutOfBattle_*) y
## src/wild_encounter.c (UpdateRepelCounter / IsWildLevelAllowedByRepel).
##
## Parcelas de bayas (item_use.c ItemUseOutOfBattle_WailmerPail y
## ItemUseOutOfBattle_Berry): quien llama pasa la parcela a la que mira el
## jugador (ControladorBaya.parcela_frente_jugador()); si el uso tiene efecto
## en ella, la mochila se cierra y la parcela muestra sus mensajes en el campo.

## Valores de la columna Objetos.uso_campo (BaseDatos/poke.db).
const USO_NO_USABLE: String = "NO_USABLE"
const USO_REPELENTE: String = "REPELENTE"
const USO_REGADERA: String = "REGADERA"
const USO_CUERDA_HUIDA: String = "CUERDA_HUIDA"
## ItemUseOutOfBattle_CoinCase: muestra las FICHAS (MonederoFichas).
const USO_MONEDERO: String = "MONEDERO"
## Se usan sobre un Pokémon desde la pantalla de equipo (PantallaEquipoControlador).
const USO_PIEDRA_EVOLUTIVA: String = "PIEDRA_EVOLUTIVA"
const USO_CARAMELORARO: String = "CARAMELORARO"
## ItemUseOutOfBattle_PokeblockCase: la mochila abre la CAJA POKéCUBOS
## (PantallaEstuchePokecubos) en vez de llamar a usar().
const USO_CAJA_POKECUBOS: String = "CAJA_POKECUBOS"
## ItemUseOutOfBattle_Rod: CAÑA VIEJA, CAÑA BUENA y SUPERCAÑA.
const USO_CANA: String = "CANA"
## ItemUseOutOfBattle_Bike: BICI CARRERA y BICI ACROB.
const USO_BICI: String = "BICI"
## ItemUseOutOfBattle_BlackWhiteFlute: FL. BLANCA y FLAUTA NEGRA.
const USO_FLAUTA_BN: String = "FLAUTA_BN"
const FLAUTA_BLANCA: String = "FLBLANCA"
## FLAG_SYS_ENC_UP_ITEM / FLAG_SYS_ENC_DOWN_ITEM: ClearTempFieldEventData las
## borra al cambiar de mapa, igual que las banderas temporales.
const BANDERA_FLAUTA_BLANCA: String = "FLAG_SYS_ENC_UP_ITEM"
const BANDERA_FLAUTA_NEGRA: String = "FLAG_SYS_ENC_DOWN_ITEM"
## ItemUseOutOfBattle_Itemfinder.
const USO_BUSCAOBJETOS: String = "BUSCAOBJETOS"
const USO_BAYA_ENIGMA: String = "BAYA_ENIGMA"
## ItemUseOutOfBattle_SacredAsh: la mochila abre el equipo y revive a todos.
const USO_CENIZA_SAGRADA: String = "CENIZA_SAGRADA"

## Pasos que dura cada repelente (holdEffectParam en pokeruby).
const PASOS_REPELENTE: Dictionary = {
	"REPELENTE": 100,
	"SUPERREPEL": 200,
	"MAXREPEL": 250,
}

## Contador persistente (SistemaGuardado.datos_persistentes.contadores),
## equivalente a VAR_REPEL_STEP_COUNT.
const CONTADOR_REPELENTE: String = "pasos_repelente"

## Resultado del despacho de USAR: qué debe hacer la mochila a continuación.
enum Resultado {
	CONSEJO_PAPA,       ## Objeto sin uso en el campo → "Consejo de PAPÁ".
	REPELENTE_USADO,    ## Se activó el repelente y se gastó 1 unidad.
	REPELENTE_ACTIVO,   ## Ya había uno activo: no se gasta nada.
	PENDIENTE,          ## Uso aún no implementado (provisional).
	PARCELA_REGADA,     ## Regadera frente a una planta creciendo: ya regada.
	BAYA_PLANTADA,      ## Baya frente a tierra vacía: plantada y gastada 1.
	BAYA_NO_PLANTABLE,  ## Baya frente a tierra vacía que no se puede plantar.
	CUERDA_HUIDA,       ## En una cueva con entrada exterior: se gasta 1 y se huye en el campo.
	MONEDERO,           ## MONEDERO: la mochila muestra «FICHAS: N» (MonederoFichas.texto_uso()).
	CANA,               ## Mirando al agua: la mochila se cierra y se pesca en el campo.
	BICI,               ## La mochila se cierra y el jugador sube o baja de la bici en el campo.
	BICI_NO_BAJAR,      ## En el CAMINO de BICIS o un carril: no se puede bajar (texto propio).
	FLAUTA_ATRAE,       ## FL. BLANCA: más encuentros hasta cambiar de mapa (no se gasta).
	FLAUTA_ALEJA,       ## FLAUTA NEGRA: menos encuentros hasta cambiar de mapa (no se gasta).
	BUSCAOBJETOS,       ## La mochila se cierra y se busca en el campo (AdministradorMapa.usar_buscaobjetos).
	CARTA,              ## La mochila abre la carta vacía (PantallaCarta) y vuelve a la lista.
}


# ─── Despacho de USAR ────────────────────────────────────────────────────────

## Ejecuta la parte de lógica de USAR un objeto en el campo según su
## `uso_campo`. No toca inventario ni UI (lo hace quien llama según el
## resultado), salvo el estado propio del efecto (p. ej. el contador del
## repelente, el riego o la plantación de la parcela). Para añadir un uso
## nuevo basta con añadir un caso al match.
## `parcela`: parcela de bayas a la que mira el jugador (null si ninguna).
static func usar(item: Dictionary, parcela: ControladorBaya = null) -> Resultado:
	var uso: String = str(item.get("uso_campo", ""))
	var nombre_interno: String = str(item.get("nombre_interno", ""))
	# HandlePopupMenuAction_UseOnField: en el bolsillo de bayas USAR pasa antes
	# por ItemUseOutOfBattle_Berry (plantar si mira a tierra vacía).
	if int(item.get("bolsillo_id", -1)) == ObjetosLlevados.BOLSILLO_BAYAS and parcela != null and parcela.esta_vacia():
		if parcela.plantar_baya_jugador(nombre_interno):
			return Resultado.BAYA_PLANTADA
		return Resultado.BAYA_NO_PLANTABLE
	match uso:
		"", USO_NO_USABLE:
			return Resultado.CONSEJO_PAPA
		USO_REPELENTE:
			if repelente_activo():
				return Resultado.REPELENTE_ACTIVO
			activar_repelente(nombre_interno)
			return Resultado.REPELENTE_USADO
		USO_REGADERA:
			# TryToWaterBerryTree: sólo frente a una planta creciendo.
			if parcela != null and parcela.regar():
				return Resultado.PARCELA_REGADA
			return Resultado.CONSEJO_PAPA
		USO_CUERDA_HUIDA:
			# ItemUseOutOfBattle_EscapeRope: fuera de una cueva, Consejo de PAPÁ.
			if puede_escapar_aqui():
				return Resultado.CUERDA_HUIDA
			return Resultado.CONSEJO_PAPA
		USO_MONEDERO:
			return Resultado.MONEDERO
		USO_CANA:
			# ItemUseOutOfBattle_Rod: sin agua delante, Consejo de PAPÁ.
			if puede_pescar_aqui():
				return Resultado.CANA
			return Resultado.CONSEJO_PAPA
		USO_BICI:
			# ItemUseOutOfBattle_Bike: en el CAMINO de BICIS o un carril no se
			# baja; si el mapa no la permite, Consejo de PAPÁ.
			var jugador: Node = _jugador()
			if jugador == null:
				return Resultado.CONSEJO_PAPA
			if not str(jugador.call("texto_no_puede_bajar_de_bici")).is_empty():
				return Resultado.BICI_NO_BAJAR
			if bool(jugador.call("puede_alternar_bicicleta")):
				return Resultado.BICI
			return Resultado.CONSEJO_PAPA
		USO_FLAUTA_BN:
			# ItemUseOutOfBattle_BlackWhiteFlute: no se gasta; dura hasta el
			# próximo cambio de mapa (banderas temporales).
			if nombre_interno.to_upper() == FLAUTA_BLANCA:
				SistemaGuardado.set_flag_temporal(BANDERA_FLAUTA_BLANCA, true)
				SistemaGuardado.set_flag_temporal(BANDERA_FLAUTA_NEGRA, false)
				return Resultado.FLAUTA_ATRAE
			SistemaGuardado.set_flag_temporal(BANDERA_FLAUTA_NEGRA, true)
			SistemaGuardado.set_flag_temporal(BANDERA_FLAUTA_BLANCA, false)
			return Resultado.FLAUTA_ALEJA
		USO_BUSCAOBJETOS:
			return Resultado.BUSCAOBJETOS
		ObjetosLlevados.USO_CARTA:
			# ItemUseOutOfBattle_Mail: muestra la carta vacía; no se gasta.
			return Resultado.CARTA
		USO_BAYA_ENIGMA:
			# ItemUseOutOfBattle_EnigmaBerry: sin datos del e-Reader el efecto es
			# 0 y cae en ItemUseOutOfBattle_CannotUse.
			return Resultado.CONSEJO_PAPA
		_:
			push_warning("[USO CAMPO] Uso '%s' de %s aún no implementado" % [uso, nombre_interno])
			return Resultado.PENDIENTE


## true si el objeto se usa eligiendo un Pokémon del equipo: piedras
## evolutivas (ItemUseOutOfBattle_EvolutionStone), CARAMELORARO
## (ItemUseOutOfBattle_RareCandy), las MT/MO (ItemUseOutOfBattle_TMHM) y los
## objetos de PP (ItemUseOutOfBattle_PPRecovery / _PPUp, ver EfectosPP) y las
## vitaminas (ItemUseOutOfBattle_Medicine, ver EfectosVitaminas).
## La CEN. SAGRADA también abre el equipo, pero sin elegir a nadie.
## La mochila abre el equipo en vez de llamar a usar().
static func se_usa_en_pokemon(item: Dictionary) -> bool:
	var uso: String = str(item.get("uso_campo", ""))
	return uso == USO_PIEDRA_EVOLUTIVA or uso == USO_CARAMELORARO or uso == USO_CENIZA_SAGRADA \
		or (uso == DatosMaquinas.USO_CAMPO and DatosMaquinas.es_maquina(item)) \
		or EfectosPP.es_soportado(str(item.get("nombre_interno", ""))) \
		or EfectosVitaminas.es_soportado(str(item.get("nombre_interno", "")))


## ITEM_CLEANSE_TAG.
const OBJETO_AMULETO: String = "AMULETO"


## ApplyFluteEncounterRateMod: FL. BLANCA ×1,5, FLAUTA NEGRA ×0,5 (no se
## aplica al pescar: DoWildEncounterRateTest no corre con la caña).
static func ajustar_probabilidad_por_flauta(probabilidad: float) -> float:
	if SistemaGuardado == null or SistemaGuardado.datos_vivos == null:
		return probabilidad
	if SistemaGuardado.get_flag_temporal(BANDERA_FLAUTA_BLANCA):
		return minf(probabilidad * 1.5, 1.0)
	if SistemaGuardado.get_flag_temporal(BANDERA_FLAUTA_NEGRA):
		return probabilidad / 2.0
	return probabilidad


## ApplyCleanseTagEncounterRateMod: con el AMULETO (ITEM_CLEANSE_TAG) en el
## primer Pokémon del equipo, ×2/3. Como la flauta, no se aplica al pescar.
static func ajustar_probabilidad_por_amuleto(equipo: Array, probabilidad: float) -> float:
	if equipo.is_empty() or equipo[0] == null or (equipo[0] as BasePokemon).objeto != OBJETO_AMULETO:
		return probabilidad
	return probabilidad * 2.0 / 3.0


# ─── CUERDA HUIDA y EXCAVAR ──────────────────────────────────────────────────

## CanUseEscapeRopeOnCurrMap (también SetUpFieldMove_Dig): solo en cuevas
## (MapaConfiguracion.es_cueva, MAP_TYPE_UNDERGROUND) y, aquí, con una entrada
## exterior guardada a la que volver (SistemaGuardado.get_entrada_exterior()).
static func puede_escapar(mapa: MapaConfiguracion, entrada: Dictionary) -> bool:
	return mapa != null and mapa.es_cueva and not str(entrada.get("mapa_actual", "")).is_empty()


## puede_escapar() con el mapa actual del AdministradorMapa y la entrada guardada.
static func puede_escapar_aqui() -> bool:
	var arbol: SceneTree = Engine.get_main_loop() as SceneTree
	if arbol == null:
		return false
	var admin: Node = arbol.root.get_node_or_null("AdministradorMapa")
	if admin == null:
		return false
	return puede_escapar(admin.get("mapa_actual") as MapaConfiguracion, SistemaGuardado.get_entrada_exterior())


# ─── CAÑA ────────────────────────────────────────────────────────────────────

## CanFish con el jugador del AdministradorMapa: false si no hay jugador.
static func puede_pescar_aqui() -> bool:
	var jugador: Node = _jugador()
	return jugador != null and bool(jugador.call("puede_pescar"))


## Jugador del AdministradorMapa (con la API de character.gd), o null.
static func _jugador() -> Node:
	var arbol: SceneTree = Engine.get_main_loop() as SceneTree
	if arbol == null:
		return null
	var admin: Node = arbol.root.get_node_or_null("AdministradorMapa")
	if admin == null:
		return null
	var jugador: Node = admin.get("jugador") as Node
	return jugador if jugador != null and jugador.has_method("puede_pescar") else null


# ─── Objeto registrado en SELECT ─────────────────────────────────────────────

## Texto persistente con el nombre_interno del objeto registrado
## (gSaveBlock1.registeredItem). "" = ninguno.
const TEXTO_REGISTRADO: String = "objeto_registrado"
const BOLSILLO_CLAVE: int = 4


static func objeto_registrado() -> String:
	if SistemaGuardado == null or SistemaGuardado.datos_vivos == null:
		return ""
	return SistemaGuardado.get_texto(TEXTO_REGISTRADO)


## ASIGNAR en la mochila (HandlePopupMenuAction_Register): registra el objeto
## o, si ya era el registrado, lo quita.
static func alternar_registro(nombre_interno: String) -> void:
	var nuevo: String = "" if objeto_registrado() == nombre_interno else nombre_interno
	SistemaGuardado.set_texto(TEXTO_REGISTRADO, nuevo)


## Datos del objeto registrado si sigue en la mochila. Si ya no está, se borra
## el registro (UseRegisteredKeyItem) y devuelve {}.
static func datos_objeto_registrado() -> Dictionary:
	var nombre_interno: String = objeto_registrado()
	if nombre_interno.is_empty():
		return {}
	if not SistemaGuardado.tiene_objeto(nombre_interno, 1, BOLSILLO_CLAVE):
		SistemaGuardado.set_texto(TEXTO_REGISTRADO, "")
		return {}
	return SistemaGuardado.obtener_datos_objeto_completos(nombre_interno)


# ─── Repelente ───────────────────────────────────────────────────────────────

static func pasos_repelente_restantes() -> int:
	if SistemaGuardado == null or SistemaGuardado.datos_vivos == null:
		return 0
	return SistemaGuardado.get_contador(CONTADOR_REPELENTE)


static func repelente_activo() -> bool:
	return pasos_repelente_restantes() > 0


## Activa el repelente indicado (nombre_interno). Si no es uno conocido no hace nada.
static func activar_repelente(nombre_interno: String) -> void:
	var clave: String = nombre_interno.strip_edges().to_upper()
	if not PASOS_REPELENTE.has(clave):
		push_warning("[USO CAMPO] '%s' no es un repelente conocido" % nombre_interno)
		return
	SistemaGuardado.set_contador(CONTADOR_REPELENTE, int(PASOS_REPELENTE[clave]))


## Equivalente a UpdateRepelCounter: descuenta un paso si hay repelente activo.
## Devuelve true sólo en el paso en que el efecto se agota (llega a 0).
static func descontar_paso_repelente() -> bool:
	var pasos: int = pasos_repelente_restantes()
	if pasos <= 0:
		return false
	return SistemaGuardado.decrementar_contador(CONTADOR_REPELENTE) == 0


## Equivalente a !IsWildLevelAllowedByRepel: con repelente activo, bloquea el
## encuentro si el nivel salvaje es menor que el del PRIMER Pokémon del equipo
## con PS > 0 que no sea huevo. Sin ningún Pokémon válido también bloquea
## (igual que pokeruby).
static func repelente_bloquea(nivel_salvaje: int) -> bool:
	if not repelente_activo():
		return false
	for pokemon: BasePokemon in SistemaGuardado.datos_vivos.equipo_pokemon:
		if pokemon == null or pokemon.huevo or pokemon.estad_ps_actual <= 0:
			continue
		return nivel_salvaje < pokemon.nivel
	return true
