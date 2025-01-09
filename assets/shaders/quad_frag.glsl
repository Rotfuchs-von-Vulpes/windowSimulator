#version 330 core
out vec4 FragColor;
  
in vec2 TexCoords;

uniform sampler2D screenTexture;
uniform sampler2D normalTexture;

void main()
{
    vec3 normal = normalize((texture(normalTexture, TexCoords).xyz * 2.0) - 1.0);
    vec2 uv = TexCoords;
    uv += refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / 1.333).xy;
    vec4 color = texture(screenTexture, uv); 
    FragColor = vec4(color.rgb, 1.0);
}