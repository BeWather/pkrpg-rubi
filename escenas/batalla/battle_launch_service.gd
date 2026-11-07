extends RefCounted
class_name BattleLaunchService
## Etapa 1 (SDD 2026-09-15-battle-launch-service): dueño compartido de la
## tabla tema->texturas de fondo/suelo, la tabla tema_frente->textura, y la
## derivación tema_grafico -> tema_grafico_frente. Antes duplicadas entre
## batalla.gd (canónico) y configuracion_debug_batalla.gd/ventana_debug_batalla.gd
## (réplicas manuales); ver proposal.md/design.md de este cambio.
##
## `extends RefCounted` + miembros estáticos, sin autoload nuevo — mismo
## estilo que DatosInicioBatalla. Stateless: `resolver_tema_grafico_frente()`
## es una función pura de su parámetro (antes leía `self.datos_batalla` en
## batalla.gd).

## Copiado verbatim de batalla.gd:116-209.
const MAPEO_TEMAS_TEXTURAS: Dictionary = {
	Singleton.TemaBatalla.NO_TIENE: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_01.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_01.png"
	},
	Singleton.TemaBatalla.HIERBA_ALTA: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_02.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_02.png"
	},
	Singleton.TemaBatalla.HIERBA_MUY_ALTA: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_03.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_03.png"
	},
	Singleton.TemaBatalla.ARENA: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_04.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_04.png"
	},
	Singleton.TemaBatalla.AGUA: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_05.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_05.png"
	},
	Singleton.TemaBatalla.AGUA_KYOGRE: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_06.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_06.png"
	},
	Singleton.TemaBatalla.BAJO_AGUA: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_07.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_07.png"
	},
	Singleton.TemaBatalla.AGUA_PANTANOSA: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_08.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_08.png"
	},
	Singleton.TemaBatalla.MONTAÑA: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_09.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_09.png"
	},
	Singleton.TemaBatalla.CUEVA: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_10.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_10.png"
	},
	Singleton.TemaBatalla.CUEVA_GROUDON: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_11.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_11.png"
	},
	Singleton.TemaBatalla.EDIFICIO_1: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_12.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_12.png"
	},
	Singleton.TemaBatalla.EDIFICIO_2: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_13.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_13.png"
	},
	Singleton.TemaBatalla.EDIFICIO_3: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_14.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_14.png"
	},
	Singleton.TemaBatalla.CIELO: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_15.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_15.png"
	},
	Singleton.TemaBatalla.ESTADIO_1: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_16.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_16.png"
	},
	Singleton.TemaBatalla.ESTADIO_2: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_17.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_17.png"
	},
	Singleton.TemaBatalla.ESTADIO_3: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_18.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_18.png"
	},
	Singleton.TemaBatalla.ESTADIO_4: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_18.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_19.png"
	},
	Singleton.TemaBatalla.ESTADIO_5: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_18.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_20.png"
	},
	Singleton.TemaBatalla.ESTADIO_6: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_18.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_21.png"
	},
	Singleton.TemaBatalla.ESTADIO_7: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_22.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_22.png"
	},
	Singleton.TemaBatalla.ESTADIO_8: {
		"fondo": "res://graficos/batalla/temas/batalla_fondo_23.png",
		"suelo": "res://graficos/batalla/temas/batalla_suelo_23.png"
	}
}

## Copiado verbatim de batalla.gd:210-221.
const MAPEO_TEMAS_TEXTURAS_FRENTE: Dictionary = {
	Singleton.TemaBatallaFrente.BASICO: "res://graficos/batalla/temas/btFrente1.png",
	Singleton.TemaBatallaFrente.HIERBA_ALTA: "res://graficos/batalla/temas/btFrente2.png",
	Singleton.TemaBatallaFrente.HIERBA_MUY_ALTA: "res://graficos/batalla/temas/btFrente3.png",
	Singleton.TemaBatallaFrente.ARENA: "res://graficos/batalla/temas/btFrente4.png",
	Singleton.TemaBatallaFrente.ROCA: "res://graficos/batalla/temas/btFrente5.png",
	Singleton.TemaBatallaFrente.BURBUJAS: "res://graficos/batalla/temas/btFrente6.png",
	Singleton.TemaBatallaFrente.AGUA_BAJA: "res://graficos/batalla/temas/btFrente7.png",
	Singleton.TemaBatallaFrente.AGUA_PROFUNDA: "res://graficos/batalla/temas/btFrente8.png",
	Singleton.TemaBatallaFrente.MONTAÑA: "res://graficos/batalla/temas/btFrente9.png",
	Singleton.TemaBatallaFrente.CIELO: "res://graficos/batalla/temas/btFrente10.png"
}

## Generalizado de batalla.gd::_resolver_tema_grafico_frente(): mismo match de
## 11 ramas, mismos valores de retorno, pero como función pura de `tema_grafico`
## en vez de leer `self.datos_batalla.get("tema_grafico", ...)`. El llamador
## ahora provee ese valor explícitamente.
static func resolver_tema_grafico_frente(tema_grafico: Singleton.TemaBatalla) -> Singleton.TemaBatallaFrente:
	match tema_grafico:
		Singleton.TemaBatalla.HIERBA_ALTA:
			return Singleton.TemaBatallaFrente.HIERBA_ALTA
		Singleton.TemaBatalla.HIERBA_MUY_ALTA:
			return Singleton.TemaBatallaFrente.HIERBA_MUY_ALTA
		Singleton.TemaBatalla.ARENA:
			return Singleton.TemaBatallaFrente.ARENA
		Singleton.TemaBatalla.AGUA:
			return Singleton.TemaBatallaFrente.AGUA_BAJA
		Singleton.TemaBatalla.AGUA_KYOGRE, Singleton.TemaBatalla.BAJO_AGUA, Singleton.TemaBatalla.AGUA_PANTANOSA:
			return Singleton.TemaBatallaFrente.AGUA_PROFUNDA
		Singleton.TemaBatalla.MONTAÑA:
			return Singleton.TemaBatallaFrente.MONTAÑA
		Singleton.TemaBatalla.CUEVA, Singleton.TemaBatalla.CUEVA_GROUDON:
			return Singleton.TemaBatallaFrente.ROCA
		Singleton.TemaBatalla.CIELO:
			return Singleton.TemaBatallaFrente.CIELO
		_:
			return Singleton.TemaBatallaFrente.BASICO

## Terreno (EscenarioBatalla.Terreno) aproximado de un tema gráfico legado, para
## la animación de la tira de entrada cuando los datos no traen escenario ni
## terreno. Lo que no tiene equivalente claro (NO_TIENE, CIELO) → LLANURA.
static func terreno_desde_tema(tema_grafico: int) -> EscenarioBatalla.Terreno:
	match tema_grafico:
		Singleton.TemaBatalla.HIERBA_ALTA:
			return EscenarioBatalla.Terreno.HIERBA_ALTA
		Singleton.TemaBatalla.HIERBA_MUY_ALTA:
			return EscenarioBatalla.Terreno.HIERBA_LARGA
		Singleton.TemaBatalla.ARENA:
			return EscenarioBatalla.Terreno.ARENA
		Singleton.TemaBatalla.AGUA, Singleton.TemaBatalla.AGUA_KYOGRE:
			return EscenarioBatalla.Terreno.AGUA
		Singleton.TemaBatalla.BAJO_AGUA:
			return EscenarioBatalla.Terreno.BAJO_AGUA
		Singleton.TemaBatalla.AGUA_PANTANOSA:
			return EscenarioBatalla.Terreno.ESTANQUE
		Singleton.TemaBatalla.MONTAÑA:
			return EscenarioBatalla.Terreno.MONTANA
		Singleton.TemaBatalla.CUEVA, Singleton.TemaBatalla.CUEVA_GROUDON:
			return EscenarioBatalla.Terreno.CUEVA
		Singleton.TemaBatalla.EDIFICIO_1, Singleton.TemaBatalla.EDIFICIO_2, Singleton.TemaBatalla.EDIFICIO_3, \
				Singleton.TemaBatalla.ESTADIO_1, Singleton.TemaBatalla.ESTADIO_2, Singleton.TemaBatalla.ESTADIO_3, \
				Singleton.TemaBatalla.ESTADIO_4, Singleton.TemaBatalla.ESTADIO_5, Singleton.TemaBatalla.ESTADIO_6, \
				Singleton.TemaBatalla.ESTADIO_7, Singleton.TemaBatalla.ESTADIO_8:
			return EscenarioBatalla.Terreno.EDIFICIO
	return EscenarioBatalla.Terreno.LLANURA


## Terreno efectivo de unos datos de batalla (diccionario de
## DatosInicioBatalla.a_diccionario): `terreno` si viene; si no, el deducido del
## escenario o, sin escenario, del tema gráfico legado.
static func resolver_terreno_datos(datos: Dictionary) -> EscenarioBatalla.Terreno:
	var terreno := int(datos.get("terreno", DatosInicioBatalla.TERRENO_NINGUNO))
	if terreno >= 0 and terreno < EscenarioBatalla.IDS_TERRENO.size():
		return terreno as EscenarioBatalla.Terreno
	var escenario := str(datos.get("escenario", ""))
	if not escenario.is_empty():
		return EscenarioBatalla.terreno_de_escenario(escenario)
	return terreno_desde_tema(int(datos.get("tema_grafico", Singleton.TemaBatalla.NO_TIENE)))


## Tema musical de reserva cuando ninguna fuente resuelve una música válida.
const TEMA_MUSICA_BATALLA_DEFECTO: String = "BATALLA_SALVAJE_1"
const TEMA_MUSICA_ENTRENADOR_DEFECTO: String = "BATALLA_ENTRENADOR_1"

## Resuelve qué tema musical debe sonar en una batalla, dada la misma prioridad
## que usaban por separado (y de forma duplicada) el flujo real de juego y el
## lanzador de depuración: música explícita (la propia del entrenador, o una
## anulación manual como config.musica_id en el lanzador de depuración) tiene
## prioridad sobre la música de batalla configurada en el mapa; si ninguna de
## las dos está registrada en Singleton.TEMAS_REGISTRADOS, se usa
## TEMA_MUSICA_BATALLA_DEFECTO ("BATALLA_SALVAJE_1") como último recurso.
##
## Antes duplicado entre Singleton.reproducir_tema_batalla_mapa()
## (scripts/singleton.gd, solo consideraba la música del mapa) y
## escenas/batalla/debug/lanzador_debug_batalla.gd::_reproducir_musica()
## (consideraba config.musica_id y la música del entrenador). Ambos llamadores
## ahora delegan la resolución en esta función; la reproducción en sí sigue
## siendo dos caminos distintos (Singleton.reproducir_tema() a través del
## ReproductorMusica de AdministradorMapa vs. un NuevoAudioStreamPlayer propio
## del lanzador de depuración) porque el lanzador de depuración no tiene un
## AdministradorMapa vivo en el árbol (ver cabecera de lanzador_debug_batalla.gd).
static func resolver_tema_musica_batalla(musica_preferida: String = "", musica_mapa: String = "") -> String:
	if _es_tema_valido(musica_preferida):
		return musica_preferida
	return resolver_musica_salvaje(musica_mapa)


static func resolver_musica_salvaje(musica_mapa: String = "") -> String:
	if _es_tema_valido(musica_mapa):
		return musica_mapa
	return TEMA_MUSICA_BATALLA_DEFECTO


## Tema musical de un combate contra entrenador.
##
## Prioridad, como en la ROM: primero una anulación manual explícita; si no,
## el tema se DERIVA de la clase del entrenador (GetMUS_ForBattle en el decomp:
## no está en los datos del entrenador, sale de su clase); y por último la
## música de batalla del mapa. `entrenador` puede ser null.
static func resolver_musica_entrenador(
	entrenador,
	musica_mapa: String = "",
	override_manual: String = ""
) -> String:
	if _es_tema_valido(override_manual):
		return override_manual
	if entrenador != null:
		var por_clase := MusicaRubi.tema_batalla(
			str(entrenador.clase_entrenador),
			MusicaRubi.es_rival(str(entrenador.nombre)))
		if _es_tema_valido(por_clase):
			return por_clase
		# `musica_id` del registro es un override previsto por el autor del mapa.
		if _es_tema_valido(str(entrenador.musica_id)):
			return str(entrenador.musica_id)
	if _es_tema_valido(musica_mapa):
		return musica_mapa
	return TEMA_MUSICA_ENTRENADOR_DEFECTO


static func _es_tema_valido(tema: String) -> bool:
	return not tema.is_empty() and tema != "Por defecto" and Singleton.TEMAS_REGISTRADOS.has(tema)
