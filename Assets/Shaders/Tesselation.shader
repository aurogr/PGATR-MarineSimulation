Shader "Unlit/Tesselation"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    _Color("Color",Color) = (1,1,1,1)
        _TessellationUniform("TesselationUniform", Range(1,64)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma hull hull
            #pragma domain domain
            #pragma target 4.6


            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 tangent : TANGENT;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD2;
                float3 tangent : TEXCOORD3;
            };

            struct TessellationFactors {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };


            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _TessellationUniform;


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);

                o.normal = v.normal;
                o.tangent = v.tangent;
                o.uv = v.uv;

                o.uv = v.uv;
                return o;
            }

            // le entra el triangulo y genera los factores de teselacion
            TessellationFactors patchConstantFunction(
                InputPatch<appdata, 3> patch)
            {
                TessellationFactors f;
                f.edge[0] = _TessellationUniform;
                f.edge[1] = _TessellationUniform;
                f.edge[2] = _TessellationUniform;
                f.inside = _TessellationUniform;
                return f;
            }

            [UNITY_domain("tri")]               // define que trabaja con triangulos
            [UNITY_outputcontrolpoints(3)]      // define que se establecen tres puntos d control por cada patch. uno para cada esquina del triangulo
            [UNITY_outputtopology("triangle_cw")] // topologia de los triangulos que va a generar la GPU. si clockwise o counterclockwise
            [UNITY_partitioning("integer")]     // metodo de partición del patch para la GPU
            [UNITY_patchconstantfunc("patchConstantFunction")] // en cuantas partes se corta el patch, puede variar para cada uno
            appdata hull(
                InputPatch<appdata, 3> patch,
                uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            [UNITY_domain("tri")]
            //InterpolatorsVertex domain(
            v2f domain(
                TessellationFactors factors,
                OutputPatch<appdata, 3> patch,
                float3 barycentricCoordinates : SV_DomainLocation /* coordenadas para generar nuevos vertices*/)
            {
                appdata data = (appdata)0; 
                #define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
		            patch[0].fieldName * barycentricCoordinates.x + \
		            patch[1].fieldName * barycentricCoordinates.y + \
		            patch[2].fieldName * barycentricCoordinates.z;

                MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
                MY_DOMAIN_PROGRAM_INTERPOLATE(normal)
                MY_DOMAIN_PROGRAM_INTERPOLATE(tangent)

                return vert(data);
            }


            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                return col;
            }

            ENDCG
        }
    }
}
