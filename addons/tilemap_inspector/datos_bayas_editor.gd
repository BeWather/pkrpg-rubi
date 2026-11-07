@tool
extends RefCounted

## Datos de las bayas para las herramientas del editor (selector de `baya_inicial`
## del árbol de bayas y su galería). Todo sale del enum ControladorBaya.ENBayas
## (nombre = nombre del .tres, valor = id en la tabla Objetos) y de los sprites:
## no consulta poke.db, así el inspector no abre la base de datos.
##
## El número de baya (el de la BAYADEX / ficha_baya) es la posición del id en el
## enum ordenado: los ids de Objetos siguen el orden de Gen III (ZREZA = 1 …
## ENIGMA = 43).

## Se carga al usarse (no con preload): así el inspector no depende de que el
## script del árbol, que usa autoloads, compile.
const RUTA_SCRIPT_BAYA := "res://graficos/bayas/controlador_baya.gd"

const RUTA_SPRITES := "res://graficos/bayas/%s.tres"
## Iconos del fruto: 8 por fila de 48x48, el frame N es la baya número N (0 vacío).
const RUTA_ICONOS_FRUTO := "res://UI/ficha-baya/bayas-43.png"
const TAM_ICONO_FRUTO := 48
const COLUMNAS_ICONOS_FRUTO := 8

## Animaciones del SpriteFrames por etapa (PLANTADA … FRUTO).
const ANIM_ETAPAS: Array[StringName] = [&"1_plantada", &"2_brote", &"3_tallo", &"4_flor", &"5_fruto"]
const ANIM_FRUTO: StringName = &"5_fruto"

static var _lista: Array[Dictionary] = []
static var _por_valor: Dictionary = {}
static var _cache_frames: Dictionary = {}
static var _cache_iconos: Dictionary = {}


## Bayas ordenadas por número. Cada entrada: {clave ("BAYA_ZIDRA"), valor (id en
## Objetos), numero (1-43), nombre ("ZIDRA"), ruta (.tres del árbol)}.
static func lista() -> Array[Dictionary]:
	if _lista.is_empty():
		var script := load(RUTA_SCRIPT_BAYA) as Script
		var enum_bayas: Dictionary = script.get_script_constant_map().get("ENBayas", {}) if script != null else {}
		if enum_bayas.is_empty():
			push_warning("[📦 PKRPG] No se pudo leer ENBayas de %s" % RUTA_SCRIPT_BAYA)
		var valores: Array = enum_bayas.values()
		valores.sort()
		for i: int in valores.size():
			var valor: int = valores[i]
			var clave: String = enum_bayas.find_key(valor)
			var entrada := {
				"clave": clave,
				"valor": valor,
				"numero": i + 1,
				"nombre": clave.trim_prefix("BAYA_"),
				"ruta": RUTA_SPRITES % clave,
			}
			_lista.append(entrada)
			_por_valor[valor] = entrada
	return _lista

## Entrada de la baya con ese id (vacía si el valor no está en el enum).
static func buscar(valor: int) -> Dictionary:
	lista()
	return _por_valor.get(valor, {})

## "Nº06 ARANJA".
static func texto(entrada: Dictionary) -> String:
	if entrada.is_empty():
		return ""
	return "Nº%02d %s" % [int(entrada.numero), str(entrada.nombre)]

## SpriteFrames del árbol (null si falta el .tres).
static func frames(entrada: Dictionary) -> SpriteFrames:
	if entrada.is_empty():
		return null
	var ruta: String = entrada.ruta
	if not _cache_frames.has(ruta):
		_cache_frames[ruta] = load(ruta) as SpriteFrames if ResourceLoader.exists(ruta) else null
	return _cache_frames[ruta]

## Primer frame del árbol en esa etapa (16x32).
static func miniatura_arbol(entrada: Dictionary, animacion: StringName = ANIM_FRUTO) -> Texture2D:
	var sf := frames(entrada)
	if sf == null or not sf.has_animation(animacion) or sf.get_frame_count(animacion) == 0:
		return null
	return sf.get_frame_texture(animacion, 0)

## Todos los frames del árbol en esa etapa (para animar la vista previa).
static func frames_etapa(entrada: Dictionary, animacion: StringName = ANIM_FRUTO) -> Array[Texture2D]:
	var texturas: Array[Texture2D] = []
	var sf := frames(entrada)
	if sf == null or not sf.has_animation(animacion):
		return texturas
	for i: int in sf.get_frame_count(animacion):
		texturas.append(sf.get_frame_texture(animacion, i))
	return texturas

static func velocidad_etapa(entrada: Dictionary, animacion: StringName = ANIM_FRUTO) -> float:
	var sf := frames(entrada)
	if sf == null or not sf.has_animation(animacion):
		return 0.0
	return sf.get_animation_speed(animacion)

## Icono del fruto (48x48) de la hoja de la BAYADEX.
static func icono_fruto(entrada: Dictionary) -> Texture2D:
	if entrada.is_empty():
		return null
	var numero: int = entrada.numero
	if not _cache_iconos.has(numero):
		var hoja := load(RUTA_ICONOS_FRUTO) as Texture2D if ResourceLoader.exists(RUTA_ICONOS_FRUTO) else null
		var icono: AtlasTexture = null
		if hoja != null:
			icono = AtlasTexture.new()
			icono.atlas = hoja
			icono.region = Rect2(
				(numero % COLUMNAS_ICONOS_FRUTO) * TAM_ICONO_FRUTO,
				floori(numero / float(COLUMNAS_ICONOS_FRUTO)) * TAM_ICONO_FRUTO,
				TAM_ICONO_FRUTO, TAM_ICONO_FRUTO)
		_cache_iconos[numero] = icono
	return _cache_iconos[numero]
