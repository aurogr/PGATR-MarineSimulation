Shader "PGATR/Seagull"
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
		float3 direction;
		float speed;
	};
    
    StructuredBuffer<Boid> _BoidBuffer;

	struct vertexOutput {
        float4 pos : SV_POSITION;
        float3 direction : TEXCOORD0;
        float speed : TEXCOORD1;
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
                o.direction =  boid.direction;
                o.speed = boid.speed;
                o.id = id;
                return o;
            }
    

            float _FlapSpeedToVelocityRelation;
            float _FlapAmplitudeToSpeedRelation;
            float _SizeMin;
            float _SizeMax;
            float _BodyCrease;

            [maxvertexcount(14)] // 5 Quads in a single strip = 12 vertices
            void geo(point vertexOutput IN[1], inout TriangleStream<geometryOutput> triStream)
            {
                float3 pos = IN[0].pos.xyz;
                float3 fwd = normalize(IN[0].direction);
                float3 worldUp = float3(0, 1, 0);
                float3 right = normalize(cross(worldUp, fwd));
                float3 localUp = cross(fwd, right);

                // Random Size (between your Min/Max)
                float s = lerp(_SizeMin, _SizeMax, rand(float(IN[0].id))) * 0.8;
    
                float bodyW = 0.2 * s;
                float creaseDepth = _BodyCrease * s;
                float wingW = 0.15 * s;
                float tipW  = 0.25 * s;

                // Animation
                float flapSin = sin(_Time.y * (IN[0].speed * _FlapSpeedToVelocityRelation));
                float amp = IN[0].speed * _FlapAmplitudeToSpeedRelation;

                // Rotation Matrices
                float3x3 rotL = AngleAxis3x3(flapSin * amp, fwd);
                float3x3 rotR = AngleAxis3x3(-flapSin * amp, fwd);
                float3x3 tipLRot = mul(rotL, rotL); // Doubled rotation for tips
                float3x3 tipRRot = mul(rotR, rotR);

                geometryOutput o;
                float chord = 0.4 * s;   // The "width" of the bird (front-to-back)

                // --- CONSTRUCTION: FROM LEFT TIP TO RIGHT TIP (12 Vertices) ---
    
                // 1. LEFT WING TIP (UV 0.0)
                float3 p1 = mul(tipLRot, -right * (bodyW + wingW + tipW));
                o.uv = float2(0.0, 1.0); o.pos = UnityObjectToClipPos(float4(pos + p1 + fwd * chord, 1)); triStream.Append(o);
                o.uv = float2(0.0, 0.0); o.pos = UnityObjectToClipPos(float4(pos + p1 - fwd * chord, 1)); triStream.Append(o);

                // 2. LEFT ELBOW (UV 0.25)
                float3 p2 = mul(rotL, -right * (bodyW + wingW));
                o.uv = float2(0.25, 1.0); o.pos = UnityObjectToClipPos(float4(pos + p2 + fwd * chord, 1)); triStream.Append(o);
                o.uv = float2(0.25, 0.0); o.pos = UnityObjectToClipPos(float4(pos + p2 - fwd * chord, 1)); triStream.Append(o);

                // 3. LEFT SHOULDER / BODY EDGE (UV 0.4)
                float3 p3 = -right * bodyW;
                o.uv = float2(0.4, 1.0); o.pos = UnityObjectToClipPos(float4(pos + p3 + fwd * chord, 1)); triStream.Append(o);
                o.uv = float2(0.4, 0.0); o.pos = UnityObjectToClipPos(float4(pos + p3 - fwd * chord, 1)); triStream.Append(o);

                // 4. SPINE - THE CREASE (UV 0.5)
                float3 p4 = -localUp * creaseDepth; 
                o.uv = float2(0.5, 1.0); o.pos = UnityObjectToClipPos(float4(pos + p4 + fwd * chord, 1)); triStream.Append(o);
                o.uv = float2(0.5, 0.0); o.pos = UnityObjectToClipPos(float4(pos + p4 - fwd * chord, 1)); triStream.Append(o);

                // 5. RIGHT SHOULDER / BODY EDGE (UV 0.6)
                float3 p5 = right * bodyW;
                o.uv = float2(0.6, 1.0); o.pos = UnityObjectToClipPos(float4(pos + p5 + fwd * chord, 1)); triStream.Append(o);
                o.uv = float2(0.6, 0.0); o.pos = UnityObjectToClipPos(float4(pos + p5 - fwd * chord, 1)); triStream.Append(o);

                // 6. RIGHT ELBOW (UV 0.75)
                float3 p6 = mul(rotR, right * (bodyW + wingW));
                o.uv = float2(0.75, 1.0); o.pos = UnityObjectToClipPos(float4(pos + p6 + fwd * chord, 1)); triStream.Append(o);
                o.uv = float2(0.75, 0.0); o.pos = UnityObjectToClipPos(float4(pos + p6 - fwd * chord, 1)); triStream.Append(o);

                // 7. RIGHT WING TIP (UV 1.0)
                float3 p7 = mul(tipRRot, right * (bodyW + wingW + tipW));
                o.uv = float2(1.0, 1.0); o.pos = UnityObjectToClipPos(float4(pos + p7 + fwd * chord, 1)); triStream.Append(o);
                o.uv = float2(1.0, 0.0); o.pos = UnityObjectToClipPos(float4(pos + p7 - fwd * chord, 1)); triStream.Append(o);

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