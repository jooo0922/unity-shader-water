Shader "Custom/water"
{
    Properties
    {
        _BumpMap ("NormalMap", 2D) = "bump" {} // 물 노말맵 텍스쳐를 받아오는 인터페이스 생성을 위해 프로퍼티 추가
        _Cube ("Cubemap", cube) = "" {} // 큐브맵 텍스쳐를 받아오는 인터페이스 생성을 위해 프로퍼티 추가
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        CGPROGRAM
        #pragma surface surf Lambert 


        sampler2D _BumpMap; // 물 노멀맵 텍스쳐를 담는 샘플러 변수
        samplerCUBE _Cube; // 큐브맵 텍스쳐를 담는 전용 샘플러 변수인 samplerCUBE 선언

        struct Input
        {
            float2 uv_BumpMap; // 노멀맵 텍스쳐를 샘플링할 uv 좌표값 버텍스 구조체에 정의
            float3 worldRefl; // 큐브맵 텍스쳐 샘플링에 사용할 반사벡터
            /*
                큐브맵 텍스쳐는 3차원 공간에 맵핑되는 텍스쳐임.

                3차원 텍스처로부터 텍셀값을 샘플링 해오기 위한 방법은
                3차원 벡터값(float3)을 uv좌표로 사용하는 방법이 존재함.

                이때, 어떤 3차원 벡터값을 사용할 것인지가 중요한데,
                
                물체의 표면(프래그먼트)의 노말벡터를 기준으로,
                카메라 벡터(뷰 벡터)로 들어오는 빛을 역추적해서 구한
                반사벡터 (엄밀히 말하면, 카메라로 들어오는 빛이 반사된 빛임!)
                를 이용하면, 해당 프래그먼트에 비춰진 큐브맵의 텍셀(환경광)을 샘플링할 수 있음.

                그래서 큐브맵 텍스쳐를 샘플링할 때에는
                노말벡터와 카메라벡터의 반사벡터를 구해서 사용하는 것임.

                -> 이 과정을 직접 계산하는 내용이 <셰이더 코딩 입문>의
                스카이박스 파트에 나와있으므로, 공부할 때 참고할 것!
            */

            INTERNAL_DATA // 탄젠트 공간 노멀 벡터(UnpackNormal 에서 구해주는 값)를 월드 공간의 픽셀 노멀 벡터로 변환하기 위해 필요한 키워드 지정!
        };

        void surf (Input IN, inout SurfaceOutput o)
        {
            o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap)); // UnpackNormal() 로 노말맵 텍스쳐로부터 탄젠트 공간 노멀 벡터를 구함.

            // 큐브맵 텍스쳐로부터 텍셀값을 샘플링함. (샘플링 시 카메라벡터와 노말벡터를 기준으로 역추적한 반사벡터를 사용함.)
            float3 refColor = texCUBE(_Cube, WorldReflectionVector(IN, o.Normal)); // WorldReflectionVector() 내장함수로 월드공간 픽셀 노멀로 변환된 노멀벡터와 카메라벡터로 역추적한 반사벡터를 구함.
            o.Emission = refColor; // 반사광은 물체로부터 발산되는 빛(Emission) 의 한 종류로 볼 수 있으므로, 큐브맵으로부터 반사된 조명값 refColor 를 o.Emission 에 할당함.
            o.Alpha = 1;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
