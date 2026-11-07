@tool
class_name ValidadorCapasAgua
extends RefCounted

## Reglas de configuración del agua de un mapa (banderas de las capas de datos y
## piezas de CapasAgua). Funciones estáticas que devuelven avisos legibles
## (PackedStringArray vacío = todo correcto); las usan los avisos del editor de
## CapasAgua, TPTileDataMap y MapaConfiguracion, y los tests.
##
## Convención mar / estanque: el agua navegable (mar) lleva solo SURF, sin
## REFLEJO a propósito (tiene su propia capa de oleaje animado); los estanques de
## aguas quietas llevan SURF + REFLEJO + AGUA_SALPICA. Por eso NO se avisa de SURF
## sin REFLEJO/AGUA_SALPICA: los avisos de agua dependen de las piezas que activa
## cada mapa en su CapasAgua.

## Prefijos (en minúsculas) de nombres de capas de tierra que deben ir DESPUÉS de
## CapasAgua (si se dibujan antes, el agua y sus efectos las taparían).
const PREFIJOS_CAPAS_TIERRA: PackedStringArray = ["suelo", "tierra"]
## Celdas de ejemplo que se citan en cada aviso de banderas.
const MAX_EJEMPLOS := 5
const TAMANO_TILE := 16
## Nombre de la TileMapLayer del agua tras la que va CapasAgua.
const NOMBRE_CAPA_AGUA := "Agua"

## Banderas cuyos efectos (reflejo, ondas) dibuja AguaFX.
const MASCARA_EFECTOS_AGUA: int = TPTileDataMap.Flags.REFLEJO | TPTileDataMap.Flags.AGUA_SALPICA
## Banderas de efectos de agua que se ignoran fuera de la capa 0. AGUA_PIES solo
## salpica a los pies: no necesita AguaFX, así que no entra en MASCARA_EFECTOS_AGUA.
const MASCARA_EFECTOS_AGUA_CAPA_0: int = MASCARA_EFECTOS_AGUA | TPTileDataMap.Flags.AGUA_PIES
const _SURF_CAPA_SUPERIOR: int = TPTileDataMap.Flags.SURF | TPTileDataMap.Flags.CAPA_SUPERIOR


# ---------------------------------------------------------------------------
# Banderas de una capa de datos
# ---------------------------------------------------------------------------

## Reglas de banderas sobre el diccionario `tile_data` ("x,y" -> {"flags": int})
## de una capa con `layer_id`. `rect_celdas` (en celdas del mapa) activa la regla
## de puentes fuera del mapa; un rect sin área la omite.
## - PUENTE_* solo en capas elevadas (layer_id >= 1) y dentro del mapa.
## - REFLEJO / AGUA_SALPICA / AGUA_PIES en capas >= 1 se ignoran (efectos solo a ras de agua).
## - SURF + CAPA_SUPERIOR en la misma celda (el surf no sube de capa).
static func validar_banderas(tile_data: Dictionary, layer_id: int, rect_celdas: Rect2i = Rect2i()) -> PackedStringArray:
	var puente_en_capa_0: Array[Vector2i] = []
	var puente_fuera: Array[Vector2i] = []
	var agua_elevada: Array[Vector2i] = []
	var surf_capa_superior: Array[Vector2i] = []
	var comprobar_rect: bool = rect_celdas.has_area()
	for clave: Variant in tile_data.keys():
		var celda: Variant = _parsear_celda(String(clave))
		if celda == null:
			continue
		var datos: Variant = tile_data[clave]
		var flags: int = int((datos as Dictionary).get("flags", 0)) if datos is Dictionary else 0
		var c: Vector2i = celda
		if flags & TPTileDataMap.MASCARA_PUENTE:
			if layer_id < 1:
				puente_en_capa_0.append(c)
			if comprobar_rect and not rect_celdas.has_point(c):
				puente_fuera.append(c)
		if layer_id >= 1 and flags & MASCARA_EFECTOS_AGUA_CAPA_0:
			agua_elevada.append(c)
		if (flags & _SURF_CAPA_SUPERIOR) == _SURF_CAPA_SUPERIOR:
			surf_capa_superior.append(c)

	var avisos := PackedStringArray()
	if not puente_en_capa_0.is_empty():
		avisos.append("Capa de datos %d: PUENTE_* solo vale en capas elevadas (layer_id >= 1); %s." % [
			layer_id, _describir(puente_en_capa_0)])
	if not puente_fuera.is_empty():
		avisos.append("Capa de datos %d: PUENTE_* fuera del rectángulo del mapa %s; %s." % [
			layer_id, rect_celdas, _describir(puente_fuera)])
	if not agua_elevada.is_empty():
		avisos.append("Capa de datos %d: REFLEJO/AGUA_SALPICA/AGUA_PIES en una capa elevada se ignoran (los efectos de agua son solo de la capa 0); %s." % [
			layer_id, _describir(agua_elevada)])
	if not surf_capa_superior.is_empty():
		avisos.append("Capa de datos %d: SURF y CAPA_SUPERIOR en la misma celda; %s." % [
			layer_id, _describir(surf_capa_superior)])
	return avisos


## validar_banderas() de un TPTileDataMap.
static func validar_capa_datos(capa: TPTileDataMap, rect_celdas: Rect2i = Rect2i()) -> PackedStringArray:
	if capa == null:
		return PackedStringArray()
	return validar_banderas(capa.tile_data, capa.layer_id, rect_celdas)


## Rectángulo del mapa en celdas, leído del VisibleOnScreenEnabler2D hijo del mapa
## (los exteriores lo tienen; sin él, Rect2i vacío). No depende de _ready.
static func rect_celdas_de_mapa(mapa: Node) -> Rect2i:
	if mapa == null:
		return Rect2i()
	var enabler := mapa.get_node_or_null("VisibleOnScreenEnabler2D") as VisibleOnScreenNotifier2D
	if enabler == null or not enabler.rect.has_area():
		return Rect2i()
	var rect: Rect2 = enabler.rect
	var inicio := Vector2i(floori(rect.position.x / TAMANO_TILE), floori(rect.position.y / TAMANO_TILE))
	var fin := Vector2i(ceili(rect.end.x / TAMANO_TILE), ceili(rect.end.y / TAMANO_TILE))
	return Rect2i(inicio, fin - inicio)


# ---------------------------------------------------------------------------
# Piezas de CapasAgua
# ---------------------------------------------------------------------------

## Avisos de una CapasAgua (solo de las piezas activas).
static func validar_capas_agua(capas: CapasAgua) -> PackedStringArray:
	var avisos := PackedStringArray()
	if capas == null:
		return avisos
	var padre: Node = capas.get_parent()
	if padre != null:
		if capas.obtener_capa_agua() == null:
			avisos.append("CapasAgua debe ir inmediatamente después de la TileMapLayer del agua (Agua).")
		for indice: int in range(capas.get_index()):
			var hermano: Node = padre.get_child(indice)
			if hermano is TileMapLayer and es_capa_de_tierra(String(hermano.name)):
				avisos.append("La capa '%s' va antes de CapasAgua: las capas de tierra deben dibujarse después del agua." % hermano.name)
	if capas.position != Vector2.ZERO:
		avisos.append("CapasAgua debe estar en (0, 0): las nubes, la sombra y los reflejos usan las celdas del mapa.")

	if capas.necesita_backbuffer() and not CapasAgua.backbuffer_activo(capas.obtener_backbuffer()):
		avisos.append("El canal de clima o el reflejo opaco necesitan el BackBufferCopy del agua y no está activo.")

	avisos.append_array(_validar_hijos(capas))

	if capas.sombra_activa():
		var agua := capas.obtener_capa_agua()
		var sombra := capas.obtener_capa_sombra_puente()
		if agua != null and sombra.tile_set != agua.tile_set:
			avisos.append("La sombra de puente '%s' usa un tile_set distinto al de '%s'." % [sombra.name, agua.name])

	if capas.reflejos:
		avisos.append_array(_validar_datos_reflejos(capas))
	return avisos


## true si `nombre` es de una capa de tierra (Suelo, Tierra…).
static func es_capa_de_tierra(nombre: String) -> bool:
	var minusculas := nombre.to_lower()
	for prefijo: String in PREFIJOS_CAPAS_TIERRA:
		if minusculas.begins_with(prefijo):
			return true
	return false


## Orden y tipos de los hijos visibles: TileMapLayer (sombra) antes que el
## ReflexionesAgua, y como mucho un ReflexionesAgua.
static func _validar_hijos(capas: CapasAgua) -> PackedStringArray:
	var avisos := PackedStringArray()
	var reflexiones_vistas: int = 0
	for hijo: Node in capas.get_children():
		if hijo is ReflexionesAgua:
			reflexiones_vistas += 1
		elif hijo is TileMapLayer and reflexiones_vistas > 0:
			avisos.append("La TileMapLayer '%s' va después del AguaFX: en ejecución se reordena, pero conviene ponerla antes." % hijo.name)
	if reflexiones_vistas > 1:
		avisos.append("CapasAgua tiene %d nodos ReflexionesAgua: solo se usa el primero." % reflexiones_vistas)
	if reflexiones_vistas > 0 and not capas.reflejos:
		avisos.append("Hay un AguaFX hijo pero 'reflejos' está desactivado: no se dibujará.")
	return avisos


## Con `reflejos` activo, la capa de datos 0 debe existir y tener alguna celda
## REFLEJO o AGUA_SALPICA; si no, AguaFX no hace nada.
static func _validar_datos_reflejos(capas: CapasAgua) -> PackedStringArray:
	var avisos := PackedStringArray()
	var tp: TPTileDataMap = null
	var hija := capas.obtener_reflexiones_hija()
	if hija != null and hija.tp_tile_data_map != null:
		tp = hija.tp_tile_data_map
	else:
		var mapa := mapa_ancestro(capas)
		if mapa != null:
			tp = mapa.get_capa_por_id(0)
	if tp == null:
		avisos.append("'reflejos' está activo pero el mapa no tiene capa de datos 0 (TPTileDataMap).")
	elif not capa_tiene_alguna_bandera(tp, MASCARA_EFECTOS_AGUA):
		avisos.append("'reflejos' está activo pero la capa de datos 0 no tiene ninguna celda REFLEJO ni AGUA_SALPICA: desactívalo si el mapa solo tiene mar (SURF).")
	return avisos


## true si alguna celda de `capa` tiene alguno de los bits de `mascara`.
static func capa_tiene_alguna_bandera(capa: TPTileDataMap, mascara: int) -> bool:
	for datos: Variant in capa.tile_data.values():
		if datos is Dictionary and int((datos as Dictionary).get("flags", 0)) & mascara:
			return true
	return false


# ---------------------------------------------------------------------------
# Celdas REFLEJO / AGUA_SALPICA sin AguaFX que las dibuje
# ---------------------------------------------------------------------------

## true si la capa de datos 0 del mapa tiene celdas REFLEJO o AGUA_SALPICA pero
## nada las dibuja: sin CapasAgua (ni AguaFX suelto de mapa sin migrar) o con su
## `reflejos` desactivado. No usa obtener_reflexiones(): en el editor CapasAgua
## no crea su AguaFX interno.
static func faltan_efectos_agua(mapa: MapaConfiguracion) -> bool:
	if mapa == null:
		return false
	var tp := mapa.get_capa_por_id(0)
	if tp == null or not capa_tiene_alguna_bandera(tp, MASCARA_EFECTOS_AGUA):
		return false
	var capas := mapa.obtener_capas_agua()
	if capas != null:
		return not capas.reflejos
	return mapa.get_node_or_null(String(CapasAgua.NOMBRE_REFLEXIONES)) == null


## Aviso de faltan_efectos_agua() (vacío si no falta nada).
static func validar_efectos_agua(mapa: MapaConfiguracion) -> PackedStringArray:
	var avisos := PackedStringArray()
	if not faltan_efectos_agua(mapa):
		return avisos
	if mapa.obtener_capas_agua() != null:
		avisos.append("La capa de datos 0 tiene celdas REFLEJO/AGUA_SALPICA pero CapasAgua tiene 'reflejos' desactivado: no se verán los reflejos ni las ondas.")
	else:
		avisos.append("La capa de datos 0 tiene celdas REFLEJO/AGUA_SALPICA pero el mapa no tiene CapasAgua: no se verán los reflejos ni las ondas. Insértala desde el panel de TPTileDataMap o instancia capas_agua.tscn justo después de '%s'." % NOMBRE_CAPA_AGUA)
	return avisos


## TileMapLayer del agua del mapa (hija directa `Agua`), o null.
static func capa_agua_de_mapa(mapa: Node) -> TileMapLayer:
	if mapa == null:
		return null
	return mapa.get_node_or_null(NOMBRE_CAPA_AGUA) as TileMapLayer


# ---------------------------------------------------------------------------
# Mapas sin migrar (nodos sueltos AguaFX / BackBufferAgua / AnclaClimaMundo)
# ---------------------------------------------------------------------------

## Avisos de un mapa que aún usa los nodos sueltos por nombre (sin CapasAgua).
static func validar_mapa_sin_capas(mapa: Node) -> PackedStringArray:
	var avisos := PackedStringArray()
	if mapa == null:
		return avisos
	var copia := mapa.get_node_or_null(String(CapasAgua.NOMBRE_BACKBUFFER)) as BackBufferCopy
	var ancla := mapa.get_node_or_null(String(CapasAgua.NOMBRE_ANCLA))
	var agua_fx := mapa.get_node_or_null(String(CapasAgua.NOMBRE_REFLEXIONES))
	var sombra := mapa.get_node_or_null("SombraPuente")
	if copia == null and ancla == null and agua_fx == null and sombra == null:
		return avisos
	avisos.append("Mapa sin migrar: sustituye AguaFX/BackBufferAgua/AnclaClimaMundo/SombraPuente por una instancia de capas_agua.tscn tras la capa Agua.")
	if ancla != null and not CapasAgua.backbuffer_activo(copia):
		avisos.append("AnclaClimaMundo sin BackBufferAgua activo: las nubes no tendrán la copia del agua.")
	if copia != null and agua_fx != null and copia.get_index() > agua_fx.get_index():
		avisos.append("BackBufferAgua va después de AguaFX: la copia incluiría los reflejos.")
	return avisos


# ---------------------------------------------------------------------------
# Auxiliares
# ---------------------------------------------------------------------------

static func mapa_ancestro(nodo: Node) -> MapaConfiguracion:
	var actual: Node = nodo.get_parent()
	while actual != null:
		if actual is MapaConfiguracion:
			return actual as MapaConfiguracion
		actual = actual.get_parent()
	return null


static func _parsear_celda(clave: String) -> Variant:
	var partes := clave.split(",")
	if partes.size() != 2 or not partes[0].strip_edges().is_valid_int() or not partes[1].strip_edges().is_valid_int():
		return null
	return Vector2i(partes[0].strip_edges().to_int(), partes[1].strip_edges().to_int())


## "N celdas, p. ej. (x, y), …" con como mucho MAX_EJEMPLOS ejemplos ordenados.
static func _describir(celdas: Array[Vector2i]) -> String:
	var ordenadas: Array[Vector2i] = celdas.duplicate()
	ordenadas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var ejemplos := PackedStringArray()
	for indice: int in range(mini(ordenadas.size(), MAX_EJEMPLOS)):
		ejemplos.append(str(ordenadas[indice]))
	var resto: String = ", …" if ordenadas.size() > MAX_EJEMPLOS else ""
	return "%d celda(s): %s%s" % [ordenadas.size(), ", ".join(ejemplos), resto]
