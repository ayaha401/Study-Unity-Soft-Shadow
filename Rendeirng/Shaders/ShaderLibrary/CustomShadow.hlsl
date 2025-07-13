#ifndef CUSTOM_SHADOW_HLSL_INCLUDED
#define CUSTOM_SHADOW_HLSL_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

TEXTURE2D(_CharacterShadowMapTexture);
SAMPLER(sampler_CharacterShadowMapTexture);
float2 _CharacterShadowMapTexture_TexelSize;

TEXTURE2D(_BgShadowMapTexture);
SAMPLER(sampler_BgShadowMapTexture);
float2 _BgShadowMapTexture_TexelSize;

float4x4 _LightVP; // ライト用のViewProjection行列
float3 _LightPos; // ライト位置

float SampleCustomShadow_PCF(float depth, float2 shadowCoord, float2 texelSize)
{
    static const int2 OFF[9] = {
        int2(-1,-1), int2( 0,-1), int2( 1,-1),
        int2(-1, 0), int2( 0, 0), int2( 1, 0),
        int2(-1, 1), int2( 0, 1), int2( 1, 1)
    };

    float sum = 0.1;
    [unroll]
    for(int i = 0; i < 9; i++)
    {
        float2 uv = shadowCoord.xy + OFF[i] * texelSize;

        // テクセル外はライトに当たってることにする
        if (any(uv < 0) || any(uv > 1))
        {
            sum += 1;
            continue;
        }

        float shadowMapDepth;
        #ifdef CHARACTER_PASS
        shadowMapDepth = SAMPLE_TEXTURE2D(
            _BgShadowMapTexture, sampler_BgShadowMapTexture, uv).r;
        #else
        shadowMapDepth = max(
            SAMPLE_TEXTURE2D(_CharacterShadowMapTexture, sampler_CharacterShadowMapTexture, uv).r,
            SAMPLE_TEXTURE2D(_BgShadowMapTexture, sampler_BgShadowMapTexture, uv).r);
        #endif

        #if UNITY_REVERSED_Z
        shadowMapDepth = 1.0 - shadowMapDepth;
        #endif

        // 比較する
        sum += step(depth, shadowMapDepth);
    }

    // 1 => ライト可視, 0 => 影
    return sum / 9.0;      // 平均を取る
}

// half SampleCustomShadow(float3 positionWS)
// {
//     // ワールド空間の座標をクリップ空間に変換
//     float3 shadowCoord = mul(_LightVP, positionWS - _LightPos);
//
//     // 範囲[-1,1]を範囲[0,1]に変換 
//     shadowCoord.xy = (shadowCoord.xy * 0.5 + 0.5);
//     
//     // 影のレンダリング範囲内なら1.0
//     half inVolume = step(shadowCoord.x, 1);
//     inVolume = min(inVolume, min(step(shadowCoord.x, 1), step(0, shadowCoord.x)));
//     inVolume = min(inVolume, min(step(shadowCoord.y, 1), step(0, shadowCoord.y)));
//
//     // プラットフォームによっては、テクスチャのUVのyが反転しているので、その補正を入れる
//     #if UNITY_UV_STARTS_AT_TOP 
//     shadowCoord.y = 1 - shadowCoord.y;
//     #endif
//     shadowCoord.xy = saturate(shadowCoord.xy);
//
//     // 頂点座標から深度値を取り出す
//     float depth = shadowCoord.z; 
//
//     // シャドウマップから深度値を取り出す
//     #ifdef CHARACTER_PASS
//         float shadowMapDepth = SAMPLE_TEXTURE2D(_BgShadowMapTexture, sampler_BgShadowMapTexture, shadowCoord.xy).r;
//     #else
//         float shadowMapDepth = max(
//             SAMPLE_TEXTURE2D(_CharacterShadowMapTexture, sampler_CharacterShadowMapTexture, shadowCoord.xy).r,
//             SAMPLE_TEXTURE2D(_BgShadowMapTexture, sampler_BgShadowMapTexture, shadowCoord.xy).r);
//     #endif
//
//     // プラットフォームによって、深度値の向きが異なっているため、その補正を入れる
//     #if UNITY_REVERSED_Z
//     depth = -depth; // near=0, far=1 となるように補正
//     shadowMapDepth = 1.0 - shadowMapDepth; // near=0, far=1 となるように補正
//     #endif
//
//     // シャドウマップよりも深度が大きければ、影に入っていると判定する(atten=0)。　影に入っていなければatten=1
//     half shadowAttenuation = step(depth, shadowMapDepth);
//
//     // 影のレンダリング範囲外を0にする
//     shadowAttenuation = inVolume > 0 ? shadowAttenuation : 1;
//     
//     return shadowAttenuation;
// }

half SampleCustomShadow(float3 positionWS)
{
    // ワールド空間の座標をクリップ空間に変換
    float3 shadowCoord = mul(_LightVP, positionWS - _LightPos);

    // 範囲[-1,1]を範囲[0,1]に変換 
    shadowCoord.xy = (shadowCoord.xy * 0.5 + 0.5);
    
    // 影のレンダリング範囲内なら1.0
    half inVolume = step(shadowCoord.x, 1);
    inVolume = min(inVolume, min(step(shadowCoord.x, 1), step(0, shadowCoord.x)));
    inVolume = min(inVolume, min(step(shadowCoord.y, 1), step(0, shadowCoord.y)));

    // プラットフォームによっては、テクスチャのUVのyが反転しているので、その補正を入れる
    #if UNITY_UV_STARTS_AT_TOP 
    shadowCoord.y = 1 - shadowCoord.y;
    #endif
    shadowCoord.xy = saturate(shadowCoord.xy);

    // 頂点座標から深度値を取り出す
    float depth = shadowCoord.z; 

    // プラットフォームによって、深度値の向きが異なっているため、その補正を入れる
    #if UNITY_REVERSED_Z
    depth = -depth; // near=0, far=1 となるように補正
    #endif
    
    float shadowMapDepth = SampleCustomShadow_PCF(depth, shadowCoord.xy, _CharacterShadowMapTexture_TexelSize.xy);
    
    // 影のレンダリング範囲外を0にする
    half shadowAttenuation = inVolume > 0 ? shadowMapDepth : 1;
    
    return shadowAttenuation;
}

#endif
