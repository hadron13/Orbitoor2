#version 330

#define PI 3.14159265359


// Cellular noise ("Worley noise") in 2D in GLSL.
// Copyright (c) Stefan Gustavson 2011-04-19. All rights reserved.
// This code is released under the conditions of the MIT license.
// See LICENSE file for details.
// https://github.com/stegu/webgl-noise

// Modulo 289 without a division (only multiplications)
vec2 mod289(vec2 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

// Modulo 7 without a division
vec4 mod7(vec4 x) {
  return x - floor(x * (1.0 / 7.0)) * 7.0;
}

// Permutation polynomial: (34x^2 + 6x) mod 289
vec4 permute(vec4 x) {
  return mod289((34.0 * x + 10.0) * x);
}

// Cellular noise, returning F1 and F2 in a vec2.
// Speeded up by using 2x2 search window instead of 3x3,
// at the expense of some strong pattern artifacts.
// F2 is often wrong and has sharp discontinuities.
// If you need a smooth F2, use the slower 3x3 version.
// F1 is sometimes wrong, too, but OK for most purposes.
vec2 cellular2x2(vec2 P) {
#define K 0.142857142857 // 1/7
#define K2 0.0714285714285 // K/2
#define jitter 0.8 // jitter 1.0 makes F1 wrong more often
	vec2 Pi = mod289(floor(P));
 	vec2 Pf = fract(P);
	vec4 Pfx = Pf.x + vec4(-0.5, -1.5, -0.5, -1.5);
	vec4 Pfy = Pf.y + vec4(-0.5, -0.5, -1.5, -1.5);
	vec4 p = permute(Pi.x + vec4(0.0, 1.0, 0.0, 1.0));
	p = permute(p + Pi.y + vec4(0.0, 0.0, 1.0, 1.0));
	vec4 ox = mod7(p)*K+K2;
	vec4 oy = mod7(floor(p*K))*K+K2;
	vec4 dx = Pfx + jitter*ox;
	vec4 dy = Pfy + jitter*oy;
	vec4 d = dx * dx + dy * dy; // d11, d12, d21 and d22, squared
	// Sort out the two smallest distances
#if 0
	// Cheat and pick only F1
	d.xy = min(d.xy, d.zw);
	d.x = min(d.x, d.y);
	return vec2(sqrt(d.x)); // F1 duplicated, F2 not computed
#else
	// Do it right and find both F1 and F2
	d.xy = (d.x < d.y) ? d.xy : d.yx; // Swap if smaller
	d.xz = (d.x < d.z) ? d.xz : d.zx;
	d.xw = (d.x < d.w) ? d.xw : d.wx;
	d.y = min(d.y, d.z);
	d.y = min(d.y, d.w);
	return sqrt(d.xy);
#endif
}

vec4 BlackBodyRadiation(float T, bool bComputeRadiance){

    vec4 ChromaRadiance = vec4(0.0, 0.0, 0.0, 0.0);
    
    // --- Effective radiance in W/(sr*m2) ---
    if(bComputeRadiance)
        ChromaRadiance.a = 230141698.067 / (exp(25724.2/T) - 1.0);
    
    // luminance Lv = Km*ChromaRadiance.a in cd/m2, where Km = 683.002 lm/W
    
    // --- Chromaticity in linear sRGB ---
    // (i.e. color luminance Y = dot({r,g,b}, {0.2126, 0.7152, 0.0722}) = 1)
    // --- R ---
    float u = 0.000536332*T;
    ChromaRadiance.r = 0.638749 + (u + 1.57533) / (u*u + 0.28664);
    
    // --- G ---
    u = 0.0019639*T;
    ChromaRadiance.g = 0.971029 + (u - 10.8015) / (u*u + 6.59002);
    
    // --- B ---
    float p = 0.00668406*T + 23.3962;
    u = 0.000941064*T;
    float q = u*u + 0.00100641*T + 10.9068;
    ChromaRadiance.b = 2.25398 - p/q;
    
    return ChromaRadiance;
}


float rand(vec2 n) { 
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 p){
	vec2 ip = floor(p);
	vec2 u = fract(p);
	u = u*u*(3.0-2.0*u);
	
	float res = mix(
		mix(rand(ip),rand(ip+vec2(1.0,0.0)),u.x),
		mix(rand(ip+vec2(0.0,1.0)),rand(ip+vec2(1.0,1.0)),u.x),u.y);
	return res*res;
}

uniform vec2 resolution;
uniform vec3 camera_dir;

void main(){
    vec2 uv = gl_FragCoord.xy/resolution.y - vec2((resolution.x/resolution.y - 1.0)/2.0, 0);
    vec2 centered_uv = (uv - 0.5)*2;

    vec3 cam_right = normalize(cross(camera_dir, vec3(0, 1.0f, 0))); 
    vec3 cam_up = normalize(cross(cam_right, camera_dir));

    vec3 ray_direction = normalize(centered_uv.x * cam_right + centered_uv.y * cam_up + camera_dir );

    vec2 coord = vec2(
        atan(ray_direction.z, ray_direction.x) / (2.0f * PI) + 0.5,   
        asin(ray_direction.y) / PI + 0.5f    
    );
    
    vec2 worley = cellular2x2( coord * vec2(900.0f, 300.0f));
    vec2 worley2 = cellular2x2( coord * vec2(300.0f, 100.0f));
   
    float threshold = step(0.95,worley.x);
    float temperature = noise(uv*100) * 25000;

    vec4 star_color = BlackBodyRadiation(temperature, false);

    gl_FragColor = vec4(star_color.rgb * threshold, 1.0);
}
