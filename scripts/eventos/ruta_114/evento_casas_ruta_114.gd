## evento_casas_ruta_114.gd
## Guiones de las casas de la RUTA 114 (pokeruby Route114_LanettesHouse y
## Route114_FossilManiacsHouse). Cada escena asigna solo lo que tiene.
##
## - CASA de AREDIA (LANETTE), solo si ya la conoció en el CENTRO POKÉMON de PUEBLO
##   PARDAL (bandera `ruta_114_aredia_en_casa` ≈ inversa de FLAG_HIDE_LANETTE): la
##   primera vez activa FLAG_SYS_PC_LANETTE y regala el MUÑECO SEEDOT (givedecoration;
##   sin sitio, «no queda sitio» y vuelve a intentarlo). Después da un consejo.
## - Cuaderno de notas de AREDIA (bg_event 15C299): tres páginas encadenadas con
##   «¿Sigo leyendo?» (NO en la primera: «cerró el cuaderno»; NO en la segunda: se
##   queda ahí).
## - CASA del FOSILMANÍACO, su hermano pequeño: regala la MT28 EXCAVAR una sola vez
##   (FLAG_RECEIVED_TM28); después explica qué hace EXCAVAR en una cueva.
extends EventoInteriorMalvalona
class_name EventoCasasRuta114

const MOTIVO_PAUSA: StringName = &"casas_ruta_114"

const OBJETO_MT28: String = "MT28"
## DECOR_SEEDOT_DOLL.
const DECORACION_MUNECO_SEEDOT: int = 100

## FLAG_RECEIVED_DOLL_LANETTE.
const BANDERA_MUNECO_AREDIA: String = "ruta_114_muneco_aredia_recibido"
## FLAG_SYS_PC_LANETTE: el PC público pasa de «PC de ALGUIEN» a «PC de AREDIA»
## (MenuPCPublico lee la misma bandera).
const BANDERA_PC_AREDIA: String = MenuPCPublico.BANDERA_PC_AREDIA
## FLAG_RECEIVED_TM28.
const BANDERA_MT28: String = "ruta_114_mt28_recibida"

const TEXTO_AREDIA_REGALO: String = "RUTA114_AREDIA_REGALO"
const TEXTO_AREDIA_TRAS: String = "RUTA114_AREDIA_TRAS"
const TEXTO_NOTAS_1: String = "RUTA114_AREDIA_NOTAS_1"
const TEXTO_NOTAS_2: String = "RUTA114_AREDIA_NOTAS_2"
const TEXTO_NOTAS_3: String = "RUTA114_AREDIA_NOTAS_3"
const TEXTO_NOTAS_CERRADO: String = "RUTA114_AREDIA_NOTAS_CERRADO"
const TEXTO_HERMANO_REGALO: String = "RUTA114_FOSIL_HERMANO_REGALO"
const TEXTO_HERMANO_TRAS: String = "RUTA114_FOSIL_HERMANO_TRAS"
## Los mismos textos de la CASA TRETA: «no queda sitio para X», «obtuvo X», «enviada al PC».
const TEXTO_DECOR_SIN_SITIO: String = "CASA_TRETA_DECOR_SIN_SITIO"
const TEXTO_DECOR_OBTENIDA: String = "CASA_TRETA_DECOR_OBTENIDA"
const TEXTO_DECOR_ENVIADA_PC: String = "CASA_TRETA_DECOR_ENVIADA_PC"

@export var aredia: NodePath
@export var hermano: NodePath
## Contenedor de los carteles; el CartelEvento «Notas» abre el cuaderno de AREDIA.
@export var carteles: NodePath = ^"../../Carteles"


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(aredia, _on_aredia)
	escuchar(hermano, _on_hermano)
	var contenedor := get_node_or_null(carteles)
	if contenedor == null:
		return
	for hijo in contenedor.get_children():
		if hijo is CartelEvento:
			hijo.accionado.connect(_on_notas)


## Route114_LanettesHouse_EventScript_15C262.
func _on_aredia(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if SistemaGuardado.get_flag(BANDERA_MUNECO_AREDIA):
		await mensaje(TEXTO_AREDIA_TRAS)
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(BANDERA_PC_AREDIA, true)
	await mensaje(TEXTO_AREDIA_REGALO)
	var inventario := SistemaGuardado.get_bases_secretas()
	var nombre := tr("BASES_DECOR_%03d_NOMBRE" % DECORACION_MUNECO_SEEDOT)
	if inventario.agregar_decoracion(DECORACION_MUNECO_SEEDOT) < 0:
		await mensaje(TEXTO_DECOR_SIN_SITIO, true, {"{decoracion}": nombre})  # ShowNoRoomForDecor
		terminar(false, [npc])
		return
	await mensaje_con_fanfarria(TEXTO_DECOR_OBTENIDA, FANFARRIA_OBJETO, {"{decoracion}": nombre})
	await mensaje(TEXTO_DECOR_ENVIADA_PC, true, {"{decoracion}": nombre})
	SistemaGuardado.set_flag(BANDERA_MUNECO_AREDIA, true)
	terminar(false, [npc])


## Route114_FossilManiacsHouse_EventScript_15C1C3.
func _on_hermano(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if SistemaGuardado.get_flag(BANDERA_MT28):
		await mensaje(TEXTO_HERMANO_TRAS)
		terminar(false, [npc])
		return
	await mensaje(TEXTO_HERMANO_REGALO, false)
	if not await dar_objeto(npc, OBJETO_MT28):
		await mensaje_mochila_llena()
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(BANDERA_MT28, true)
	terminar(false, [npc])


## Route114_LanettesHouse_EventScript_15C299 (lockall).
func _on_notas(_cartel: CartelEvento) -> void:
	var administrador_mapa := _administrador()
	if administrador_mapa == null or not comenzar(administrador_mapa):
		return
	if not await preguntar_si_no(TEXTO_NOTAS_1):
		await mensaje(TEXTO_NOTAS_CERRADO)
		terminar()
		return
	if await preguntar_si_no(TEXTO_NOTAS_2):
		await mensaje(TEXTO_NOTAS_3)
	terminar()
