extends EfectoMovimientoNativo
## Hidrocañón (Move_HYDRO_CANNON, subrutina _81D4EA8). hidrocanon.tscn
## anima el orbe de carga (gBattleAnimSpriteTemplate_83D92D0: escala y giro),
## la inversión de colores (sub_80E2324), la salpicadura y las sacudidas; aquí
## solo vive el chorro: cada gota (gBattleAnimSpriteTemplate_83D92E8,
## sub_80D3728) va en línea recta 15 frames desde la base del atacante
## (+10,-10, reflejado por lado) hasta la base del defensor.

const FRAMES_VUELO: int = 15

@export var desplazamiento_salida: Vector2 = Vector2(10, -10)

@onready var plantilla_gota: AnimatedSprite2D = $PlantillaGota
@onready var orbe: AnimatedSprite2D = $AtacanteBase/Orbe
@onready var inversion: ColorRect = $Inversion
@onready var copia_previa: BackBufferCopy = $CopiaPrevia
@onready var copia_fondo: BackBufferCopy = $CopiaFondo
@onready var sonido_carga: AudioStreamPlayer2D = $SonidoCarga


func _al_configurar() -> void:
	inversion.size = tamano_campo
	# §35: en combate doble los compañeros no se invierten (sub_80E2324 solo toca fondo, atacante y defensor).
	inversion.visibility_changed.connect(func() -> void: fijar_preinversion(inversion.visible))
	# La inversión va al nivel de los battlers: el campo se dibuja antes que la
	# UI, así que con el mismo z las cajas de PS quedan encima, sin invertir.
	var z_inversion: int = maxi(z_absoluto(sprite_atacante), z_absoluto(sprite_defensor))
	for capa: CanvasItem in [copia_previa, inversion, copia_fondo]:
		capa.z_as_relative = false
		capa.z_index = z_inversion
	# Subprioridad del original: el orbe queda detrás del atacante del jugador
	# (+2) y delante del rival (-2). Si queda bajo la capa de inversión, su
	# material pre-invierte el color mientras la inversión está activa. Con el
	# mismo z se dibuja después de la capa (va más abajo en el árbol).
	orbe.z_as_relative = false
	orbe.z_index = z_absoluto(sprite_atacante) + (-1 if direccion > 0.0 else 1)
	(orbe.material as ShaderMaterial).set_shader_parameter(&"encima_inversion", orbe.z_index >= z_inversion)
	# SE_W057 suena en el lado del atacante (SOUND_PAN_ATTACKER).
	sonido_carga.position = Vector2(tamano_campo.x * (0.5 - 0.5 * direccion), tamano_campo.y * 0.5)


## Pista de método: lanza `cantidad` gotas en este frame.
func emitir_gotas(cantidad: int = 1) -> void:
	var lado_x: float = direccion
	# §36: contra el aliado, sub_80D3728 niega arg 0 si el atacante está a la derecha (posiciones 2 y 3 de la GBA).
	if doble and posicion_atacante != posicion_defensor and posicion_atacante % 2 == posicion_defensor % 2 \
			and posicion_atacante >= 2:
		lado_x = -lado_x
	var desde: Vector2 = marca_atacante_base.position + Vector2(desplazamiento_salida.x * lado_x, desplazamiento_salida.y)
	for i: int in cantidad:
		var gota: AnimatedSprite2D = _instanciar_plantilla(plantilla_gota) as AnimatedSprite2D
		gota.position = desde
		var tween: Tween = _crear_tween()
		tween.tween_property(gota, ^"position", marca_defensor_base.position, FRAMES_VUELO * FRAME).set_delay(FRAME)
		tween.tween_callback(gota.queue_free)
