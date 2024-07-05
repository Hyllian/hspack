#version 450

/*
   SGENPT-MIX - Sega Genesis Pseudo Transparency Mixer Shader - v11 - Pass0
   
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
	float SGPT_GAMMA;
} params;

#pragma parameter SGPT_BLEND_OPTION        "SGENPT-MIX: [ OFF | CB | VL | VL+CB ]" 3.0  0.0 3.0 1.0
#pragma parameter SGPT_BLEND_LEVEL         "SGENPT-MIX: Blend Level"               0.85 0.0 1.0 0.01
#pragma parameter SGPT_BLEND_FINE_TUNING   "SGENPT-MIX: Blend Fine Tuning"         0.05 0.0 0.5 0.01
#pragma parameter SGPT_CONTRAST_THRESHOLD  "SGENPT-MIX: Contrast Threshold"        1.25 0.0 6.0 0.05
#pragma parameter SGPT_GAMMA               "SGENPT-MIX: Input Gamma"               2.0  1.0 3.0 0.05
#pragma parameter SGPT_ADJUST_VIEW         "SGENPT-MIX: Adjust View"               0.0  0.0 1.0 1.0

#define SGPT_GAMMA     params.SGPT_GAMMA

#define GAMMA_IN(color)     pow(color, vec3(SGPT_GAMMA, SGPT_GAMMA, SGPT_GAMMA))

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
   FragColor = vec4(GAMMA_IN(texture(Source, vTexCoord).rgb), 1.0);
}
