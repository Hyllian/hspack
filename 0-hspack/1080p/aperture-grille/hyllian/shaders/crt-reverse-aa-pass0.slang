#version 450

/*
   CRT-Hyllian with Reverse Antialiasing Shader - horizontal pass

   Adapted from the C source (see Copyright below) to shader
   cg language by Hyllian/Jararaca - sergiogdb@gmail.com

   This shader works best in 2x scale.

*/

/*
 *
 *  Copyright (c) 2012, Christoph Feck <christoph@maxiom.de>
 *  All Rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are met:
 *
 *    * Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *
 *    * Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 */

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
    float CRT_InputGamma;
} params;

#pragma parameter CRT_InputGamma "  INPUT GAMMA" 2.4 1.0 5.0 0.1
#pragma parameter CRT_OutputGamma "OUTPUT GAMMA" 2.2 1.0 5.0 0.05
#pragma parameter PHOSPHOR_LAYOUT "PHOSPHOR LAYOUT [1-6 Aperture, 7-10 Shadow, 11-14 Slot]" 1.0 0.0 15.0 1.0
#pragma parameter MASK_DARK_STRENGTH "MASK DARK SUBPIXEL STRENGTH" 0.5 0.0 1.0 0.01
#pragma parameter MASK_LIGHT_STRENGTH "MASK LIGHT SUBPIXEL STRENGTH" 0.5 0.0 6.0 0.01
#pragma parameter MONITOR_SUBPIXELS "MONITOR SUBPIXELS LAYOUT [0=RGB, 1=BGR]" 0.0 0.0 1.0 1.0
#pragma parameter BRIGHTBOOST "BRIGHTNESS BOOST" 1.30 0.0 3.0 0.05
#pragma parameter BEAM_MIN_WIDTH "MIN BEAM WIDTH" 0.72 0.0 1.0 0.01
#pragma parameter BEAM_MAX_WIDTH "MAX BEAM WIDTH" 1.0 0.0 1.0 0.01
#pragma parameter SCANLINES_STRENGTH "SCANLINES STRENGTH" 0.72 0.0 1.0 0.01
#pragma parameter SCANLINES_SHAPE "SCANLINES SHAPE (SINC | GAUSSIAN)" 1.0 0.0 1.0 1.0
#pragma parameter SCANLINES_CUTOFF "SCANLINES CUTOFF" 300.0 0.0 1000.0 1.0
#pragma parameter SCANLINES_HIRES "HIGH RESOLUTION SCANLINES" 0.0 0.0 1.0 1.0
#pragma parameter IR_SCALE "INTERNAL RESOLUTION SCALE (downsampling)" 1.0 1.0 10.0 1.0
#pragma parameter POST_BRIGHTNESS "POST-BRIGHTNESS" 1.00 1.0 3.0 0.05
#pragma parameter CURVATURE "ENABLE CURVATURE" 0.0 0.0 1.0 1.0
#pragma parameter WARP_X "  CURVATURE-X" 0.020 0.0 0.125 0.005
#pragma parameter WARP_Y "  CURVATURE-Y" 0.025 0.0 0.125 0.005
#pragma parameter CORNER_SIZE "  CORNER SIZE" 0.02 0.001 1.0 0.005
#pragma parameter CORNER_SMOOTHNESS "  CORNER SMOOTHNESS" 1.10 1.0 2.2 0.02

#define CRT_InputGamma params.CRT_InputGamma


layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#define GAMMA_IN(color)    pow(color, vec3(CRT_InputGamma, CRT_InputGamma, CRT_InputGamma))

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * 1.0001;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define P(x,y) texture(Source, coord + params.SourceSize.zw * vec2(x, y)).rgb

vec3 res2x(vec3 pre2, vec3 pre1, vec3 px, vec3 pos1, vec3 pos2)
{
    vec3 t, m;
    mat4x3 pre = mat4x3(pre2, pre1,   px, pos1);
    mat4x3 pos = mat4x3(pre1,   px, pos1, pos2);
    mat4x3  df = pos - pre;

    m = 0.5 - abs(px - 0.5);
    m = 2.0 * min(m, min(abs(df[1]), abs(df[2])));
    t = (7 * (df[1] + df[2]) - 3 * (df[0] + df[3])) / 16;
    t = clamp(t, -m, m);


    return t;
}



void main()
{
   vec2 pos = fract(vTexCoord * params.SourceSize.xy) - vec2(0.5, 0.5);
   vec2 coord = vTexCoord - pos * params.SourceSize.zw;

    // D0  D  E  F F4

   vec3 D0 = GAMMA_IN( P(-2, 0) );
   vec3 D  = GAMMA_IN( P(-1, 0) );
   vec3 E  = GAMMA_IN( P( 0, 0) );
   vec3 F  = GAMMA_IN( P( 1, 0) );
   vec3 F4 = GAMMA_IN( P( 2, 0) );

   vec3 tx = res2x(D0, D, E, F, F4) * pos.x;

   vec3 res = clamp(E + 2.0*tx, 0.0, 1.0);

   FragColor = vec4(res, 1.0);
}
