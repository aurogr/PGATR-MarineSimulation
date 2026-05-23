Shader "PGATR/Fish"
{
    Properties
    {
        [Header(Shading)]
        _MainTex("Texture", 2D) = "white" {}
        _WiggleSpeedToVelocityRelation ("Wiggle Speed To Velocity Relation", Float) = 0.8
        _WiggleAmplitudeToVelocityRelation ("Wiggle Amplitude To Velocity Relation", Float) = 0.1
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        
        Cull Off

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma geometry geo
            #pragma fragment frag
            #pragma target 4.6
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Boid{
                float3 position;
                float3 velocity;
                float size;
            };
            
            StructuredBuffer<Boid> _BoidBuffer;

            struct vertexOutput {
                float4 pos : SV_POSITION;
                float3 velocity : TEXCOORD0;
                float size : TEXCOORD1;
            };

            struct geometryOutput {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float fogFactor : TEXCOORD1;
            };

            vertexOutput vert (uint id : SV_VertexID)
            {
                vertexOutput o;
                Boid boid = _BoidBuffer[id];
                o.pos = float4(boid.position, 1.0);
                o.velocity = boid.velocity;
                o.size = boid.size;
                return o;
            }

            float _WiggleSpeedToVelocityRelation;
            float _WiggleAmplitudeToVelocityRelation;

            [maxvertexcount(14)]
            void geo(point vertexOutput IN[1], inout TriangleStream<geometryOutput> triStream)
            {
                float speed = length(IN[0].velocity);
                
                float3 fwd = speed > 0.001 ? IN[0].velocity / speed : float3(0, 0, 1);
                
                float3 worldUp = float3(0, 1, 0);
                if (abs(dot(fwd, worldUp)) > 0.98) 
                {
                    worldUp = float3(0, 0, 1); // Fallback to forward axis to avoid math implosion
                }

                float3 right = normalize(cross(worldUp, fwd));
                float3 localUp = cross(fwd, right);
                float size = IN[0].size;

                float fishLength = 2.0 * size; // the fish is longer than wider

                // Animation
                float maxWiggleSpeed = 5.0; 
                float wiggleSpeed = min(speed * _WiggleSpeedToVelocityRelation, maxWiggleSpeed);

                float maxWiggleAmp = 0.4;
                float wiggleAmp = min(speed * _WiggleAmplitudeToVelocityRelation, maxWiggleAmp);

                geometryOutput o;
                float bodyX[7] = {0.0, 0.15, 0.50, 0.7, 0.8, 0.9, 1.0};

                for (int i = 0; i < 7; i++)
                {
                    float segmentPercent = bodyX[i];
                    float3 segmentPos = IN[0].pos.xyz - (fwd * segmentPercent * fishLength);

                    // traveling wave, with a speed based on the boid's velocity, and an amplitude that increases towards the tail
                    // phase = time * speed - distance along the body, so the wave travels from head to tail
                    float wiggle = sin(_Time.y * wiggleSpeed - segmentPercent * 5.0) * wiggleAmp * segmentPercent;
        
                    // Shift the segment
                    segmentPos += right * wiggle;

                    // --- Top Vertex ---
                    o.uv = float2(segmentPercent, 1.0);
                    float3 topWorldPos = segmentPos + localUp * size;
                    o.pos = TransformWorldToHClip(topWorldPos);
                    // FIXED: Pass the computed clip-space Z directly from the transformation sequence
                    o.fogFactor = ComputeFogFactor(o.pos.z);
                    triStream.Append(o);

                    // --- Bottom Vertex ---
                    o.uv = float2(segmentPercent, 0.0);
                    float3 bottomWorldPos = segmentPos - localUp * size;
                    o.pos = TransformWorldToHClip(bottomWorldPos);
                    // FIXED: Pass the computed clip-space Z directly from the transformation sequence
                    o.fogFactor = ComputeFogFactor(o.pos.z);
                    triStream.Append(o);
                }

                triStream.RestartStrip();
            }

            Texture2D _MainTex;
            SamplerState sampler_MainTex;

            float4 frag (geometryOutput i) : SV_Target
            {
                float4 tex = _MainTex.Sample(sampler_MainTex, i.uv);
                clip(tex.a - 0.5);
                
                tex.rgb = MixFog(tex.rgb, i.fogFactor);
                return tex;
            }
            ENDHLSL
        }
    }
}