# Configuración para el sistema de pantalla de equipo
# Permite personalizar colores, animaciones y comportamientos

class_name ConfiguracionPantallaEquipo
extends Resource

# Colores para los diferentes sexos
@export var color_macho: Color = Color(0.25, 0.78, 0.97, 1.0)  # Azul
@export var color_hembra: Color = Color(0.97, 0.25, 0.25, 1.0)  # Rosa/Rojo
@export var color_sin_sexo: Color = Color(0.5, 0.5, 0.5, 1.0)   # Gris

# Configuración de animaciones
@export var velocidad_animacion_icono: float = 2.0  # FPS para animación de iconos
@export var tiempo_transicion_cursor: float = 0.1   # Tiempo de transición del cursor

# Configuración de rutas
@export var carpeta_iconos: String = "res://graficos/Icons/"
@export var carpeta_estados: String = "res://graficos/batalla/"

# Configuración de frames para estados especiales
@export var mostrar_informacion_en_vacia: bool = false
@export var animar_estado_debilitado: bool = true
@export var animar_estado_seleccionado: bool = true

# Configuración de navegación
@export var permitir_navegacion_circular: bool = true
@export var auto_seleccionar_primera_caja: bool = true

# Configuración de sonidos (para futuras implementaciones)
@export var sonido_mover_cursor: String = ""
@export var sonido_seleccionar: String = ""
@export var sonido_intercambiar: String = ""
@export var sonido_error: String = ""

func get_color_sexo(sexo) -> Color:
	"""Obtiene el color correspondiente al sexo del Pokémon"""
	if sexo == null:
		return color_sin_sexo
	
	var sexo_str = str(sexo).to_upper()
	match sexo_str:
		"M", "MACHO":
			return color_macho
		"F", "HEMBRA":
			return color_hembra
		_:
			return color_sin_sexo

func get_simbolo_sexo(sexo) -> String:
	"""Obtiene el símbolo correspondiente al sexo del Pokémon"""
	if sexo == null:
		return ""
	
	var sexo_str = str(sexo).to_upper()
	match sexo_str:
		"M", "MACHO":
			return "♂"
		"F", "HEMBRA":
			return "♀"
		_:
			return ""
