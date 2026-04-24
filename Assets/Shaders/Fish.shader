Shader "PGATR/Fish"
{
    Properties
    {
		[Header(Shading)]
        _MainTex("Texture", 2D) = "white" {}
		_SizeMin("SizeMin", Float) = 0.2
		_SizeMax("SizeMax", Float) = 0.5
        _BodyCrease("Body Crease", Float) = 0.5
		_FlapSpeedToVelocityRelation ("Flap Speed To Velocity Relation", Float) = 2
		_FlapAmplitudeToSpeedRelation ("Flap Amplitude To Speed Relation", Float) = 0.2
    }

    CGINCLUDE
	#include "UnityCG.cginc"
	#include "Autolight.cginc"

    // Simple noise function, sourced from http://answers.unity.com/answers/624136/view.html
	// Extended discussion on this function can be found at the following link:
	// https://forum.unity.com/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
	// Returns a number in the 0...1 range.
	float rand(float3 co)
	{
		return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
	}

    
	// Construct a rotation matrix that rotates around the provided axis, sourced from:
	// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
	float3x3 AngleAxis3x3(float angle, float3 axis)
	{
		float c, s;
		sincos(angle, s, c);

		float t = 1 - c;
		float x = axis.x;
		float y = axis.y;
		float z = axis.z;

		return float3x3(
			t * x * x + c, t * x * y - s * z, t * x * z + s * y,
			t * x * y + s * z, t * y * y + c, t * y * z - s * x,
			t * x * z - s * y, t * y * z + s * x, t * z * z + c
			);
	}

    // It must be the same as the struct defined in the C# script.
	struct Boid{
		float3 position;
		float3 velocity;
	};
    
    StructuredBuffer<Boid> _BoidBuffer;

	struct vertexOutput {
        float4 pos : SV_POSITION;
        float3 velocity : TEXCOORD0;
        float id : TEXCOORD2;
    };

	struct geometryOutput {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
    };

	geometryOutput VertexOutput(float3 pos, float2 uv)
	{
		geometryOutput o;
		o.pos = UnityObjectToClipPos(pos);
		o.uv = uv;
		return o;
	}

    // Instead of an array, because of problems with the GPU, we use a simple func
    float GetXPos(int i) {
        if (i == 0) return 0.0;
        if (i == 1) return 0.25;
        if (i == 2) return 0.42;
        if (i == 3) return 0.5;
        if (i == 4) return 0.58;
        if (i == 5) return 0.75;
        return 1.0;
    }

	ENDCG

    SubShader
    {
		Cull Off

        Pass
        {
			Tags
			{
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
			}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 4.6
			#pragma geometry geo

            // -------- VERTEX SHADER ------------
            // takes in the vertex ID and retrieves the boid data from the buffer
	        vertexOutput vert (uint id : SV_VertexID)
            {
                vertexOutput o;
                Boid boid = _BoidBuffer[id];
                o.pos = float4(boid.position, 1.0);
                o.velocity = boid.velocity;
                o.id = id;
                return o;
            }
    

            float _FlapSpeedToVelocityRelation;
            float _FlapAmplitudeToSpeedRelation;
            float _SizeMin;
            float _SizeMax;
            float _BodyCrease;

            [maxvertexcount(14)]
            void geo(point vertexOutput IN[1], inout TriangleStream<geometryOutput> triStream)
            {
                float speed = length(IN[0].velocity);
                float3 fwd = normalize(IN[0].velocity);
                float3 worldUp = float3(0, 1, 0);
                float3 right = normalize(cross(worldUp, fwd));
                float3 localUp = cross(fwd, right);

                float s = lerp(_SizeMin, _SizeMax, rand(float(IN[0].id)));
                float fishLength = 2.0 * s; // the fish is longer than wider

                // --- ANIMATION ---
                float wiggleSpeed = min(speed * _FlapSpeedToVelocityRelation, 12.0);
                float wiggleAmp = speed * _FlapAmplitudeToSpeedRelation;

                geometryOutput o;
                // Define 7 segments along the fish (Nose to Tail)
                // ribX: position along length (0=Nose, 1=Tail Tip)
                // ribH: half-height of the fish at that point (silhouette)
                float ribX[5] = {0.0, 0.15, 0.50, 0.85, 1.0};

                for (int i = 0; i < 5; i++)
                {
                    float segmentPercent = ribX[i];
                    float3 segmentPos = IN[0].pos.xyz - (fwd * segmentPercent * fishLength);

                    // --- THE WIGGLE ---
                    // 1. We use segmentPercent * 5.0 to create a traveling wave (tail follows head)
                    // 2. We multiply by segmentPercent so the nose stays still and the tail wiggles most
                    float wiggle = sin(_Time.y * wiggleSpeed - segmentPercent * 5.0) * wiggleAmp * segmentPercent;
        
                    // Shift the segment left/right
                    segmentPos += right * wiggle;

                    // Top Vertex (Dorsal side)
                    o.uv = float2(segmentPercent, 1.0);
                    o.pos = UnityObjectToClipPos(float4(segmentPos + localUp * 0.5, 1));
                    triStream.Append(o);

                    // Bottom Vertex (Ventral side)
                    o.uv = float2(segmentPercent, 0.0);
                    o.pos = UnityObjectToClipPos(float4(segmentPos - localUp * 0.5, 1));
                    triStream.Append(o);
                }

                triStream.RestartStrip();
            }

            sampler2D _MainTex;

            // -------- FRAGMENT SHADER ------------
	        #include "Lighting.cginc"
	        fixed4 frag (geometryOutput i) : SV_Target
            {
		        fixed4 tex = tex2D(_MainTex, i.uv);
		        clip(tex.a - 0.5);
		        return tex;
            }
            ENDCG
        }
    }
}