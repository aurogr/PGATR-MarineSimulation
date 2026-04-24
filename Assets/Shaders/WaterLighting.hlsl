#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

float GTR2_aniso(float HdotX, float HdotY, float NdotH, float ax, float ay)
{
	float denom = (HdotX * HdotX) / (ax * ax) + (HdotY * HdotY) / (ay * ay) + NdotH * NdotH;
	return 1.0 / (PI * ax * ay * denom * denom);
}
float smithG_GGX_aniso(float NdotW, float WdotX, float WdotY, float ax, float ay)
{
	float num = NdotW;
	float denom = sqrt(WdotX * WdotX / (ax * ax) + WdotY * WdotY / (ay * ay) + NdotW * NdotW);
	return 2.0 * num / (num + denom + 1e-5); // evita división por cero
}

float3 Specular(float3 N, float3 X, float3 Y, float3 L, float3 V, float3 H, float NdotL, float NdotV, float NdotH, float HdotL,
	float Anisotropic, float Roughness, float Specular)
{
	float aspect = sqrt(1 - 0.9 * Anisotropic);
	float ax = max(0.001, (Roughness * Roughness) / aspect);
	float ay = max(0.001, (Roughness * Roughness) * aspect);
	float HdotX = dot(H, X);
	float HdotY = dot(H, Y);

	//Dm
	float Dm = GTR2_aniso(HdotX, HdotY, NdotH, ax, ay);
	//Fm
	float3 Cspecular = 0.08 * Specular;
	float3 fresnelSpec = lerp(Cspecular, float3(1, 1, 1), pow(1 - saturate(HdotL), 5));
	//Gm
	float Gm;
	Gm = smithG_GGX_aniso(NdotL, dot(L, X), dot(L, Y), ax, ay);
	Gm *= smithG_GGX_aniso(NdotV, dot(V, X), dot(V, Y), ax, ay);

	return Dm * fresnelSpec * Gm / max(4 * NdotL * NdotV, 0.0000001);
}

void MainLighting_float(float3 normal, float3 position, float3 view, float roughness, float SpecularInt,  out float3 Out)
{
	Out = 0;

#ifndef SHADERGRAPH_PREVIEW
	normal = normalize(normal);
	float3 up = abs(normal.y) < 0.999 ? float3(0, 1, 0) : float3(1, 0, 0);
	float3 tangent = normalize(cross(up, normal));
	float3 bitangent = normalize(cross(normal, tangent));
	view = SafeNormalize(view);
	Light mainLight = GetMainLight(TransformWorldToShadowCoord(position));
	float3 lightDir = mainLight.direction;
	float3 halfway = normalize(view + lightDir);

	float HdotL = saturate(dot(halfway, lightDir));
	float HdotV = saturate(dot(halfway, view));
	float NdotL = saturate(dot(normal, lightDir));
	float NdotV = saturate(dot(normal, view));
	float NdotH = saturate(dot(normal, halfway));

	float3 spec = Specular(normal, tangent, bitangent, lightDir, view, halfway,
		NdotL, HdotV, NdotH, HdotL,
		0, roughness, SpecularInt);

	Out = spec;
#endif
}

void AdditionalLighting_float(float3 normal, float3 position, float3 view, float roughness, float SpecularInt, out float3 Out)
{
	Out = 0;

#ifndef SHADERGRAPH_PREVIEW
	normal = normalize(normal);
	float3 up = abs(normal.y) < 0.999 ? float3(0, 1, 0) : float3(1, 0, 0);
	float3 tangent = normalize(cross(up, normal));
	float3 bitangent = normalize(cross(normal, tangent));
	view = SafeNormalize(view);
	float3 NdotV = saturate(dot(normal, view));

	float3 lightDir, halfway, spec;
	float HdotL, NdotL, HdotV, NdotH;
	Light light;

	int pixelLightCount = GetAdditionalLightsCount();
	for (int i = 0; i < pixelLightCount; ++i)
	{
		light = GetAdditionalLight(i, position);
		lightDir = light.direction;
		halfway = normalize(view + lightDir);
		HdotL = saturate(dot(halfway, lightDir));
		NdotL = saturate(dot(normal, lightDir));
		HdotV = saturate(dot(halfway, view));
		NdotH = saturate(dot(normal, halfway));

		spec = Specular(normal, tangent, bitangent, lightDir, view, halfway,
			NdotL, HdotV, NdotH, HdotL,
			0, roughness, SpecularInt);
		Out += spec * light.color;
	}
#endif
}