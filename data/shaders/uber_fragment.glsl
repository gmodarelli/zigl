#version 450 core

layout (location = 0) in vec2 uv;
layout (location = 1) in vec3 normal;
layout (binding = 0) uniform sampler2D albedo;

out vec4 color;

void main() {
    color = texture(albedo, uv);
}