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


void main(){ 
    vec2 uv = gl_FragCoord.xy/resolution.y - vec2((resolution.x/resolution.y - 1.0)/2.0, 0);
    vec2 centered_uv = (uv - 0.5)*2;

    vec3 cam_right = normalize(cross(camera_dir, vec3(0, 1.0f, 0))); 
    vec3 cam_up = normalize(cross(cam_right, camera_dir));

    vec3 ray_origin = camera_pos;
    vec3 ray_direction = normalize(centered_uv.x * cam_right + centered_uv.y * cam_up + camera_dir );

    vec2 inner_intersection = sphIntersect(ray_origin, ray_direction, body_origin, body_radius * 0.9f);
    vec2 outer_intersection = sphIntersect(ray_origin, ray_direction, body_origin, body_radius);
    
    if(outer_intersection.y < 0.0){
        discard;
    }


    float z_far = 1000.0;
    float z_near = 0.1;

    float A = (z_far + z_near) / (z_far - z_near);
    float B = (-2.0 * z_far * z_near) / (z_far - z_near);

    float depth = A + 1/outer_intersection.x * B;
    gl_FragDepth = depth;
    
    if(inner_intersection.y < 0.0){
        gl_FragColor = vec4(body_color1, 0.8);
    }else{
        gl_FragColor = vec4(body_color1, 1.0);
    }

}

