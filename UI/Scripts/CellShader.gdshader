shader_type canvas_item;

// Параметры для инспектора Godot
uniform sampler2D hex_texture : repeat_enable, filter_linear;
uniform vec4 shield_color : source_color = vec4(0.0, 0.6, 1.0, 1.0);
uniform vec2 texture_scale = vec2(5.0, 5.0);
uniform float pulse_speed = 1.5;

// Настройки линзы и изгиба
uniform float distortion_amount : hint_range(0.0, 0.5) = 0.12;

// Геометрия шлема
uniform float cheek_width : hint_range(0.0, 0.5) = 0.20;       
uniform float cheek_height : hint_range(0.0, 1.0) = 0.60;      
uniform float forehead_height : hint_range(0.0, 0.5) = 0.07;   
uniform float fade_smoothness : hint_range(0.01, 0.3) = 0.05;  

void fragment() {
	// 1. Блок искажения координат с компенсацией масштаба по краям
	vec2 uv_centered = UV - 0.5;
	
	// Автоматически расширяем текстуру внутрь, чтобы соты не обрезались по углам экрана
	float scale_compensation = 1.0 + distortion_amount * 0.25;
	uv_centered *= scale_compensation;
	
	// Математика дисторсии бочонка
	float dist = length(uv_centered);
	vec2 distorted_uv = uv_centered * (1.0 + distortion_amount * (dist * dist));
	
	// Возвращаем координаты в стандартный диапазон 0.0 - 1.0
	distorted_uv += 0.5;

	// 2. Наложение зацикленной текстуры сот по новым координатам
	vec2 scaled_uv = distorted_uv * texture_scale;
	vec4 hex_mask = texture(hex_texture, scaled_uv);
	
	// 3. Расчет геометрии маски шлема
	float mask = 0.0;
	
	// Верхняя полоса ("Лоб")
	float forehead = smoothstep(forehead_height, forehead_height - fade_smoothness, distorted_uv.y);
	mask = max(mask, forehead);
	
	// Левая "щека" шлема
	float left_cheek_shape = cheek_width * smoothstep(1.0 - cheek_height, 1.0, distorted_uv.y);
	float left_cheek = smoothstep(left_cheek_shape, left_cheek_shape - fade_smoothness, distorted_uv.x);
	mask = max(mask, left_cheek);
	
	// Правая "щека" шлема
	float right_cheek_shape = cheek_width * smoothstep(1.0 - cheek_height, 1.0, distorted_uv.y);
	float right_cheek = smoothstep(1.0 - right_cheek_shape, 1.0 - right_cheek_shape + fade_smoothness, distorted_uv.x);
	mask = max(mask, right_cheek);
	
	// 4. Мягкая пульсация щита по времени
	float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;
	
	// 5. Финальное смешивание цвета и прозрачности
	vec4 final_color = shield_color;
	
	// Инвертируем маску, если соты на картинке черного цвета
	float hex_alpha = 1.0 - hex_mask.r;
	
	// Перемножаем все слои прозрачности
	final_color.a = hex_alpha * shield_color.a * mask * pulse;
	
	COLOR = final_color;
}
