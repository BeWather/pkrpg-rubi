class_name Buceo
extends RefCounted

## BUCEO (MO08, MOVE_DIVE) en el overworld: a qué mapa y celda lleva sumergirse o
## emerger desde una celda. Es la parte pura de TrySetDiveWarp / SetDiveWarp
## (field_control_avatar.c y overworld.c de pokeruby); la interacción (pregunta,
## animación, warp y avatar submarino) vive en character.gd y administrador_mapa.gd.
##
## Reglas de Rubí:
##   - Bajar: el jugador hace surf sobre una casilla buceable (bandera BUCEO =
##     MB_SEMI_DEEP_WATER / MB_UNUSED_DEEP_WATER / MB_SOOTOPOLIS_DEEP_WATER). Se mira
##     su propia casilla, no la de enfrente. Se llega a `mapa_inmersion` en la misma
##     coordenada (conexión `dive`) o en `celda_inmersion_fija` (`setdivewarp`).
##   - Subir: en un mapa `mapa_submarino`, desde cualquier casilla sin NO_EMERGER
##     (MB_NO_SURFACING / MB_SEAWEED_NO_SURFACING) se llega a `mapa_emersion` en la
##     misma coordenada (conexión `emerge`) o en `celda_emersion_fija`.
##   - En un mapa submarino nunca se baja (el `else if` de TrySetDiveWarp): una
##     casilla NO_EMERGER no da BUCEO aunque fuera buceable.
##
## Mapas de superficie con `setdivewarp` en su cabecera: la entrada de la CAVERNA ABISAL
## (caverna_abisal_entrada, herramientas/importar_caverna_abisal.py: mapa_inmersion =
## "bajo_agua_caverna_abisal", celda fija (6, 5), banderas BUCEO en su agua) y la sala
## exterior de la CÁMARA SELLADA (camara_sellada_exterior, herramientas/importar_camara_sellada.py).

enum Tipo {
	NINGUNO = 0,	## TrySetDiveWarp() == 0
	EMERGER = 1,	## TrySetDiveWarp() == 1 (S_UseDiveUnderwater)
	SUMERGIRSE = 2,	## TrySetDiveWarp() == 2 (UseDiveScript)
}

## Celda "sin celda fija" de los exports de MapaConfiguracion.
const SIN_CELDA_FIJA: Vector2i = Vector2i(-1, -1)

## Underwater_SealedChamber_MapScript1_15F086 (MAP_SCRIPT_ON_DIVE_WARP): desde la
## casilla (12, 44) de la CÁMARA SELLADA submarina se emerge dentro de la sala
## exterior de la CÁMARA SELLADA (SEALED_CHAMBER_OUTER_ROOM, 10, 19); desde el
## resto, en la RUTA 134 (60, 31), que es lo que configura la escena. Es el único
## `setdivewarp` condicional del juego, así que se resuelve aquí y no en un export.
const CLAVE_CAMARA_SELLADA_SUBMARINA: String = "bajo_agua_camara_sellada"
const CELDA_CAMARA_SELLADA_INTERIOR: Vector2i = Vector2i(12, 44)
## SealedChamber_OuterRoom (escenas/mapas/camara-sellada/).
const MAPA_CAMARA_SELLADA_EXTERIOR: String = "camara_sellada_exterior"
const CELDA_CAMARA_SELLADA_EXTERIOR: Vector2i = Vector2i(10, 19)


## TrySetDiveWarp sin efectos: qué haría BUCEO en `celda` del mapa `mapa` con
## las banderas de `tp`. No comprueba medalla, Pokémon ni que el destino exista.
static func tipo_en_celda(mapa: MapaConfiguracion, tp: TPTileDataMap, celda: Vector2i) -> int:
	return int(destino(mapa, tp, celda).get("tipo", Tipo.NINGUNO))


## Destino de BUCEO desde `celda`: {"tipo": Tipo, "mapa": String, "celda": Vector2i}.
## Con Tipo.NINGUNO no lleva "mapa" ni "celda".
static func destino(mapa: MapaConfiguracion, tp: TPTileDataMap, celda: Vector2i) -> Dictionary:
	var ninguno := {"tipo": Tipo.NINGUNO}
	if mapa == null:
		return ninguno
	var flags: int = tp.get_flags(Vector2(celda)) if tp != null else 0
	if mapa.mapa_submarino:
		if flags & TPTileDataMap.Flags.NO_EMERGER:
			return ninguno
		var emersion := _destino_emersion(mapa, celda)
		if emersion.is_empty():
			return ninguno
		emersion["tipo"] = Tipo.EMERGER
		return emersion
	if not (flags & TPTileDataMap.Flags.BUCEO) or mapa.mapa_inmersion.is_empty():
		return ninguno
	return {
		"tipo": Tipo.SUMERGIRSE,
		"mapa": mapa.mapa_inmersion,
		"celda": _celda_destino(celda, mapa.celda_inmersion_fija),
	}


## SetDiveWarpEmerge + el map script de la CÁMARA SELLADA. {} si no hay superficie.
static func _destino_emersion(mapa: MapaConfiguracion, celda: Vector2i) -> Dictionary:
	if es_camara_sellada_submarina(mapa) and celda == CELDA_CAMARA_SELLADA_INTERIOR:
		return {"mapa": MAPA_CAMARA_SELLADA_EXTERIOR, "celda": CELDA_CAMARA_SELLADA_EXTERIOR}
	if mapa.mapa_emersion.is_empty():
		return {}
	return {"mapa": mapa.mapa_emersion, "celda": _celda_destino(celda, mapa.celda_emersion_fija)}


static func es_camara_sellada_submarina(mapa: MapaConfiguracion) -> bool:
	if mapa == null:
		return false
	var clave := mapa.scene_file_path.get_file().get_basename()
	if clave.is_empty():
		clave = mapa.nombre_interno
	return clave == CLAVE_CAMARA_SELLADA_SUBMARINA


static func _celda_destino(celda: Vector2i, fija: Vector2i) -> Vector2i:
	return celda if fija == SIN_CELDA_FIJA else fija


## ¿Se llega haciendo surf al emerger en `celda` del mapa `mapa`? Como
## GetAdjustedInitialTransitionFlags: surf si la casilla es agua surfeable. Los
## exteriores marinos aún no tienen pintada la bandera SURF de todo su mar, así que
## en un exterior (ni interior ni cueva) se emerge siempre surfeando: la conexión
## `emerge` y los `setdivewarp` de Rubí siempre dejan en el agua.
static func llega_surfeando(mapa: MapaConfiguracion, tp: TPTileDataMap, celda: Vector2i) -> bool:
	if mapa == null or mapa.mapa_submarino:
		return false
	if tp != null and tp.has_flag(Vector2(celda), TPTileDataMap.Flags.SURF):
		return true
	return not mapa.esInterior and not mapa.es_cueva
