#include "common.h"

#define SMAA_HLSL_3
#define SMAA_RT_METRICS screen_res.zwxy

#if !defined(PP_AA_QUALITY) || (PP_AA_QUALITY <= 1) || (PP_AA_QUALITY > 4)
	#define	SMAA_PRESET_LOW
#elif PP_AA_QUALITY == 2
	#define	SMAA_PRESET_MEDIUM
#elif PP_AA_QUALITY == 3
	#define	SMAA_PRESET_HIGH
#elif PP_AA_QUALITY == 4
	#define	SMAA_PRESET_ULTRA
#endif

#include "smaa.h"

uniform sampler2D s_blendtex;

struct _in
{
	float2	tc0 : TEXCOORD0;
};

float4 main(_in I) : COLOR0
{
	// RainbowZerg: offset calculation can be moved to VS or CPU...
	float4 offset = mad(SMAA_RT_METRICS.xyxy, float4(1.0f, 0.0f, 0.0f, 1.0f), I.tc0.xyxy);
	return SMAANeighborhoodBlendingPS(I.tc0, offset, s_image, s_blendtex);
};
