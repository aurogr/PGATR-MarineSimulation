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

            // -------- GEOMETRY SHADER ------------
	        [maxvertexcount(36)]
            void geo(point vertexOutput IN[1], inout TriangleStream<geometryOutput> triStream)
            {
                geometryOutput o;
                // get parameters from the vertex shader
                float3 pos = IN[0].pos.xyz;
                float3 fwd = normalize(IN[0].direction);
                float boidSpeed = IN[0].speed;
                
                // Get random size, between size min and max
                float rSize = rand(float3(IN[0].id, IN[0].id, IN[0].id)); // seed is random but consistent per boid
                float s = lerp(_SizeMin, _SizeMax, rSize);
                
                // Animation parameters, based on the boid's speed and the global time
                float flapSin = sin(_Time.y * (boidSpeed * _FlapSpeedToVelocityRelation));
                float amp = boidSpeed * _FlapAmplitudeToSpeedRelation;

                float3x3 rotL = AngleAxis3x3(flapSin * amp, fwd);
                float3x3 rotLStronger = AngleAxis3x3(flapSin * amp * 2, fwd);
                float3x3 rotR = AngleAxis3x3(-flapSin * amp, fwd);
                float3x3 rotRStronger = AngleAxis3x3(-flapSin * amp * 2, fwd);

                // construct right and up vector to create a local space for the bird based on its forward direction
                float3 right = normalize(cross(float3(0, 1, 0), fwd));
                float3 up = cross(fwd, right); // crease direction

                // body parameters
                float bodyW = 0.2 * s;
                float3 sideL = -right * bodyW;
                float3 sideR =  right * bodyW;
                float3 spine = -up * _BodyCrease; // push center down

                // Body is two triangle strips with a crease in the center to show a little more dimension                
                // 1. HEAD
                float3 h_start = fwd * s * 1;
                float3 h_end = fwd * s * 0.8;
                // Left Head
                o.uv = float2(0.42, 1.0); o.pos = UnityObjectToClipPos(float4(pos + h_start + sideL, 1)); triStream.Append(o);
                o.uv = float2(0.50, 1.0); o.pos = UnityObjectToClipPos(float4(pos + h_start + spine, 1)); triStream.Append(o);
                o.uv = float2(0.42, 0.8); o.pos = UnityObjectToClipPos(float4(pos + h_end + sideL, 1)); triStream.Append(o);
                o.uv = float2(0.50, 0.8); o.pos = UnityObjectToClipPos(float4(pos + h_end + spine, 1)); triStream.Append(o);
                triStream.RestartStrip();
                // Right Head
                o.uv = float2(0.50, 1.0); o.pos = UnityObjectToClipPos(float4(pos + h_start + spine, 1)); triStream.Append(o);
                o.uv = float2(0.58, 1.0); o.pos = UnityObjectToClipPos(float4(pos + h_start + sideR, 1)); triStream.Append(o);
                o.uv = float2(0.50, 0.8); o.pos = UnityObjectToClipPos(float4(pos + h_end + spine, 1)); triStream.Append(o);
                o.uv = float2(0.58, 0.8); o.pos = UnityObjectToClipPos(float4(pos + h_end + sideR, 1)); triStream.Append(o);
                triStream.RestartStrip();

                // 2. BODY
                float3 b_start = fwd * s * 0.8;
                float3 b_end = -fwd * s * 0.5;
                // Left Body
                o.uv = float2(0.42, 0.8); o.pos = UnityObjectToClipPos(float4(pos + b_start + sideL, 1)); triStream.Append(o);
                o.uv = float2(0.50, 0.8); o.pos = UnityObjectToClipPos(float4(pos + b_start + spine, 1)); triStream.Append(o);
                o.uv = float2(0.42, 0.3); o.pos = UnityObjectToClipPos(float4(pos + b_end + sideL, 1)); triStream.Append(o);
                o.uv = float2(0.50, 0.3); o.pos = UnityObjectToClipPos(float4(pos + b_end + spine, 1)); triStream.Append(o);
                triStream.RestartStrip();
                // Right Body
                o.uv = float2(0.50, 0.8); o.pos = UnityObjectToClipPos(float4(pos + b_start + spine, 1)); triStream.Append(o);
                o.uv = float2(0.58, 0.8); o.pos = UnityObjectToClipPos(float4(pos + b_start + sideR, 1)); triStream.Append(o);
                o.uv = float2(0.50, 0.3); o.pos = UnityObjectToClipPos(float4(pos + b_end + spine, 1)); triStream.Append(o);
                o.uv = float2(0.58, 0.3); o.pos = UnityObjectToClipPos(float4(pos + b_end + sideR, 1)); triStream.Append(o);
                triStream.RestartStrip();

                // 3. TAIL
                float3 t_start = -fwd * s * 0.5;
                float3 t_end = -fwd * s * 1;
                // Left Tail
                o.uv = float2(0.42, 0.3); o.pos = UnityObjectToClipPos(float4(pos + t_start + sideL, 1)); triStream.Append(o);
                o.uv = float2(0.50, 0.3); o.pos = UnityObjectToClipPos(float4(pos + t_start + spine, 1)); triStream.Append(o);
                o.uv = float2(0.42, 0.0); o.pos = UnityObjectToClipPos(float4(pos + t_end + sideL, 1)); triStream.Append(o);
                o.uv = float2(0.50, 0.0); o.pos = UnityObjectToClipPos(float4(pos + t_end + spine, 1)); triStream.Append(o);
                triStream.RestartStrip();
                // Right Tail
                o.uv = float2(0.50, 0.3); o.pos = UnityObjectToClipPos(float4(pos + t_start + spine, 1)); triStream.Append(o);
                o.uv = float2(0.58, 0.3); o.pos = UnityObjectToClipPos(float4(pos + t_start + sideR, 1)); triStream.Append(o);
                o.uv = float2(0.50, 0.0); o.pos = UnityObjectToClipPos(float4(pos + t_end + spine, 1)); triStream.Append(o);
                o.uv = float2(0.58, 0.0); o.pos = UnityObjectToClipPos(float4(pos + t_end + sideR, 1)); triStream.Append(o);
                triStream.RestartStrip();

                // --- 4. WINGS (Using Rotations) ---
                // Left Wing
                float3 wing_end = - fwd * s * 0.2;
                o.uv = float2(0.42, 0.7); o.pos = UnityObjectToClipPos(float4(pos - b_end + sideL, 1)); triStream.Append(o);
                o.uv = float2(0.42, 0.4); o.pos = UnityObjectToClipPos(float4(pos + wing_end + sideL, 1)); triStream.Append(o);
                float3 elbLT = mul(rotL, -right * s * 1.0 + fwd * s * 0.2);
                float3 elbLB = mul(rotL, -right * s * 1.0 - fwd * s * 0.1);
                o.uv = float2(0.25, 0.8); o.pos = UnityObjectToClipPos(float4(pos + elbLT, 1)); triStream.Append(o);
                o.uv = float2(0.25, 0.5); o.pos = UnityObjectToClipPos(float4(pos + elbLB, 1)); triStream.Append(o);
                float3 tipLT = mul(rotLStronger, -right * s * 2.0 + fwd * s * 0.1);
                float3 tipLB = mul(rotLStronger, -right * s * 2.0 - fwd * s * 0.1);
                o.uv = float2(0.0, 0.6); o.pos = UnityObjectToClipPos(float4(pos + tipLT, 1)); triStream.Append(o);
                o.uv = float2(0.0, 0.3); o.pos = UnityObjectToClipPos(float4(pos + tipLB, 1)); triStream.Append(o);
                triStream.RestartStrip();

                // Right Wing
                o.uv = float2(0.58, 0.7); o.pos = UnityObjectToClipPos(float4(pos + fwd * s * 0.5 + sideR, 1)); triStream.Append(o);
                o.uv = float2(0.58, 0.4); o.pos = UnityObjectToClipPos(float4(pos - fwd * s * 0.2 + sideR, 1)); triStream.Append(o);
                float3 elbRT = mul(rotR, right * s * 1.0 + fwd * s * 0.2);
                float3 elbRB = mul(rotR, right * s * 1.0 - fwd * s * 0.1);
                o.uv = float2(0.75, 0.8); o.pos = UnityObjectToClipPos(float4(pos + elbRT, 1)); triStream.Append(o);
                o.uv = float2(0.75, 0.5); o.pos = UnityObjectToClipPos(float4(pos + elbRB, 1)); triStream.Append(o);
                float3 tipRT = mul(rotRStronger, right * s * 2.0 + fwd * s * 0.1);
                float3 tipRB = mul(rotRStronger, right * s * 2.0 - fwd * s * 0.1);
                o.uv = float2(1.0, 0.6); o.pos = UnityObjectToClipPos(float4(pos + tipRT, 1)); triStream.Append(o);
                o.uv = float2(1.0, 0.3); o.pos = UnityObjectToClipPos(float4(pos + tipRB, 1)); triStream.Append(o);
                triStream.RestartStrip();
            }

            sampler2D _MainTex;

            // -------- FRAGMENT SHADER ------------
	        #include "Lighting.cginc"
	        fixed4 frag (geometryOutput i) : SV_Target
            {
                // 1. Sample the texture
		        fixed4 col = tex2D(_MainTex, i.uv);

		        // 2. The Clip Magic:
		        // If (col.a - 0.5) is less than 0, the pixel is discarded.
		        clip(col.a - 0.5);

		        return col;
            }
            ENDCG
        }
    }
}