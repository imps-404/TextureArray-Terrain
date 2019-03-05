Shader "Toon/ToonTerrain"
{
	Properties{
	[HideInInspector] _ControlTex("_ControlTex", 2DArray) = "red" {}
	[HideInInspector] _SplatTex("_SplatTex", 2DArray) = "white" {}
	[HideInInspector] _NormalTex("_NormalTex", 2DArray) = "bump" {}
	[HideInInspector] _BumpTex("_BumpTex", 2DArray) = "black" {}

	_Ramp("Toon Ramp (RGB)", 2D) = "gray" {}

	}

		SubShader
	{
		Tags
	{
		"Queue" = "Geometry"
		"IgnoreProjector" = "False"
		"RenderType" = "Opaque"
	}
		LOD 200
		// TERRAIN PASS 
		CGPROGRAM
#pragma target 3.5
#pragma  surface surf ToonRamp vertex:vert exclude_path:prepass addshadow noambient 
#pragma shader_feature __ _PARALLAX
#pragma shader_feature __ _NORMALMAP
		// Access the Shaderlab properties
	uniform sampler2D _Ramp;
	float _Attenuation;
	float _Scale;
	float _Parallax;
	float _Offset;
	float _TileCount;
	int _NumTextures;

	UNITY_DECLARE_TEX2DARRAY(_ControlTex);
	UNITY_DECLARE_TEX2DARRAY(_SplatTex);
	UNITY_DECLARE_TEX2DARRAY(_NormalTex);
	UNITY_DECLARE_TEX2DARRAY(_BumpTex);

	struct SurfaceOutputCustom
	{
		fixed3 Albedo;
		fixed3 Normal;
		fixed3 Emission;
		fixed Alpha;
	};

	// Custom lighting model that uses a texture ramp based
	// on angle between light direction and normal
	inline half4 LightingToonRamp(SurfaceOutputCustom s, half3 lightDir, half atten)
	{
#ifndef USING_DIRECTIONAL_LIGHT
		lightDir = normalize(lightDir);
#endif
		// Wrapped lighting
		half d = dot(s.Normal, lightDir) * 0.5 + 0.5;
		// Applied through ramp
		half3 ramp = tex2D(_Ramp, float2(d,d)).rgb;
		half4 c;
		c.rgb = s.Albedo * _LightColor0.rgb * (ramp) * (atten *_Attenuation);
		c.a = 0;
		return c;
	}
	void vert(inout appdata_full v)
	{
		v.tangent.xyz = cross(v.normal, float3(0, 0, 1));
		v.tangent.w = -1;
	}

	float2 rand2(float2 n)
	{
		float2 result;
		result.x = frac(sin(fmod(dot(n.xy, float2 (12.9898, 78.233)), 3.14)) * 43758.5453);
		result.y = frac(sin(fmod(dot(n.yx, float2 (12.9898, 78.233)), 3.14)) * 43758.5453);

		return result;
	}

	float2 TextOffset(float2 n)
	{
		float2 result;
		result = rand2(floor(n));
		result = floor(result * _TileCount) / _TileCount;
		return result;
	}


	// Surface shader input structure
	struct Input
	{
		float2 uv_Control : TEXCOORD0;
		float2 uv_Splat0 : TEXCOORD1;
		float3 viewDir;
	};

	UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_DEFINE_INSTANCED_PROP(float, _TextureIndex)
#define _TextureIndex_arr Props
		UNITY_INSTANCING_BUFFER_END(Props)

		inline float2 ParallaxOffsetSteep(half h, half height, half3 viewDir)
	{
		h = h * height - height / 2.0;

		float3 v = normalize(viewDir);
		v.z += 0.42;
		return h * (v.xy / v.z);
	}

	// Surface Shader function
	void surf(Input IN, inout SurfaceOutputCustom o)
	{
	

		fixed2 realUV, originalUV;
		originalUV = IN.uv_Splat0 * _Scale;
		originalUV = (frac(originalUV) / _TileCount + TextOffset(originalUV));

		realUV = originalUV;

		fixed4 splat_control = UNITY_SAMPLE_TEX2DARRAY(_ControlTex, fixed3(IN.uv_Control, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 0)));
		fixed4 splat = fixed4(0, 0, 0, 1);
		fixed3 col = fixed3(0, 0, 0);

		
#if defined(_NORMALMAP)
		fixed4 nrm;
		fixed splatSum = dot(splat_control, fixed4(1, 1, 1, 1));
		fixed4 flatNormal = fixed4(0.5, 0.5, 1, 0.5); // this is "flat normal" in both DXT5nm and xyz*2-1 cases
#endif
#if defined(_PARALLAX)
		fixed4 bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 0)));
		fixed h;
		fixed2 offset;
		h = bumpTex.r;
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 0)));
		fixed4 tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.r * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 0)));
		nrm = splat_control.r *splat;
#endif
		realUV = originalUV;
///////////////
#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 1)));
		h = bumpTex.r;
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 1)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.g * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 1)));
		nrm += splat_control.g *splat;
#endif
		realUV = originalUV;
/////////////

#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 2)));
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 2)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.b * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 2)));
		nrm += splat_control.b * splat;
#endif
		realUV = originalUV;
/////////////
#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 3)));
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 3)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.a * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 3)));
		nrm += splat_control.a * splat;
#endif
		realUV = originalUV;
///////////////////////////////////////////////////////////////////////////////////////

		splat_control = UNITY_SAMPLE_TEX2DARRAY(_ControlTex, fixed3(IN.uv_Control, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 1)));
///////////////
#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 4)));
		h = bumpTex.r;
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 4)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.r * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 4)));
		nrm += splat_control.g *splat;
#endif
		realUV = originalUV;
///////////////
#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 5)));
		h = bumpTex.r;
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 5)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.g * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 5)));
		nrm += splat_control.g *splat;
#endif
		realUV = originalUV;
		/////////////

#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 6)));
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 6)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.b * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 6)));
		nrm += splat_control.b * splat;
#endif
		realUV = originalUV;
		/////////////
#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 7)));
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 7)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.a * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 7)));
		nrm += splat_control.a * splat;
#endif
		realUV = originalUV;
		///////////////////////////////////////////////////////////////////////////////////////

		splat_control = UNITY_SAMPLE_TEX2DARRAY(_ControlTex, fixed3(IN.uv_Control, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 2)));
		///////////////
#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 8)));
		h = bumpTex.r;
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 8)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.r * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 8)));
		nrm += splat_control.g *splat;
#endif
		realUV = originalUV;
		///////////////
#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 9)));
		h = bumpTex.r;
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 9)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.g * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 9)));
		nrm += splat_control.g *splat;
#endif
		realUV = originalUV;
		/////////////

#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 10)));
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 10)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.b * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 10)));
		nrm += splat_control.b * splat;
#endif
		realUV = originalUV;
		/////////////
#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 11)));
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 11)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.a * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 11)));
		nrm += splat_control.a * splat;
#endif
		realUV = originalUV;
		//////////////
		///////////////////////////////////////////////////////////////////////////////////////

		splat_control = UNITY_SAMPLE_TEX2DARRAY(_ControlTex, fixed3(IN.uv_Control, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 3)));
		///////////////
#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 12)));
		h = bumpTex.r;
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 12)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.r * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 13)));
		nrm += splat_control.g *splat;
#endif
		realUV = originalUV;
		///////////////
#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 13)));
		h = bumpTex.r;
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 13)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.g * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 13)));
		nrm += splat_control.g *splat;
#endif
		realUV = originalUV;
		/////////////

#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 14)));
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 14)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.b * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 14)));
		nrm += splat_control.b * splat;
#endif
		realUV = originalUV;
		/////////////
#if defined(_PARALLAX)
		bumpTex = UNITY_SAMPLE_TEX2DARRAY(_BumpTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 15)));
		offset = ParallaxOffsetSteep(h, _Parallax, IN.viewDir);
		realUV += offset;
#endif
		splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 15)));
		tmp = splat;
		col = lerp(col, tmp.rgb, splat_control.a * tmp.a);
#if defined(_NORMALMAP)
		splat = UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, UNITY_ACCESS_INSTANCED_PROP(_TextureIndex_arr, 15)));
		nrm += splat_control.a * splat;
#endif
		realUV = originalUV;
		//////////////
#if defined(_NORMALMAP)
		nrm = lerp(flatNormal, nrm, splatSum);
		o.Normal = UnpackNormal(nrm);
#endif
		//color
		o.Albedo = col.rgb;

	}


	ENDCG

	} // End SubShader

} 
