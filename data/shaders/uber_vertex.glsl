#version 450 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 uv;
layout (location = 0) out vec2 outUV;
layout (location = 1) out vec3 outNormal;

layout (std140, binding = 0) uniform SceneTransformBlock {
    mat4 view_matrix;
    mat4 proj_matrix;
} scene;

layout (std140, binding = 1) uniform ObjectTransformBlock {
    mat4 model_matrix;
} object;

void main() {
    gl_Position = scene.proj_matrix * scene.view_matrix * object.model_matrix * vec4(position.xyz, 1.0);
    outUV = uv;
    outNormal = normal;
};
