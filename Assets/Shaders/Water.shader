Shader "Unlit/Water"
{
    Properties
    {
        _aa("aa", Float) = 1
        [Header(Tessellation)]

        _TessFactor("Tesselation Factor", Float) = 1
        _TessBias("Tesselation Bias",Float) = 1
        _CullingTolerance("Culling Tolerance", Float) = 1

        [Header(HeightMap)]

        _Height("Height", Float) = 1
        _Speed("Waves Speed",Float) = 1
        _Scale("Waves Scale", Float) = 1

        [Header(Water)]

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
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent" 
            //"LightMode" = "UniversalForward"
        }
        LOD 100
        Cull Off

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag
            #pragma target 5.0
            #pragma multi_compile_fog

            #include "HLSLSupport.cginc"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 
           // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/Shaders/Noise.hlsl" // to generate heightmap
            #include "Assets/Shaders/WaterFuncs.hlsl"
            #include "Assets/Shaders/WaterLighting.hlsl"
            #define PI 3.14159265359


            // tessellation
            float _TessBias;
            float _TessFactor;
            float _CullingTolerance;
            float _Height;
            float _Speed;
            float _Scale;

            float heightmap;
            // water
            float _aa;
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

            ////////////////////////////////////////////
            //////////////// VERTEX STAGE //////////////
            ////////////////////////////////////////////

            struct Attributes {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                float4 tangentOS : TANGENT;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct TessellationControlPoint {
                float4 positionCS : SV_POSITION;
                float3 positionWS : INTERNALTESSPOS;
                float3 normalWS : NORMAL;
                float3 tangentWS : TEXCOORD1;
                float3 bitangentWS : TEXCOORD2;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // vertex function. just converts vertex and normal from OS to WS
            TessellationControlPoint vert(Attributes input) {
                TessellationControlPoint output;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionWS = posInputs.positionWS;
                output.positionCS = posInputs.positionCS;
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = normalInputs.tangentWS;
                output.bitangentWS = normalInputs.bitangentWS;
                output.uv = input.uv;
                return output;
            }


            ///////////////////////////////////////////
            //////////////// HULL STAGE ///////////////
            ///////////////////////////////////////////

            // this function executes once per vertex in each patch
            [domain("tri")] // signal we're inputting triangles
            [outputcontrolpoints(3)] // establish 3 control point per patch. one for each triangle corner
            [outputtopology("triangle_cw")] // signal we're outputin triangles. defines clockwise/counterclockwise topology
            [partitioning("integer")] // patch partition method 
            [patchconstantfunc("patchConstantFunction")] // register the patch constant function
            TessellationControlPoint hull(
                InputPatch<TessellationControlPoint, 3> patch, // input triangle
                uint id : SV_OutputControlPointID) // vertex index on the triangle
            {
                return patch[id];
            }

            //#define NUM_BEZIER_CONTROL_POINTS 10
            struct TessellationFactors {
                float edge[3] : SV_TessFactor; // num of times an edge will subdivide
                float inside : SV_InsideTessFactor; // num of times a new triangle will be created
                //float3 bezierPoints[NUM_BEZIER_CONTROL_POINTS] : BEZIERPOS;
            };

            /////////////// CLIPPING AND CULLING ////////////////

            // true if p is outside the bounds set by lower and higher
            bool IsOutOfBounds(float3 p, float3 lower, float3 higher) {
                return p.x < lower.x || p.x > higher.x || p.y < lower.y || p.y > higher.y || p.z < lower.z || p.z > higher.z;
            }
            bool IsPointOutOfFrustum(float4 positionCS, float tolerance) {
                float3 culling = positionCS.xyz;
                float w = positionCS.w;
                // UNITY_RAW_FAR_CLIP_VALUE is either 0 or 1, depending on the graphics API. OpenGL uses 1, the rest mostly 0.
                float3 lowerBounds = float3(-w - tolerance, -w - tolerance, -w * UNITY_RAW_FAR_CLIP_VALUE - tolerance);
                float3 higherBounds = float3(w + tolerance, w + tolerance, w + tolerance);
                return IsOutOfBounds(culling, lowerBounds, higherBounds);
            }

            // Returns true if the points in this triangle are wound counter-clockwise
            bool ShouldBackFaceCull(float4 p0PositionCS, float4 p1PositionCS, float4 p2PositionCS, float tolerance) {
                float3 point0 = p0PositionCS.xyz / p0PositionCS.w;
                float3 point1 = p1PositionCS.xyz / p1PositionCS.w;
                float3 point2 = p2PositionCS.xyz / p2PositionCS.w;
                //float3 normal = cross(point1 - point0, point2 - point0);
                // In clip space, the view direction is float3(0, 0, 1), so we can just test the z coord
                #if UNITY_REVERSED_Z
                return cross(point1 - point0, point2 - point0).z < - tolerance;
                #else // In OpenGL, the test is reversed
                return cross(point1 - point0, point2 - point0).z > tolerance;
                #endif            
            }

            bool ShouldClipPatch(float4 p0PositionCS, float4 p1PositionCS, float4 p2PositionCS, float tolerance) {
                bool allOutside = IsPointOutOfFrustum(p0PositionCS,tolerance) &&
                    IsPointOutOfFrustum(p1PositionCS, tolerance) &&
                    IsPointOutOfFrustum(p2PositionCS, tolerance);
                return allOutside || ShouldBackFaceCull(p0PositionCS,p1PositionCS,p2PositionCS,tolerance);
            }

            // dinamic tessellation factor for an edge
            float EdgeTessellationFactor(float scale, float bias, float3 p0PositionWS, float4 p0PositionCS, float3 p1PositionWS, float4 p1PositionCS) {
                float length = distance(p0PositionWS, p1PositionWS);
                float distanceToCamera = distance(GetCameraPositionWS(), (p0PositionWS + p1PositionWS) * 0.5);
                float factor = length / (scale * distanceToCamera * distanceToCamera);

                return max(1, factor + bias);
            }


            // this functions executes once per patch
            TessellationFactors patchConstantFunction(
                InputPatch<TessellationControlPoint, 3> patch)
            {
                UNITY_SETUP_INSTANCE_ID(patch[0]); // set up instancing
                TessellationFactors f = (TessellationFactors)0;
                // Check if this patch should be culled (it is out of view)
                if (ShouldClipPatch(patch[0].positionCS, patch[1].positionCS, patch[2].positionCS, _CullingTolerance)) {
                    f.edge[0] = f.edge[1] = f.edge[2] = f.inside = 0; // Cull the patch
                }
                else {
                    f.edge[0] = EdgeTessellationFactor(_TessFactor, _TessBias, patch[1].positionWS, patch[1].positionCS, patch[2].positionWS, patch[2].positionCS);
                    f.edge[1] = EdgeTessellationFactor(_TessFactor, _TessBias, patch[2].positionWS, patch[2].positionCS, patch[0].positionWS, patch[0].positionCS);
                    f.edge[2] = EdgeTessellationFactor(_TessFactor, _TessBias, patch[0].positionWS, patch[0].positionCS, patch[1].positionWS, patch[1].positionCS);
                    f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) / 3.0;
                }
                return f;
            }

            /////////////////////////////////////////////
            ///////////////// DOMAIN STAGE //////////////
            /////////////////////////////////////////////

            struct Interpolators {
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float fogFactor : TEXCOORD5;
                float4 positionCS : SV_POSITION;
            };

#define BARYCENTRIC_INTERPOLATE(fieldName) \
    patch[0].fieldName * barycentricCoordinates.x + \
    patch[1].fieldName * barycentricCoordinates.y + \
    patch[2].fieldName * barycentricCoordinates.z;

            [domain("tri")] // Signal we're inputting triangles
            Interpolators domain(
                TessellationFactors factors, // Output of the patch constant function
                OutputPatch<TessellationControlPoint, 3> patch, // input triangle
                float3 barycentricCoordinates : SV_DomainLocation )  // baricentric coords of the vertex of the triangle. for creating new vertices
            {
                Interpolators output;

                float3 positionWS = BARYCENTRIC_INTERPOLATE(positionWS);
                float3 normalWS = BARYCENTRIC_INTERPOLATE(normalWS);
                float3 tangentWS = BARYCENTRIC_INTERPOLATE(tangentWS);
                float3 bitangentWS = BARYCENTRIC_INTERPOLATE(bitangentWS);

                // heightmap
                float2 uv = BARYCENTRIC_INTERPOLATE(uv);
                uv = (uv * _Scale) + float2(0, _Time.y * _Speed);
                heightmap;  GradientNoise_float(uv, 1, heightmap);
                float height = heightmap * _Height;
                positionWS += normalWS * height;

                output.uv = uv;
                output.positionCS = TransformWorldToHClip(positionWS);
                output.normalWS = normalWS;
                output.positionWS = positionWS;
                output.tangentWS = tangentWS;
                output.bitangentWS = bitangentWS;

                output.fogFactor = ComputeFogFactor(output.positionCS.z);

                return output;
            }

            ///////////////////////////////////////////////
            //////////////// FRAGMENT STAGE ///////////////
            ///////////////////////////////////////////////

            float2 PannedUVs(Interpolators i, float Direction, float Scale, float Speed)
            {
                float dir = (Direction * 2 - 1) * PI;
                float time = _Time.y * Speed;
                float2 uv = i.uv * Scale;

                return uv + time * normalize(float2(cos(dir), sin(dir)));
            }

            float3 NormalWaves(Interpolators i)
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

            float3 WorldSpaceScenePosition(float2 UV, Interpolators i)
            {
                float3 view = _WorldSpaceCameraPos.xyz - GetAbsolutePositionWS(i.positionWS);
                float depth = SceneDepth(UV);
                float3 res = (-view / i.positionCS.w) * depth + _WorldSpaceCameraPos;
                return res;
            }

            float2 RefractedUVs(Interpolators i, float3 UV)
            {
                float2 positionCS = i.positionCS.xy / _ScaledScreenParams.xy;// SCREEN POSITION 

                float3 uvWS = TransformTangentToWorldDir(UV, TBN_matrix);
                uvWS = TransformWorldToViewDir(uvWS, true);
                float2 refractedUVs = positionCS.xy + (uvWS.xy * 0.2);

                float3 scenePosWS = WorldSpaceScenePosition(refractedUVs, i);
                float yDifference = (i.positionWS - scenePosWS).y;
                float2 res = (yDifference <= 0) ? positionCS : refractedUVs;

                return res;
            }

            float Depth_WS(Interpolators i, float2 UV)
            {
                float3 dif = i.positionWS - WorldSpaceScenePosition(UV, i);
                float depth = saturate(exp(-dif.y / _Depth_Fade_Distance));
                return depth;
            }

            float4 EdgeFoam(Interpolators i, float refractedDepth)
            {
                // noise
                float2 pannedUVs = PannedUVs(i, _StreamDirection, _FoamScale, _StreamSpeed);
                float2 distortedUVs; DistortUV_float(pannedUVs, _Foam_Distortion, distortedUVs);
                float gradientNoise; GradientNoise_float(distortedUVs, 10, gradientNoise);

                // mask
                float mask = pow(refractedDepth, _Foam_Cutoff);
                return lerp(_Foam_Color, float4(0, 0, 0, 0), step(mask, gradientNoise));
            }

            float4 WaterDiffuse(Interpolators i, float2 UV, float Depth)
            {
                float4 waterColor = lerp(_Deep_Color, float4(0, 0, 0, 0), Depth);
                float4 sceneColor = tex2D(_CameraOpaqueTexture, UV);

                float fresnel = pow((1.0 - saturate(dot(normalize(i.normalWS), GetWorldSpaceNormalizeViewDir(i.positionWS)))), _Horizon_Distance);
                float4 horizonLerp; HSVLerp_half(waterColor, _Horizon_Color, fresnel, horizonLerp);

                return horizonLerp + (sceneColor * (1 - horizonLerp.a));
            }

            float4 WaterSpecular(Interpolators i, float3 normals)
            {
                normals = normalize(mul(normals, TBN_matrix));
                float3 viewDir = _WorldSpaceCameraPos.xyz - GetAbsolutePositionWS(i.positionWS);

                float3 mainLighting;  MainLighting_float(normals, i.positionWS, viewDir, _Roughness, _Specular * 10, mainLighting);
                float3 additionalLighting; AdditionalLighting_float(normals, i.positionWS, viewDir, _Roughness, _Specular * 10, additionalLighting);

                return float4(mainLighting + additionalLighting, 1);
            }

            fixed4 frag(Interpolators i) : SV_Target
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
                float depth = 1 - normalize(i.positionWS.y + _aa);

                float3 normalWaves = NormalWaves(i);
                float2 refractedUVs = RefractedUVs(i, normalWaves);
                float refractedDepth = Depth_WS(i, refractedUVs);
                float4 edgeFoam = EdgeFoam(i, refractedDepth);
                float4 baseColor = WaterDiffuse(i, refractedUVs, refractedDepth);
                float4 waterSpecular = WaterSpecular(i, normalWaves);
                    
                float4 col = baseColor + (edgeFoam * _Foam_Blend) + waterSpecular;
                
                col.rgb = MixFog(col.rgb, i.fogFactor);

                return col;
            }

            ENDHLSL
        }
    }
}
