#version 450

/*
   SGENPT-MIX - Sega Genesis Pseudo Transparency Mixer Shader - v11 - Pass2
   
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
	float SGPT_CONTRAST_THRESHOLD;
	float SGPT_ADJUST_VIEW;
	float SGPT_GAMMA;
} params;

#pragma parameter SGPT_BLEND_OPTION        "SGENPT-MIX: [ OFF | CB | VL | VL+CB ]" 3.0  0.0 3.0 1.0
#pragma parameter SGPT_BLEND_LEVEL         "SGENPT-MIX: Blend Level"               0.85 0.0 1.0 0.01
#pragma parameter SGPT_BLEND_FINE_TUNING   "SGENPT-MIX: Blend Fine Tuning"         0.05 0.0 0.5 0.01
#pragma parameter SGPT_CONTRAST_THRESHOLD  "SGENPT-MIX: Contrast Threshold"        1.25 0.0 6.0 0.05
#pragma parameter SGPT_GAMMA               "SGENPT-MIX: Input Gamma"               2.0  1.0 3.0 0.05
#pragma parameter SGPT_ADJUST_VIEW         "SGENPT-MIX: Adjust View"               0.0  0.0 1.0 1.0

#define SGPT_BLEND_OPTION params.SGPT_BLEND_OPTION
#define SGPT_BLEND_LEVEL params.SGPT_BLEND_LEVEL
#define SGPT_BLEND_FINE_TUNING params.SGPT_BLEND_FINE_TUNING
#define SGPT_CONTRAST_THRESHOLD params.SGPT_CONTRAST_THRESHOLD
#define SGPT_ADJUST_VIEW params.SGPT_ADJUST_VIEW
#define SGPT_GAMMA params.SGPT_GAMMA

#define GAMMA_OUT(color)	pow(color, vec3(1.0 / SGPT_GAMMA, 1.0 / SGPT_GAMMA, 1.0 / SGPT_GAMMA))

#define PATTERN(A)              step(Delta,A)

#define SGPT_MITIG_NEIGHBRS     4.0
#define SGPT_MITIG_LINES        1.0

const float Delta = 0.000000001;

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
layout(set = 0, binding = 3) uniform sampler2D LinearGamma;

void main()
{
	vec2 dx = vec2(1.0, 0.0)*params.SourceSize.zw;
	vec2 dy = vec2(0.0, 1.0)*params.SourceSize.zw;

	// Reading the texels.
	vec4 C =  texture(Source, vTexCoord        );
	vec4 L =  texture(Source, vTexCoord -dx    );
	vec4 R =  texture(Source, vTexCoord +dx    );
	vec4 U =  texture(Source, vTexCoord     -dy);
	vec4 D =  texture(Source, vTexCoord     +dy);
	vec4 UL = texture(Source, vTexCoord -dx -dy);
	vec4 UR = texture(Source, vTexCoord +dx -dy);
	vec4 DL = texture(Source, vTexCoord -dx +dy);
	vec4 DR = texture(Source, vTexCoord +dx +dy);

	vec4 L2 =  texture(Source, vTexCoord -2.0*dx    );
	vec4 R2 =  texture(Source, vTexCoord +2.0*dx    );
	vec4 U2 =  texture(Source, vTexCoord     -2.0*dy);
	vec4 D2 =  texture(Source, vTexCoord     +2.0*dy);

	vec4 L3 =  texture(Source, vTexCoord -3.0*dx    );
	vec4 R3 =  texture(Source, vTexCoord +3.0*dx    );
	vec4 U3 =  texture(Source, vTexCoord     -3.0*dy);
	vec4 D3 =  texture(Source, vTexCoord     +3.0*dy);

	vec3 color =  C.rgb;

	vec3 oriC = texture(LinearGamma, vTexCoord        ).rgb;
	vec3 oriL = texture(LinearGamma, vTexCoord -dx    ).rgb;
	vec3 oriR = texture(LinearGamma, vTexCoord +dx    ).rgb;

	float count   = 0.0;
	float count2  = 0.0;
	float count3  = 0.0;

//              U3
//              U2     
//          UL   U  UR     
//  L3  L2   L   C   R   R2  R3
//          DL   D  DR     
//              D2     
//              D3


	count += PATTERN(L.a);
	count += PATTERN(R.a);
	count += PATTERN(U.a);
	count += PATTERN(D.a);
	count += PATTERN(UL.a*UR.a*DL.a*DR.a);

	count2 += PATTERN(L.a*UL.a*U.a + U.a*UR.a*R.a + R.a*DR.a*D.a + D.a*DL.a*L.a);

	count3 += PATTERN(L3.a*L2.a*L.a);
	count3 += PATTERN(L2.a*L.a*R.a);
	count3 += PATTERN(L.a*R.a*R2.a);
	count3 += PATTERN(R.a*R2.a*R3.a);

	count3 += PATTERN(U3.a*U2.a*U.a);
	count3 += PATTERN(U2.a*U.a*D.a);
	count3 += PATTERN(U.a*D.a*D2.a);
	count3 += PATTERN(D.a*D2.a*D3.a);

	    float diff = dot(max(oriC, max(oriL, oriR)) - min(oriC, min(oriL, oriR)), Y);

	    diff *= SGPT_CONTRAST_THRESHOLD;

	if (((count < SGPT_MITIG_NEIGHBRS)  && (count2 < 1.0)) || ((SGPT_MITIG_LINES == 1.0) && (count3 < 1.0)))
	{
		vec3 aux = 0.5*( oriC + oriR + diff*( oriC - oriR ));
		color    = 0.5*( oriC + oriL + diff*( oriC - oriL ));
		color = mix(aux, color, step(dot(abs(oriC-color), Y), dot(abs(oriC-aux), Y)));
	}


	float luma_diff = abs(dot(oriC, Y)-dot(color, Y));

	color = mix(color, vec3(luma_diff), SGPT_ADJUST_VIEW);

	FragColor = vec4(GAMMA_OUT(color), 1.0);
}
