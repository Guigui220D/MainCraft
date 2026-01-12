#version 330

in vec3 vertexPosition;     // Vertex input attribute: position
in vec2 vertexTexCoord;     // Vertex input attribute: texture coordinate
in vec4 vertexColor;        // Vertex input attribute: color
in vec3 vertexNormal;       // Vertex input attribute: normal

out vec2 fragTexCoord;      // To-fragment attribute: texture coordinate
out vec4 fragColor;         // To-fragment attribute: color

uniform mat4 mvp;           // Model-View-Projection matrix

uniform isampler2D blocklight;
uniform isampler2D skylight;

void main()
{
    gl_Position = mvp * vec4(vertexPosition, 1.0);
    fragTexCoord = vertexTexCoord;

    vec3 n = vertexNormal;
    
    int nx = int(n.x);
    int ny = int(n.y);
    int nz = int(n.z);

    // Default values
    float blight = 1.0;
    float slight = 1.0;

    vec4 color = vertexColor;
    
    // Access uniform
    if (nx >= 0 && nx < 16 && ny >= 0 && ny < 128 && nz >= 0 && nz < 16) {
        // Index
        int index = ny + nx * 128 * 16 + nz * 128;
        int actualIndex = index / 8;

        if (actualIndex >= textureSize(blocklight, 0).x)
            color.g = 0; // Debug reading blocklight out of bounds

        int blVal = texelFetch(blocklight, ivec2(actualIndex, 0), 0).r;
        int slVal = texelFetch(skylight, ivec2(actualIndex, 0), 0).r;

        int byteIndex = (index / 2) % 4;
        int blByte = 0;
        int slByte = 0;
        // Get correct byte in integer
        switch (byteIndex) {
            case 3:
                blByte = blVal & 0xFF;
                slByte = slVal & 0xFF;
                break;
            case 2:
                blByte = (blVal >> 8) & 0xFF;
                slByte = (slVal >> 8) & 0xFF;
                break;
            case 1:
                blByte = (blVal >> 16) & 0xFF;
                slByte = (slVal >> 16) & 0xFF;
                break;
            case 0:
                blByte = (blVal >> 24) & 0xFF;
                slByte = (slVal >> 24) & 0xFF;
                break;
        }

        // Assign light levels
        if (index % 2 == 0) {
            blight = float((blByte >> 4) & 0xf) / 16.0;
            slight = float((slByte >> 4) & 0xf) / 16.0;
        } else {
            blight = float(blByte & 0xf) / 16.0;
            slight = float(slByte & 0xf) / 16.0;
        }
    }

    float light = (max(blight, slight) + 0.2) / 1.2;

    fragColor = vec4(color.rgb * light, color.a);
}
