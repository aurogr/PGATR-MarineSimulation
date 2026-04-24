Shader "Unlit/Water"
{
    Properties
    {
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
        //COLOR
        _Deep_Color("Deep Color", Color) = (0.1335885, 0.1953748, 0.3584906, 1)
        _Shallow_Color("Shallow Color", Color) = (0.1335885, 0.1953748, 0.3584906, 1)
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


            #include "HLSLSupport.cginc"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 
           // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/Shaders/Noise.hlsl" // to generate heightmap
            #include "Assets/Shaders/WaterFuncs.hlsl"
            #include "Assets/Shaders/WaterLighting.hlsl"


            // tessellation
            float _TessBias;
            float _TessFactor;
            float _CullingTolerance;
            float _Height;
            float _Speed;
            float _Scale;

            float heightmap;
            // water
            float _Depth_Fade_Distance;
            float4 _Deep_Color;
            float4 _Shallow_Color;
            float _Horizon_Distance;
            float4 _Horizon_Color;
            float _FoamScale;
            float _Foam_Distortion;
            float4 _Foam_Color;
            float _Foam_Blend;
            float _Foam_Cutoff;

            ////////////////////////////////////////////
            //////////////// VERTEX STAGE //////////////
            ////////////////////////////////////////////

            struct Attributes {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct TessellationControlPoint {
                float4 positionCS : SV_POSITION;
                float3 positionWS : INTERNALTESSPOS;
                float3 normalWS : NORMAL;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // vertex function. just converts vertex and normal from OS to WS
            TessellationControlPoint vert(Attributes input) {
                TessellationControlPoint output;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);

                output.positionWS = posInputs.positionWS;
                output.positionCS = posInputs.positionCS;
                output.normalWS = normalInputs.normalWS;
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
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD2;
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

                return output;
            }

            ///////////////////////////////////////////////
            //////////////// FRAGMENT STAGE ///////////////
            ///////////////////////////////////////////////


            fixed4 frag(Interpolators i) : SV_Target
            {
                float depth = 1 - normalize(i.positionWS.y + _Depth_Fade_Distance);
            fixed4 a = lerp(_Shallow_Color, _Deep_Color, depth);
                
                fixed4 col = fixed4(depth.xxxx);
                return a;
            }

            ENDHLSL
        }
    }
}
