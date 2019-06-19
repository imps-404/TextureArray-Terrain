/////////////
Shader "Custom/TerrainArray"
{

	Properties
	{
		[HideInInspector] _ControlTex("_ControlTex", 2DArray) = "red" {}
		[HideInInspector] _SplatTex("_SplatTex", 2DArray) = "white" {}
		[HideInInspector] _NormalTex("_NormalTex", 2DArray) = "bump" {}
		[HideInInspector] _BumpTex("_BumpTex", 2DArray) = "white" {}
		[HideInInspector]_Attenuation("_Attenuation", Range(0.1,3)) = 1.5
		[HideInInspector]_Specular("_Specular", Color) = (0,0,0,0)
		[HideInInspector]_NumTextures("_NumTextures", Int) = 0
			_SnowTex("_SnowTex", 2D) = "white" {}
		[HideInInspector]_snowCoef("_snowCoef", Range(0,3)) = 0
	}

		SubShader
		{
			Tags
			{
				"SplatCount" = "4"
				"Queue" = "Geometry-100"
				"RenderType" = "Opaque"
			}
			LOD 200
			// TERRAIN PASS 
			CGPROGRAM
	#define TERRAIN_INSTANCED_PERPIXEL_NORMAL
	#pragma target 5.0
	#pragma surface surf Standard   exclude_path:prepass vertex:vert addshadow fullforwardshadows
	#pragma shader_feature __ _PARALLAX
	#pragma debug
	#pragma require 2darray
	#define TERRAIN_SURFACE_OUTPUT SurfaceOutputStandard

	#include "UnityCG.cginc"
	#include <Lighting.cginc>
			//#include "UnityDeferredLibrary.cginc"

			// Access the Shaderlab properties
			uniform	float _snowCoef;
		uniform fixed _Attenuation;
		uniform fixed _Scale;
		uniform fixed _Parallax;
		uniform fixed _Normal;
		uniform half _Offset;
		uniform fixed _TileCount;
		uniform int _NumTextures;
		sampler2D _SnowTex;
		uniform fixed4 _Specular;
		const fixed3 desat = float3(0.22, 0.707, 0.071);
		uniform half2 realUV;
		uniform half2 originalUV;	

		uniform float4 matAtt[256];
		uniform float4 specMat[256];
		uniform float4 snowMat[256];

		UNITY_DECLARE_TEX2DARRAY(_ControlTex);
		UNITY_DECLARE_TEX2DARRAY(_SplatTex);
		UNITY_DECLARE_TEX2DARRAY(_NormalTex);
		UNITY_DECLARE_TEX2DARRAY(_BumpTex);
		
		// Surface shader input structure
		struct Input
		{
			float2 uv_Control : TEXCOORD0;
			float2 uv_Splat0 : TEXCOORD1;

			float3 viewDir;
			float4 vertex : POSITION;
	
			float sampleRatio;

		};
	

		void parallax_vert(float4 vertex, float3 normal, float4 tangent, out float3 viewDir, out float sampleRatio)
		{
			float4x4 mW = unity_ObjectToWorld;
			float3 binormal = cross(normal, tangent.xyz) * tangent.w;
			float3 EyePosition = _WorldSpaceCameraPos;

			// Need to do it this way for W-normalisation and.. stuff.
			float4 localCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
			float3 eyeLocal = vertex - localCameraPos;
			float4 eyeGlobal = mul(float4(eyeLocal, 1), mW);
			float3 E = eyeGlobal.xyz;

			float3x3 tangentToWorldSpace;

			tangentToWorldSpace[0] = mul(normalize(tangent), mW);
			tangentToWorldSpace[1] = mul(normalize(binormal), mW);
			tangentToWorldSpace[2] = mul(normalize(normal), mW);

			float3x3 worldToTangentSpace = transpose(tangentToWorldSpace);

			viewDir = mul(E, worldToTangentSpace);
			sampleRatio = 1 - dot(normalize(E), -normal);
		}
		void vert(inout appdata_full IN, out Input OUT)
		{
			UNITY_INITIALIZE_OUTPUT(Input, OUT);
			parallax_vert(IN.vertex, IN.normal, IN.tangent, OUT.viewDir, OUT.sampleRatio);
			OUT.uv_Splat0 = IN.texcoord;

			IN.tangent.xyz =  cross(IN.normal, float3(0, 0, 1));
			IN.tangent.w = -1;
			float3 binormal = cross(IN.normal, IN.tangent); // Calculate binormal as per usual.
		
		}

		//functions
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
		float CurrentCoord(float4 col, int i,int x)
		{
			uint k = i;
				[branch]if (k!= 0)
				k -= x * 4;
			[branch]if (k == 0)
				return col.r;
			else if (k == 1)
				return col.g;
			else if (k == 2)
				return col.b;
			else
				return col.a;
		}

		float4 Texture2DGrad(int i,float2 uv, float2 dx, float2 dy, float2 texSize)
		{
			//Sampling a texture by derivatives in unsupported in vert shaders in Unity but if you
			//can manually calculate the derivates you can reproduce its effect using tex2Dlod
			float2 px = texSize.x * dx;
			float2 py = texSize.y * dy;
			float lod = 0.5 * log2(max(dot(px, px), dot(py, py)));
			return UNITY_SAMPLE_TEX2DARRAY_LOD(_BumpTex, fixed3(uv,i), lod);	
		}
		inline float2 ParallaxOffsetSteep( half fHeightMapScale, half3 viewDir, float sampleRatio, float2 texcoord, int index,int x)
		{	
			float fParallaxLimit;
			fParallaxLimit = -length(viewDir.xy) / viewDir.z; 
			fParallaxLimit *= fHeightMapScale;

			float2 vOffsetDir = normalize(viewDir.xy);
			float2 vMaxOffset = vOffsetDir * fParallaxLimit;

			int nNumSamples = (int)lerp(4, 30, saturate(sampleRatio));
			float fStepSize = 1.0 / (float)nNumSamples;

			float2 dx = ddx(texcoord);
			float2 dy = ddy(texcoord);
			float fCurrRayHeight = 1.0;
			float2 vCurrOffset = float2(0, 0);
			float2 vLastOffset = float2(0, 0);

			float fLastSampledHeight = 1;
			float fCurrSampledHeight = 1;

			int nCurrSample = 0;

			 while (nCurrSample < nNumSamples)
			{
				fCurrSampledHeight = Texture2DGrad(index, texcoord + vCurrOffset, dx, dy, float2(2048, 2048));

				[branch]if (fCurrSampledHeight > fCurrRayHeight)
				{
					float delta1 = fCurrSampledHeight - fCurrRayHeight;
					float delta2 = (fCurrRayHeight + fStepSize) - fLastSampledHeight;

					float ratio = delta1 / (delta1 + delta2);

					vCurrOffset = (ratio)* vLastOffset + (1.0 - ratio) * vCurrOffset;

					nCurrSample = nNumSamples + 1;
				}
				else
				{
					nCurrSample++;

					fCurrRayHeight -= fStepSize;

					vLastOffset = vCurrOffset;
					vCurrOffset += fStepSize * (vMaxOffset);

					fLastSampledHeight = fCurrSampledHeight;
				}
			}
			return vCurrOffset;
		}

		float4 blend_unity(float4 n1, float4 n2)
		{
			n1 = n1.xyzz*float4(2, 2, 2, -2) + float4(-1, -1, -1, 1);
			n2 = n2 * 2 - 1;
			float3 r;
			r.x = dot(n1.zxx, n2.xyz);
			r.y = dot(n1.yzy, n2.xyz);
			r.z = dot(n1.xyw, -n2.xyz);
			return float4(r,1);
		}
		float3 blend(float4 texture1, float a1, float4 texture2, float a2)
		{
			return texture1.a + a1 > texture2.a + a2 ? texture1.rgb : texture2.rgb;
		}

		// Surface Shader function
		void surf(Input IN, inout SurfaceOutputStandard  o)
		{
		
			//Scaling and multipling num tiles
			//we are using 1st splat as reference for UV, since this a surface shader
			
			fixed4 snow = tex2D(_SnowTex, IN.uv_Splat0);
			fixed4 snowSum=0;
			//pre-set
			fixed4 splat_control;
			fixed4 splat = fixed4(0, 0, 0, 1);
	
			fixed3 col = fixed3(0, 0, 0);
			fixed4 col2 = fixed4(0, 0, 0, 0);

			o.Normal = fixed3(0, 0, 1);
			fixed4 nrm = fixed4(0, 0, 1, 1);
			fixed4 splatSum = fixed4(0, 0, 1, 1);
			
			half2 offset;

			fixed smoothness = 0;
			fixed metallic = 0;
			half4 specular = 0;
			int x = 0;
			int y = 0;
			//Loop texture array
			for (int i = 0; i < _NumTextures; i++)
			{
				originalUV = _Scale*IN.uv_Splat0*matAtt[0].z;

				[branch] if(i>0)
					originalUV /= matAtt[i].z;

				originalUV = (frac(originalUV) / _TileCount + TextOffset(originalUV));
				realUV = originalUV;// 

				//for control
				if (y > 3)
				{
					x++;
					y -= y;
				}

				splat_control = UNITY_SAMPLE_TEX2DARRAY(_ControlTex, fixed3(IN.uv_Control, x));

				//Parallax offset
	//#if defined(_PARALLAX)	
				offset = ParallaxOffsetSteep(_Parallax, IN.viewDir, IN.sampleRatio, realUV, i, x);
				realUV += offset;
	//#endif

				//Diffuse
				splat = UNITY_SAMPLE_TEX2DARRAY(_SplatTex, fixed3(realUV,  i));
				snow = tex2D(_SnowTex, realUV);
				col2.rgb += CurrentCoord(splat_control, i, x)*splat.rgb;
				col = lerp(col, splat.rgb, CurrentCoord(splat_control, i, x));
				//
				snowSum += snow* CurrentCoord(splat_control, i, x)*	snowMat[i].x;
			
			//	snowSum = lerp(col2, snowSum, 0.5)* CurrentCoord(splat_control, i, x);
				/////NORMAL NOTES
				//normalize dxt1, unpack for dxt5
				//read our text from Array
				//nrm += CurrentCoord(splat_control, i, x)*UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, i));
				nrm.rgb += UnpackNormalWithScale(UNITY_SAMPLE_TEX2DARRAY(_NormalTex, fixed3(realUV, i)), matAtt[i].w)*CurrentCoord(splat_control, i, x);
				//tex2D(_TerrainNormalmapTexture, IN.tc.zw).xyz * 2 - 1).xzy
				splatSum = nrm;
				[branch] if (y == 3 && i != 0) //check if it's a new control
				{
					splatSum = float4(nrm.xyz * 0.5f + 0.5f, 1.0f);
				}
				y++;
				realUV = originalUV;

				smoothness += matAtt[i].y*CurrentCoord(splat_control, i, x);
				metallic += matAtt[i].x*CurrentCoord(splat_control, i, x);
				specular += specMat[i] * CurrentCoord(splat_control, i, x);
			}
			if((uint)_NumTextures%4 !=0)
			splatSum += nrm;
			o.Normal = normalize(splatSum)-0.4;// UnpackScaleNormal(splatSum, 0);
			col = blend(fixed4(col,1), 0.5, col2, 0.25);
		

			col = blend(fixed4(col, 1), 0.5, snowSum, _snowCoef);//lerp(col, snowSum, snowCoef);
		
			//other
			o.Smoothness = smoothness * specular;// clamp(dot(col2, smoothness), 0.25, 0.75);
			o.Metallic = metallic;// clamp(dot(col2, metallic), 0.1, 1);
			//color
			o.Albedo = col.rgb*_Attenuation;
		
			
		
		}
		ENDCG
	} // End SubShader

	// Fallback to Diffuse
	Fallback "Nature/Terrain/Diffuse"
} 
