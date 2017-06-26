/*
Shader that displaces and rotates vertices in the geometry shader, converts each triangle in a pyramid and adding lightning
in the geometry shader.
Fixed values are Set in the script Fragmentation manager, updates from Fragmentor (per object)
*/

Shader "Custom/Fragment4"
{
	Properties
	{
		_MainTex("Base (RGB)", 2D) = "white" {}
		_DispTex("Disp Texture", 2D) = "gray" {}
		_Displacement("Displacement", Range(0, 10.0)) = 0.3
		_Randomness("Randomness", Range(0, 1.0)) = 0.3
		_TurnSpeed("Turn speed", Range(0, 500)) = 100
		_SpecColor("Spec Color", Color) = (1,1,1,1)
		_Gloss("Gloss", Range(0, 1)) = 0.5
		
	}

		SubShader
	{
		Pass
	{
		Tags{ "RenderType" = "Opaque" }
		

		CGPROGRAM
#pragma target 5.0
#pragma vertex VS_Main
#pragma fragment FS_Main
#pragma geometry GS_Main
#include "UnityCG.cginc" 
#include "UnityLightingCommon.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

		// **************************************************************
		// Data structures												*
		// **************************************************************
	struct GS_INPUT
	{
		float4	pos		: POSITION;
		float3	normal	: NORMAL;
		float2  tex0	: TEXCOORD0;
	};

	struct FS_INPUT
	{
		float4	pos		: POSITION;
		float2  uv	: TEXCOORD0;
		fixed4 col : COLOR0;
	};


	// **************************************************************
	// Vars															*
	// **************************************************************

	
	sampler2D  _MainTex;
	sampler2D _DispTex;
	float _Displacement;
	float _Randomness;
	float _TurnSpeed;
	float _TurnSpeedMultiplier;
	fixed4 _ColWarning;
	float _AlertLevel;
	float _Factor;
	float _Gloss;


	// **************************************************************
	// Shader Programs												*
	// **************************************************************

	// Vertex Shader ------------------------------------------------
	GS_INPUT VS_Main(appdata_base v)
	{
		GS_INPUT output = (GS_INPUT)0;

		output.pos = mul(unity_ObjectToWorld, v.vertex);
		output.normal = v.normal;
		output.tex0 = v.texcoord;

		return output;
	}

	//Rotation functio
	
	float4 RotateAroundCenterYInDegrees(float4 vertex, float degrees)
	{
		float4 center =  mul(unity_ObjectToWorld, float4(0,0,0,1));
		vertex -= center;
		float alpha = degrees * UNITY_PI / 180.0;
		float sina, cosa;
		sincos(alpha, sina, cosa);
		float2x2 m = float2x2(cosa, -sina, sina, cosa);
		float4 rot = float4(mul(m, vertex.xz), vertex.yw).xzyw;
		rot += center;
		return rot;

	}


	// Geometry Shader -----------------------------------------------------
[maxvertexcount(12)]
	void GS_Main(triangle GS_INPUT p[3], inout TriangleStream<FS_INPUT> tristream)
	{
		
		//Get normal of the triangle from the normals of the 3 vertice
		//------ Face normal
		//
		float3 P0 = p[0].pos.xyz;
		float3 P1 = p[1].pos.xyz;
		float3 P2 = p[2].pos.xyz;

		float3 V0 = P0 - P1;
		float3 V1 = P2 - P1;

		// If the diff between V0 and V1 is too small, 
		// the normal will be incorrect as well as the deformation.
		//
		float3 diff = V1 - V0;
		float diff_len = length(diff);

		float3 N = normalize(cross(V1, V0));

		//diplace the verices by N * scale
		float rdm = (tex2Dlod(_DispTex, float4(p[0].tex0, 0, 0)).r) * _Randomness;
		
		float displ = _Displacement - rdm * _Displacement *2;
		float3 Nd = N*displ;
		float4 v[3];
		v[0] = float4(P0 + Nd,1);
		v[1] = float4(P1 +Nd,1);
		v[2] = float4(P2 + Nd,1);
		
		//Rotate
		float pp = 0.5;
		float speed = sin(v[0].y*5) *_TurnSpeed* _TurnSpeedMultiplier;
		float rot =pow( displ, pp)*speed;

		
		v[0] = RotateAroundCenterYInDegrees(v[0],rot );
		v[1] = RotateAroundCenterYInDegrees(v[1], rot);
		v[2] = RotateAroundCenterYInDegrees(v[2], rot );

			

		//Make pyramide
		FS_INPUT o;
		_Factor = clamp(0.1 * _Displacement,0,0.1);
		float3 edgeA = v[1] - v[0];
		float3 edgeB = v[2] - v[0];
		N = normalize(cross(edgeA, edgeB));
		float3 centerPos = (v[0] + v[1] + v[2]) / 3;
		float2 centerTex = (p[0].tex0 + p[1].tex0 + p[2].tex0) / 3;
		centerPos += float4(N, 0) * _Factor;

		//calc normals sides
		float3 norm[4];
		norm[0] = N;
		norm[1] = normalize(cross(edgeA, centerPos - v[0]));
		norm[2] = normalize(cross(v[2] - v[1], centerPos - v[1]));
		norm[3] = normalize(-cross(edgeB, centerPos - v[2]));
		
		
		
		
		//Get common values for lightning & positioning
		
		float4x4 vp = mul(UNITY_MATRIX_MVP, unity_WorldToObject);
		
		float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
		float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - mul(vp, v[0]));
		float3 halfDirection = normalize(viewDirection + lightDirection);
		float attenuation = LIGHT_ATTENUATION(p);

		//for each side of the pyramide
		for (int i = 0; i < 3; i++)
		{

			//Calc the light
			float3 normalDirection = -norm[i + 1];
			float nl = max(0, dot(normalDirection, lightDirection));//lambert

			float3 fc = nl+ nl*pow(max(0, dot(normalDirection, halfDirection)), exp2(lerp(1, 11, _Gloss)))*_SpecColor*_LightColor0.rgb*attenuation;
			fixed4 Col = float4(fc, 1);
			
			
			//Make Stream
			o.pos = mul(vp, v[i]);
			o.uv = p[i].tex0;
			o.col = Col;
			tristream.Append(o);

			int inext = (i + 1) % 3;
			o.pos = mul(vp, v[inext]);
			o.uv = p[inext].tex0;
			o.col = Col;
			tristream.Append(o);

			o.pos = mul(vp,float4(centerPos, 1));
			o.uv = centerTex;
			o.col = Col;
			tristream.Append(o);

			tristream.RestartStrip();
		}
		
		// do the base of pyramid

		//Calc the light
		float3 normalDirection = -norm[0];
		float nl = max(0, dot(normalDirection, lightDirection));//lambert

		float3 fc = nl + nl*pow(max(0, dot(normalDirection, halfDirection)), exp2(lerp(1, 11, _Gloss)))*_SpecColor*_LightColor0.rgb*attenuation;
		fixed4 Col = float4(fc, 1);


		//Make Stream
		o.pos = mul(vp, v[0]);
		o.uv = p[0].tex0;
		o.col = Col;
		tristream.Append(o);

		o.pos = mul(vp, v[2]);
		o.uv = p[1].tex0;
		o.col = Col;
		tristream.Append(o);

		o.pos = mul(vp, v[1]);
		o.uv = p[2].tex0;
		o.col = Col;
		tristream.Append(o);

		tristream.RestartStrip();
		
				
	}



	// Fragment Shader -----------------------------------------------
	float4 FS_Main(FS_INPUT input) : COLOR
	{
		//Get color from texture
		fixed4 col = tex2D(_MainTex, input.uv);

		// multiply by lighting
		col *= input.col;
		
		return col;
	}

		ENDCG
	}
	}
}
