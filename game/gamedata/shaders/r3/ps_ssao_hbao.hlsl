#ifndef	SSAO_QUALITY

float4 calc_hbao(float z, float3 N, float2 tc0, float4 pos2d)
{
	return 1.0;
}

#else	//	SSAO_QUALITY

//cbuffer PixelGlobalShaderData_s : register(b0)
//{

//uniform	float4		screen_res;

#define g_Resolution screen_res.xy
#define g_InvResolution screen_res.zw

static const float g_MaxFootprintUV=0.01f;

#if SSAO_QUALITY == 3
static const float g_NumDir = 6.0f;
static const float g_NumSteps = 3.0f;
#elif SSAO_QUALITY == 2
static const float g_NumDir = 5.0f;
static const float g_NumSteps = 3.0f;
#elif SSAO_QUALITY == 1
static const float g_NumDir = 4.0f;
static const float g_NumSteps = 3.0f;
#endif

//  static const float g_Contrast = 1.5f;
  static const float g_Contrast = 0.8f;
  static const float g_AngleBias = 0.0f;


  static const float g_R = 0.400009334f;
  static const float g_sqr_R = 0.160007462f;
  static const float g_inv_R = 2.49994159f;

uniform texture2D 	jitter4;

#define M_PI 3.1415926f

//----------------------------------------------------------------------------------
struct PostProc_VSOut
{
    float4 pos   : SV_Position;
    float2 texUV : TEXCOORD0;
};

//----------------------------------------------------------------------------------
float tangent(float3 P, float3 S)
{
    return (P.z - S.z) / length(S.xy - P.xy);
}

//----------------------------------------------------------------------------------
float tangent(float3 T)
{
    return -T.z / length(T.xy);
}

float length2(float3 v) { return dot(v, v); } 

//----------------------------------------------------------------------------------
float3 min_diff(float3 P, float3 Pr, float3 Pl)
{
    float3 V1 = Pr - P;
    float3 V2 = P - Pl;
    return (length2(V1) < length2(V2)) ? V1 : V2;
}

//----------------------------------------------------------------------------------
// there's a hack in r3 that forbides enable SSAO_OPT_DATA if hbao is enabled automatically
// fix that later
float3 fetch_eye_pos(float2 uv)
{
////#define SSAO_OPT_DATA
#ifndef SSAO_OPT_DATA
#ifdef USE_MSAA
#ifdef GBUFFER_OPTIMIZATION
		gbuffer_data gbd = gbuffer_load_data_offset( tc, tap, pos2d, iSample ); // this is wrong - need to correct this
#else
		gbuffer_data gbd = gbuffer_load_data( tap, iSample );
#endif
#else
#ifdef GBUFFER_OPTIMIZATION
		gbuffer_data gbd = gbuffer_load_data_offset( tc, tap, pos2d ); // this is wrong - need to correct this
#else
		gbuffer_data gbd = gbuffer_load_data( tap );
#endif
#endif

		//float3	tap_pos	= s_position.Sample(smp_nofilter,tap);
		float3	tap_pos	= gbd.P;
#else // SSAO_OPT_DATA
    float z = s_half_depth.SampleLevel( smp_nofilter, uv, 0 );
    return uv_to_eye(uv, z);
#endif // SSAO_OPT_DATA
}

//----------------------------------------------------------------------------------
float falloff(float r)
{
    return 1.0f - r*r;
}

float4 falloff4(float4 r)
{
    return ( (1.0f).xxxx - r*r );
}

//----------------------------------------------------------------------------------
float2 snap_uv_offset(float2 uv)
{
    return round(uv * g_Resolution) * g_InvResolution;
}

float2 snap_uv_coord(float2 uv)
{
    //return (floor(uv * g_Resolution) + 0.5f) * g_InvResolution;
    return uv - (frac(uv * g_Resolution) - 0.5f) * g_InvResolution;
}

//----------------------------------------------------------------------------------
float tan_to_sin(float x)
{
    return x / sqrt(1.0f + x*x);
}

//----------------------------------------------------------------------------------
float3 tangent_vector(float2 deltaUV, float3 dPdu, float3 dPdv)
{
    return deltaUV.x * dPdu + deltaUV.y * dPdv;
}

float3 tangent_eye_pos(float2 uv, float4 tangentPlane)
{
    // view vector going through the surface point at uv
    float3 V = fetch_eye_pos(uv);
    float NdotV = dot(tangentPlane.xyz, V);
    // intersect with tangent plane except for silhouette edges
    if (NdotV < 0.0) V *= (tangentPlane.w / NdotV);
    return V;
}

//----------------------------------------------------------------------------------
float biased_tangent(float3 T)
{
    float phi = atan(tangent(T)) + g_AngleBias;
    return tan(min(phi, M_PI*0.5));
}

//----------------------------------------------------------------------------------
void integrate_direction(inout float ao, float3 P, float2 uv, float2 deltaUV,
                         float numSteps, float tanH, float sinH)
{
    for (float j = 1; j <= numSteps; ++j) {
        uv += deltaUV;
        float3 S = fetch_eye_pos(uv);
        
        // Ignore any samples outside the radius of influence
        float d2  = length2(S - P);
        if (d2 < g_sqr_R) {
            float tanS = tangent(P, S);

            [branch]
            if(tanS > tanH) {
                // Accumulate AO between the horizon and the sample
                float sinS = tanS / sqrt(1.0f + tanS*tanS);
                float r = sqrt(d2) * g_inv_R;
                ao += falloff(r) * (sinS - sinH);
                
                // Update the current horizon angle
                tanH = tanS;
                sinH = sinS;
            }
        }
    }
}

//----------------------------------------------------------------------------------
float horizon_occlusion_integrateDirection(float2 deltaUV, 
                                           float2 uv0, 
                                           float3 P, 
                                           float numSteps, 
                                           float randstep)
{
    // Randomize starting point within the first sample distance
    float2 uv = uv0 + snap_uv_offset( randstep * deltaUV );
    
    // Snap increments to pixels to avoid disparities between xy 
    // and z sample locations and sample along a line
    deltaUV = snap_uv_offset( deltaUV );

    // Add a small bias in case (g_AngleBias == 0.0)
    float tanT = tan(-M_PI*0.5 + g_AngleBias + 1.e-5);
    float sinT = tan_to_sin(tanT);

    float ao = 0;
    integrate_direction(ao, P, uv, deltaUV, numSteps, tanT, sinT);

    // Integrate opposite directions together
    deltaUV = -deltaUV;
    uv = uv0 + snap_uv_offset( randstep * deltaUV );
    integrate_direction(ao, P, uv, deltaUV, numSteps, tanT, sinT);

    // Divide by 2 because we have integrated 2 directions together
    // Subtract 1 and clamp to remove the part below the surface
    return max(ao * 0.5 - 1.0, 0.0);
}

//----------------------------------------------------------------------------------
float horizon_occlusion2(float2 deltaUV, 
                         float2 uv0, 
                         float3 P, 
                         float numSteps, 
                         float randstep,
                         float3 dPdu,
                         float3 dPdv )
{

    // Randomize starting point within the first sample distance
    float2 uv = uv0 + snap_uv_offset( randstep * deltaUV );
    
    // Snap increments to pixels to avoid disparities between xy 
    // and z sample locations and sample along a line
    deltaUV = snap_uv_offset( deltaUV );

    // Compute tangent vector using the tangent plane
    float3 T = deltaUV.x * dPdu + deltaUV.y * dPdv;

    float tanH = tangent(T);
    float sinH = tanH / sqrt(1.0f + tanH*tanH);

    float ao = 0;
    for(float j = 1; j <= numSteps; ++j) {
        uv += deltaUV;
        float3 S = fetch_eye_pos(uv);
        
        // Ignore any samples outside the radius of influence
        float d2  = length2(S - P);
        float tanS = tangent(P, S);	
	[branch]
        if ((d2 < g_sqr_R) && (tanS > tanH)) {
                // Accumulate AO between the horizon and the sample
                float sinS = tanS / sqrt(1.0f + tanS*tanS);
                float r = sqrt(d2) * g_inv_R;
                ao += falloff(r) * (sinS - sinH);
                
                // Update the current horizon angle
                tanH = tanS;
                sinH = sinS;
        } 
    }

    return ao;
}

//----------------------------------------------------------------------------------
float horizon_occlusion2_4way(float2 deltaUV0,
                              float2 deltaUV1, 
                              float2 deltaUV2, 
                              float2 deltaUV3, 
                              float2 uv_0, 
                              float3 P, 
                              float numSteps, 
                              float randstep,
                              float3 dPdu,
                              float3 dPdv )
{

    // Randomize starting point within the first sample distance
    float2 uv0 = uv_0 + snap_uv_offset( randstep * deltaUV0 );
    float2 uv1 = uv_0 + snap_uv_offset( randstep * deltaUV1 );
    float2 uv2 = uv_0 + snap_uv_offset( randstep * deltaUV2 );
    float2 uv3 = uv_0 + snap_uv_offset( randstep * deltaUV3 );
    
    // Snap increments to pixels to avoid disparities between xy 
    // and z sample locations and sample along a line
    deltaUV0 = snap_uv_offset( deltaUV0 );
    deltaUV1 = snap_uv_offset( deltaUV1 );
    deltaUV2 = snap_uv_offset( deltaUV2 );
    deltaUV3 = snap_uv_offset( deltaUV3 );

    // Compute tangent vector using the tangent plane
    float3 T0 = deltaUV0.x * dPdu + deltaUV0.y * dPdv;
    float3 T1 = deltaUV1.x * dPdu + deltaUV1.y * dPdv;
    float3 T2 = deltaUV2.x * dPdu + deltaUV2.y * dPdv;
    float3 T3 = deltaUV3.x * dPdu + deltaUV3.y * dPdv;

    float4 tanH = float4( tangent(T0), tangent(T1),
                          tangent(T2), tangent(T3) );
    float4 sinH = tanH / sqrt((1.0f).xxxx + tanH*tanH);

    float ao = 0.0f;
    for(float j = 1; j <= numSteps; ++j) {
        uv0 += deltaUV0; 
        uv1 += deltaUV1; 
        uv2 += deltaUV2; 
        uv3 += deltaUV3;
        
        float3 S0 = fetch_eye_pos(uv0);
        float3 S1 = fetch_eye_pos(uv1);
        float3 S2 = fetch_eye_pos(uv2);
        float3 S3 = fetch_eye_pos(uv3);
        
        // Ignore any samples outside the radius of influence
        float4 d2   = float4( length2(S0 - P), length2(S1 - P),
                              length2(S2 - P), length2(S3 - P) );
        float4 tanS = float4( tangent(P, S0), tangent(P, S1),
                              tangent(P, S2), tangent(P, S3) );
        float4 sinS = tanS / sqrt((1.0f).xxxx + tanS*tanS);
        float4 r    = sqrt( d2 ) * g_inv_R.xxxx;
        float4 fo   = float4( falloff( r.x ), falloff( r.y ),
                              falloff( r.z ), falloff( r.w ) );
        float4 flag = ( d2 < g_sqr_R.xxxx ? (1.0f).xxxx : (0.0f).xxxx );
        
        flag *= ( tanS > tanH  ? (1.0f).xxxx : (0.0f).xxxx );
        
        ao  += dot( flag, fo * ( sinS - sinH ) );
        tanH = ( flag > (0.0f).xxxx ? tanS : tanH );
        sinH = ( flag > (0.0f).xxxx ? sinS : sinH );
        }

    return ao;
}

float4 calc_hbao(float z, float3 N, float2 tc0, float4 pos2d)
{
    float3 P = uv_to_eye(tc0, z);

	float2 	step_size	= float2	(.5f / 1024.0f, .5f / 768.0f)*ssao_kernel_size/max(z,1.3);
  	float numSteps = min ( g_NumSteps, min(step_size.x * g_Resolution.x, step_size.y * g_Resolution.y));
	float numDirs = min ( g_NumDir, min(step_size.x / 4 * g_Resolution.x, step_size.y / 4 * g_Resolution.y));
    if( numSteps < 1.0 ) return 1.0;
    step_size = step_size / ( numSteps + 1 );


// (cos(alpha),sin(alpha),jitter)
#ifndef HBAO_WORLD_JITTER
    float3 rand_Dir = jitter4.Load(int3((int)pos2d.x&63, (int)pos2d.y&63, 0)).xyz;
#else
    float3 tc1	= mul(m_invV, float4(P,1));
	const float ssao_noise_tile_factor = ssao_params.x;
    tc1 *= ssao_noise_tile_factor;
    tc1.xz += tc1.y; 
    float3 rand_Dir = jitter4.SampleLevel(smp_jitter, tc1.xz, 0).xyz; 
#endif


	// footprint optimization
	float maxNumSteps = g_MaxFootprintUV / step_size;
	if (maxNumSteps < numSteps)
	{
		numSteps = floor(maxNumSteps + rand_Dir.z);
        	numSteps = max(numSteps, 1);
	        step_size = g_MaxFootprintUV / numSteps;
    	}

    float4 tangentPlane = float4(N, dot(P, N));
    float3 Pr = tangent_eye_pos(tc0 + float2(g_InvResolution.x, 0), tangentPlane);
    float3 Pl = tangent_eye_pos(tc0 + float2(-g_InvResolution.x, 0), tangentPlane);
    float3 Pt = tangent_eye_pos(tc0 + float2(0, g_InvResolution.y), tangentPlane);
    float3 Pb = tangent_eye_pos(tc0 + float2(0, -g_InvResolution.y), tangentPlane);

    float3 dPdu = min_diff(P, Pr, Pl);
    float3 dPdv = min_diff(P, Pt, Pb) * (g_Resolution.y * g_InvResolution.x);

    
    // Loop for all directions
    float ao = 0;
    float alpha = 2.0f * M_PI / g_NumDir;
    float delta = g_NumDir / numDirs;
    
    int   iNumDir = ceil( int( g_NumDir / delta ) );
    
#ifndef VECTORIZED_CODE    
    for (int i = 0; i < iNumDir; ++i ) {  
        float d     = float(i)*delta;
	    float angle = alpha * d;
	    float2 dir = float2(cos(angle), sin(angle));
	    float2 deltaUV = float2(dir.x*rand_Dir.x - dir.y*rand_Dir.y, 
	                            dir.x*rand_Dir.y + dir.y*rand_Dir.x)
						* step_size.xy;
	    
	    ao += horizon_occlusion2(deltaUV, tc0, P, numSteps, rand_Dir.z, dPdu, dPdv);
        //ao += horizon_occlusion_integrateDirection(deltaUV, tc0, P, numSteps, rand_Dir.z);

	}
#else // VECTORIZED_CODE
    for (int i = 0; i < (iNumDir / 4); ++i) {  
  
        float d      = float(i)*delta;
	    float4 angle = alpha * float4( 4.0f*d + 0.0f * delta, 4.0f*d + 1.0f * delta,
	                                   4.0f*d + 2.0f * delta, 4.0f*d + 3.0f * delta);
	    float4 f4Cos = cos( angle );
	    float4 f4Sin = sin( angle );
	    
        float2 dir_0 = float2(f4Cos.x, f4Sin.x);
        float2 dir_1 = float2(f4Cos.y, f4Sin.y);
        float2 dir_2 = float2(f4Cos.z, f4Sin.z);
        float2 dir_3 = float2(f4Cos.w, f4Sin.w);
	    float2 deltaUV0 = step_size.xy * float2(dir_0.x*rand_Dir.x - dir_0.y*rand_Dir.y, 
	                                            dir_0.x*rand_Dir.y + dir_0.y*rand_Dir.x);
	    float2 deltaUV1 = step_size.xy * float2(dir_1.x*rand_Dir.x - dir_1.y*rand_Dir.y, 
	                                            dir_1.x*rand_Dir.y + dir_1.y*rand_Dir.x);
	    float2 deltaUV2 = step_size.xy * float2(dir_2.x*rand_Dir.x - dir_2.y*rand_Dir.y, 
	                                            dir_2.x*rand_Dir.y + dir_2.y*rand_Dir.x);
	    float2 deltaUV3 = step_size.xy * float2(dir_3.x*rand_Dir.x - dir_3.y*rand_Dir.y, 
	                                            dir_3.x*rand_Dir.y + dir_3.y*rand_Dir.x);
	    
	    ao += horizon_occlusion2_4way(deltaUV0, deltaUV1, deltaUV2, deltaUV3, 
	                                  tc0, P, numSteps, rand_Dir.z, dPdu, dPdv);
	    }
	
    // Handle remaining directions that are not a multiple of 4. Only define this if the number of directions required
    // is not a multiple of 4.
    for (i = 4 * (iNumDir/4); i < iNumDir; ++i) {
        float d     = float(i)*delta;
    	float angle = alpha * d;
	    float2 dir  = float2(cos(angle), sin(angle));
	    float2 deltaUV = float2(dir.x*rand_Dir.x - dir.y*rand_Dir.y, 
	                            dir.x*rand_Dir.y + dir.y*rand_Dir.x)
				         * step_size.xy;
	    
	    ao += horizon_occlusion2(deltaUV, tc0, P, numSteps, rand_Dir.z, dPdu, dPdv);
        }

#endif // VECTORIZED_CODE

	float WeaponAttenuation = smoothstep( 0.8, 0.9, length( P.xyz ));

    return 1.0 - ao / g_NumDir * (g_Contrast*WeaponAttenuation);
}

#endif	//	SSAO_QUALITY
