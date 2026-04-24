Shader "Unlit/Water2"
{
    Properties
    {
        //REFRACTION, DEPTH
        _Depth_Fade_Distance("Depth", Float) = 1.18
        //LIGHTING
        _Normal_Scale("Normal Scale", Float) = 0.31
        _Normal_Strength("Normal Strength", Range(0,10)) = 0.1
        _Roughness("Roughness", Range(0,1)) = 0
        _Specular("Specular", Range(0,10)) = 0
        //STREAM 
        _StreamSpeed("Stream Speed", Float) = 0
        _StreamDirection("Stream Direction", Float) = 0
        //COLOR
        _Deep_Color("Deep Color", Color) = (0.1335885, 0.1953748, 0.3584906, 1)
        _Horizon_Distance("Horizon Distance", Float) = 1.7
        _Horizon_Color("Horizon Color", Color) = (0, 0.1109023, 0.6313726, 0)
        //FOAM
        _FoamScale("Foam Scale", Float) = 2.11
        _Foam_Distortion("Foam Distortion", Float) = 0.91
        _Foam_Color("Foam Color", Color) = (1, 1, 1, 0)
        _Foam_Blend("Foam Blend", Float) = 0.52
        _Foam_Cutoff("Foam Depth", Float) = 0
    }
        SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "HLSLSupport.cginc" 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 

            #define PI 3.14159265359

            struct appdata
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float2 uv : TEXCOORD0;
            };

            //VARIABLE INIT
            float _Depth_Fade_Distance;
            float4 _Deep_Color;
            float _Horizon_Distance;
            float4 _Horizon_Color;
            float _StreamSpeed;
            float _StreamDirection;
            float _FoamScale;
            float _Foam_Distortion;
            float4 _Foam_Color;
            float _Foam_Blend;
            float _Foam_Cutoff;
            float _Normal_Strength;
            float _Normal_Scale;
            float _Roughness;
            float _Specular;

            // URP textures
            float4 _CameraDepthTexture_ST;
            sampler2D _CameraDepthTexture;
            sampler2D _CameraOpaqueTexture;
            float4 _CameraOpaqueTexture_ST;
            //TBN matrix
            float3x3 TBN_matrix;
            float2 positionNDC;

            //FUNCTIONS
            #include "Assets/Shaders/WaterFuncs.hlsl"
            #include "Assets/Shaders/WaterLighting.hlsl"
            #include "Assets/Shaders/Noise.hlsl"

            float2 PannedUVs(v2f i, float Direction, float Scale, float Speed)
            {
                float dir = (Direction * 2 - 1) * PI;
                float time = _Time.y * Speed;
                float2 uv = i.uv * Scale;

                return uv + time * normalize(float2(cos(dir), sin(dir)));
            }

            float3 NormalWaves(v2f i)
            {
                float direction = _StreamDirection;

                float2 uv = PannedUVs(i, direction, rcp(_Normal_Scale * 0.5f), _StreamSpeed * 0.5f);
                float noise; SimpleNoise_float(uv, 500, noise);
                float3 normal1; NormalFromHeight_float3(noise, _Normal_Strength * 0.1, i.positionWS, TBN_matrix, normal1);

                uv = PannedUVs(i, direction, rcp(_Normal_Scale), _StreamSpeed);
                noise; SimpleNoise_float(uv, 500, noise);
                float3 normal2; NormalFromHeight_float3(noise, _Normal_Strength * 0.1, i.positionWS, TBN_matrix, normal2);

                return SafeNormalize(float3(normal1.rg + normal2.rg, normal1.b * normal2.b));
            }

            float SceneDepth(float2 uv)
            {
                float depthNDC = tex2D(_CameraDepthTexture, uv).r;
                return LinearEyeDepth(depthNDC, _ZBufferParams);
            }

            float3 WorldSpaceScenePosition(float2 UV, v2f i)
            {
                float3 view = _WorldSpaceCameraPos.xyz - GetAbsolutePositionWS(i.positionWS);
                float depth = SceneDepth(UV);
                float3 res = (-view / i.positionCS.w) * depth + _WorldSpaceCameraPos;
                return res;
            }

            float2 RefractedUVs(v2f i, float3 UV)
            {
                float2 positionCS = i.positionCS.xy / _ScaledScreenParams.xy;// SCREEN POSITION 

                float3 uvWS = TransformTangentToWorldDir(UV, TBN_matrix);
                uvWS = TransformWorldToViewDir(uvWS,true);
                float2 refractedUVs = positionCS.xy + (uvWS.xy * 0.2);

                float3 scenePosWS = WorldSpaceScenePosition(refractedUVs, i);
                float yDifference = (i.positionWS - scenePosWS).y;
                float2 res = (yDifference <= 0) ? positionCS : refractedUVs;

                return res;
            }

            float Depth_WS(v2f i, float2 UV)
            {
                float3 dif = i.positionWS - WorldSpaceScenePosition(UV, i);
                float depth = saturate(exp(-dif.y / _Depth_Fade_Distance));
                return depth;
            }

            float4 WaterDiffuse(v2f i, float2 UV, float Depth)
            {
                float4 waterColor = lerp(_Deep_Color, float4(0, 0, 0, 0), Depth);
                float4 sceneColor = tex2D(_CameraOpaqueTexture, UV);

                float fresnel = pow((1.0 - saturate(dot(normalize(i.normalWS), GetWorldSpaceNormalizeViewDir(i.positionWS)))), _Horizon_Distance);
                float4 horizonLerp; HSVLerp_half(waterColor, _Horizon_Color, fresnel, horizonLerp);

                return horizonLerp + (sceneColor * (1 - horizonLerp.a));
            }

            float4 EdgeFoam(v2f i, float refractedDepth)
            {
                // noise
                float2 pannedUVs = PannedUVs(i, _StreamDirection, _FoamScale, _StreamSpeed);
                float2 distortedUVs; DistortUV_float(pannedUVs, _Foam_Distortion, distortedUVs);
                float gradientNoise; GradientNoise_float(distortedUVs, 10, gradientNoise);

                // mask
                float mask = pow(refractedDepth, _Foam_Cutoff);
                return lerp(_Foam_Color,float4(0,0,0,0),step(mask, gradientNoise));
            }

            float4 WaterSpecular(v2f i, float3 normals)
            {
                normals = normalize(mul(normals, TBN_matrix));
                float3 viewDir = _WorldSpaceCameraPos.xyz - GetAbsolutePositionWS(i.positionWS);

                float3 mainLighting;  MainLighting_float(normals, i.positionWS, viewDir, _Roughness, _Specular * 10, mainLighting);
                float3 additionalLighting; AdditionalLighting_float(normals, i.positionWS, viewDir, _Roughness, _Specular * 10, additionalLighting);

                return float4(mainLighting + additionalLighting, 1);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.uv = v.uv;
                VertexPositionInputs input = GetVertexPositionInputs(v.positionOS);
                o.positionCS = input.positionCS;
                o.positionWS = input.positionWS;
                VertexNormalInputs tbn = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.normalWS = tbn.normalWS;
                o.tangentWS = tbn.tangentWS;
                o.bitangentWS = tbn.bitangentWS;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // TBN matrix
                TBN_matrix = float3x3
                (
                    i.tangentWS,
                    i.bitangentWS,
                    i.normalWS
                );

            // Parameter adjustments
            _StreamSpeed *= 0.01;

            float3 normalWaves = NormalWaves(i);
            float2 refractedUVs = RefractedUVs(i, normalWaves);
            float refractedDepth = Depth_WS(i,refractedUVs);
            float4 edgeFoam = EdgeFoam(i, refractedDepth);
            float4 baseColor = WaterDiffuse(i, refractedUVs, refractedDepth);
            float4 waterSpecular = WaterSpecular(i, normalWaves);

            fixed4 col = baseColor + (edgeFoam * _Foam_Blend) + waterSpecular;
            return col;
        }

        ENDHLSL
    }
    }
}