@tool
class_name DefinicionClima
extends Resource

## Datos de un clima visual del overworld. La escena concreta implementa el
## renderizado; el controlador solo depende de EfectoClimaBase (canal de
## pantalla) y EfectoClimaMundoBase (canal de mundo).

## Cómo se aplica `tinte` sobre el mundo.
## - VELO: un ColorRect normal cuyo alfa (`tinte.a`) se mezcla encima del mundo.
## - MULTIPLICAR: el ColorRect usa `BLEND_MODE_MUL`; el color (opaco) multiplica
##   lo ya dibujado, como la gamma de paleta del GBA (lluvia: 13/16 de brillo).
enum ModoTinte {
	VELO,
	MULTIPLICAR,
}

@export var id: StringName = &"NINGUNO"
@export var nombre_editor: String = "Sin clima"
## Efecto en espacio de pantalla (hereda EfectoClimaBase). Puede estar vacío si el
## clima solo usa `escena_mundo`.
@export var escena_efecto: PackedScene = null
## Copia el mundo ya dibujado antes del efecto de pantalla que lee SCREEN_UV.
## Independiente del backbuffer de agua usado por los efectos de mundo.
@export var requiere_copia_pantalla: bool = false
## Efecto en espacio de mundo (hereda EfectoClimaMundoBase). Se instancia bajo el
## nodo `AnclaClimaMundo` del mapa actual; sin ancla no se crea.
@export var escena_mundo: PackedScene = null
@export var tinte: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var modo_tinte: ModoTinte = ModoTinte.VELO
@export_range(0.0, 1.0, 0.01) var intensidad_base: float = 1.0
@export var permite_destellos: bool = true


## Definición que se aplica de verdad. Una definición normal es ella misma; una de
## ciclo (DefinicionClimaCiclo) elige su etapa del día. El controlador la llama antes
## de aplicar o transicionar, así que zonas de entrada y disparadores pueden llevar
## cualquiera de las dos sin cambiar nada más.
func resolver() -> DefinicionClima:
	return self


func intensidad_normalizada(valor: float = -1.0) -> float:
	var resultado: float = intensidad_base if valor < 0.0 else valor
	return clampf(resultado, 0.0, 1.0)


## Sin clima: el preset NINGUNO o uno que no tiene nada que dibujar (sin escenas y
## con tinte neutro). Un preset solo de tinte sí es un clima.
func es_sin_clima() -> bool:
	return id == &"NINGUNO" or (escena_efecto == null and escena_mundo == null and tinte_es_neutro())


## true si `tinte` no altera el mundo: VELO con alfa 0 o MULTIPLICAR por blanco.
func tinte_es_neutro() -> bool:
	if modo_tinte == ModoTinte.MULTIPLICAR:
		return is_equal_approx(tinte.r, 1.0) and is_equal_approx(tinte.g, 1.0) and is_equal_approx(tinte.b, 1.0)
	return is_zero_approx(tinte.a)


## Instantánea de los datos del preset: detecta cambios aunque conserve su ID.
func obtener_firma_visual() -> Array:
	return [id, escena_efecto, escena_mundo, requiere_copia_pantalla, tinte, modo_tinte, intensidad_base, permite_destellos]


func obtener_avisos() -> PackedStringArray:
	var avisos := PackedStringArray()
	if String(id).is_empty():
		avisos.append("El clima tiene un ID vacío.")
	if id == &"NINGUNO" and (escena_efecto != null or escena_mundo != null or not tinte_es_neutro()):
		avisos.append("NINGUNO no debe tener efectos ni tinte: el controlador los ignorará.")
	elif id != &"NINGUNO" and es_sin_clima():
		avisos.append("El clima no tiene efectos ni tinte visible.")
	if requiere_copia_pantalla and escena_efecto == null:
		avisos.append("La copia de pantalla requiere una escena de efecto de pantalla.")
	if escena_efecto != null:
		if not escena_efecto.can_instantiate():
			avisos.append("Escena Efecto no se puede instanciar.")
		else:
			var nodo := escena_efecto.instantiate()
			if not nodo is EfectoClimaBase:
				avisos.append("Escena Efecto debe heredar EfectoClimaBase (Control).")
			nodo.free()
	if escena_mundo != null:
		if not escena_mundo.can_instantiate():
			avisos.append("Escena Mundo no se puede instanciar.")
		else:
			var nodo := escena_mundo.instantiate()
			if not nodo is EfectoClimaMundoBase:
				avisos.append("Escena Mundo debe heredar EfectoClimaMundoBase (Node2D).")
			nodo.free()
	return avisos
