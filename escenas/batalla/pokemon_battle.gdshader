shader_type canvas_item;

// === PARÁMETROS DE CONTROL ===
uniform bool efecto_silueta = false;
uniform bool efecto_parpadeo = false;
uniform bool efecto_brillo = false;
uniform bool efecto_desvanecimiento = false;
uniform bool efecto_contorno = false;
uniform bool efecto_monocromo = false;

// === PARÁMETROS DE SILUETA ===
// color_silueta.rgb: color hacia el que se mezcla el sprite.
// color_silueta.a: cantidad máxima de mezcla/transparencia del tinte.
uniform vec4 color_silueta : source_color = vec4(1.0, 0.71, 0.97, 1.0);
uniform float intensidad_silueta : hint_range(0.0, 1.0) = 1.0;
// 0.0 = sombreado completo, 1.0 = sprite normal.
uniform float progreso_silueta : hint_range(0.0, 1.0) = 1.0;

// === PARÁMETROS DE PARPADEO ===
uniform float velocidad_parpadeo : hint_range(0.1, 10.0) = 2.0;
uniform vec4 color_parpadeo : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// === PARÁMETROS DE BRILLO ===
uniform float intensidad_brillo : hint_range(0.0, 3.0) = 1.5;
uniform vec4 color_brillo : source_color = vec4(1.0, 1.0, 0.8, 1.0);

// === PARÁMETROS DE DESVANECIMIENTO ===
uniform float alpha_desvanecimiento : hint_range(0.0, 1.0) = 1.0;

// === PARÁMETROS DE CONTORNO ===
uniform vec4 color_contorno : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float grosor_contorno : hint_range(0.5, 3.0) = 1.0;

// === PARÁMETROS DE MONOCROMO ===
uniform float intensidad_monocromo : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tinte_monocromo : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 color_original = texture(TEXTURE, UV);
	vec4 color_final = color_original;
	
	if (color_original.a < 0.01) {
		COLOR = color_original;
	} else {
		// === EFECTO SILUETA ===
		if (efecto_silueta) {
			float intensidad_final = intensidad_silueta * color_silueta.a * (1.0 - progreso_silueta);
			color_final.rgb = mix(color_final.rgb, color_silueta.rgb, clamp(intensidad_final, 0.0, 1.0));
		}
		
		// === EFECTO BRILLO ===
		if (efecto_brillo) {
			vec4 brillo = vec4(color_final.rgb * intensidad_brillo, color_final.a);
			color_final = mix(color_final, brillo, 0.7);
			
			// Agregar tinte de brillo
			color_final.rgb = mix(color_final.rgb, color_brillo.rgb, 0.3);
		}
		
		// === EFECTO CONTORNO ===
		if (efecto_contorno) {
			vec2 texture_dimensions = vec2(textureSize(TEXTURE, 0));
			vec2 texel_size = vec2(grosor_contorno) / texture_dimensions;
			bool es_borde = false;
			
			// Detectar bordes chequeando píxeles vecinos
			for (float x = -1.0; x <= 1.0; x += 1.0) {
				for (float y = -1.0; y <= 1.0; y += 1.0) {
					if (x == 0.0 && y == 0.0) continue;
					
					vec2 offset = vec2(x, y) * texel_size;
					float alpha_vecino = texture(TEXTURE, UV + offset).a;
					
					if (alpha_vecino < 0.1) {
						es_borde = true;
						break;
					}
				}
				if (es_borde) break;
			}
			
			if (es_borde) {
				color_final = vec4(color_contorno.rgb, color_final.a);
			}
		}
		
		// === EFECTO PARPADEO ===
		if (efecto_parpadeo) {
			float parpadeo = sin(TIME * velocidad_parpadeo) * 0.5 + 0.5;
			vec4 color_parpadeo_final = vec4(color_parpadeo.rgb, color_final.a);
			color_final = mix(color_final, color_parpadeo_final, parpadeo * 0.6);
		}
		
		// === EFECTO MONOCROMO ===
		if (efecto_monocromo) {
			float gris = dot(color_final.rgb, vec3(0.299, 0.587, 0.114));
			vec3 monocromo = vec3(gris) * tinte_monocromo.rgb;
			color_final.rgb = mix(color_final.rgb, monocromo, intensidad_monocromo);
		}
		
		// === EFECTO DESVANECIMIENTO ===
		if (efecto_desvanecimiento) {
			color_final.a *= alpha_desvanecimiento;
		}
		
		COLOR = color_final;
	}
}
