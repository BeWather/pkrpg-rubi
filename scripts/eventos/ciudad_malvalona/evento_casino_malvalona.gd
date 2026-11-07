## evento_casino_malvalona.gd
## Guiones del CASINO de CIUDAD MALVALONA (pokeruby data/maps/MauvilleCity_GameCorner),
## alcance mínimo: NPC, contador de FICHAS (MonederoFichas), vendedor, canje de premios
## y regalos. Las 12 TRAGAPERRAS y las 2 mesas de RULETA (bg_event) comprueban el
## MONEDERO como Rubí («No puedes jugar si no tienes un MONEDERO») y, con él, muestran
## un texto provisional: los minijuegos quedan pendientes.
##
## - CAJERO (CoinsClerk): saludo; sin MONEDERO no vende; con él, 50 FICHAS por 1.000$
##   o 500 por 10.000$ (tope 9.999: «tienes el MONEDERO lleno»; sin dinero: «no tienes
##   bastante»). Con el cuadro del dinero y el de las FICHAS a la vista.
## - Canje de MUÑECOS y de MT (PrizeCornerDolls / PrizeCornerTMs): menú con cuadro de
##   FICHAS; confirmación SÍ/NO (NO sale del menú, como Rubí); sin FICHAS vuelve al
##   menú; el MUÑECO va al PC (sin sitio: «no queda sitio» y vuelve al menú).
## - CHICA (Girl): regala una vez el MUÑECO del inicial elegido.
## - FAN (PokefanM): sin MONEDERO manda a la casa de al lado; con él y sin haber cobrado
##   (y 0 FICHAS) regala 20 FICHAS una sola vez.
extends EventoInteriorMalvalona
class_name EventoCasinoMalvalona

const MOTIVO_PAUSA: StringName = &"casino_malvalona"

const T := "CIUDAD_MALVALONA_CASINO_"
const TEXTO_BIENVENIDA: String = T + "CAJERO_BIENVENIDA"
const TEXTO_SIN_MONEDERO: String = T + "CAJERO_SIN_MONEDERO"
const TEXTO_FICHAS: String = T + "CAJERO_FICHAS"
const TEXTO_GRACIAS: String = T + "CAJERO_GRACIAS"
const TEXTO_SIN_DINERO: String = T + "CAJERO_SIN_DINERO"
const TEXTO_MONEDERO_LLENO: String = T + "CAJERO_MONEDERO_LLENO"
const TEXTO_NO_FICHAS: String = T + "CAJERO_NO_FICHAS"
const TEXTO_PREMIOS_SALUDO: String = T + "PREMIOS_SALUDO"
const TEXTO_PREMIOS_CUAL: String = T + "PREMIOS_CUAL"
const TEXTO_PREMIOS_CONFIRMA: String = T + "PREMIOS_CONFIRMA"
const TEXTO_PREMIOS_ENVIO_PC: String = T + "PREMIOS_ENVIO_PC"
const TEXTO_PREMIOS_SIN_FICHAS: String = T + "PREMIOS_SIN_FICHAS"
const TEXTO_PREMIOS_CANCELA: String = T + "PREMIOS_CANCELA"
const TEXTO_PREMIOS_AQUI_TIENES: String = T + "PREMIOS_AQUI_TIENES"
const TEXTO_CHICA_OFRECE: String = T + "CHICA_MUNECO_OFRECE"
const TEXTO_CHICA_TOMA: String = T + "CHICA_MUNECO_TOMA"
const TEXTO_CHICA_AHORA_NO: String = T + "CHICA_MUNECO_AHORA_NO"
const TEXTO_CHICA_NO: String = T + "CHICA_MUNECO_NO"
const TEXTO_CHICA_DESPUES: String = T + "CHICA_MUNECO_DESPUES"
const TEXTO_FAN_SIN_MONEDERO: String = T + "FAN_SIN_MONEDERO"
const TEXTO_FAN_REGALA: String = T + "FAN_REGALA_FICHAS"
const TEXTO_FAN_SUERTE: String = T + "FAN_SUERTE"
const TEXTO_SIN_MONEDERO_MAQUINA: String = T + "SIN_MONEDERO_MAQUINA"
const TEXTO_TRAGAPERRAS_PENDIENTE: String = T + "TRAGAPERRAS_PENDIENTE"
const TEXTO_RULETA_PENDIENTE: String = T + "RULETA_PENDIENTE"
const TEXTO_CANCELAR: String = "CIUDAD_MALVALONA_MENU_CANCELAR"
const TEXTO_FICHAS_50: String = "CIUDAD_MALVALONA_MENU_FICHAS_50"
const TEXTO_FICHAS_500: String = "CIUDAD_MALVALONA_MENU_FICHAS_500"
## Textos de la decoración (los mismos de la CASA TRETA: «no queda sitio para X»).
const TEXTO_DECOR_SIN_SITIO: String = "CASA_TRETA_DECOR_SIN_SITIO"
const TEXTO_DECOR_OBTENIDA: String = "CASA_TRETA_DECOR_OBTENIDA"
const TEXTO_DECOR_ENVIADA_PC: String = "CASA_TRETA_DECOR_ENVIADA_PC"

const SONIDO_COMPRA: String = "SE_SHOP"
## FICHAS de cada compra y su precio en dinero.
const COMPRAS: Array = [[50, 1000], [500, 10000]]
const FICHAS_REGALO: int = 20

## Premios de los MUÑECOS: [etiqueta del menú, id de decoración, FICHAS].
const PREMIOS_MUNECOS: Array = [
	["CIUDAD_MALVALONA_MENU_MUNECO_TREECKO", 88, 1000],
	["CIUDAD_MALVALONA_MENU_MUNECO_TORCHIC", 89, 1000],
	["CIUDAD_MALVALONA_MENU_MUNECO_MUDKIP", 90, 1000],
]
## Decoración del MUÑECO de cada inicial (SistemaGuardado.get_inicial(): 0, 1, 2).
const MUNECO_POR_INICIAL: Array[int] = [88, 89, 90]
## Premios de MT: [etiqueta del menú, objeto, FICHAS].
const PREMIOS_MT: Array = [
	["CIUDAD_MALVALONA_MENU_MT32", "MT32", 1500],
	["CIUDAD_MALVALONA_MENU_MT29", "MT29", 3500],
	["CIUDAD_MALVALONA_MENU_MT35", "MT35", 4000],
	["CIUDAD_MALVALONA_MENU_MT24", "MT24", 4000],
	["CIUDAD_MALVALONA_MENU_MT13", "MT13", 4000],
]

@export var cajero: NodePath
@export var premios_munecos: NodePath
@export var premios_mt: NodePath
@export var chica: NodePath
@export var aficionado: NodePath
## Contenedor de los carteles de las TRAGAPERRAS («Tragaperras…») y la RULETA («Ruleta…»).
@export var carteles: NodePath = ^"../../Carteles"


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(cajero, _on_cajero)
	escuchar(premios_munecos, _on_premios.bind(true))
	escuchar(premios_mt, _on_premios.bind(false))
	escuchar(chica, _on_chica)
	escuchar(aficionado, _on_aficionado)
	var contenedor := get_node_or_null(carteles)
	if contenedor == null:
		return
	for hijo in contenedor.get_children():
		if hijo is CartelEvento:
			hijo.accionado.connect(_on_maquina)


## ============================================================================
## CAJERO
## ============================================================================

## MauvilleCity_GameCorner_EventScript_CoinsClerk.
func _on_cajero(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	await mensaje(TEXTO_BIENVENIDA)
	if not MonederoFichas.tiene_monedero():
		await mensaje(TEXTO_SIN_MONEDERO)  # NeedCoinCase
		terminar(false, [npc])
		return
	mostrar_cuadro_dinero()
	mostrar_cuadro_fichas()
	var opciones := PackedStringArray([tr(TEXTO_FICHAS_50), tr(TEXTO_FICHAS_500), tr(TEXTO_CANCELAR)])
	var elegida := await elegir_opcion(TEXTO_FICHAS, opciones, true)
	if elegida >= COMPRAS.size():
		await mensaje(TEXTO_NO_FICHAS)  # CancelBuyCoins
		terminar(false, [npc])
		return
	await _comprar(COMPRAS[elegida][0], COMPRAS[elegida][1])
	terminar(false, [npc])


## Buy50Coins / Buy500Coins: tope, dinero y compra.
func _comprar(fichas: int, precio: int) -> void:
	if not MonederoFichas.caben(fichas):
		await mensaje(TEXTO_MONEDERO_LLENO)  # NoRoomForCoins
		return
	if SistemaGuardado.get_dinero_jugador() < precio:
		await mensaje(TEXTO_SIN_DINERO)  # NotEnoughMoney
		return
	MonederoFichas.dar(fichas)
	SistemaGuardado.quitar_dinero_jugador(precio)
	actualizar_cuadro_dinero()
	actualizar_cuadro_fichas()
	Singleton.play_sound.emit(SONIDO_COMPRA)
	await mensaje(TEXTO_GRACIAS)


## ============================================================================
## CANJE DE PREMIOS
## ============================================================================

## PrizeCornerDolls / PrizeCornerTMs.
func _on_premios(npc: Node2D, munecos: bool) -> void:
	if not empezar_con(npc):
		return
	await mensaje(TEXTO_PREMIOS_SALUDO, false)
	if not MonederoFichas.tiene_monedero():
		terminar(false, [npc])  # sin MONEDERO: solo el saludo
		return
	var premios: Array = PREMIOS_MUNECOS if munecos else PREMIOS_MT
	var opciones := PackedStringArray()
	for premio: Array in premios:
		opciones.append(tr(premio[0]))
	opciones.append(tr(TEXTO_CANCELAR))
	mostrar_cuadro_fichas()
	while true:
		var elegido := await elegir_opcion(TEXTO_PREMIOS_CUAL, opciones, true)
		if elegido >= premios.size():
			break  # CancelDollSelect / CancelTMSelect
		var premio: Array = premios[elegido]
		var nombre := _nombre_decoracion(premio[1]) if munecos else _nombre_objeto(premio[1])
		if not await preguntar_si_no(TEXTO_PREMIOS_CONFIRMA, {"{premio}": nombre}):
			break
		if not await _entregar_premio(npc, premio, munecos, nombre):
			continue
	await mensaje(TEXTO_PREMIOS_CANCELA)
	terminar(false, [npc])


## BuyXDoll / BuyTMX: FICHAS, espacio y entrega. true si se entregó.
func _entregar_premio(_npc: Node2D, premio: Array, munecos: bool, nombre: String) -> bool:
	var coste: int = premio[2]
	if MonederoFichas.fichas() < coste:
		await mensaje(TEXTO_PREMIOS_SIN_FICHAS)  # NotEnoughCoins
		return false
	if munecos:
		var inventario := SistemaGuardado.get_bases_secretas()
		if not inventario.puede_agregar_decoracion(premio[1]):
			await mensaje(TEXTO_DECOR_SIN_SITIO, true, {"{decoracion}": nombre})  # NoRoomForDecor
			return false
		MonederoFichas.quitar(coste)
		inventario.agregar_decoracion(premio[1])
	else:
		MonederoFichas.quitar(coste)
		SistemaGuardado.dar_objeto_jugador(premio[1])
	actualizar_cuadro_fichas()
	Singleton.play_sound.emit(SONIDO_COMPRA)
	await mensaje(TEXTO_PREMIOS_ENVIO_PC if munecos else TEXTO_PREMIOS_AQUI_TIENES, false)
	return true


func _nombre_decoracion(id_decoracion: int) -> String:
	return tr("BASES_DECOR_%03d_NOMBRE" % id_decoracion)


func _nombre_objeto(objeto: String) -> String:
	return str(SistemaGuardado.obtener_datos_objeto_completos(objeto).get("nombre", objeto))


## ============================================================================
## CHICA (MUÑECO del inicial) y FAN (20 FICHAS)
## ============================================================================

## MauvilleCity_GameCorner_EventScript_Girl.
func _on_chica(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if SistemaGuardado.get_flag(HistoriaMalvalona.BANDERA_MUNECO_INICIAL):
		await mensaje(TEXTO_CHICA_DESPUES)  # ReceivedStarterDoll
		terminar(false, [npc])
		return
	if not await preguntar_si_no(TEXTO_CHICA_OFRECE):
		await mensaje(TEXTO_CHICA_NO)  # DeclineStarterDoll
		terminar(false, [npc])
		return
	var decoracion: int = MUNECO_POR_INICIAL[SistemaGuardado.get_inicial()]
	var nombre := _nombre_decoracion(decoracion)
	var inventario := SistemaGuardado.get_bases_secretas()
	if not inventario.puede_agregar_decoracion(decoracion):
		await mensaje(TEXTO_DECOR_SIN_SITIO, true, {"{decoracion}": nombre})  # NoRoomForStarterDoll
		await mensaje(TEXTO_CHICA_AHORA_NO)
		terminar(false, [npc])
		return
	await mensaje(TEXTO_CHICA_TOMA)
	inventario.agregar_decoracion(decoracion)  # givedecoration
	await mensaje_con_fanfarria(TEXTO_DECOR_OBTENIDA, FANFARRIA_OBJETO, {"{decoracion}": nombre})
	await mensaje(TEXTO_DECOR_ENVIADA_PC, true, {"{decoracion}": nombre})
	SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_MUNECO_INICIAL, true)
	await mensaje(TEXTO_CHICA_DESPUES)
	terminar(false, [npc])


## MauvilleCity_GameCorner_EventScript_PokefanM.
func _on_aficionado(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if not MonederoFichas.tiene_monedero():
		await mensaje(TEXTO_FAN_SIN_MONEDERO)
	else:
		if not SistemaGuardado.get_flag(HistoriaMalvalona.BANDERA_20_FICHAS) and MonederoFichas.fichas() < 1:
			SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_20_FICHAS, true)
			MonederoFichas.dar(FICHAS_REGALO)
			await mensaje(TEXTO_FAN_REGALA)
			Singleton.play_sound.emit(SONIDO_COMPRA)
		await mensaje(TEXTO_FAN_SUERTE)
	admin.cuadro_dialogo.cerrar()  # closemessage
	mirar(npc, npc.direccion_base)  # Common_Movement_FaceOriginalDirection
	terminar(false, [npc])


## ============================================================================
## TRAGAPERRAS y RULETA (pendientes)
## ============================================================================

## SlotMachineN / mesas de RULETA: sin MONEDERO, el aviso de Rubí; con él, un texto
## provisional (los minijuegos no están implementados).
func _on_maquina(cartel: CartelEvento) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	if not MonederoFichas.tiene_monedero():
		await mensaje(TEXTO_SIN_MONEDERO_MAQUINA)  # CantPlayWithNoCoinCase
	elif String(cartel.name).begins_with("Ruleta"):
		await mensaje(TEXTO_RULETA_PENDIENTE)
	else:
		await mensaje(TEXTO_TRAGAPERRAS_PENDIENTE)
	terminar()
