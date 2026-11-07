@tool
class_name MapaConfiguracion
extends Node2D

## Descripción:
##
## Script base para configuración de mapas exteriores e interiores.
## Define propiedades exportables para batallas y navegación

## ===== PROPIEDADES EXPORTABLES =====

@export_group("Configuración del Mapa")
## Identificador interno único del mapa (usado por el sistema de guardado).
## Debe coincidir con el valor de "mapa_actual" en la partida guardada.
@export var nombre_interno: String = ""

## Clave de zona del mapa (patrón MAPSEC de pokeruby), p. ej. `RUTA_113` o
## `VILLA_RAIZ`. Es lo que se guarda como lugar (posición de la partida y lugar
## de encuentro de los Pokémon); el texto legible se resuelve al mostrarlo con
## `Lugares.nombre_lugar(clave)` (traducción `LUGAR_<clave>` en dialogos.csv).
## Un interior sin sección propia hereda la de `mapa_exterior_asociado` para
## guardar/encuentros, pero no anuncia cartel propio (ver administrador_mapa).
@export var seccion: String = ""

## Mapa de región: clave del POI en el que se coloca al jugador cuando la sección
## no tiene POI propio. Los submarinos se muestran en su mapa de superficie
## (sUnderwaterMaps de region_map.c). Vacío: el POI del propio mapa.
@export var poi_mapa_region: String = ""

## Casilla fija del mapa de región para secciones de 1x1 que no coinciden con su
## POI (p. ej. MAPSEC_UNDERWATER_128 en (24, 9)). (-1, -1): se calcula desde la
## celda del jugador dentro del POI.
@export var casilla_mapa_region: Vector2i = Vector2i(-1, -1)

## Si el mapa es de interior (true) o exterior (false).
@export var esInterior: bool = false

## Cueva o subterráneo (MAP_TYPE_UNDERGROUND de pokeruby): CUERDA HUIDA y
## EXCAVAR solo se pueden usar aquí (CanUseEscapeRopeOnCurrMap). Los edificios
## son interiores sin esta marca.
@export var es_cueva: bool = false

## Si es un mapa de interior, nombre del mapa exterior asociado (debe existir).
@export var mapa_exterior_asociado: String = ""

## Si true, el jugador solo puede caminar en este mapa (sin correr ni usar la bicicleta).
@export var solo_caminar: bool = false

## Si true, no se puede correr pero la bicicleta sigue permitida: las casetas del CAMINO de BICIS son
## MAP_TYPE_INDOOR (IsRunningDisallowed) con excepción en Overworld_IsBikingAllowed.
@export var sin_correr: bool = false

## Si true, al entrar por un warp se muestra el cartel con `seccion`: desde un
## exterior, cuando el nombre cambia; desde otro interior, siempre, aunque se llame
## igual (entre interiores con distinto nombre se muestra aunque sea false). Los
## exteriores ya se anuncian solos al llegar caminando o al salir de un interior.
@export var mostrar_nombre_al_entrar: bool = false

@export_group("Buceo")
## Mapa submarino (MAP_TYPE_UNDERWATER de pokeruby): el jugador va buceando (sin
## Pokémon a la vista, sin bici ni correr), con BUCEO emerge a `mapa_emersion` y
## no se puede usar VUELO ni TELETRANSP. Ver scripts/overworld/buceo.gd.
@export var mapa_submarino: bool = false

## Superficie: clave del mapa submarino al que se baja con BUCEO desde una celda
## con la bandera BUCEO (conexión `dive` de connections.inc o `setdivewarp` de la
## cabecera). Vacío: aquí no se puede bucear.
@export var mapa_inmersion: String = ""

## Celda fija de llegada al bajar (`setdivewarp` de los mapas pequeños, p. ej. la
## RUTA 134). (-1, -1): la misma celda en la que se bucea (conexión `dive`).
@export var celda_inmersion_fija: Vector2i = Vector2i(-1, -1)

## Mapa submarino: clave del mapa de superficie al que se emerge con BUCEO
## (conexión `emerge` o `setdivewarp`). Vacío: aquí no se puede emerger.
@export var mapa_emersion: String = ""

## Celda fija de llegada al emerger (`setdivewarp`). (-1, -1): la misma celda.
@export var celda_emersion_fija: Vector2i = Vector2i(-1, -1)

@export_group("Huida")
## `setescapewarp` de la cabecera (MAP_SCRIPT_ON_RESUME): al llegar a este mapa, la
## entrada exterior de CUERDA HUIDA y EXCAVAR pasa a ser `mapa_huida` en `celda_huida`.
## Sirve para los interiores a los que se llega sin pisar un warp del exterior, como la
## sala exterior de la CÁMARA SELLADA (se emerge buceando). Vacío: no cambia nada.
@export var mapa_huida: String = ""

## Celda de llegada de `mapa_huida`.
@export var celda_huida: Vector2i = Vector2i.ZERO

@export_group("Configuración de Clima")
## Clima visual aplicado inmediatamente cuando este mapa pasa a ser el actual.
## Un recurso vacío equivale a NINGUNO; los interiores no heredan el del exterior.
@export var clima_inicial: DefinicionClima = null:
	set(valor):
		clima_inicial = valor
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("update_configuration_warnings")

## Intensidad del clima inicial de este mapa.
@export_range(0.0, 1.0, 0.01) var intensidad_clima: float = 1.0

@export_group("Configuración de Audio")
## Música de fondo del mapa - Selecciona desde Singleton.TEMAS_REGISTRADOS
@export var musica_mapa: String = "" : set = set_musica_mapa

## Sonidos ambientales
#@export var sonidos_ambiente: Array[AudioStream] = []

@export_group("Configuración de Batalla")
## Escena de batalla de la cabecera del mapa (MAP_BATTLE_SCENE_*): NORMAL usa
## el terreno bajo el jugador; el resto fija el escenario (gimnasio, guaridas,
## Alto Mando, Torre Batalla/bases secretas). Ver EscenarioBatalla.
@export var escena_batalla: EscenarioBatalla.Escena = EscenarioBatalla.Escena.NORMAL

## Tipo de mapa para elegir el terreno de batalla (gMapHeader.mapType en
## BattleSetup_GetTerrain). AUTOMATICO: INTERIOR si esInterior, SUBTERRANEO si
## es_cueva y RUTA en otro caso (ver obtener_tipo_mapa_batalla()).
@export var tipo_mapa_batalla: EscenarioBatalla.TipoMapa = EscenarioBatalla.TipoMapa.AUTOMATICO

## Música de batalla vs salvajes (opcional) - Selecciona desde Singleton.TEMAS_REGISTRADOS
@export var musica_batalla: String = "" : set = set_musica_batalla

## Probabilidad de encuentros Pokémon (0.0 = nunca, 1.0 = siempre) OBSOLETO
# @export_range(0.0, 1.0) var probabilidad_encuentros: float = 0.1
var probabilidad_encuentros: float = 0.1

#@export_group("Configuración Visual")

## Color de ambiente para batallas (tinte general)
#@export var color_ambiente: Color = Color.WHITE

## Partículas de ambiente (opcional)
#@export var particulas_ambiente: PackedScene = null

## Emitida cuando este mapa pasa a ser el actual: al iniciar/cargar, al cruzar un
## borde del Overworld o al llegar por un warp (`por_warp`). Los nodos hijos que
## dependan del estado del juego (NPC que cambian de sitio) la escuchan.
signal mapa_activado(por_warp: bool)

## Indica que el jugador está interactuando con este mapa (true). Usado por el AdministradorMapa.
var foco: bool = true

## CapasAgua hija cacheada (obtener_capas_agua()).
var _capas_agua: CapasAgua = null
## Evita repetir en cada paso el aviso de AguaFX ausente.
var _aviso_agua_fx_emitido: bool = false

## Activa los mensajes de depuración de _log (desactivados por defecto: _log se
## llama en el _ready de cada mapa y en cada onda de agua).
const DEPURAR_LOG := false

## Cache del tema musical resuelto desde el mapa exterior asociado.
var _tema_mapa_asociado: String = ""
var _tema_mapa_asociado_resuelto: bool = false
var _tema_batalla_asociado: String = ""
var _tema_batalla_asociado_resuelto: bool = false

## Spawn de debug leído del nodo SpawnDebug del mapa (arranque directo con F6).
var _spawn_debug_marcado: bool = false
var _spawn_debug_tile: Vector2i = Vector2i.ZERO

## Rect en píxeles (relativo a la posición del nodo) que cubre la superficie útil del mapa.
## Se lee del nodo VisibleOnScreenEnabler2D hijo al entrar en escena.
var mapa_rect_px: Rect2 = Rect2()

## Ejecutar esta escena de mapa suelta con F6 arranca el juego completo
## (AdministradorMapa + Overworld) cargando la partida guardada y sin pasar
## por la intro. Va en _enter_tree (no en _ready) porque camion.gd sobrescribe
## _ready sin llamar a super. Ver herramientas/debug/debug_arranque.gd.
func _enter_tree() -> void:
	# El marcador SpawnDebug se lee aquí y no en _ready: en runtime su _ready lo
	# libera, y el _ready de los hijos corre después del _enter_tree del padre.
	if OS.is_debug_build():
		_leer_marcador_spawn_debug()
		call_deferred("_intentar_arranque_debug_si_escena_raiz")

func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("update_configuration_warnings")
	_aplicar_configuracion()
	# Cachear dimensiones desde el VisibleOnScreenEnabler2D (mapas exteriores)
	mapa_rect_px = obtener_rect_util()
	var enabler := get_node_or_null("VisibleOnScreenEnabler2D") as VisibleOnScreenNotifier2D
	if enabler:
		enabler.screen_entered.connect(_on_screen_entered)
		enabler.screen_exited.connect(_on_screen_exited)


## Posición del mapa en el plano del Overworld (píxeles). Un mapa de una
## RegionOverworld se coloca respecto de su región, que a su vez se coloca en el
## Overworld. No necesita estar en el árbol (a diferencia de global_position).
func posicion_en_mundo() -> Vector2:
	var padre := get_parent()
	if padre is RegionOverworld:
		return position + (padre as RegionOverworld).position
	return position


## También disponible antes de _ready: validación del arranque sin activar mapas.
func obtener_rect_util() -> Rect2:
	if mapa_rect_px != Rect2():
		return mapa_rect_px
	var enabler := get_node_or_null("VisibleOnScreenEnabler2D") as VisibleOnScreenNotifier2D
	if enabler != null:
		return enabler.rect
	# Recursivo: las salas con marea (MareaCueva) guardan sus capas dentro de los
	# grupos MareaBaja/MareaAlta; contar solo las directas dejaba el rect en la capa
	# Ingredientes (unas pocas celdas) y bloqueaba al jugador fuera de ella.
	var union := Rect2i()
	var tiene_datos := false
	for capa: TileMapLayer in _recoger_tilemaps_util(self):
		var r: Rect2i = capa.get_used_rect()
		if r.size == Vector2i.ZERO:
			continue
		union = union.merge(r) if tiene_datos else r
		tiene_datos = true
	return Rect2(Vector2(union.position) * 16, Vector2(union.size) * 16) if tiene_datos else Rect2()

## TileMapLayers del mapa a cualquier profundidad, sin entrar en mapas anidados.
func _recoger_tilemaps_util(nodo: Node) -> Array[TileMapLayer]:
	var capas: Array[TileMapLayer] = []
	for child: Node in nodo.get_children():
		if child is MapaConfiguracion:
			continue
		if child is TileMapLayer:
			capas.append(child as TileMapLayer)
		capas.append_array(_recoger_tilemaps_util(child))
	return capas

## Si esta escena de mapa se ejecutó suelta (F6), pide a DebugArranque que el
## juego arranque en este mapa y salta a la escena principal. Dentro del
## Overworld el mapa nunca es hijo directo de la raíz del árbol, así que la
## comprobación del padre distingue ambos casos sin banderas extra.
func _intentar_arranque_debug_si_escena_raiz() -> void:
	if Engine.is_editor_hint() or not OS.is_debug_build():
		return
	if get_parent() != get_tree().root:
		return
	var debug_arranque := get_node_or_null("/root/DebugArranque")
	if debug_arranque == null or not debug_arranque.has_method("arrancar_juego_en_mapa"):
		return
	var clave := _clave_mapa_debug()
	if _spawn_debug_marcado:
		_imprimir("F6 sobre escena de mapa: arrancando el juego completo en '%s' (spawn %s)" % [
			clave, _spawn_debug_tile,
		])
	else:
		_imprimir("F6 sobre escena de mapa: '%s' sin marcador SpawnDebug; se usará la posición guardada" % clave)
	debug_arranque.call_deferred(
		"arrancar_juego_en_mapa", clave, _spawn_debug_marcado, _spawn_debug_tile.x, _spawn_debug_tile.y
	)

## Clave de mapa que usa todo el sistema: nombre del archivo .tscn sin
## extensión (los mapas de interior no definen nombre_interno).
func _clave_mapa_debug() -> String:
	var base := scene_file_path.get_file().get_basename()
	return base if not base.is_empty() else name

## ===== MARCADOR DE SPAWN (nodo SpawnDebug del mapa) =====

## Ruta del script del marcador. Se compara por ruta (y no con `is`) para no
## depender de que la clase global esté registrada: este script es @tool y
## también corre en el editor.
const RUTA_SCRIPT_MARCADOR_SPAWN: String = "res://escenas/mapas/marcador_spawn_debug.gd"

## Busca el nodo SpawnDebug del mapa y cachea su tile. Sin marcador, el
## arranque directo cae a la posición guardada (ver DebugArranque).
func _leer_marcador_spawn_debug() -> void:
	_spawn_debug_marcado = false
	_spawn_debug_tile = Vector2i.ZERO
	var marcador := _buscar_marcador_spawn()
	if marcador == null or not marcador.has_method("obtener_coord_tile"):
		return
	var tile: Variant = marcador.call("obtener_coord_tile")
	if tile is Vector2i:
		_spawn_debug_tile = tile
		_spawn_debug_marcado = true

## Primer nodo (recursivo) cuyo script es marcador_spawn_debug.gd.
func _buscar_marcador_spawn() -> Node2D:
	return _buscar_marcador_spawn_en(self)

func _buscar_marcador_spawn_en(nodo: Node) -> Node2D:
	for hijo in nodo.get_children():
		if _es_marcador_spawn(hijo):
			return hijo as Node2D
		var encontrado := _buscar_marcador_spawn_en(hijo)
		if encontrado != null:
			return encontrado
	return null

func _es_marcador_spawn(nodo: Node) -> bool:
	# `as Script` evita inferir Variant desde get_script() (los warnings de
	# inferencia son errores en este proyecto).
	var script := nodo.get_script() as Script
	return script != null and script.resource_path == RUTA_SCRIPT_MARCADOR_SPAWN

func _notification(what: int) -> void:
	if Engine.is_editor_hint() and what == NOTIFICATION_CHILD_ORDER_CHANGED:
		call_deferred("update_configuration_warnings")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	warnings.append_array(ValidadorClimaMapa.validar(self))
	if obtener_capas_agua() == null:
		warnings.append_array(ValidadorCapasAgua.validar_mapa_sin_capas(self))
	warnings.append_array(ValidadorCapasAgua.validar_efectos_agua(self))
	var nodo_npcs := get_node_or_null("NPCs")

	if nodo_npcs == null:
		warnings.append("Falta el nodo 'NPCs'. AdministradorMapa lo creara en runtime con z_index=1 y Y-Sort activo, pero conviene corregir este mapa.")
		return warnings

	if not (nodo_npcs is Node2D):
		warnings.append("El nodo 'NPCs' existe, pero no es Node2D. Debe ser un Node2D con z_index=1 y Y-Sort activo.")
		return warnings

	var nodo_npcs_2d := nodo_npcs as Node2D
	if nodo_npcs_2d.z_index != 1:
		warnings.append("El nodo 'NPCs' deberia tener z_index=1.")
	if not nodo_npcs_2d.is_y_sort_enabled():
		warnings.append("El nodo 'NPCs' deberia tener Y-Sort activo.")

	return warnings

func _on_screen_entered() -> void:
	pass
	# visible = true
	# foco = true

func _on_screen_exited() -> void:
	pass
	# visible = false
	# foco = false

## ===== FUNCIONES PÚBLICAS =====

## Contrato previo a add_child/_ready. Mapas ordinarios no requieren contexto.
func preparar_entrada(contexto: Dictionary) -> bool:
	return contexto.is_empty()


## Llamada por AdministradorMapa cuando este mapa pasa a ser el actual.
func notificar_mapa_activado(por_warp: bool = false) -> void:
	# ResetCyclingRoadChallengeData: cada carga de mapa borra el cronómetro y los choques del reto.
	CaminoBici.reiniciar_datos_reto()
	mapa_activado.emit(por_warp)

## Reenvía la solicitud de onda de agua al AguaFX del mapa (obtener_reflexiones()).
## La llama EfectosAgua (jugador / NPC) al pisar un tile AGUA_SALPICA.
func reproducir_onda(pos_global: Vector2) -> void:
	var agua_fx := obtener_reflexiones()
	if agua_fx == null:
		_avisar_agua_fx_una_vez("hay tiles AGUA_SALPICA pero el mapa no tiene AguaFX (CapasAgua con 'reflejos')")
		return
	_log("reproducir_onda() → AguaFX en pos " + str(pos_global))
	agua_fx.reproducir_onda(pos_global)

func _avisar_agua_fx_una_vez(motivo: String) -> void:
	if _aviso_agua_fx_emitido:
		return
	_aviso_agua_fx_emitido = true
	push_warning("[MapConfig:%s] %s ('%s')" % [name, motivo, nombre_interno])

## Contenedor de huellas de arena del mapa: sobre las capas de tiles y bajo los
## personajes, porque se inserta justo antes de "NPCs" (z_index 1). Se crea al
## dejar la primera huella.
func obtener_contenedor_huellas() -> Node2D:
	var contenedor := get_node_or_null("HuellasArena") as Node2D
	if contenedor != null:
		return contenedor
	contenedor = Node2D.new()
	contenedor.name = "HuellasArena"
	add_child(contenedor)
	var nodo_npcs := get_node_or_null("NPCs")
	if nodo_npcs != null:
		move_child(contenedor, nodo_npcs.get_index())
	return contenedor

## Componente de hierba con ceniza del mapa (grupo `hierba_ceniza`), o null si el
## mapa no tiene. Los exteriores conviven en el Overworld: se filtra por ancestro.
func obtener_hierba_ceniza() -> HierbaCenizaMapa:
	if not is_inside_tree():
		return null
	for nodo: Node in get_tree().get_nodes_in_group(HierbaCenizaMapa.GRUPO):
		if is_ancestor_of(nodo):
			return nodo as HierbaCenizaMapa
	return null

## Componente de CORTE sobre la hierba alta del mapa. A diferencia de los demás,
## no hay que añadirlo a la escena: se crea la primera vez que se pide (hijo
## directo "HierbaCortable") y, al crearse, vuelve a aplicar las celdas cortadas
## que la partida guardada traiga de este mapa.
func obtener_hierba_cortable() -> HierbaCortableMapa:
	for hijo: Node in get_children():
		if hijo is HierbaCortableMapa:
			return hijo as HierbaCortableMapa
	var hierba := HierbaCortableMapa.new()
	hierba.name = HierbaCortableMapa.NOMBRE_NODO
	add_child(hierba)
	return hierba

## Componente de puentes de madera del mapa (grupo `puente_madera`), o null si el
## mapa no tiene. Se filtra por ancestro como en la hierba con ceniza.
func obtener_puente_madera() -> PuenteMaderaMapa:
	if not is_inside_tree():
		return null
	for nodo: Node in get_tree().get_nodes_in_group(PuenteMaderaMapa.GRUPO):
		if is_ancestor_of(nodo):
			return nodo as PuenteMaderaMapa
	return null

## Componente de cuestas de barro del mapa (grupo `cuesta_barro`), o null si no tiene.
func obtener_cuesta_barro() -> CuestaBarroMapa:
	if not is_inside_tree():
		return null
	for nodo: Node in get_tree().get_nodes_in_group(CuestaBarroMapa.GRUPO):
		if is_ancestor_of(nodo):
			return nodo as CuestaBarroMapa
	return null

## Contenedor de puertas giratorias del mapa (grupo `puertas_giratorias`), o null si no tiene.
func obtener_puertas_giratorias() -> PuertasGiratoriasMapa:
	if not is_inside_tree():
		return null
	for nodo: Node in get_tree().get_nodes_in_group(PuertasGiratoriasMapa.GRUPO):
		if is_ancestor_of(nodo):
			return nodo as PuertasGiratoriasMapa
	return null

## Componente de suelo agrietado del mapa (grupo `suelo_agrietado`), o null si no tiene.
func obtener_suelo_agrietado() -> SueloAgrietadoMapa:
	if not is_inside_tree():
		return null
	for nodo: Node in get_tree().get_nodes_in_group(SueloAgrietadoMapa.GRUPO):
		if is_ancestor_of(nodo):
			return nodo as SueloAgrietadoMapa
	return null

## ===== CAPAS DE AGUA =====
## Fuente única de las piezas de agua del mapa: la CapasAgua hija (buscada por
## tipo y cacheada). Los mapas sin migrar caen a los nodos sueltos por nombre
## (`AnclaClimaMundo`, `BackBufferAgua`, `SombraPuente`, `AguaFX`).

## Nombre del ancla del canal de mundo del clima en mapas sin CapasAgua.
const NOMBRE_ANCLA_CLIMA_MUNDO := "AnclaClimaMundo"
## Nombre de la capa de sombra bajo los puentes en mapas sin CapasAgua.
const NOMBRE_SOMBRA_PUENTE_ANTIGUA := "SombraPuente"

## CapasAgua hija directa del mapa, o null.
func obtener_capas_agua() -> CapasAgua:
	if is_instance_valid(_capas_agua) and _capas_agua.get_parent() == self:
		return _capas_agua
	_capas_agua = null
	for hijo: Node in get_children():
		if hijo is CapasAgua:
			_capas_agua = hijo as CapasAgua
			break
	return _capas_agua

## Ancla del canal de mundo del clima (nubes), o null.
func obtener_ancla_clima_mundo() -> Node2D:
	var capas := obtener_capas_agua()
	if capas != null:
		return capas.obtener_ancla_clima_mundo()
	return get_node_or_null(NOMBRE_ANCLA_CLIMA_MUNDO) as Node2D

## BackBufferCopy que copia solo el agua, o null.
func obtener_backbuffer() -> BackBufferCopy:
	var capas := obtener_capas_agua()
	if capas != null:
		return capas.obtener_backbuffer()
	return get_node_or_null(String(CapasAgua.NOMBRE_BACKBUFFER)) as BackBufferCopy

## TileMapLayer con la sombra del agua bajo los puentes, o null.
func obtener_capa_sombra_puente() -> TileMapLayer:
	var capas := obtener_capas_agua()
	if capas != null:
		return capas.obtener_capa_sombra_puente()
	return get_node_or_null(NOMBRE_SOMBRA_PUENTE_ANTIGUA) as TileMapLayer

## AguaFX (reflejos y ondas) activo, o null.
func obtener_reflexiones() -> ReflexionesAgua:
	var capas := obtener_capas_agua()
	if capas != null:
		return capas.obtener_reflexiones()
	return get_node_or_null(String(CapasAgua.NOMBRE_REFLEXIONES)) as ReflexionesAgua

## true si los reflejos deben leer el agua del backbuffer (reflejo opaco): con
## CapasAgua, su `reflejo_opaco_sobre_efectos`; sin ella, que exista un
## `BackBufferAgua` activo.
func usa_reflejo_opaco() -> bool:
	var capas := obtener_capas_agua()
	if capas != null:
		return capas.usa_reflejo_opaco()
	return CapasAgua.backbuffer_activo(obtener_backbuffer())

## ===== CLIMA =====

## SelectorClimaEntrada del mapa (descendiente del grupo `selector_clima_entrada`,
## normalmente `Eventos/SelectorClimaEntrada`), o null si el mapa no tiene. Los
## exteriores conviven en el Overworld: se filtra por ancestro.
func obtener_selector_clima_entrada() -> SelectorClimaEntrada:
	if is_inside_tree():
		for nodo: Node in get_tree().get_nodes_in_group(SelectorClimaEntrada.GRUPO):
			if is_ancestor_of(nodo):
				return nodo as SelectorClimaEntrada
		return null
	return _buscar_selector_clima_en(self)

func _buscar_selector_clima_en(nodo: Node) -> SelectorClimaEntrada:
	for hijo: Node in nodo.get_children():
		if hijo is SelectorClimaEntrada:
			return hijo as SelectorClimaEntrada
		var encontrado := _buscar_selector_clima_en(hijo)
		if encontrado != null:
			return encontrado
	return null

## Zona de clima de entrada que contiene `celda` (celda local del mapa), o null
## si el mapa no tiene selector o ninguna zona la contiene.
func resolver_zona_clima_entrada(celda: Vector2i) -> ZonaClimaEntrada:
	var selector := obtener_selector_clima_entrada()
	return selector.resolver(celda) if selector != null else null

## Devuelve el TPTileDataMap con el layer_id indicado, o null si no existe.
## Permite a NPCs y otros nodos acceder a su capa de datos sin pasar por Singleton.
func get_capa_por_id(layer_id: int) -> TPTileDataMap:
	return _buscar_capa_en_nodo(self, layer_id)

## Devuelve la capa exacta si existe; si no, intenta layer_id=0.
## Si el mapa no tiene datos para ninguna de las dos, devuelve null.
func get_capa_resuelta(layer_id: int) -> TPTileDataMap:
	var capa := get_capa_por_id(layer_id)
	if capa != null:
		return capa
	if layer_id != 0:
		return get_capa_por_id(0)
	return null

## Devuelve la primera TileMapLayer encontrada en el mapa.
## Se usa solo para convertir posiciones mundo a coordenadas de celda.
func get_tilemap_principal() -> TileMapLayer:
	return _buscar_tilemap_en_nodo(self)

## Convierte una posición global a coordenadas de celda del mapa.
func global_to_map_cell(global_pos: Vector2) -> Vector2i:
	var tilemap := get_tilemap_principal()
	if tilemap != null:
		return tilemap.local_to_map(tilemap.to_local(global_pos))
	return Vector2i(
		floor((global_pos.x - global_position.x) / Singleton.TILE_SIZE),
		floor((global_pos.y - global_position.y) / Singleton.TILE_SIZE)
	)

## ===== BLOQUEOS DE JUEGO DEL PROPIO MAPA =====
## Un mapa puede bloquear el juego por sí mismo (intros, cinemáticas), pero
## NUNCA guarda aquí la pausa global (menú, batalla, diálogo...): esa vive en
## Singleton y la combina AdministradorMapa.esta_pausado().
## OJO: estos métodos se consultan desde código @tool, así que no deben leer
## Singleton (en el editor el autoload solo es un placeholder).

## ¿Este mapa bloquea las acciones (jugador y NPCs) ahora mismo?
## Los mapas que lo necesiten (p. ej. camion.gd) lo sobrescriben.
func control_bloqueado() -> bool:
	return false

## ¿Este mapa impide abrir el menú de pausa?
func bloquea_menu() -> bool:
	return false


func permite_guardar() -> bool:
	return true

## Salta los grupos ocultos (MareaBaja/MareaAlta de MareaCueva): la capa activa la decide
## la visibilidad del grupo, no el orden de los hijos. La visibilidad de la propia
## TPTileDataMap no cuenta (se oculta en el editor para despejar la vista).
func _buscar_capa_en_nodo(node: Node, layer_id: int) -> TPTileDataMap:
	for child in node.get_children():
		if child is TPTileDataMap and child.layer_id == layer_id:
			return child
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		var resultado := _buscar_capa_en_nodo(child, layer_id)
		if resultado != null:
			return resultado
	return null

func _buscar_tilemap_en_nodo(node: Node) -> TileMapLayer:
	for child in node.get_children():
		if child is TileMapLayer:
			return child
		var resultado := _buscar_tilemap_en_nodo(child)
		if resultado != null:
			return resultado
	return null

## Tipo de mapa efectivo para el terreno de batalla. Las cuevas también son
## esInterior, por eso es_cueva se mira antes.
func obtener_tipo_mapa_batalla() -> EscenarioBatalla.TipoMapa:
	if tipo_mapa_batalla != EscenarioBatalla.TipoMapa.AUTOMATICO:
		return tipo_mapa_batalla
	if es_cueva:
		return EscenarioBatalla.TipoMapa.SUBTERRANEO
	if esInterior:
		return EscenarioBatalla.TipoMapa.INTERIOR
	return EscenarioBatalla.TipoMapa.RUTA

## Obtiene la configuración de batalla para este mapa
func obtener_configuracion_batalla() -> Dictionary:
	return {
		"escena": escena_batalla,
		"tipo_mapa": obtener_tipo_mapa_batalla(),
		"musica": musica_batalla,
		"probabilidad_encuentros": probabilidad_encuentros
	}

## Obtiene información básica del mapa
func obtener_info_mapa() -> Dictionary:
	var seccion_efectiva := obtener_seccion_efectiva()
	return {
		"id": nombre_interno,
		"seccion": seccion_efectiva,
		"nombre": obtener_nombre_lugar(),
		"foco": foco,
	}

## ===== SECCIÓN (CLAVE DE LUGAR) EFECTIVA =====

## Sección del mapa: la propia o, si es un interior sin sección, la de su mapa
## exterior asociado (instanciado en el árbol o leída de su escena).
## "" si no hay ninguna aplicable.
func obtener_seccion_efectiva() -> String:
	var propia := seccion.strip_edges()
	if not propia.is_empty():
		return propia
	if not esInterior or mapa_exterior_asociado.is_empty():
		return ""
	var exterior := _buscar_mapa_instanciado(mapa_exterior_asociado)
	if exterior != null:
		return exterior.obtener_seccion_efectiva()
	return Lugares.seccion_de_escena(mapa_exterior_asociado)

## Texto legible de la sección efectiva ("" si no hay).
func obtener_nombre_lugar() -> String:
	return Lugares.nombre_lugar(obtener_seccion_efectiva())

func _buscar_mapa_instanciado(clave: String) -> MapaConfiguracion:
	if not is_inside_tree():
		return null
	return _buscar_mapa_en_nodo(get_tree().root, _normalizar_clave_mapa(clave))

func _buscar_mapa_en_nodo(nodo: Node, clave_norm: String) -> MapaConfiguracion:
	for hijo in nodo.get_children():
		if hijo != self and hijo is MapaConfiguracion and _coincide_clave_mapa(hijo, clave_norm):
			return hijo as MapaConfiguracion
		var encontrado := _buscar_mapa_en_nodo(hijo, clave_norm)
		if encontrado != null:
			return encontrado
	return null

## ===== SETTERS PARA ENUM DROPDOWNS =====

## Obtiene la lista de temas disponibles incluyendo la opción vacía
## Esta función obtiene dinámicamente los temas desde Singleton.TEMAS_REGISTRADOS
## para evitar tener que mantener una lista hardcodeada
func _obtener_temas_disponibles() -> Array[String]:
	var temas: Array[String] = [""]  # Comenzar con opción vacía

	# Obtener dinámicamente las claves desde Singleton.TEMAS_REGISTRADOS
	if Singleton:
		var claves_temas = Singleton.TEMAS_REGISTRADOS.keys()
		claves_temas.sort()  # Ordenar alfabéticamente para consistencia
		temas.append_array(claves_temas)
	else:
		push_warning("[MapConfig:%s] No se pudo acceder a Singleton.TEMAS_REGISTRADOS" % name)
		# Fallback con temas conocidos
		temas.append_array(["VILLA_RAIZ", "PUEBLO_ESCASO", "RUTA_101", "RUTA_102", "RUTA_103", "CENTRO_POKEMON", "TIENDA_POKEMON"])

	return temas

## Valor de `musica_mapa` que deja el mapa en silencio: sin tema propio y sin
## heredar el del mapa exterior asociado (p. ej. el camión de la intro, donde la
## música la gestiona el script del mapa). Se acepta en mayúsculas o minúsculas.
const MUSICA_NINGUNA := "NINGUNA"

## Setter para la música del mapa
func set_musica_mapa(value: String) -> void:
	if value.strip_edges().to_upper() == MUSICA_NINGUNA:
		musica_mapa = MUSICA_NINGUNA
		return
	# En el editor Singleton no expone sus vars (no es @tool); omitir validación.
	if value != "" and not Engine.is_editor_hint() and Singleton:
		var temas = Singleton.get("TEMAS_REGISTRADOS")
		if temas != null and not temas.has(value):
			push_warning("[MapConfig:%s] Tema musical no encontrado: %s" % [name, value])
			return

	musica_mapa = value

## Setter para la música de batalla
func set_musica_batalla(value: String) -> void:
	# En el editor Singleton no expone sus vars (no es @tool); omitir validación.
	if value != "" and not Engine.is_editor_hint() and Singleton:
		var temas = Singleton.get("TEMAS_REGISTRADOS")
		if temas != null and not temas.has(value):
			push_warning("[MapConfig:%s] Tema musical de batalla no encontrado: %s" % [name, value])
	musica_batalla = value

## ===== TEMA MUSICAL EFECTIVO =====

## Tema musical efectivo del mapa: el suyo propio o, si es un interior sin
## tema, el tema del mapa exterior asociado (p. ej. nodo_casa_1_piso_2 →
## villa_raiz, que sí define VILLA_RAIZ). Devuelve "" si no hay tema aplicable
## o si el mapa está marcado como `MUSICA_NINGUNA`. Con la sequía de GROUDON
## (ClimaLegendario) sus exteriores tocan MUS_WEATHER_GROUDON; un interior que
## hereda el tema de su exterior pide el de la cabecera (`con_clima_legendario`).
func obtener_musica_mapa_efectiva(con_clima_legendario: bool = true) -> String:
	if es_sin_musica():
		return ""
	if con_clima_legendario and ClimaLegendario.aplica_a(self):
		return ClimaLegendario.MUSICA
	if not musica_mapa.is_empty():
		return musica_mapa
	if esInterior and not mapa_exterior_asociado.is_empty():
		var tema_asociado := _obtener_tema_mapa_asociado()
		if not tema_asociado.is_empty():
			return tema_asociado
	return ""


## True si el mapa debe quedar en silencio (`musica_mapa` = NINGUNA).
func es_sin_musica() -> bool:
	return musica_mapa.to_upper() == MUSICA_NINGUNA


## Música de batalla propia o la configurada por el mapa exterior asociado.
func obtener_musica_batalla_efectiva() -> String:
	if not musica_batalla.is_empty():
		return musica_batalla
	if not esInterior or mapa_exterior_asociado.is_empty():
		return ""
	if _tema_batalla_asociado_resuelto:
		return _tema_batalla_asociado
	_tema_batalla_asociado_resuelto = true
	_tema_batalla_asociado = _buscar_musica_batalla_en_mapa_instanciado(mapa_exterior_asociado)
	if _tema_batalla_asociado.is_empty():
		_tema_batalla_asociado = _leer_propiedad_de_escena_mapa(mapa_exterior_asociado, &"musica_batalla")
	return _tema_batalla_asociado


func _buscar_musica_batalla_en_mapa_instanciado(clave: String) -> String:
	if not is_inside_tree():
		return ""
	return _buscar_musica_batalla_en_nodo(get_tree().root, _normalizar_clave_mapa(clave))


func _buscar_musica_batalla_en_nodo(nodo: Node, clave_norm: String) -> String:
	for hijo in nodo.get_children():
		if hijo != self and hijo is MapaConfiguracion and _coincide_clave_mapa(hijo, clave_norm):
			return hijo.obtener_musica_batalla_efectiva()
		var tema := _buscar_musica_batalla_en_nodo(hijo, clave_norm)
		if not tema.is_empty():
			return tema
	return ""

## Resuelve (con cache) el tema musical del mapa exterior asociado.
func _obtener_tema_mapa_asociado() -> String:
	if _tema_mapa_asociado_resuelto:
		return _tema_mapa_asociado
	_tema_mapa_asociado_resuelto = true
	# 1) Mapa exterior ya instanciado en el árbol (caso normal: el Overworld
	#    contiene todos los mapas exteriores).
	_tema_mapa_asociado = _buscar_tema_en_mapa_instanciado(mapa_exterior_asociado)
	# 2) Fallback: leer la propiedad desde la escena sin instanciar (SceneState).
	if _tema_mapa_asociado.is_empty():
		_tema_mapa_asociado = _leer_musica_de_escena_mapa(mapa_exterior_asociado)
	return _tema_mapa_asociado

## Busca un MapaConfiguracion ya instanciado en el árbol cuyo archivo de
## escena, nombre de nodo o nombre_interno coincida con la clave dada.
func _buscar_tema_en_mapa_instanciado(clave: String) -> String:
	if not is_inside_tree():
		return ""
	return _buscar_tema_en_nodo(get_tree().root, _normalizar_clave_mapa(clave))

func _buscar_tema_en_nodo(nodo: Node, clave_norm: String) -> String:
	for hijo in nodo.get_children():
		if hijo != self and hijo is MapaConfiguracion and _coincide_clave_mapa(hijo, clave_norm):
			return hijo.obtener_musica_mapa_efectiva(false)
		var tema := _buscar_tema_en_nodo(hijo, clave_norm)
		if not tema.is_empty():
			return tema
	return ""

func _coincide_clave_mapa(mapa: MapaConfiguracion, clave_norm: String) -> bool:
	return (
		_normalizar_clave_mapa(mapa.scene_file_path.get_file().get_basename()) == clave_norm
		or _normalizar_clave_mapa(String(mapa.name)) == clave_norm
		or _normalizar_clave_mapa(mapa.nombre_interno) == clave_norm
	)

func _normalizar_clave_mapa(valor: String) -> String:
	return valor.to_lower().replace("_", "").replace("-", "").replace(" ", "")

## Lee `musica_mapa` del nodo raíz de la escena del mapa, buscándola por nombre
## bajo res://escenas/mapas/. Usa el SceneState del PackedScene para NO
## instanciar el mapa (instanciar dispararía _ready/_enter_tree y efectos
## secundarios como registrar_mapa_activo).
func _leer_musica_de_escena_mapa(clave: String) -> String:
	return _leer_propiedad_de_escena_mapa(clave, &"musica_mapa")


func _leer_propiedad_de_escena_mapa(clave: String, propiedad: StringName) -> String:
	var ruta := _buscar_ruta_escena_mapa("res://escenas/mapas/", clave)
	if ruta.is_empty():
		return ""
	var packed: PackedScene = load(ruta)
	if packed == null:
		return ""
	var estado := packed.get_state()
	for nodo_idx in estado.get_node_count():
		for prop_idx in estado.get_node_property_count(nodo_idx):
			if estado.get_node_property_name(nodo_idx, prop_idx) == propiedad:
				return str(estado.get_node_property_value(nodo_idx, prop_idx))
	return ""

## Búsqueda recursiva de un .tscn por nombre (case-insensitive) bajo base_path.
func _buscar_ruta_escena_mapa(base_path: String, nombre: String) -> String:
	var dir := DirAccess.open(base_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var nombre_archivo := ""
	while true:
		nombre_archivo = dir.get_next()
		if nombre_archivo == "":
			break
		if dir.current_is_dir():
			if nombre_archivo != "." and nombre_archivo != "..":
				var encontrado := _buscar_ruta_escena_mapa(base_path + nombre_archivo + "/", nombre)
				if not encontrado.is_empty():
					dir.list_dir_end()
					return encontrado
		# En una exportación las escenas aparecen como `<mapa>.tscn.remap`.
		elif nombre_archivo.trim_suffix(".remap").ends_with(".tscn") \
				and nombre_archivo.trim_suffix(".remap").get_basename().to_lower() == nombre.to_lower():
			var ruta_encontrada := base_path + nombre_archivo.trim_suffix(".remap")
			dir.list_dir_end()
			return ruta_encontrada
	dir.list_dir_end()
	return ""

## ===== FUNCIONES PRIVADAS =====

## Mensaje de depuración: solo se imprime con DEPURAR_LOG activado.
func _log(mensaje: String) -> void:
	if DEPURAR_LOG:
		_imprimir(mensaje)

## Imprime siempre en consola con formato: "HH:MM:SS [MapConfig:NombreNodo] mensaje"
func _imprimir(mensaje: String) -> void:
	var t := Time.get_time_dict_from_system()
	var hora := "%02d:%02d:%02d" % [t.hour, t.minute, t.second]
	print("%s [MapConfig:%s] %s" % [hora, name, mensaje])

## Aplica la configuración del mapa
func _aplicar_configuracion():

	# Aplicar música si está definida
	if musica_mapa != null:
		_reproducir_musica_mapa()

	# Configurar partículas de ambiente si están definidas
	# if particulas_ambiente != null:
	# 	_crear_particulas_ambiente()

	# Notificar al sistema que este mapa está activo
	# En el editor (script @tool) Singleton puede ser null: no es @tool o su script no compila.
	if Singleton != null and Singleton.has_method("registrar_mapa_activo"):
		Singleton.registrar_mapa_activo(self)

## Reproduce la música del mapa.
func _reproducir_musica_mapa():
	# Implementación básica - se puede mejorar con fade y gestión de audio
	pass

## Crea las partículas de ambiente.
# func _crear_particulas_ambiente():
# 	var particulas = particulas_ambiente.instantiate()
# 	add_child(particulas)

## ===== UTILIDADES DE DEBUG =====

func _to_string() -> String:
	return "MapaConfiguracion(id: %s, seccion: %s, escena batalla: %s)" % [
		name,
		seccion,
		EscenarioBatalla.Escena.keys()[escena_batalla]
	]

## Imprime información de debug del mapa
func debug_info():
	_imprimir("=== DEBUG MAPA ===")
	_imprimir("ID: " + name)
	_imprimir("Sección: %s (efectiva: %s)" % [seccion, obtener_seccion_efectiva()])
	_imprimir("Música Mapa: " + musica_mapa)
	_imprimir("Música efectiva: " + obtener_musica_mapa_efectiva())
	_imprimir("Música Batalla: " + musica_batalla)
	_imprimir("Escena Batalla: %s (tipo de mapa: %s)" % [
		EscenarioBatalla.Escena.keys()[escena_batalla],
		EscenarioBatalla.TipoMapa.keys()[obtener_tipo_mapa_batalla()]])
	_imprimir("Foco: " + str(foco))
	_imprimir("Temas disponibles en Singleton: " + str(Singleton.TEMAS_REGISTRADOS.keys() if (Singleton and Singleton.has("TEMAS_REGISTRADOS")) else []))
