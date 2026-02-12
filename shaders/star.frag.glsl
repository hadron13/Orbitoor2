#version 330


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


void main(){ 
    vec2 uv = gl_FragCoord.xy/resolution.y - vec2((resolution.x/resolution.y - 1.0)/2.0, 0);
    vec2 centered_uv = (uv - 0.5)*2;

    vec3 cam_right = normalize(cross(camera_dir, vec3(0, 1.0f, 0))); 
    vec3 cam_up = normalize(cross(cam_right, camera_dir));

    vec3 ray_origin = camera_pos;
    // vec3 ray_direction = normalize(centered_uv.x * cam_right + centered_uv.y * cam_up + camera_dir );
    vec3 rd = ray_dir(90.0, vec2(1.0), uv);
    vec3 ray_direction = rd.x * cam_right + rd.y * cam_up + rd.z * camera_dir;

    vec2 inner_intersection = sphIntersect(ray_origin, ray_direction, body_origin, body_radius);
    vec2 outer_intersection = sphIntersect(ray_origin, ray_direction, body_origin, body_radius * 8.0);

    if(outer_intersection.y < 0.0){
        discard;
    }else{
    }


    // float z_far = 1495978707000.0;
    // float z_near = 0.1;
    //
    // float A = (z_far + z_near) / (z_far - z_near);
    // float B = (-2.0 * z_far * z_near) / (z_far - z_near);
    //
    // float depth = A + 1/outer_intersection.x * B;
    // gl_FragDepth = depth;

    // float inner_thickness = (inner_intersection.y - inner_intersection.x)/1.0;
    float atmospheric_thickness = (outer_intersection.y - outer_intersection.x)/1.0;

    // float travel = outer_intersection.x < 0.0f? outer_intersection.y : outer_intersection.x;

    float height = distance(ray_origin + ray_direction * (outer_intersection.x + atmospheric_thickness/2.0), body_origin)/body_radius;

    
    if(inner_intersection.y < 0.0){
        gl_FragColor = vec4(body_color1 , exp(-height));
    }else{
        gl_FragColor = vec4(body_color1 , 1.0);
    }

}

