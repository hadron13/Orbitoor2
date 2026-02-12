#version 330

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
// layout (location = 1) in vec2 aTex;

// out vec2 texCoord;
out vec3 normal;
out vec3 position;

uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;

uniform mat4 mvp;

void main(){
    // texCoord = aTex;
    normal = aNormal;
    position = aPos;
    gl_Position = proj * view * model * vec4(aPos, 1.0);
    // gl_Position = mvp * vec4(aPos, 1.0);
}

