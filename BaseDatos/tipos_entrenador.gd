extends RefCounted
class_name TiposEntrenador

## Valores por defecto usados por el editor y por los cargadores de datos.
##
## Estos valores se aplican únicamente cuando un registro no trae
## `ratio_dinero`, o cuando se selecciona una clase desde el selector de
## "Clases de Entrenadores". Un valor explícito guardado en el JSON siempre
## tiene prioridad.
const RATIO_DINERO_POR_DEFECTO: int = 5

## Catálogo completo con todas las clases derivadas de `NOMBRES_CLASE_POR_FRAME`,
## ordenadas alfabéticamente. Las clases no incluidas (si las hubiera) usarían
## el valor genérico de RATIO_DINERO_POR_DEFECTO.
const RATIOS_DINERO_POR_CLASE: Dictionary = {
	"ADMIN. AQUA": 10,		# AQUA ADMIN
	"ADMIN. MAGMA": 10,		# MAGMA ADMIN
	"ALTO MANDO": 25,		# ELITE FOUR
	"AMO PALACIO": 1,
	"ASTRO CÚPULA": 1,
	"BELLA": 20,			# BEAUTY
	"BICHOMANÍACO": 15, 	# BUG MANIAC
	"BRUJITA": 6,			# HEX MANIAC
	"CABALLERO": 20,		# GENTLEMAN
	"CAMPEÓN": 50,			# CHAMPION
	"CAMPISTA": 4,			# CAMPER
	"CAZABICHOS": 4,		# BUG CATCHER
	"CHICA": 4,				# LASS
	"CHICO NINJA": 3,		# NINJA BOY
	"CRIAPOKéMON": 10,		# POKéMON BREEDER
	"DAMA PARASOL": 10,		# PARASOL LADY
	"DAMA TORRE": 1,
	"DAMISELA": 50,			# LADY
	"DOMADRAGÓN": 12,		# DRAGON TAMER
	"DOMINGUERA": 4,		# PICNICKER
	"ENTRE. GUAY": 12,		# COOLTRAINER
	"ENTRENADOR": 15,		# POKéMON TRAINER
	"ENTRENADORA": 15,		# POKéMON TRAINER
	"EQUIPO AQUA": 5,		# TEAM AQUA
	"EQUIPO MAGMA": 5,		# TEAM MAGMA
	"ESCOLAR": 5,			# SCHOOL KID
	"ESTUDIANTES": 4,		# SR. AND JR.
	"FOGONERO": 8,			# KINDLER
	"GEMELAS": 3,			# TWINS
	"GUITARRISTA": 8,		# GUITARIST
	"HERMANOS": 3,			# SIS AND BRO
	"JEFE FÁBRICA": 1,
	"JOVEN": 4,				# YOUNGSTER - BOARDER
	"KARATEKA": 8,			# BLACK BELT - BATTLE GIRL tiene ratio 6 :P
	"LÍDER": 25,			# GYM LEADER
	"LÍDER AQUA": 20,
	"LÍDER MAGMA": 1,
	"MAESTRA DOJO": 1,
	"MARINERO": 8,			# SAILOR
	"MéDIUM": 6,			# PSYCHIC
	"MONTAÑERO": 10,		# HIKER
	"NADADOR": 2,			# SWIMMER ♂
	"NADADORA": 2,			# SWIMMER ♀
	"NIÑO BIEN": 50,		# RICH BOY
	"ORNITÓLOGO": 8,		# BIRD KEEPER
	"PAREJA JOVEN": 8,		# YOUNG COUPLE
	"PAREJA MAYOR": 10,		# OLD COUPLE
	"PERIODISTAS": 12,
	"PESCADOR": 10,			# FISHERMAN
	"PLAYERA": 1,			# TUBER
	"PLAYERO": 1,
	"POKéABU": 10,			# EXPERT
	"POKéCOLECTOR": 15,		# COLLECTOR
	"POKéFAN": 20,			# POKéFAN - Hay un WISTRATE de 5
	"POKéGUARDA": 12,		# POKéMON RANGER
	"POKéMANÍACO": 15,		# POKéMANIAC
	"PROFESOR": 1,
	"REINA SERPIE": 1,
	"REY PIRÁMIDE": 1,
	"RUINAMANÍACO": 15,
	"SRTA. AROMA": 10,
	"TRIATLETA": 10,		# TRIATHLETE
	"VACIO": 1,
}

## Mapeo del frame del spritesheet `entrenadores_64.tres` a la clase sugerida.
## Un frame puede compartir clase con otros frames; el frame sigue siendo el
## identificador visual y la clase es el dato semántico reutilizable.
const NOMBRES_CLASE_POR_FRAME: Dictionary = {
	0:   "ENTRENADOR",
	1:   "ENTRENADORA",
	2:   "CHICA",
	3:   "JOVEN",
	4:   "MONTAÑERO",
	5:   "BELLA",
	6:   "PESCADOR",
	7:   "DAMISELA",
	8:   "TRIATLETA",
	9:   "EQUIPO AQUA",
	10:  "GEMELAS",
	11:  "NADADORA",
	12:  "CAZABICHOS",
	13:  "ESCOLAR",
	14:  "NIÑO BIEN",
	15:  "ESTUDIANTES",
	16:  "KARATEKA",
	17:  "ENTRENADOR",
	18:  "EQUIPO AQUA",
	19:  "PLAYERA",
	20:  "BRUJITA",
	21:  "CRIAPOKéMON",
	22:  "EQUIPO MAGMA",
	23:  "EQUIPO MAGMA",
	24:  "PERIODISTAS",
	25:  "PLAYERO",
	26:  "PAREJA JOVEN",
	27:  "GUITARRISTA",
	28:  "CABALLERO",
	29:  "CAMPEÓN",
	30:  "LÍDER MAGMA",
	31:  "TRIATLETA",
	32:  "TRIATLETA",
	33:  "KARATEKA",
	34:  "TRIATLETA",
	35:  "NADADOR",
	36:  "POKéFAN",
	37:  "POKéABU",
	38:  "POKéABU",
	39:  "TRIATLETA",
	40:  "TRIATLETA",
	41:  "DOMADRAGÓN",
	42:  "ORNITÓLOGO",
	43:  "CHICO NINJA",
	44:  "DAMA PARASOL",
	45:  "BICHOMANÍACO",
	46:  "MARINERO",
	47:  "POKéCOLECTOR",
	48:  "CRIAPOKéMON",
	49:  "POKéGUARDA",
	50:  "POKéGUARDA",
	51:  "ADMIN. MAGMA",
	52:  "ADMIN. MAGMA",
	53:  "SRTA. AROMA",
	54:  "RUINAMANÍACO",
	55:  "ENTRE. GUAY",
	56:  "ENTRE. GUAY",
	57:  "POKéMANÍACO",
	58:  "FOGONERO",
	59:  "CAMPISTA",
	60:  "DOMINGUERA",
	61:  "MéDIUM",
	62:  "MéDIUM",
	63:  "ESCOLAR",
	64:  "POKéFAN",
	65:  "HERMANOS",
	66:  "PAREJA MAYOR",
	67:  "ADMIN. AQUA",
	68:  "ADMIN. AQUA",
	69:  "LÍDER AQUA",
	70:  "LÍDER",
	71:  "LÍDER",
	72:  "LÍDER",
	73:  "LÍDER",
	74:  "LÍDER",
	75:  "LÍDER",
	76:  "LÍDER",
	77:  "LÍDER",
	78:  "ALTO MANDO",
	79:  "ALTO MANDO",
	80:  "ALTO MANDO",
	81:  "ALTO MANDO",
	82:  "PROFESOR",
	83:  "VACIO",
	84:  "EQUIPO AQUA",  # ALTERNATIVO
	85:  "BRUJITA",      # ALTERNATIVO
	86:  "MARINERO",     # ALTERNATIVO
	87:  "ENTRE. GUAY",  # ALTERNATIVO
	88:  "MéDIUM",       # ALTERNATIVO
	89:  "VACIO",
	90:  "LÍDER",
	91:  "CAMPEÓN",
	92:  "CAMPEÓN",
	93:  "CAMPEÓN",
	94:  "DAMA TORRE",
	95:  "ASTRO CÚPULA",
	96:  "AMO PALACIO",
	97:  "MAESTRA DOJO",
	98:  "JEFE FÁBRICA",
	99:  "REINA SERPIE",
	100: "REY PIRÁMIDE",
	101: "ENTRENADOR",
	102: "ENTRENADOR",
	103: "PROFESOR",  # ALTERNATIVO
	104: "VACIO",
	105: "VACIO",
	106: "VACIO",
	107: "VACIO",
	108: "VACIO",
	109: "VACIO",
}

static func obtener_ratio_dinero(clase: String) -> int:
	var clave := clase.strip_edges().to_upper()
	return int(RATIOS_DINERO_POR_CLASE.get(clave, RATIO_DINERO_POR_DEFECTO))

static func obtener_clase_por_sprite(frame: int) -> String:
	return str(NOMBRES_CLASE_POR_FRAME.get(frame, "ENTRENADOR_%03d" % frame))

static func obtener_cantidad_sprites_configurados() -> int:
	return NOMBRES_CLASE_POR_FRAME.size()
