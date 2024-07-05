#version 450

/*
	Fragment shader based on "Improved texture interpolation" by Iñigo Quílez
	Original description: http://www.iquilezles.org/www/articles/texture/texture.htm

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float OUTPUT_GAMMA;
	float BRIGHTBOOST;
    float CURVATURE;
    float WARP_X;
    float WARP_Y;
    float CORNER_SIZE;
    float CORNER_SMOOTHNESS;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter OUTPUT_GAMMA "OUTPUT GAMMA" 2.2 1.0 5.0 0.05
#pragma parameter BRIGHTBOOST "BRIGHTNESS BOOST" 1.20 1.0 3.0 0.05
#pragma parameter CURVATURE "ENABLE CURVATURE" 1.0 0.0 1.0 1.0
#pragma parameter WARP_X "  CURVATURE-X" 0.015 0.0 0.125 0.005
#pragma parameter WARP_Y "  CURVATURE-Y" 0.015 0.0 0.125 0.005
#pragma parameter CORNER_SIZE "  CORNER SIZE" 0.01 0.001 1.0 0.005
#pragma parameter CORNER_SMOOTHNESS "  CORNER SMOOTHNESS" 1.10 1.0 2.2 0.02

#define OUTPUT_GAMMA params.OUTPUT_GAMMA
#define BRIGHTBOOST params.BRIGHTBOOST
#define CURVATURE params.CURVATURE
#define WARP_X params.WARP_X
#define WARP_Y params.WARP_Y
#define CORNER_SIZE params.CORNER_SIZE
#define CORNER_SMOOTHNESS (80.0*pow(params.CORNER_SMOOTHNESS,10.0))

#define GAMMA_OUT(color)   pow(color, vec4(1.0 / OUTPUT_GAMMA, 1.0 / OUTPUT_GAMMA, 1.0 / OUTPUT_GAMMA, 1.0 / OUTPUT_GAMMA))


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const vec2 corner_aspect   = vec2(1.0,  0.75);

float corner(vec2 coord)
{
    coord = (coord - vec2(0.5)) + vec2(0.5, 0.5);
    coord = min(coord, vec2(1.0) - coord) * corner_aspect;
    vec2 cdist = vec2(CORNER_SIZE);
    coord = (cdist - min(coord, cdist));
    float dist = sqrt(dot(coord, coord));
    
    return clamp((cdist.x - dist)*CORNER_SMOOTHNESS, 0.0, 1.0);
}

/* Curvature code. Credits to torridgristle! */
vec2 CRT_Distortion = vec2(WARP_X, WARP_Y) * 15.;

#define SQRT_OF_2  1.4142135623730950488016887242097

// Radius of Convergence = 1.0 - SQRT_OF_2 / 2

#define CONVERGENCE_RADIUS 0.29289321881345247559915563789515

vec2 Warp(vec2 texCoord)
{
   vec2 cCoords = texCoord * 2.0 - 1.0;
   float cCoordsDist = sqrt(cCoords.x * cCoords.x + cCoords.y * cCoords.y);
   cCoords = cCoords / cCoordsDist;
   cCoords = cCoords * (1.0 - pow(vec2(1.0 - (cCoordsDist/SQRT_OF_2)),(1.0/(1.0+CRT_Distortion*0.2))));
   cCoords = cCoords / (1.0-pow(vec2(CONVERGENCE_RADIUS),(1.0/(vec2(1.0)+CRT_Distortion*0.2))));
   cCoords = cCoords * 0.5 + 0.5;

   return cCoords;
}

void main()
{
    vec2 WarpedTexCoord = vTexCoord.xy;

    WarpedTexCoord = (CURVATURE > 0.5) ? Warp(WarpedTexCoord) : WarpedTexCoord;

	vec2 p = WarpedTexCoord.xy;

	p = p * params.SourceSize.xy + vec2(0.5, 0.5);

	vec2 i = floor(p);
	vec2 f = p - i;
	f = f * f * f * (f * (f * 6.0 - vec2(15.0, 15.0)) + vec2(10.0, 10.0));
	p = i + f;

	p = (p - vec2(0.5, 0.5)) * params.SourceSize.zw;

	// final sum and weight normalization
	vec3 color = BRIGHTBOOST * texture(Source, p).rgb;

	FragColor = GAMMA_OUT(vec4(color, 1.0));

	FragColor *= (CURVATURE > 0.5) ? corner(WarpedTexCoord) : 1.0;
}
