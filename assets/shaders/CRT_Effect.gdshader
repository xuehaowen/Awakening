shader_type canvas_item;

// Awakening CRT Premium Shader
// Optimized for dark terminal aesthetics and readability.

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.02;
uniform float scanline_count : hint_range(100.0, 2000.0) = 600.0;
uniform float chromatic_aberration : hint_range(0.0, 5.0) = 0.4;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float vignette_size : hint_range(0.0, 2.0) = 1.2;
uniform float curvature : hint_range(0.0, 0.1) = 0.005;
uniform float noise_intensity : hint_range(0.0, 0.5) = 0.005;
uniform float flicker_intensity : hint_range(0.0, 0.1) = 0.002;
uniform float brightness : hint_range(0.5, 2.0) = 1.45;
uniform float contrast : hint_range(0.5, 2.0) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool enabled = true;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec2 curved_uv(vec2 uv) {
    vec2 delta = uv - 0.5;
    float dist = dot(delta, delta);
    return uv + delta * dist * curvature;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 color;
    
    if (!enabled) {
        color = texture(SCREEN_TEXTURE, uv).rgb;
    } else {
        uv = curved_uv(uv);
        
        float aberration = chromatic_aberration / 1500.0;
        vec2 uv_r = clamp(uv + vec2(aberration, 0.0), vec2(0.0), vec2(1.0));
        vec2 uv_b = clamp(uv - vec2(aberration, 0.0), vec2(0.0), vec2(1.0));
        
        float r = texture(SCREEN_TEXTURE, uv_r).r;
        float g = texture(SCREEN_TEXTURE, uv).g;
        float b = texture(SCREEN_TEXTURE, uv_b).b;
        
        color = vec3(r, g, b);
        
        // Softer Scanlines
        float s = sin(uv.y * scanline_count * PI * 2.0);
        float scanline = 1.0 - (abs(s) * scanline_intensity);
        color *= scanline;
        
        // Vignette
        float d = distance(uv, vec2(0.5));
        float vignette = smoothstep(vignette_size, vignette_size - 0.5, d);
        color *= mix(1.0, vignette, vignette_intensity);
        
        // Noise
        float noise = random(uv + fract(TIME));
        color += (noise - 0.5) * noise_intensity;
        
        // Flicker
        float flicker = 1.0 + (random(vec2(TIME, 0.0)) - 0.5) * flicker_intensity;
        color *= flicker;
        
        // Color Grade
        color = (color - 0.5) * contrast + 0.5;
        color *= brightness;
        color *= tint_color.rgb;
        
        color = clamp(color, 0.0, 1.0);
        
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            color = vec3(0.0);
        }
    }
    
    COLOR = vec4(color, 1.0);
}
