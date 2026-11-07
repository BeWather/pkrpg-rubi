## clima_legendario.gd
## Sequía de GROUDON mientras FLAG_SYS_WEATHER_CTRL está activa (entre la CAVERNA ABISAL y la CUEVA ANCESTRAL;
## ver HistoriaArrecipolis). En Rubí la ponen los OnTransition de ARRECÍPOLIS, las RUTAS 124 a 128, ALGARIA, CALAGUA y
## COLOSALIA (Common_EventScript_SetLegendaryWeather: setweather WEATHER_DROUGHT) y en esos mismos mapas suena
## MUS_WEATHER_GROUDON (overworld.c, ShouldLegendaryMusicPlayAtLocation). Solo los exteriores: los interiores siguen
## con su música y su clima.
##
## Lo aplican ServicioClimaMapa.aplicar_clima_entrada (en lugar del clima de entrada del mapa) y
## MapaConfiguracion.obtener_musica_mapa_efectiva.
class_name ClimaLegendario
extends RefCounted

const BANDERA: String = "SYS_WEATHER_CTRL"
## Nombre de la escena (.tscn sin extensión) de cada mapa de Rubí que lo usa.
const MAPAS: PackedStringArray = [
	"arrecipolis", "ruta_124", "ruta_125", "ruta_126", "ruta_127", "ruta_128",
	"ciudad_algaria", "ciudad_calagua", "ciudad_colosalia",
]
const CLIMA := preload("res://recursos/clima/sol_fuerte.tres")
## MUS_WEATHER_GROUDON.
const MUSICA: String = "SEQUIA"


static func activo() -> bool:
	if Engine.is_editor_hint() or SistemaGuardado.datos_vivos == null:
		return false
	return SistemaGuardado.get_flag(BANDERA)


static func es_mapa_legendario(mapa: Node) -> bool:
	return mapa != null and MAPAS.has(mapa.scene_file_path.get_file().get_basename())


static func aplica_a(mapa: Node) -> bool:
	return es_mapa_legendario(mapa) and activo()
