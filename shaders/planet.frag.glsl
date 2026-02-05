#version 330

//
// Description : Array and textureless GLSL 2D/3D/4D simplex 
//               noise functions.
//      Author : Ian McEwan, Ashima Arts.
//  Maintainer : stegu
//     Lastmod : 20201014 (stegu)
//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
//               Distributed under the MIT License. See LICENSE file.
//               https://github.com/ashima/webgl-noise
//               https://github.com/stegu/webgl-noise
// 

vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
     return mod289(((x*34.0)+10.0)*x);
}

vec4 taylorInvSqrt(vec4 r)
{
  return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v)
  { 
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

// First corner
  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 =   v - i + dot(i, C.xxx) ;

// Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );

  //   x0 = x0 - 0.0 + 0.0 * C.xxx;
  //   x1 = x0 - i1  + 1.0 * C.xxx;
  //   x2 = x0 - i2  + 2.0 * C.xxx;
  //   x3 = x0 - 1.0 + 3.0 * C.xxx;
  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
  vec3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

// Permutations
  i = mod289(i); 
  vec4 p = permute( permute( permute( 
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

// Gradients: 7x7 points over a square, mapped onto an octahedron.
// The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
  float n_ = 0.142857142857; // 1.0/7.0
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );

  //vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
  //vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);

//Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

// Mix final noise value
  vec4 m = max(0.5 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 105.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                dot(p2,x2), dot(p3,x3) ) );
  }


float ridged(vec3 p, int octaves){
    float value = 0; 
    float frequency = 1.0f;
    float amplitude = 1.0f;
    for (int i = 0; i < octaves; i++){
        float val = snoise((p + i) * frequency); 
        val = 1-abs(val);
        val *= val;

        value += val * amplitude;
        amplitude /= 2;
        frequency *= 2;
    }
    return value;
}

mat3 rotation_mat(vec3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;

    return mat3(
    oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  
    oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  
    oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c   
    );
}





vec2 sphIntersect( in vec3 ro, in vec3 rd, in vec3 ce, float ra ){
    vec3 oc = ro - ce;
    float b = dot( oc, rd );
    float c = dot( oc, oc ) - ra*ra;
    float h = b*b - c;
    if( h<0.0 ) return vec2(-1.0); // no intersection
    h = sqrt( h );
    return vec2( -b-h, -b+h );
}



vec3 ray_dir( float fov, vec2 size, vec2 pos ) {
	vec2 xy = pos - size * 0.5;

	float cot_half_fov = tan( radians( 90.0 - fov * 0.5 ) );	
	float z = size.y * -0.5 * cot_half_fov;
	
	return normalize( vec3( xy, -z ) );
}


uniform float time;
uniform vec2 resolution;
uniform vec3 camera_pos;
uniform vec3 camera_dir;

uniform vec3  body_origin;
uniform float body_radius;
uniform vec3  body_axis;
uniform float body_rotation_speed;
uniform vec3  body_color1;
uniform vec3  body_color2;
uniform vec3  sun_position;

uniform vec3  light_positions[8];
uniform vec4  light_colors[8];

uniform bool planet_has_sea;
uniform vec3 planet_sea_color;

uniform bool  planet_has_atmosphere;
uniform float planet_atmosphere_radius;
uniform vec3  planet_atmosphere_color;

uniform bool planet_has_ice_caps;
uniform vec3 planet_ice_color;


// Scattering written by GLtracy
// link: https://www.shadertoy.com/view/lslXDr

// math const
const float PI = 3.14159265359;
const float MAX = 10000.0;

// ray intersects sphere
// e = -b +/- sqrt( b^2 - c )
vec2 ray_vs_sphere( vec3 p, vec3 dir, float r ) {
	float b = dot( p, dir );
	float c = dot( p, p ) - r * r;
	
	float d = b * b - c;
	if ( d < 0.0 ) {
		return vec2( MAX, -MAX );
	}
	d = sqrt( d );
	
	return vec2( -b - d, -b + d );
}

// Mie
// g : ( -0.75, -0.999 )
//      3 * ( 1 - g^2 )               1 + c^2
// F = ----------------- * -------------------------------
//      8pi * ( 2 + g^2 )     ( 1 + g^2 - 2 * g * c )^(3/2)
float phase_mie( float g, float c, float cc ) {
	float gg = g * g;
	
	float a = ( 1.0 - gg ) * ( 1.0 + cc );

	float b = 1.0 + gg - 2.0 * g * c;
	b *= sqrt( b );
	b *= 2.0 + gg;	
	
	return ( 3.0 / 8.0 / PI ) * a / b;
}

// Rayleigh
// g : 0
// F = 3/16PI * ( 1 + c^2 )
float phase_ray( float cc ) {
	return ( 3.0 / 16.0 / PI ) * ( 1.0 + cc );
}

// scatter const
const float R_INNER = 1.0;
const float R = R_INNER + 0.5;

const int NUM_OUT_SCATTER = 4;
const int NUM_IN_SCATTER = 32;

float density( vec3 p, float ph ) {
	return exp( -max( (length( p ) - R_INNER) * 8.0, 0.0 ) / ph );
}

float optic( vec3 p, vec3 q, float ph ) {
	vec3 s = ( q - p ) / float( NUM_OUT_SCATTER );
	vec3 v = p + s * 0.5;
	
	float sum = 0.0;
	for ( int i = 0; i < NUM_OUT_SCATTER; i++ ) {
		sum += density( v, ph );
		v += s;
	}
	sum *= length( s );
	
	return sum;
}

vec3 in_scatter( vec3 o, vec3 dir, vec2 e, vec3 l ) {
	const float ph_ray = 0.05;
    const float ph_mie = 0.02;
    
    const vec3 k_ray = vec3( 3.8, 13.5, 33.1 );
    const vec3 k_mie = vec3( 21.0 );
    const float k_mie_ex = 1.1;
    
	vec3 sum_ray = vec3( 0.0 );
    vec3 sum_mie = vec3( 0.0 );
    
    float n_ray0 = 0.0;
    float n_mie0 = 0.0;
    
	float len = ( e.y - e.x ) / float( NUM_IN_SCATTER );
    vec3 s = dir * len;
	vec3 v = o + dir * ( e.x + len * 0.5 );
    
    for ( int i = 0; i < NUM_IN_SCATTER; i++, v += s ) {   
		float d_ray = density( v, ph_ray ) * len;
        float d_mie = density( v, ph_mie ) * len;
        
        n_ray0 += d_ray;
        n_mie0 += d_mie;
        
#if 0
        vec2 e = ray_vs_sphere( v, l, R_INNER );
        e.x = max( e.x, 0.0 );
        if ( e.x < e.y ) {
           continue;
        }
#endif
        
        vec2 f = ray_vs_sphere( v, l, R );
		vec3 u = v + l * f.y;
        
        float n_ray1 = optic( v, u, ph_ray );
        float n_mie1 = optic( v, u, ph_mie );
		
        vec3 att = exp( - ( n_ray0 + n_ray1 ) * k_ray - ( n_mie0 + n_mie1 ) * k_mie * k_mie_ex );
        
		sum_ray += d_ray * att;
        sum_mie += d_mie * att;
	}
	
	float c  = dot( dir, -l );
	float cc = c * c;
    vec3 scatter =
        sum_ray * k_ray * phase_ray( cc ) +
     	sum_mie * k_mie * phase_mie( -0.78, c, cc );
    
	
	return 10.0 * scatter;
}

void main(){
    vec2 uv = gl_FragCoord.xy/resolution.y - vec2((resolution.x/resolution.y - 1.0)/2.0, 0);
    vec2 centered_uv = (uv - 0.5)*2;

    vec3 cam_right = normalize(cross(camera_dir, vec3(0, 1.0f, 0))); 
    vec3 cam_up = normalize(cross(cam_right, camera_dir));

    vec3 ray_origin = camera_pos;
    vec3 rd = ray_dir(90.0, vec2(1.0), uv);
    vec3 ray_direction = rd.x * cam_right + rd.y * cam_up + rd.z * camera_dir;
    // vec3 ray_direction = normalize(centered_uv.x * cam_right + centered_uv.y * cam_up + camera_dir );
    // vec3 ray_direction = normalize(camera_dir + ray_dir( 90.0, resolution.xy, gl_FragCoord.xy ));


    vec2 ground_intersection = sphIntersect(ray_origin, ray_direction, body_origin, body_radius);
    vec2 atm_intersection = vec2(0);
    vec2 closest_intersection = ground_intersection;

    if(planet_has_atmosphere){
        atm_intersection = sphIntersect(ray_origin, ray_direction, body_origin, planet_atmosphere_radius);
        closest_intersection = atm_intersection; 
        if(atm_intersection.y < 0.0){
            discard;
        }
    }else{
        if(ground_intersection.y < 0.0){
            discard;
        }
    }
    

    float z_far = 100000000.0;
    float z_near = 0.1;

    float A = (z_far + z_near) / (z_far - z_near);
    float B = (-2.0 * z_far * z_near) / (z_far - z_near);

    float depth = A + 1/closest_intersection.x * B;
    gl_FragDepth = depth;

    int octaves = 6 - clamp(int(sqrt(closest_intersection.x/body_radius)), 0, 3);


    vec3 intersection_point = normalize(ray_origin + ray_direction * ground_intersection.x - body_origin); 

    vec3 sphere_normal = normalize(intersection_point); 
    vec3 tangent_right = normalize(cross(vec3(0, 1.0, 0), sphere_normal));
    vec3 tangent_up = normalize(cross(tangent_right, sphere_normal));
  
    intersection_point *= rotation_mat(body_axis, time * body_rotation_speed);
    float height = ridged(intersection_point, octaves);
    
    float eps = 0.0005;
    float height_north = ridged(intersection_point + eps * tangent_up, octaves);
    float height_south = ridged(intersection_point - eps * tangent_up, octaves);
    float height_east = ridged(intersection_point  + eps * tangent_right, octaves);
    float height_west = ridged(intersection_point  - eps * tangent_right, octaves);

    vec3 noise_normal = normalize(vec3(height_west - height_east, height_south - height_north, 0.05));
    vec3 normal = normalize(noise_normal.x * tangent_right + noise_normal.y * tangent_up + noise_normal.z * sphere_normal);

    vec3 ground_color = body_color1;

    if(planet_has_sea && height < 1.1){
        ground_color = planet_sea_color;
        normal = sphere_normal;
    }

    float polarness = abs(intersection_point.y) / (body_radius*0.8f);

    if(planet_has_ice_caps && polarness + height*0.1 > 1.0){
        ground_color = planet_ice_color;
    }
   
    float diffuse = 0;
    for(int i = 0; i < 8; i++){
        vec3 to_light = light_positions[i] - body_origin;
        float distance = length(to_light);
        float attenuation = 1.0 / (0.1 + 0.01 * distance + 0.005 * distance * distance);

        vec3 light_direction = normalize(to_light); 
        diffuse += max(0.0, dot(sphere_normal, light_direction) * max(0.1, dot(normal, light_direction))) * light_colors[i].w * attenuation;
    }

    vec3 light_dir = normalize(light_positions[0] - body_origin);

    vec3 eye = (ray_origin-body_origin)/body_radius;

    vec2 e = ray_vs_sphere( eye, ray_direction, R );	
	vec2 f = ray_vs_sphere( eye, ray_direction, R_INNER );
	e.y = min( e.y, f.x );
    vec3 scatter = in_scatter( eye, ray_direction, e, light_dir );

    scatter = 1.0 - exp(-scatter);

    if(ground_intersection.y < 0.0){ 
        gl_FragColor = vec4(scatter, min(1.0, length(scatter)));
    }else{
        gl_FragColor = vec4(mix(diffuse * ground_color, scatter, 0.9), 1.0);
    }
    // gl_FragColor = vec4(scatter, 1.0);
}
