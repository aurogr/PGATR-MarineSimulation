Shader "Custom/Tesselation Sample"
{
    Properties
    {
        _Tess("Tessellation", Range(1,32)) = 4
        _Displacement("Displacement", Range(0, 1.0)) = 0.3
        _Color("Color", color) = (1,1,1,0)
        _SpecColor("Spec color", color) = (0.5,0.5,0.5,0.5)
        _NoiseScale("Noise Scale", Range(0,50)) = 1
        _Speed("Speed", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 300

        CGPROGRAM
        #pragma surface surf BlinnPhong addshadow fullforwardshadows vertex:disp tessellate:tessFixed nolightmap
        #pragma target 4.6

        #include "Assets/Shaders/Noise.hlsl" 

        struct appdata {
            float4 vertex : POSITION;
            float4 tangent : TANGENT;
            float3 normal : NORMAL;
            float2 texcoord : TEXCOORD0;
        };

        float _Tess;

        float4 tessFixed()
        {
            return _Tess;
        }

        float _NoiseScale;
        float _Speed;
        float _Displacement;

        void disp(inout appdata v)
        {
            float2 uv = (v.texcoord * _NoiseScale) + float2(0, _Time.y * _Speed);
            float noise; GradientNoise_float(uv, 1, noise);
            v.vertex.xyz += v.normal * (noise * _Displacement);
        }

        struct Input
        {
            float2 uv_MainTex;
        };

        fixed4 _Color;

        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 c = _Color;
            o.Albedo = c.rgb;
            o.Specular = 0.2;
            o.Gloss = 1.0;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
