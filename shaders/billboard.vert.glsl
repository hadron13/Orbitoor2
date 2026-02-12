#version 330

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTex;

out vec2 texCoord;

uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;

void main(){
    texCoord = aTex;
    mat4 view_billboarded = view;
    
    gl_Position = proj * view * model * vec4(aPos*2, 1.0);
    
}
