extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Pure109 source recurrences. Native projection/range policy is explicit, not GBA pixels.
const Trig = preload("res://scripts/battle/animations/sequence/source_trig.gd")
const ART := ["texture","frame_rects","scale_factor","color","recolor","flip_h","flip_v"]
const STRUCTURE_SHA256 := "930eecdb17f3ed691bdf920ae93bfc44a9676678f0a1d6fe679478190e54d680"
const KEY := "ruby:move/109"

static func stable(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys();keys.sort();var parts: PackedStringArray = []
		for key: Variant in keys:parts.append(JSON.stringify(str(key))+":"+stable(value[key]))
		return "d{"+",".join(parts)+"}"
	if value is Array:
		var parts: PackedStringArray = []
		for child: Variant in value:parts.append(stable(child))
		return "a["+",".join(parts)+"]"
	if typeof(value) in [TYPE_INT,TYPE_FLOAT]:
		return "n"+str(int(value)) if is_finite(float(value)) and float(value)==floor(float(value)) else "invalid_fraction"
	return "s"+JSON.stringify(value)

static func normalized(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in raw:
		if typeof(key) not in [TYPE_STRING,TYPE_STRING_NAME] or result.has(str(key)):return {}
		result[str(key)] = raw[key]
	return result

static func body(d: BattleAnimationDefinition) -> bool:
	if d==null or d.key!=KEY or not BattleAnimationSequenceRegistry.is_builtin_source_definition(d):return false
	var steps: Array = []
	for raw: Dictionary in d.steps:
		var s: Dictionary = normalized(raw)
		if s.is_empty():return false
		if s.get("op")=="effect":
			var line: int = int(s.get("source_line",-1))
			if line in [2057,2061]:
				for key: String in ART:s.erase(key)
			elif line in [2053,2066]:s.erase("texture")
		steps.append(s)
	return stable([d.key,d.coverage,d.source_script,d.schema_version,steps]).sha256_text()==STRUCTURE_SHA256

static func translation(start: Vector2,target: Vector2) -> Dictionary:
	for point: Vector2 in [start,target]:
		if not point.is_finite() or maxf(absf(point.x),absf(point.y))>1048576.0:return {"valid":false,"reason":"numeric_range","D":1}
	var delta: Vector2 = target-start;var m: float = maxf(absf(delta.x),absf(delta.y))
	if not delta.is_finite() or m>2097152.0:return {"valid":false,"reason":"numeric_range","D":1}
	var source: bool = start==start.floor() and target==target.floor() and start.x>=-32768 and start.x<=32767 and start.y>=-32768 and start.y<=32767 and target.x>=-32768 and target.x<=32767 and target.y>=-32768 and target.y<=32767 and m<=255
	var duration: int = int(absf(delta.x)*256.0/288.0) if source else 0
	if duration<1:source = false
	if not source:duration = 240 if m>=270.0 else maxi(1,ceili(m/1.125))
	if duration<1 or duration>(226 if source else 240):return {"valid":false,"reason":"invalid_duration","D":1}
	var x: int = int(absf(delta.x)*256.0)/duration;var y: int = int(absf(delta.y)*256.0)/duration
	x = (x|1) if delta.x<0 else x&~1;y = (y|1) if delta.y<0 else y&~1
	return {"valid":true,"D":duration,"remaining":duration,"vx":x,"vy":y,"ax":0,"ay":0,"negative_x":delta.x<0,"negative_y":delta.y<0,"source":source,"start":start,"point":start,"angle":0,"amount":16,"alpha":16,"direction":-1,"phase":"travel","pulses":0,"live":true}

static func alpha(s: Dictionary) -> void:
	if int(s.amount)>255:
		s.amount += 1
		if s.amount==269:s.amount = 0
		return
	s.amount += int(s.direction);s.alpha = s.amount
	if int(s.amount) in [0,16]:s.direction = -int(s.direction)
	if s.amount==0:s.amount = 256

static func ball(s: Dictionary) -> void:
	if not bool(s.get("valid",false)) or s.phase=="dead":return
	if int(s.pulses)>=576:s.live=false;s.phase="dead";s.reason="pulse_budget";return
	s.pulses += 1;s.cue = false
	if s.phase=="cleanup":s.phase="dead";s.live=false;return
	var arrival: bool = s.phase=="arrival"
	if not arrival:
		alpha(s)
		if int(s.remaining)==0:s.phase="arrival";return
	s.ax += int(s.vx);s.ay += int(s.vy)
	if bool(s.source):s.ax &= 65535;s.ay &= 65535
	var offset: Vector2 = Vector2(-(int(s.ax)>>8) if bool(s.negative_x) else int(s.ax)>>8,-(int(s.ay)>>8) if bool(s.negative_y) else int(s.ay)>>8)
	var old: int = s.angle
	s.point = s.start+offset+Vector2(Trig.sine(old,10),Trig.cosine(old,15));s.angle=(old+5)&255;s.remaining-=1
	s.cue = (old==0 or old>196) and int(s.angle)>0;s.panned = not arrival
	if arrival:
		if int(s.amount)==0:s.live=false;s.phase="cleanup"
		else:alpha(s)

static func orbit(base: Vector2,k: int) -> Dictionary:
	var angle: int = ((k-1)*19)&255
	return {"point":base+Vector2(Trig.sine(angle,32),Trig.cosine(angle,8)+((k*80)>>8)),"priority":2 if ((angle-65)&65535)<=130 else 1,"live":k<61}

static func hardware(n: int) -> Dictionary:
	var y: int = 0 if n<=1 else n-1 if n<=17 else 16 if n<=19 else maxi(0,35-n)
	return {"y":y,"swapped":n>=19,"done":n>=36,"active":n in range(1,18) or n in range(19,36)}

static func normal(n: int) -> int:
	if n>=120:return 0
	var segment: int = n/20;var local: int = n%20
	var amount: int = mini(14,maxi(0,((local-1)/2)*2)) if local>0 else 0
	return amount if segment%2==0 else 14-amount

static func palette(input: Image,amount: int,source_default: bool,color: Color,recolor: bool) -> Image:
	var image: Image = input.duplicate();image.convert(Image.FORMAT_RGBA8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x,y)
			if recolor:
				var brightness: float = maxf(pixel.r,maxf(pixel.g,pixel.b));pixel = Color(brightness,brightness,brightness,pixel.a)
			var values: Array[int] = [pixel.r8,pixel.g8,pixel.b8];var target: Array[int] = [31,10,0]
			if source_default:
				for c: int in 3:
					var base: int = values[c]/8;values[c] = (base+((target[c]-base)*amount>>4))*255/31
				pixel = Color8(values[0],values[1],values[2],pixel.a8)
			else:
				pixel.r = lerpf(pixel.r,31.0/31.0,amount/16.0);pixel.g = lerpf(pixel.g,10.0/31.0,amount/16.0);pixel.b = lerpf(pixel.b,0.0,amount/16.0)
			image.set_pixel(x,y,pixel*color)
	return image
