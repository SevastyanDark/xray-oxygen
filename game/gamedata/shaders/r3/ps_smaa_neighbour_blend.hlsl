#include "common.h"

#if defined(SM_4_1) || defined(SM_5)
	#define SMAA_HLSL_4_1
#else
	#define SMAA_HLSL_4
#endif
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

Texture2D s_blendtex;

struct _in
{
	float4	pos	: SV_Position;
	float2	tc0 : TEXCOORD0;
};

float4 main(_in I) : SV_Target
{
	// RainbowZerg: offset calculation can be moved to VS or CPU...
	float4 offset = mad(SMAA_RT_METRICS.xyxy, float4(1.0f, 0.0f, 0.0f, 1.0f), I.tc0.xyxy);
	return SMAANeighborhoodBlendingPS(I.tc0, offset, s_image, s_blendtex);
};
