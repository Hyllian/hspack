#version 450

/*
   SGENPT-MIX - Sega Genesis Pseudo Transparency Mixer Shader - v11 - Pass1
   
   2011-2024 Hyllian - sergiogdb@gmail.com

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is 
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

*/


layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SGPT_BLEND_OPTION;
	float SGPT_BLEND_LEVEL;
	float SGPT_BLEND_FINE_TUNING;
	float SGPT_ADJUST_VIEW;
} params;

#pragma parameter SGPT_BLEND_OPTION        "SGENPT-MIX: [ OFF | CB | VL | VL+CB ]" 3.0  0.0 3.0 1.0
#pragma parameter SGPT_BLEND_LEVEL         "SGENPT-MIX: Blend Level"               0.85 0.0 1.0 0.01
#pragma parameter SGPT_BLEND_FINE_TUNING   "SGENPT-MIX: Blend Fine Tuning"         0.05 0.0 0.5 0.01
#pragma parameter SGPT_ADJUST_VIEW         "SGENPT-MIX: Adjust View"               0.0  0.0 1.0 1.0

#define SGPT_BLEND_OPTION params.SGPT_BLEND_OPTION
#define SGPT_BLEND_LEVEL params.SGPT_BLEND_LEVEL
#define SGPT_BLEND_FINE_TUNING params.SGPT_BLEND_FINE_TUNING
#define SGPT_ADJUST_VIEW params.SGPT_ADJUST_VIEW

const vec3 Y = vec3( 0.299,  0.587,  0.114);

vec3 min_s(vec3 central, vec3 adj1, vec3 adj2) {return min(central, max(adj1, adj2));}
vec3 max_s(vec3 central, vec3 adj1, vec3 adj2) {return max(central, min(adj1, adj2));}

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;


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

void main()
{
	vec2 dx = vec2(1.0, 0.0)*params.SourceSize.zw;
	vec2 dy = vec2(0.0, 1.0)*params.SourceSize.zw;

	// Reading the texels.
	vec3 C = texture(Source, vTexCoord    ).xyz;
	vec3 L = texture(Source, vTexCoord -dx).xyz;
	vec3 R = texture(Source, vTexCoord +dx).xyz;
	vec3 L2 = texture(Source, vTexCoord -2.0*dx).xyz;
	vec3 R2 = texture(Source, vTexCoord +2.0*dx).xyz;

	//  Get medium samples
	vec3 min_sample = min_s(C, L, R);
	vec3 max_sample = max_s(C, L, R);

	float contrast = dot(max(C, max(L, R)) - min(C, min(L, R)), Y);

	contrast = smoothstep(0.0, 1.0, (1.0 - SGPT_BLEND_LEVEL) * contrast);

	if (SGPT_BLEND_OPTION == 1) // Only Checkerboard
	{
		vec3 U = texture(Source, vTexCoord -dy).xyz;
		vec3 D = texture(Source, vTexCoord +dy).xyz;

		min_sample = max(min_sample, min_s(C, U, D));
		max_sample = min(max_sample, max_s(C, U, D));
	}
	else if (SGPT_BLEND_OPTION == 2) // Only Vertical Lines
	{
		vec3 UL = texture(Source, vTexCoord -dx -dy).xyz;
		vec3 UR = texture(Source, vTexCoord +dx -dy).xyz;
		vec3 DL = texture(Source, vTexCoord -dx +dy).xyz;
		vec3 DR = texture(Source, vTexCoord +dx +dy).xyz;

		min_sample = max_s(min_sample, min_s(C, DL, DR), min_s(C, UL, UR));
		max_sample = min_s(max_sample, max_s(C, DL, DR), max_s(C, UL, UR));

	}

	float K = SGPT_BLEND_FINE_TUNING;

	vec3 CL = (1.0+K)*L - K*L2;
	vec3 CR = (1.0+K)*R - K*R2;

	vec3 col_L = 0.5*( C + CL + contrast*( C - CL ));
	vec3 col_R = 0.5*( C + CR + contrast*( C - CR ));

	float contrast_L = dot(abs(C - col_L), Y);
	float contrast_R = dot(abs(C - col_R), Y);

	// Choose smaller contrast
	vec3 color = contrast_R < contrast_L ? col_R : col_L;

	color = SGPT_BLEND_OPTION > 0.5 ? clamp(color, min_sample, max_sample) : C;

	float luma_diff = abs(dot(C, Y)-dot(color, Y));

	FragColor = vec4(color, luma_diff);
}
