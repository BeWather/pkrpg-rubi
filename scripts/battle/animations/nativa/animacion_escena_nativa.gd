extends MoveAnimation
class_name AnimacionEscenaNativa
## Adaptador fino del piloto de animaciones nativas: reproduce una escena
## `EfectoMovimientoNativo` (AnimationPlayer + Tweens) con el contrato
## `MoveAnimation` (señales impacto/finalizada). Opt-in: `MoveAnimationRegistry`
## solo lo usa con `usar_animaciones_nativas` activo (desactivado por defecto).
##
## Funciona con slots reales de batalla y con slots de prueba (el harness
## `herramientas/piloto_animaciones_nativas/`): solo necesita
## `slot_*.sprite_pokemon` dentro del árbol.

const ESCENAS: Dictionary = {
	"ruby:move/33": "res://escenas/batalla/animaciones_nativas/placaje.tscn",
	"ruby:move/53": "res://escenas/batalla/animaciones_nativas/lanzallamas.tscn",
	"ruby:move/308": "res://escenas/batalla/animaciones_nativas/hidrocanon.tscn",
	# Dos turnos: la escena elige la animación por MoveAnimationContext.source_move_turn.
	"ruby:move/13": "res://escenas/batalla/animaciones_nativas/viento_cortante.tscn",
	"ruby:move/76": "res://escenas/batalla/animaciones_nativas/rayo_solar.tscn",
	"ruby:move/130": "res://escenas/batalla/animaciones_nativas/cabezazo.tscn",
	"ruby:move/143": "res://escenas/batalla/animaciones_nativas/ataque_aereo.tscn",
	# Semiinvulnerables: la visibilidad del atacante entre turnos pasa por
	# BattleHiddenProjection (ver _proyeccion_oculta()).
	"ruby:move/19": "res://escenas/batalla/animaciones_nativas/vuelo.tscn",
	"ruby:move/91": "res://escenas/batalla/animaciones_nativas/excavar.tscn",
	"ruby:move/291": "res://escenas/batalla/animaciones_nativas/buceo.tscn",
	"ruby:move/340": "res://escenas/batalla/animaciones_nativas/bote.tscn",
	# Lote C, golpes de contacto: una escena compartida, una animación por movimiento
	# (pendientes de validar el lado rival y la batalla real por movimiento, §13).
	"ruby:move/1": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#destructor",
	"ruby:move/29": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#golpe_cabeza",
	"ruby:move/34": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#golpe_cuerpo",
	"ruby:move/36": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#derribo",
	"ruby:move/38": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#doble_filo",
	"ruby:move/64": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#picotazo",
	"ruby:move/66": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#sumision",
	"ruby:move/70": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#fuerza",
	"ruby:move/98": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#ataque_rapido",
	"ruby:move/175": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#azote",
	"ruby:move/233": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#tiro_vital",
	# Multigolpe: «<animación>_par/_impar» según el turno (choosetwoturnanim por golpe).
	"ruby:move/3": "res://escenas/batalla/animaciones_nativas/multigolpe.tscn#doble_bofeton",
	"ruby:move/4": "res://escenas/batalla/animaciones_nativas/multigolpe.tscn#puno_cometa",
	"ruby:move/31": "res://escenas/batalla/animaciones_nativas/multigolpe.tscn#ataque_furia",
	"ruby:move/292": "res://escenas/batalla/animaciones_nativas/multigolpe.tscn#empujon",
	# Golpes con sprite propio, mecánicos (generar_golpes.py con_sprite).
	"ruby:move/2": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#golpe_karate",
	"ruby:move/10": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#aranazo",
	"ruby:move/11": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#agarre",
	"ruby:move/15": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#corte",
	"ruby:move/23": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#pisoton",
	"ruby:move/24": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#doble_patada",
	"ruby:move/26": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#patada_salto",
	"ruby:move/27": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#patada_giro",
	"ruby:move/30": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#cornada",
	"ruby:move/44": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#mordisco",
	"ruby:move/67": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#patada_baja",
	"ruby:move/68": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#contraataque",
	"ruby:move/128": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#tenaza",
	"ruby:move/136": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#patada_salto_alta",
	"ruby:move/163": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#cuchillada",
	"ruby:move/206": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#falso_tortazo",
	"ruby:move/238": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#tajo_cruzado",
	"ruby:move/332": "res://escenas/batalla/animaciones_nativas/golpes_con_sprite.tscn#golpe_aereo",
	# Golpes con lógica propia, a mano con componentes de EfectoGolpeNativo.
	"ruby:move/125": "res://escenas/batalla/animaciones_nativas/golpes_propios.tscn#hueso_palo",
	"ruby:move/198": "res://escenas/batalla/animaciones_nativas/golpes_propios.tscn#ataque_oseo",
	"ruby:move/155": "res://escenas/batalla/animaciones_nativas/golpes_propios.tscn#huesomerang",
	"ruby:move/162": "res://escenas/batalla/animaciones_nativas/golpes_propios.tscn#superdiente",
	"ruby:move/232": "res://escenas/batalla/animaciones_nativas/golpes_propios.tscn#garra_metal",
	"ruby:move/22": "res://escenas/batalla/animaciones_nativas/golpes_propios.tscn#latigo_cepa",
	"ruby:move/231": "res://escenas/batalla/animaciones_nativas/golpes_propios.tscn#cola_ferrea",
	# Cambios de estadística, mecánicos (generar_golpes.py estadistica).
	"ruby:move/39": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#latigo",
	"ruby:move/97": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#agilidad",
	"ruby:move/106": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#fortaleza",
	"ruby:move/334": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#defensa_ferrea",
	"ruby:move/74": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#desarrollo",
	"ruby:move/43": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#malicioso",
	"ruby:move/204": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#encanto",
	"ruby:move/116": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#foco_energia",
	"ruby:move/294": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#ola_luz",
	"ruby:move/230": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#dulce_aroma",
	"ruby:move/28": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#ataque_arena",
	"ruby:move/178": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#esporagodon",
	"ruby:move/14": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#danza_espada",
	"ruby:move/159": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#afilar",
	"ruby:move/244": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#mas_psique",
	"ruby:move/81": "res://escenas/batalla/animaciones_nativas/estadistica.tscn#disparo_demora",
	# Cambios de estadística con lógica propia, a mano con componentes de EfectoGolpeNativo.
	"ruby:move/148": "res://escenas/batalla/animaciones_nativas/estadistica_propios.tscn#destello",
	"ruby:move/110": "res://escenas/batalla/animaciones_nativas/estadistica_propios.tscn#refugio",
	"ruby:move/339": "res://escenas/batalla/animaciones_nativas/estadistica_propios.tscn#corpulencia",
	"ruby:move/111": "res://escenas/batalla/animaciones_nativas/estadistica_propios.tscn#rizo_defensa",
	"ruby:move/104": "res://escenas/batalla/animaciones_nativas/estadistica_propios.tscn#doble_equipo",
	"ruby:move/297": "res://escenas/batalla/animaciones_nativas/estadistica_propios.tscn#danza_pluma",
	"ruby:move/112": "res://escenas/batalla/animaciones_nativas/estadistica_propios.tscn#barrera",
	# Venganza: «venganza_par» (carga, turno 0) / «venganza_impar» (golpe, turno 1).
	"ruby:move/117": "res://escenas/batalla/animaciones_nativas/golpes_turnos.tscn#venganza",
	# Familia proyectil_partículas (generar_golpes.py, EfectoProyectilNativo), un sub-lote por escena.
	"ruby:move/40": "res://escenas/batalla/animaciones_nativas/proyectiles_rectos.tscn#picotazo_veneno",
	"ruby:move/41": "res://escenas/batalla/animaciones_nativas/proyectiles_rectos.tscn#dobleataque",
	"ruby:move/42": "res://escenas/batalla/animaciones_nativas/proyectiles_rectos.tscn#pin_misil",
	"ruby:move/333": "res://escenas/batalla/animaciones_nativas/proyectiles_rectos.tscn#carambano",
	"ruby:move/131": "res://escenas/batalla/animaciones_nativas/proyectiles_rectos.tscn#clavo_canon",
	"ruby:move/331": "res://escenas/batalla/animaciones_nativas/proyectiles_rectos.tscn#recurrente",
	"ruby:move/71": "res://escenas/batalla/animaciones_nativas/drenajes.tscn#absorber",
	"ruby:move/72": "res://escenas/batalla/animaciones_nativas/drenajes.tscn#megaagotar",
	"ruby:move/202": "res://escenas/batalla/animaciones_nativas/drenajes.tscn#gigadrenado",
	"ruby:move/141": "res://escenas/batalla/animaciones_nativas/drenajes.tscn#chupavidas",
	"ruby:move/83": "res://escenas/batalla/animaciones_nativas/vortices.tscn#giro_fuego",
	"ruby:move/250": "res://escenas/batalla/animaciones_nativas/vortices.tscn#torbellino",
	"ruby:move/328": "res://escenas/batalla/animaciones_nativas/vortices.tscn#bucle_arena",
	"ruby:move/88": "res://escenas/batalla/animaciones_nativas/rocas.tscn#lanzarrocas",
	"ruby:move/157": "res://escenas/batalla/animaciones_nativas/rocas.tscn#avalancha",
	"ruby:move/342": "res://escenas/batalla/animaciones_nativas/proyectil_varios.tscn#cola_veneno",
	"ruby:move/173": "res://escenas/batalla/animaciones_nativas/proyectil_varios.tscn#ronquido",
	"ruby:move/99": "res://escenas/batalla/animaciones_nativas/proyectil_varios.tscn#furia",
	"ruby:move/283": "res://escenas/batalla/animaciones_nativas/proyectil_varios.tscn#esfuerzo",
	"ruby:move/321": "res://escenas/batalla/animaciones_nativas/proyectil_varios.tscn#cosquillas",
	"ruby:move/343": "res://escenas/batalla/animaciones_nativas/proyectil_varios.tscn#antojo",
	"ruby:move/75": "res://escenas/batalla/animaciones_nativas/hojas_estrellas.tscn#hoja_afilada",
	"ruby:move/345": "res://escenas/batalla/animaciones_nativas/hojas_estrellas.tscn#hoja_magica",
	"ruby:move/129": "res://escenas/batalla/animaciones_nativas/hojas_estrellas.tscn#rapidez",
	"ruby:move/80": "res://escenas/batalla/animaciones_nativas/hojas_estrellas.tscn#danza_petalo",
	"ruby:move/350": "res://escenas/batalla/animaciones_nativas/rocas2.tscn#pedrada",
	"ruby:move/246": "res://escenas/batalla/animaciones_nativas/rocas2.tscn#poder_pasado",
	"ruby:move/317": "res://escenas/batalla/animaciones_nativas/rocas2.tscn#tumba_rocas",
	"ruby:move/120": "res://escenas/batalla/animaciones_nativas/explosiones.tscn#autodestruccion",
	"ruby:move/153": "res://escenas/batalla/animaciones_nativas/explosiones.tscn#explosion",
	"ruby:move/6": "res://escenas/batalla/animaciones_nativas/proyectiles_arco.tscn#dia_de_pago",
	"ruby:move/121": "res://escenas/batalla/animaciones_nativas/proyectiles_arco.tscn#bomba_huevo",
	"ruby:move/191": "res://escenas/batalla/animaciones_nativas/proyectiles_arco.tscn#puas",
	# proyectil_partículas, §19 (sub-lotes de agua, eléctricos, fuego, ráfagas…)
	"ruby:move/127": "res://escenas/batalla/animaciones_nativas/agua.tscn#cascada",
	"ruby:move/152": "res://escenas/batalla/animaciones_nativas/agua.tscn#martillazo",
	"ruby:move/145": "res://escenas/batalla/animaciones_nativas/agua.tscn#burbuja",
	"ruby:move/323": "res://escenas/batalla/animaciones_nativas/agua.tscn#salpicar",
	"ruby:move/346": "res://escenas/batalla/animaciones_nativas/agua.tscn#hidrochorro",
	"ruby:move/344": "res://escenas/batalla/animaciones_nativas/electricos.tscn#placaje_electrico",
	"ruby:move/284": "res://escenas/batalla/animaciones_nativas/fuego.tscn#estallido",
	"ruby:move/209": "res://escenas/batalla/animaciones_nativas/electricos.tscn#chispa",
	"ruby:move/268": "res://escenas/batalla/animaciones_nativas/electricos.tscn#carga",
	"ruby:move/221": "res://escenas/batalla/animaciones_nativas/fuego.tscn#fuego_sagrado",
	"ruby:move/200": "res://escenas/batalla/animaciones_nativas/fuego.tscn#enfado",
	"ruby:move/189": "res://escenas/batalla/animaciones_nativas/rafagas.tscn#bofeton_lodo",
	"ruby:move/300": "res://escenas/batalla/animaciones_nativas/rafagas.tscn#chapoteo_lodo",
	"ruby:move/123": "res://escenas/batalla/animaciones_nativas/nubes.tscn#polucion",
	"ruby:move/263": "res://escenas/batalla/animaciones_nativas/casi_listos.tscn#imagen",
	"ruby:move/49": "res://escenas/batalla/animaciones_nativas/casi_listos.tscn#bomba_sonica",
	"ruby:move/304": "res://escenas/batalla/animaciones_nativas/casi_listos.tscn#vozarron",
	"ruby:move/17": "res://escenas/batalla/animaciones_nativas/golpes_sprite2.tscn#ataque_ala",
	"ruby:move/211": "res://escenas/batalla/animaciones_nativas/golpes_sprite2.tscn#ala_de_acero",
	"ruby:move/306": "res://escenas/batalla/animaciones_nativas/golpes_sprite2.tscn#garra_brutal",
	"ruby:move/337": "res://escenas/batalla/animaciones_nativas/golpes_sprite2.tscn#garra_dragon",
	"ruby:move/154": "res://escenas/batalla/animaciones_nativas/golpes_sprite2.tscn#golpes_furia",
	"ruby:move/282": "res://escenas/batalla/animaciones_nativas/golpes_sprite2.tscn#desarme",
	"ruby:move/305": "res://escenas/batalla/animaciones_nativas/golpes_sprite2.tscn#colmillo_veneno",
	"ruby:move/243": "res://escenas/batalla/animaciones_nativas/barreras.tscn#manto_espejo",
	"ruby:move/277": "res://escenas/batalla/animaciones_nativas/barreras.tscn#capa_magica",
	"ruby:move/65": "res://escenas/batalla/animaciones_nativas/golpes_varios.tscn#pico_taladro",
	"ruby:move/122": "res://escenas/batalla/animaciones_nativas/golpes_varios.tscn#lenguetazo",
	"ruby:move/165": "res://escenas/batalla/animaciones_nativas/golpes_varios.tscn#combate",
	"ruby:move/279": "res://escenas/batalla/animaciones_nativas/golpes_varios.tscn#desquite",
	"ruby:move/310": "res://escenas/batalla/animaciones_nativas/golpes_varios.tscn#impresionar",
	"ruby:move/265": "res://escenas/batalla/animaciones_nativas/golpes_varios.tscn#estimulo",
	"ruby:move/140": "res://escenas/batalla/animaciones_nativas/golpes_varios.tscn#presa",
	"ruby:move/132": "res://escenas/batalla/animaciones_nativas/golpes_varios.tscn#restriccion",
	# §34: las cinco ramas de Desenrollar por el contador (RamasNativas.sufijo); golpes_varios.tscn#desenrollar es el nivel 1.
	"ruby:move/205": "res://escenas/batalla/animaciones_nativas/variantes_desenrollar.tscn#desenrollar",
	"ruby:move/18": "res://escenas/batalla/animaciones_nativas/viento_y_fuerza.tscn#remolino",
	"ruby:move/338": "res://escenas/batalla/animaciones_nativas/viento_y_fuerza.tscn#planta_feroz",
	"ruby:move/220": "res://escenas/batalla/animaciones_nativas/viento_y_fuerza.tscn#divide_dolor",
	"ruby:move/276": "res://escenas/batalla/animaciones_nativas/viento_y_fuerza.tscn#fuerza_bruta",
	"ruby:move/314": "res://escenas/batalla/animaciones_nativas/viento_y_fuerza.tscn#aire_afilado",
	"ruby:move/161": "res://escenas/batalla/animaciones_nativas/triataque.tscn#triataque",
	# §20: otros compuestos, problemas de estado, sonido y Golpe Furioso (generar_estado.py,
	# EfectoEstadoNativo; una escena por sub-lote).
	"ruby:move/20": "res://escenas/batalla/animaciones_nativas/otros_compuestos.tscn#atadura",
	"ruby:move/35": "res://escenas/batalla/animaciones_nativas/otros_compuestos.tscn#repeticion",
	"ruby:move/89": "res://escenas/batalla/animaciones_nativas/otros_compuestos.tscn#terremoto",
	"ruby:move/150": "res://escenas/batalla/animaciones_nativas/otros_compuestos.tscn#salpicadura",
	"ruby:move/252": "res://escenas/batalla/animaciones_nativas/otros_compuestos.tscn#sorpresa",
	"ruby:move/77": "res://escenas/batalla/animaciones_nativas/polvos.tscn#polvo_veneno",
	"ruby:move/78": "res://escenas/batalla/animaciones_nativas/polvos.tscn#paralizador",
	"ruby:move/79": "res://escenas/batalla/animaciones_nativas/polvos.tscn#somnifero",
	"ruby:move/147": "res://escenas/batalla/animaciones_nativas/polvos.tscn#espora",
	"ruby:move/73": "res://escenas/batalla/animaciones_nativas/polvos.tscn#drenadoras",
	"ruby:move/92": "res://escenas/batalla/animaciones_nativas/polvos.tscn#toxico",
	"ruby:move/139": "res://escenas/batalla/animaciones_nativas/polvos.tscn#gas_venenoso",
	"ruby:move/169": "res://escenas/batalla/animaciones_nativas/polvos.tscn#telarana",
	"ruby:move/50": "res://escenas/batalla/animaciones_nativas/estado_varios.tscn#anulacion",
	"ruby:move/86": "res://escenas/batalla/animaciones_nativas/estado_varios.tscn#onda_trueno",
	"ruby:move/142": "res://escenas/batalla/animaciones_nativas/estado_varios.tscn#beso_amoroso",
	"ruby:move/186": "res://escenas/batalla/animaciones_nativas/estado_varios.tscn#beso_dulce",
	"ruby:move/170": "res://escenas/batalla/animaciones_nativas/estado_varios.tscn#telepata",
	"ruby:move/193": "res://escenas/batalla/animaciones_nativas/estado_varios.tscn#profecia",
	"ruby:move/199": "res://escenas/batalla/animaciones_nativas/estado_varios.tscn#fijar_blanco",
	"ruby:move/212": "res://escenas/batalla/animaciones_nativas/estado_varios.tscn#mal_de_ojo",
	"ruby:move/335": "res://escenas/batalla/animaciones_nativas/estado_varios.tscn#bloqueo",
	"ruby:move/261": "res://escenas/batalla/animaciones_nativas/estado_varios.tscn#fuego_fatuo",
	"ruby:move/207": "res://escenas/batalla/animaciones_nativas/burlas.tscn#contoneo",
	"ruby:move/259": "res://escenas/batalla/animaciones_nativas/burlas.tscn#tormento",
	"ruby:move/269": "res://escenas/batalla/animaciones_nativas/burlas.tscn#mofa",
	"ruby:move/281": "res://escenas/batalla/animaciones_nativas/burlas.tscn#bostezo",
	"ruby:move/316": "res://escenas/batalla/animaciones_nativas/burlas.tscn#rastreo",
	"ruby:move/45": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#grunido",
	"ruby:move/46": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#rugido",
	"ruby:move/336": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#aullido",
	"ruby:move/48": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#supersonico",
	"ruby:move/103": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#chirrido",
	"ruby:move/319": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#eco_metalico",
	"ruby:move/47": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#canto",
	"ruby:move/320": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#silbato",
	"ruby:move/187": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#tambor",
	"ruby:move/253": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#alboroto",
	"ruby:move/298": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#danza_caos",
	"ruby:move/313": "res://escenas/batalla/animaciones_nativas/sonidos.tscn#llanto_falso",
	"ruby:move/37": "res://escenas/batalla/animaciones_nativas/golpe_furioso.tscn#golpe_furioso",
	"ruby:move/105": "res://escenas/batalla/animaciones_nativas/curaciones.tscn#recuperacion",
	"ruby:move/135": "res://escenas/batalla/animaciones_nativas/curaciones.tscn#amortiguador",
	"ruby:move/208": "res://escenas/batalla/animaciones_nativas/curaciones.tscn#batido",
	"ruby:move/235": "res://escenas/batalla/animaciones_nativas/curaciones.tscn#sintesis",
	"ruby:move/236": "res://escenas/batalla/animaciones_nativas/curaciones.tscn#luz_lunar",
	"ruby:move/303": "res://escenas/batalla/animaciones_nativas/curaciones.tscn#relajo",
	"ruby:move/273": "res://escenas/batalla/animaciones_nativas/curaciones.tscn#deseo",
	"ruby:move/275": "res://escenas/batalla/animaciones_nativas/curaciones.tscn#arraigo",
	"ruby:move/156": "res://escenas/batalla/animaciones_nativas/curaciones.tscn#descanso",
	"ruby:move/54": "res://escenas/batalla/animaciones_nativas/protecciones.tscn#neblina",
	"ruby:move/113": "res://escenas/batalla/animaciones_nativas/protecciones.tscn#pantalla_luz",
	"ruby:move/115": "res://escenas/batalla/animaciones_nativas/protecciones.tscn#reflejo",
	"ruby:move/182": "res://escenas/batalla/animaciones_nativas/protecciones.tscn#proteccion",
	"ruby:move/197": "res://escenas/batalla/animaciones_nativas/protecciones.tscn#deteccion",
	"ruby:move/203": "res://escenas/batalla/animaciones_nativas/protecciones.tscn#aguante",
	"ruby:move/219": "res://escenas/batalla/animaciones_nativas/protecciones.tscn#velo_sagrado",
	"ruby:move/7": "res://escenas/batalla/animaciones_nativas/punos.tscn#puno_fuego",
	"ruby:move/8": "res://escenas/batalla/animaciones_nativas/punos.tscn#puno_hielo",
	"ruby:move/9": "res://escenas/batalla/animaciones_nativas/punos.tscn#puno_trueno",
	"ruby:move/146": "res://escenas/batalla/animaciones_nativas/punos.tscn#puno_mareo",
	"ruby:move/179": "res://escenas/batalla/animaciones_nativas/punos.tscn#inversion",
	"ruby:move/223": "res://escenas/batalla/animaciones_nativas/punos.tscn#punodinamico",
	"ruby:move/249": "res://escenas/batalla/animaciones_nativas/punos.tscn#golpe_roca",
	"ruby:move/299": "res://escenas/batalla/animaciones_nativas/punos.tscn#patada_ignea",
	"ruby:move/302": "res://escenas/batalla/animaciones_nativas/punos.tscn#brazo_pincho",
	# Demolición: «demolicion_par» (golpe) / «demolicion_impar» (rompe la pared de luz).
	"ruby:move/280": "res://escenas/batalla/animaciones_nativas/demolicion.tscn#demolicion",
	"ruby:move/240": "res://escenas/batalla/animaciones_nativas/climas.tscn#danza_lluvia",
	"ruby:move/241": "res://escenas/batalla/animaciones_nativas/climas.tscn#dia_soleado",
	"ruby:move/258": "res://escenas/batalla/animaciones_nativas/climas.tscn#granizo",
	"ruby:move/52": "res://escenas/batalla/animaciones_nativas/rayos_fuego.tscn#ascuas",
	"ruby:move/126": "res://escenas/batalla/animaciones_nativas/rayos_fuego.tscn#llamarada",
	"ruby:move/172": "res://escenas/batalla/animaciones_nativas/rayos_fuego.tscn#rueda_fuego",
	"ruby:move/82": "res://escenas/batalla/animaciones_nativas/rayos_fuego.tscn#furia_dragon",
	"ruby:move/225": "res://escenas/batalla/animaciones_nativas/rayos_fuego.tscn#dragoaliento",
	"ruby:move/307": "res://escenas/batalla/animaciones_nativas/rayos_fuego.tscn#anillo_igneo",
	"ruby:move/315": "res://escenas/batalla/animaciones_nativas/rayos_fuego.tscn#sofoco",
	"ruby:move/55": "res://escenas/batalla/animaciones_nativas/rayos_agua.tscn#pistola_agua",
	"ruby:move/56": "res://escenas/batalla/animaciones_nativas/rayos_agua.tscn#hidrobomba",
	"ruby:move/61": "res://escenas/batalla/animaciones_nativas/rayos_agua.tscn#rayo_burbuja",
	"ruby:move/352": "res://escenas/batalla/animaciones_nativas/rayos_agua.tscn#hidropulso",
	"ruby:move/341": "res://escenas/batalla/animaciones_nativas/rayos_agua.tscn#disparo_lodo",
	"ruby:move/324": "res://escenas/batalla/animaciones_nativas/rayos_agua.tscn#doble_rayo",
	"ruby:move/190": "res://escenas/batalla/animaciones_nativas/rayos_agua.tscn#pulpocanon",
	"ruby:move/84": "res://escenas/batalla/animaciones_nativas/rayos_electricos.tscn#impactrueno",
	"ruby:move/85": "res://escenas/batalla/animaciones_nativas/rayos_electricos.tscn#rayo",
	"ruby:move/192": "res://escenas/batalla/animaciones_nativas/rayos_electricos.tscn#electrocanon",
	"ruby:move/351": "res://escenas/batalla/animaciones_nativas/rayos_electricos.tscn#onda_voltio",
	"ruby:move/16": "res://escenas/batalla/animaciones_nativas/rayos_varios.tscn#tornado",
	"ruby:move/51": "res://escenas/batalla/animaciones_nativas/rayos_varios.tscn#acido",
	"ruby:move/124": "res://escenas/batalla/animaciones_nativas/rayos_varios.tscn#residuos",
	"ruby:move/188": "res://escenas/batalla/animaciones_nativas/rayos_varios.tscn#bomba_lodo",
	"ruby:move/108": "res://escenas/batalla/animaciones_nativas/rayos_varios.tscn#pantallahumo",
	"ruby:move/58": "res://escenas/batalla/animaciones_nativas/rayos_varios.tscn#rayo_hielo",
	"ruby:move/181": "res://escenas/batalla/animaciones_nativas/rayos_varios.tscn#nieve_polvo",
	"ruby:move/63": "res://escenas/batalla/animaciones_nativas/rayos_varios.tscn#hiperrayo",
	"ruby:move/239": "res://escenas/batalla/animaciones_nativas/rayos_varios.tscn#ciclon",
	# Familia fondo_movimiento (§22), fondo psíquico: generar_golpes.py psiquicos.
	"ruby:move/93": "res://escenas/batalla/animaciones_nativas/psiquicos.tscn#confusion",
	"ruby:move/94": "res://escenas/batalla/animaciones_nativas/psiquicos.tscn#psiquico",
	"ruby:move/96": "res://escenas/batalla/animaciones_nativas/psiquicos.tscn#meditacion",
	"ruby:move/95": "res://escenas/batalla/animaciones_nativas/psiquicos.tscn#hipnosis",
	"ruby:move/60": "res://escenas/batalla/animaciones_nativas/psiquicos.tscn#psicorrayo",
	"ruby:move/133": "res://escenas/batalla/animaciones_nativas/psiquicos.tscn#amnesia",
	"ruby:move/134": "res://escenas/batalla/animaciones_nativas/psiquicos.tscn#kinetico",
	"ruby:move/149": "res://escenas/batalla/animaciones_nativas/psiquicos.tscn#psicoonda",
	"ruby:move/326": "res://escenas/batalla/animaciones_nativas/psiquicos.tscn#paranormal",
	"ruby:move/138": "res://escenas/batalla/animaciones_nativas/psiquicos.tscn#comesuenos",
	# fondo_movimiento (§22), fondos siniestro, fantasma, cósmico y del Sísmico: generar_golpes.py siniestros.
	"ruby:move/168": "res://escenas/batalla/animaciones_nativas/siniestros.tscn#ladron",
	"ruby:move/242": "res://escenas/batalla/animaciones_nativas/siniestros.tscn#triturar",
	"ruby:move/247": "res://escenas/batalla/animaciones_nativas/siniestros.tscn#bola_sombra",
	"ruby:move/101": "res://escenas/batalla/animaciones_nativas/siniestros.tscn#tinieblas",
	"ruby:move/325": "res://escenas/batalla/animaciones_nativas/siniestros.tscn#puno_sombra",
	"ruby:move/309": "res://escenas/batalla/animaciones_nativas/siniestros.tscn#puno_meteoro",
	"ruby:move/322": "res://escenas/batalla/animaciones_nativas/siniestros.tscn#masa_cosmica",
	"ruby:move/327": "res://escenas/batalla/animaciones_nativas/siniestros.tscn#gancho_alto",
	# fondo_movimiento (§22), fondos de impacto, taladro, trueno, vuelo y fisura: generar_golpes.py impactos.
	"ruby:move/12": "res://escenas/batalla/animaciones_nativas/impactos.tscn#guillotina",
	"ruby:move/32": "res://escenas/batalla/animaciones_nativas/impactos.tscn#perforador",
	"ruby:move/224": "res://escenas/batalla/animaciones_nativas/impactos.tscn#megacuerno",
	"ruby:move/87": "res://escenas/batalla/animaciones_nativas/impactos.tscn#trueno",
	"ruby:move/177": "res://escenas/batalla/animaciones_nativas/impactos.tscn#aerochorro",
	"ruby:move/90": "res://escenas/batalla/animaciones_nativas/impactos.tscn#fisura",
	# fondo_movimiento (§22), capas superpuestas (BG1) con scroll, mezcla y ventana: generar_golpes.py capas.
	"ruby:move/114": "res://escenas/batalla/animaciones_nativas/capas.tscn#niebla",
	"ruby:move/184": "res://escenas/batalla/animaciones_nativas/capas.tscn#cara_susto",
	"ruby:move/201": "res://escenas/batalla/animaciones_nativas/capas.tscn#tormenta_arena",
	"ruby:move/257": "res://escenas/batalla/animaciones_nativas/capas.tscn#onda_ignea",
	"ruby:move/296": "res://escenas/batalla/animaciones_nativas/capas.tscn#bola_neblina",
	"ruby:move/287": "res://escenas/batalla/animaciones_nativas/capas.tscn#alivio",
	# fondo_movimiento (§22), ondulación por filas de un battler copiado en su capa: generar_golpes.py ondas.
	"ruby:move/349": "res://escenas/batalla/animaciones_nativas/ondas.tscn#danza_dragon",
	# fondo_movimiento (§22), Persecución: «persecucion_par/_impar» según el turno (choosetwoturnanim).
	"ruby:move/228": "res://escenas/batalla/animaciones_nativas/persecucion.tscn#persecucion",
	# §23, los tres que esperaban gráficos (importados del decomp): generar_golpes.py importados.
	"ruby:move/21": "res://escenas/batalla/animaciones_nativas/importados.tscn#portazo",
	"ruby:move/348": "res://escenas/batalla/animaciones_nativas/importados.tscn#hoja_aguda",
	"ruby:move/215": "res://escenas/batalla/animaciones_nativas/importados.tscn#campana_cura",
	# fondo_movimiento (§23), fondo fantasma/siniestro con copias del battler: generar_golpes.py fantasmas.
	"ruby:move/171": "res://escenas/batalla/animaciones_nativas/fantasmas.tscn#pesadilla",
	"ruby:move/180": "res://escenas/batalla/animaciones_nativas/fantasmas.tscn#rencor",
	"ruby:move/194": "res://escenas/batalla/animaciones_nativas/fantasmas.tscn#mismodestino",
	"ruby:move/109": "res://escenas/batalla/animaciones_nativas/fantasmas.tscn#rayo_confuso",
	"ruby:move/185": "res://escenas/batalla/animaciones_nativas/fantasmas.tscn#finta",
	# fondo_movimiento (§23), fondos de hielo, aurora y psíquico: generar_golpes.py hielo_luz.
	"ruby:move/196": "res://escenas/batalla/animaciones_nativas/hielo_luz.tscn#viento_hielo",
	"ruby:move/329": "res://escenas/batalla/animaciones_nativas/hielo_luz.tscn#frio_polar",
	"ruby:move/62": "res://escenas/batalla/animaciones_nativas/hielo_luz.tscn#rayo_aurora",
	"ruby:move/295": "res://escenas/batalla/animaciones_nativas/hielo_luz.tscn#resplandor",
	"ruby:move/354": "res://escenas/batalla/animaciones_nativas/hielo_luz.tscn#psicoataque",
	# fondo_movimiento (§23), foco con ventana OBJ de un sprite y oscurecimiento por hardware: generar_golpes.py focos.
	"ruby:move/227": "res://escenas/batalla/animaciones_nativas/focos.tscn#otra_vez",
	"ruby:move/260": "res://escenas/batalla/animaciones_nativas/focos.tscn#camelo",
	# fondo_movimiento (§23), capas BG1 con mezcla y lo que pasa encima: generar_golpes.py capas2.
	"ruby:move/137": "res://escenas/batalla/animaciones_nativas/capas2.tscn#deslumbrar",
	"ruby:move/213": "res://escenas/batalla/animaciones_nativas/capas2.tscn#atraccion",
	"ruby:move/234": "res://escenas/batalla/animaciones_nativas/capas2.tscn#sol_matinal",
	"ruby:move/312": "res://escenas/batalla/animaciones_nativas/capas2.tscn#aromaterapia",
	"ruby:move/347": "res://escenas/batalla/animaciones_nativas/capas2.tscn#paz_mental",
	# fondo_movimiento (§23), la ola de Surf y Agua Lodosa: generar_golpes.py olas.
	"ruby:move/57": "res://escenas/batalla/animaciones_nativas/olas.tscn#surf",
	"ruby:move/330": "res://escenas/batalla/animaciones_nativas/olas.tscn#agua_lodosa",
	# fondo_movimiento (§23), copias del battler deformadas por filas (scanline): generar_golpes.py derretidos.
	"ruby:move/262": "res://escenas/batalla/animaciones_nativas/derretidos.tscn#legado",
	"ruby:move/151": "res://escenas/batalla/animaciones_nativas/derretidos.tscn#armadura_acida",
	"ruby:move/229": "res://escenas/batalla/animaciones_nativas/derretidos.tscn#giro_rapido",
	# §24, la familia especial (generar_golpes.py especial_*; traducciones en generar_especial.py). Mecánicos.
	"ruby:move/100": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#teletransporte",
	"ruby:move/195": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#canto_mortal",
	"ruby:move/226": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#relevo",
	"ruby:move/237": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#poder_oculto",
	"ruby:move/266": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#senuelo",
	"ruby:move/271": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#truco",
	"ruby:move/278": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#reciclaje",
	"ruby:move/285": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#intercambio",
	"ruby:move/288": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#rabia",
	"ruby:move/286": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#cerca",
	"ruby:move/270": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#refuerzo",
	"ruby:move/248": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#premonicion",
	"ruby:move/353": "res://escenas/batalla/animaciones_nativas/especial_mecanicos.tscn#deseo_oculto",
	# §24, movimientos que encadenan otro: solo su animación propia (la batalla anima después el movimiento elegido
	# como otra acción, con su propia entrada de esta tabla).
	"ruby:move/118": "res://escenas/batalla/animaciones_nativas/especial_encadenados.tscn#metronomo",
	"ruby:move/214": "res://escenas/batalla/animaciones_nativas/especial_encadenados.tscn#sonambulo",
	"ruby:move/274": "res://escenas/batalla/animaciones_nativas/especial_encadenados.tscn#ayuda",
	"ruby:move/289": "res://escenas/batalla/animaciones_nativas/especial_encadenados.tscn#robo",
	# §24, Mov. Espejo y Adaptación no tienen animación propia en Rubí: su entrada de gBattleAnims_Moves es
	# Move_POUND y Move_ANCIENT_POWER (la batalla anima el movimiento copiado o el del terreno): mismas escenas.
	"ruby:move/119": "res://escenas/batalla/animaciones_nativas/golpes_contacto.tscn#destructor",
	"ruby:move/267": "res://escenas/batalla/animaciones_nativas/rocas2.tscn#poder_pasado",
	# §24, Daño Secreto: la escena del movimiento del terreno (RamasNativas.ESCENA_POR_TERRENO), elegida al reproducir.
	"ruby:move/290": "",
	# §24, ramas por un dato de batalla («<animación>_<rama>», RamasNativas) o por el turno («_t<turno>», «_par/_impar»).
	"ruby:move/69": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#sismico",
	"ruby:move/216": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#retroceso",
	"ruby:move/218": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#frustracion",
	"ruby:move/217": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#presente",
	"ruby:move/222": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#magnitud",
	"ruby:move/210": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#corte_furia",
	"ruby:move/301": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#bola_hielo",
	"ruby:move/311": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#meteorobola",
	"ruby:move/254": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#reserva",
	"ruby:move/255": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#escupir",
	"ruby:move/256": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#tragar",
	"ruby:move/167": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#triplepatada",
	"ruby:move/251": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#paliza",
	"ruby:move/174": "res://escenas/batalla/animaciones_nativas/especial_datos.tscn#maldicion",
	# §24, mezclas de paleta (Camuflaje lee el terreno en EfectoMovimientoNativo.datos).
	"ruby:move/293": "res://escenas/batalla/animaciones_nativas/especial_paletas.tscn#camuflaje",
	"ruby:move/160": "res://escenas/batalla/animaciones_nativas/especial_paletas.tscn#conversion",
	"ruby:move/176": "res://escenas/batalla/animaciones_nativas/especial_paletas.tscn#conversion2",
	# §24, ramas por lado («<animación>_rival» cuando ataca el rival).
	"ruby:move/59": "res://escenas/batalla/animaciones_nativas/especial_lados.tscn#ventisca",
	"ruby:move/183": "res://escenas/batalla/animaciones_nativas/especial_lados.tscn#ultrapuno",
	"ruby:move/318": "res://escenas/batalla/animaciones_nativas/especial_lados.tscn#viento_plata",
	"ruby:move/245": "res://escenas/batalla/animaciones_nativas/especial_lados.tscn#vel_extrema",
	"ruby:move/5": "res://escenas/batalla/animaciones_nativas/especial_lados.tscn#megapuno",
	"ruby:move/25": "res://escenas/batalla/animaciones_nativas/especial_lados.tscn#megapatada",
	"ruby:move/158": "res://escenas/batalla/animaciones_nativas/especial_lados.tscn#hip_colmillo",
	"ruby:move/264": "res://escenas/batalla/animaciones_nativas/especial_lados.tscn#puno_certero",
	# §24, imagen de un battler (Transformación y Sustituto la dejan cambiada: ver AparienciaNativa).
	"ruby:move/144": "res://escenas/batalla/animaciones_nativas/especial_imagen.tscn#transformacion",
	"ruby:move/164": "res://escenas/batalla/animaciones_nativas/especial_imagen.tscn#sustituto",
	"ruby:move/272": "res://escenas/batalla/animaciones_nativas/especial_imagen.tscn#imitacion",
	"ruby:move/102": "res://escenas/batalla/animaciones_nativas/especial_imagen.tscn#mimetico",
	"ruby:move/166": "res://escenas/batalla/animaciones_nativas/especial_imagen.tscn#esquema",
	"ruby:move/107": "res://escenas/batalla/animaciones_nativas/especial_imagen.tscn#reduccion",
	# §32: animaciones que no son de movimiento (gBattleAnims_General / StatusConditions / Special). Las lanza
	# BattleAnimationDirector.play_key() a través de AnimacionAuxiliarNativa (generar_golpes.py generales_*;
	# traducciones en generar_generales.py). Sol, arena y granizo que continúan son el script del movimiento.
	"ruby:general/1": "res://escenas/batalla/animaciones_nativas/generales_estadistica.tscn#estadistica",
	"ruby:general/5": "res://escenas/batalla/animaciones_nativas/generales_objetos.tscn#objeto_tirado",
	"ruby:general/6": "res://escenas/batalla/animaciones_nativas/generales_atrapado.tscn#atrapado",
	"ruby:general/7": "res://escenas/batalla/animaciones_nativas/generales_objetos.tscn#efecto_objeto",
	"ruby:general/9": "res://escenas/batalla/animaciones_nativas/generales_objetos.tscn#aguanto",
	"ruby:general/10": "res://escenas/batalla/animaciones_nativas/generales_climas.tscn#lluvia",
	"ruby:general/11": "res://escenas/batalla/animaciones_nativas/climas.tscn#dia_soleado",
	"ruby:general/12": "res://escenas/batalla/animaciones_nativas/capas.tscn#tormenta_arena",
	"ruby:general/13": "res://escenas/batalla/animaciones_nativas/climas.tscn#granizo",
	"ruby:general/14": "res://escenas/batalla/animaciones_nativas/generales_curaciones.tscn#drenadoras",
	"ruby:general/16": "res://escenas/batalla/animaciones_nativas/generales_objetos.tscn#robo_objeto",
	"ruby:general/18": "res://escenas/batalla/animaciones_nativas/generales_futuros.tscn#premonicion",
	"ruby:general/19": "res://escenas/batalla/animaciones_nativas/generales_futuros.tscn#deseo_oculto",
	"ruby:general/20": "res://escenas/batalla/animaciones_nativas/generales_curaciones.tscn#puno_certero_prepara",
	"ruby:general/21": "res://escenas/batalla/animaciones_nativas/generales_curaciones.tscn#arraigo",
	"ruby:general/22": "res://escenas/batalla/animaciones_nativas/generales_curaciones.tscn#deseo",
	"ruby:status/0": "res://escenas/batalla/animaciones_nativas/generales_estados.tscn#veneno",
	"ruby:status/1": "res://escenas/batalla/animaciones_nativas/generales_estados.tscn#confusion",
	"ruby:status/2": "res://escenas/batalla/animaciones_nativas/generales_estados.tscn#quemadura",
	"ruby:status/3": "res://escenas/batalla/animaciones_nativas/generales_estados.tscn#enamorado",
	"ruby:status/4": "res://escenas/batalla/animaciones_nativas/generales_estados.tscn#sueno",
	"ruby:status/5": "res://escenas/batalla/animaciones_nativas/generales_estados.tscn#paralisis",
	"ruby:status/6": "res://escenas/batalla/animaciones_nativas/generales_estados.tscn#congelado",
	"ruby:status/7": "res://escenas/batalla/animaciones_nativas/generales_estados.tscn#maldicion_estado",
	"ruby:status/8": "res://escenas/batalla/animaciones_nativas/generales_estados.tscn#pesadilla",
	# §33: sustituto (se desvanece, aparece, pasa a Pokémon y vuelve a muñeco) y el robo de Snatch. Las imágenes del
	# muñeco y del Pokémon salen del estado de presentación (AparienciaNativa.imagenes_sustituto()); las ramas de
	# Snatch (compañero, sustituto), de RamasNativas.sufijo().
	"ruby:general/2": "res://escenas/batalla/animaciones_nativas/generales_sustituto.tscn#sustituto_fuera",
	"ruby:general/3": "res://escenas/batalla/animaciones_nativas/generales_sustituto.tscn#sustituto_aparece",
	"ruby:general/17": "res://escenas/batalla/animaciones_nativas/generales_sustituto.tscn#robo_general",
	"ruby:special/5": "res://escenas/batalla/animaciones_nativas/generales_sustituto.tscn#sustituto_a_pokemon",
	"ruby:special/6": "res://escenas/batalla/animaciones_nativas/generales_sustituto.tscn#pokemon_a_sustituto",
}

## §35: movimientos con `.target = MOVE_TARGET_USER` en el original (src/data/battle_moves.c) salvo Refuerzo (su
## efecto pone de objetivo al compañero antes de animar): su objetivo de animación es el propio atacante. La batalla
## puede darles de primer objetivo al compañero (CAMPO_PROPIO, TODO_EL_CAMPO, USUARIO_Y_ALIADOS y TODOS de
## AlcanceMovimientoGen3 empiezan por los aliados); en ese caso la escena nativa anima contra el atacante, como el
## original (slot_objetivo()). En individual el primer objetivo ya es el atacante: nada cambia.
const OBJETIVO_ATACANTE: Array[int] = [14, 54, 74, 96, 97, 100, 104, 105, 106, 107, 110, 111, 112, 113, 114, 115, 116, 117,
	133, 135, 150, 151, 156, 159, 160, 164, 176, 182, 187, 194, 195, 197, 201, 203, 208, 215, 219, 226, 234, 235, 236, 240,
	241, 254, 256, 258, 266, 268, 273, 275, 278, 286, 287, 288, 293, 294, 300, 303, 312, 322, 334, 336, 339, 346, 347, 349]
## Corrección de la base nominal del rival (ver _base()).
const AJUSTE_BASE_RIVAL: Vector2 = Vector2(0, -14)
## Corrección del centro (coordenadas 2/3) del jugador (ver _ajuste_centro()).
const AJUSTE_CENTRO_JUGADOR: Vector2 = Vector2(0, 8)

var escena: PackedScene
## Animación de la escena compartida que corresponde a este movimiento (vacía = la de la escena).
var animacion: StringName = &""
## Clave de la VM del movimiento ("ruby:move/N"): elige la rama de las escenas de §24 (RamasNativas).
var clave: String = ""
## §32: argumento de una animación general (el `source_general_argument` que la batalla pasa a la VM: estadística
## de B_ANIM_STATS_CHANGE, movimiento que atrapa…); -1 = sin argumento. Elige la rama (RamasNativas.sufijo_auxiliar)
## y llega a la escena como datos.argumento.
var argumento_auxiliar: int = -1
var instancia: EfectoMovimientoNativo
## Escena que ya terminó lo visual pero aún suena (se libera sola).
var _escena_sonando: EfectoMovimientoNativo


func _init(escena_: PackedScene = null) -> void:
	escena = escena_


## Devuelve el adaptador para una clave de la VM ("ruby:move/53"), o null si
## ese movimiento no tiene versión nativa.
static func para_clave(clave_: String) -> AnimacionEscenaNativa:
	if not ESCENAS.has(clave_):
		return null
	var adaptador: AnimacionEscenaNativa = AnimacionEscenaNativa.new()
	adaptador.clave = clave_
	# Daño Secreto (§24): la escena depende del terreno; se elige en reproducir().
	if not str(ESCENAS[clave_]).is_empty():
		adaptador._cargar(str(ESCENAS[clave_]))
	return adaptador


## "ruta.tscn#animacion": escena compartida por una familia (una animación por movimiento).
func _cargar(ruta: String) -> void:
	var partes: PackedStringArray = ruta.split("#")
	escena = load(partes[0]) as PackedScene
	animacion = StringName(partes[1]) if partes.size() > 1 else &""


func reproducir(contexto: MoveAnimationContext, _resultado: ResultadoMovimiento) -> void:
	if escena == null and RamasNativas.ESCENA_POR_TERRENO.has(clave):
		var lista: Array = RamasNativas.ESCENA_POR_TERRENO[clave]
		_cargar(str(ESCENAS.get(lista[clampi(RamasNativas.terreno(contexto), 0, lista.size() - 1)], "")))
	var slot_d: BattleSlot = slot_objetivo(clave, contexto)
	var sprite_a: Sprite2D = _sprite_de(contexto.slot_atacante)
	var sprite_d: Sprite2D = _sprite_de(slot_d)
	if escena == null or sprite_a == null or sprite_d == null:
		_emitir_impacto()
		_emitir_finalizada()
		return
	var campo: Node2D = _resolver_campo(contexto, sprite_a, sprite_d)
	instancia = escena.instantiate() as EfectoMovimientoNativo
	instancia.turno = contexto.source_move_turn
	if animacion != &"":
		instancia.nombre_animacion = animacion
	instancia.proyeccion_oculta = _proyeccion_oculta(contexto)
	# §24: rama del script por un dato de batalla y datos de presentación (la misma fuente que la VM).
	instancia.rama = RamasNativas.sufijo(clave, contexto)
	instancia.datos = RamasNativas.datos(contexto)
	var geometria: Dictionary = contexto.geometria_concurso
	instancia.concurso = not geometria.is_empty()
	instancia.datos.merge(geometria.get("datos", {}), true)
	if instancia.concurso and instancia.rama.is_empty():
		# jumpifcontest: «<animación>_concurso» si la escena la tiene; si no, la de siempre.
		instancia.rama = "concurso"
	if argumento_auxiliar >= 0:
		# §33: las auxiliares sin rama por argumento conservan la de RamasNativas.sufijo() (Snatch).
		var rama_auxiliar: String = RamasNativas.sufijo_auxiliar(clave, argumento_auxiliar)
		if not rama_auxiliar.is_empty():
			instancia.rama = rama_auxiliar
		instancia.datos["argumento"] = argumento_auxiliar
	if instancia is EfectoEspecialNativo and clave in RamasNativas.APARIENCIA and AparienciaNativa.disponible(contexto):
		# §33: con las guardas que el llamador puso en este adaptador (BattleMoveActionPresenter), como en la VM.
		(instancia as EfectoEspecialNativo).apariencia = AparienciaNativa.new(contexto, _resultado, self)
	if clave in RamasNativas.IMAGENES_SUSTITUTO:
		instancia.datos["sustituto"] = AparienciaNativa.imagenes_sustituto(contexto.slot_atacante)
		# Snatch: la copia del que roba va en el sitio del objetivo con el desfase de su especie en ese lado.
		var batalla: Variant = contexto.batalla
		if instancia.datos.has("especie_atacante") and is_instance_valid(batalla) and (batalla as Object).has_method(&"obtener_offset_pokemon"):
			instancia.datos["offset_copia"] = batalla.obtener_offset_pokemon(str(instancia.datos.especie_atacante), not contexto.slot_atacante.es_jugador)
	campo.add_child(instancia)
	# §35: combate doble: posiciones de la GBA y los battlers visibles del campo (compañeros incluidos).
	instancia.fijar_dobles(es_doble(contexto, campo), posicion_gba(contexto.slot_atacante), posicion_gba(slot_d),
		_battlers_del_campo(campo, contexto.slot_atacante, slot_d))
	instancia.configurar(sprite_a, sprite_d,
		geometria.get("centro_atacante", _centro(campo, sprite_a) + _ajuste_centro(contexto.slot_atacante)),
		geometria.get("centro_defensor", _centro(campo, sprite_d) + _ajuste_centro(slot_d)),
		geometria.get("base_atacante", _base(campo, contexto.slot_atacante, sprite_a)),
		geometria.get("base_defensor", _base(campo, slot_d, sprite_d)),
		contexto.slot_atacante.es_jugador,
		campo.get_meta(&"tamano_campo", BattleLayout.TAM_CAMPO) as Vector2)
	instancia.impacto_visual.connect(_al_impacto)
	instancia.terminado.connect(_al_terminar, CONNECT_ONE_SHOT)
	instancia.reproducir()


## Cancelación: corta también el audio, restaura sprites, libera la escena y
## emite impacto/finalizada si faltaban (como BattleSequenceAnimation.cancel()).
## Tras `finalizada` solo queda audio sonando; cancelar lo corta igualmente.
func cancelar() -> void:
	if is_instance_valid(instancia):
		instancia.cancelar()
	elif is_instance_valid(_escena_sonando):
		_escena_sonando.cancelar()
	if not _finalizada_emitida:
		_al_terminar()


func _al_impacto() -> void:
	if not _impacto_emitido:
		_emitir_impacto()


## Fin visual. La escena se libera sola al acabar su AnimationPlayer (deja
## terminar el audio); si se canceló, ya se liberó.
func _al_terminar() -> void:
	_escena_sonando = instancia
	instancia = null
	if not _impacto_emitido:
		_emitir_impacto()
	if not _finalizada_emitida:
		_emitir_finalizada()


## Movimientos semiinvulnerables (Vuelo, Excavar, Buceo, Bote): si la lógica
## de batalla abrió una BattleHiddenProjection para el atacante, la escena
## escribe su visibilidad solo a través de ella (misma búsqueda que
## BattleAnimationContext.from_legacy hace para la VM). Sin batalla o sin
## proyección devuelve null y la escena gestiona la visibilidad por su cuenta.
static func _proyeccion_oculta(contexto: MoveAnimationContext) -> BattleHiddenProjection:
	var batalla: Variant = contexto.batalla
	if not is_instance_valid(batalla) or not (batalla as Object).has_method(&"_obtener_combatiente") or not (batalla as Object).has_method(&"_pokemon_de_slot"):
		return null
	var pokemon: BasePokemon = batalla._pokemon_de_slot(contexto.slot_atacante)
	var estado: PokemonEnCombate = batalla._obtener_combatiente(pokemon) if pokemon != null else null
	var proyeccion: BattleHiddenProjection = estado.hidden_projection if estado != null else null
	return proyeccion if proyeccion != null and proyeccion.bind_slot(contexto.slot_atacante) else null


static func _sprite_de(slot: BattleSlot) -> Sprite2D:
	if not is_instance_valid(slot) or not is_instance_valid(slot.sprite_pokemon):
		return null
	return slot.sprite_pokemon if slot.sprite_pokemon.is_inside_tree() else null


## En batalla real, el nodo "Campo" de la composition root (igual que
## BattleAnimationContext.from_legacy); si no, el ancestro común de los sprites.
static func _resolver_campo(contexto: MoveAnimationContext, sprite_a: Sprite2D, sprite_d: Sprite2D) -> Node2D:
	if is_instance_valid(contexto.batalla) and contexto.batalla is Node:
		var campo_batalla: Node2D = (contexto.batalla as Node).get_node_or_null(^"Campo") as Node2D
		if campo_batalla != null:
			return campo_batalla
		if contexto.batalla is Node2D:
			return contexto.batalla as Node2D
	var nodo: Node = sprite_a.get_parent()
	while nodo != null and not nodo.is_ancestor_of(sprite_d):
		nodo = nodo.get_parent()
	return nodo as Node2D if nodo is Node2D else sprite_a.get_parent() as Node2D


## §35: posición de la GBA de un slot (0 jugador izquierda, 1 rival izquierda, 2 jugador derecha, 3 rival derecha;
## BattleSlot.Posicion es 0 jugador izq., 1 jugador der., 2 rival izq., 3 rival der.).
static func posicion_gba(slot: BattleSlot) -> int:
	return [0, 2, 1, 3][clampi(int(slot.posicion_batalla), 0, 3)] if is_instance_valid(slot) else 0


## §35: el slot contra el que anima el original: el atacante en los movimientos MOVE_TARGET_USER (OBJETIVO_ATACANTE) a los
## que la batalla da de primer objetivo al compañero; si no, el defensor del contexto.
static func slot_objetivo(clave_: String, contexto: MoveAnimationContext) -> BattleSlot:
	var defensor: BattleSlot = contexto.slot_defensor
	if not is_instance_valid(defensor) or not is_instance_valid(contexto.slot_atacante) or defensor == contexto.slot_atacante:
		return defensor
	if defensor.es_jugador == contexto.slot_atacante.es_jugador and clave_.begins_with("ruby:move/") \
			and int(clave_.trim_prefix("ruby:move/")) in OBJETIVO_ATACANTE:
		return contexto.slot_atacante
	return defensor


## §35: combate doble como IsDoubleBattle() del original: el formato de la batalla; sin batalla real (comparador,
## laboratorio), si hay en el campo un battler visible en una posición de la derecha.
static func es_doble(contexto: MoveAnimationContext, campo: Node) -> bool:
	var batalla: Variant = contexto.batalla
	if is_instance_valid(batalla):
		var formato: Variant = (batalla as Object).get("formato_batalla")
		if formato is int:
			return formato == Singleton.FormatoBatalla.DOBLE
	for nodo: Node in campo.find_children("*", "", true, false):
		var slot: BattleSlot = nodo as BattleSlot
		if slot != null and slot.visible and int(slot.posicion_batalla) in [1, 3] and is_instance_valid(slot.sprite_pokemon):
			return true
	return false


## §35: posición de la GBA -> [sprite, centro, base] de los battlers del campo: el atacante y el defensor siempre y los
## demás si su slot y su sprite son visibles (IsAnimBankSpriteVisible del original).
static func _battlers_del_campo(campo: Node2D, slot_a: BattleSlot, slot_d: BattleSlot) -> Dictionary:
	var resultado: Dictionary = {}
	for nodo: Node in campo.find_children("*", "", true, false):
		var slot: BattleSlot = nodo as BattleSlot
		if slot == null or not is_instance_valid(slot.sprite_pokemon) or not slot.sprite_pokemon.is_inside_tree():
			continue
		if slot != slot_a and slot != slot_d and not (slot.visible and slot.sprite_pokemon.visible):
			continue
		var sprite: Sprite2D = slot.sprite_pokemon
		resultado[posicion_gba(slot)] = [sprite, _centro(campo, sprite) + _ajuste_centro(slot), _base(campo, slot, sprite)]
	return resultado


## Coordenadas 2/3 del original: en el rival coinciden con el centro del
## sprite; en el jugador (sprite de espaldas) quedan 8 px más abajo (medido en
## la ROM con las sombras de Vuelo/Bote y las ondas de Viento Cortante).
static func _ajuste_centro(slot: BattleSlot) -> Vector2:
	return AJUSTE_CENTRO_JUGADOR if is_instance_valid(slot) and slot.es_jugador else Vector2.ZERO


static func _centro(campo: Node2D, sprite: Sprite2D) -> Vector2:
	return campo.to_local(sprite.to_global(sprite.get_rect().get_center()))


static func _base(campo: Node2D, slot: BattleSlot, sprite: Sprite2D) -> Vector2:
	if slot.is_inside_tree():
		var base: Vector2 = campo.to_local(slot.to_global(BattleLayout.SOURCE_NOMINAL_CANVAS_REFERENCE))
		# El sprite del rival coincide con la ROM, pero ancla + (32, 32) queda 14 px
		# por debajo de sus coordenadas 0/1 del original (176, 40); en el jugador la
		# relación sprite/base ya coincide. Medido con los volcados de la ROM.
		return base + (Vector2.ZERO if slot.es_jugador else AJUSTE_BASE_RIVAL)
	return _centro(campo, sprite)
