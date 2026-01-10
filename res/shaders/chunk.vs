#version 330

in vec3 vertexPosition;     // Vertex input attribute: position
in vec2 vertexTexCoord;     // Vertex input attribute: texture coordinate
in vec4 vertexColor;        // Vertex input attribute: color
in vec3 vertexNormal;       // Vertex input attribute: normal

out vec2 fragTexCoord;      // To-fragment attribute: texture coordinate
out vec4 fragColor;         // To-fragment attribute: color

uniform mat4 mvp;           // Model-View-Projection matrix

void main()
{
    gl_Position = mvp * vec4(vertexPosition, 1.0);
    fragTexCoord = vertexTexCoord;

    vec3 n = vertexNormal;
    float t = 0.1;

    // Near-zero normal
    vec4 color = vec4(1.0, 1.0, 1.0, 1.0); // white

    if (abs(n.x) > t)
    {
        color = (n.x > 0.0)
            ? vec4(1.0, 0.0, 0.0, 1.0)   // +X red
            : vec4(1.0, 1.0, 0.0, 1.0);  // -X yellow
    }
    else if (abs(n.y) > t)
    {
        color = (n.y > 0.0)
            ? vec4(0.0, 1.0, 0.0, 1.0)   // +Y green
            : vec4(0.0, 1.0, 1.0, 1.0);  // -Y cyan
    }
    else if (abs(n.z) > t)
    {
        color = (n.z > 0.0)
            ? vec4(0.0, 0.0, 1.0, 1.0)   // +Z blue
            : vec4(1.0, 0.0, 1.0, 1.0);  // -Z magenta
    }

    fragColor = color;
}
