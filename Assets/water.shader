Shader "Custom/water"
{
    Properties
    {
        _BumpMap ("NormalMap", 2D) = "bump" {} // 물 노말맵 텍스쳐를 받아오는 인터페이스 생성을 위해 프로퍼티 추가
        _Cube ("Cubemap", cube) = "" {} // 큐브맵 텍스쳐를 받아오는 인터페이스 생성을 위해 프로퍼티 추가
        _SPColor("Specular Color", color) = (1, 1, 1, 1) // 스펙큘러 색상을 받아오는 인터페이스 생성을 위해 프로퍼티 추가
        _SPPower("Specular Power", Range(50, 300)) = 150 // 스펙큘러 광택값(shininess) 을 받아오는 인터페이스 생성을 위해 프로퍼티 추가
        _SPMulti("Specular Multiply", Range(1, 10)) = 3 // HDR Bloom 기능을 활성화할 때, 매우 강렬한 태양빛 반사를 재현하기 위해 1 이상의 값을 받아서 최종 스펙큘러에 더해줄 때 사용할 값을 받는 인터페이스 추가
    }
    SubShader
    {
        // 그냥 큐브맵에서 샘플링한 반사광만 적용하니까 너무 금속 느낌이 나서 알파 블렌딩(반투명) 쉐이더로 만들고,
        // o.Alpha 값을 조절해서 물 느낌이 좀 더 나게 만들려고 함.
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}

        CGPROGRAM
        // 물 셰이더에 하프벡터를 이용한 블린-퐁 스펙큘러를 계산해서 결과값에 더해주는 커스텀 함수 추가
        #pragma surface surf WaterSpecular alpha:fade


        sampler2D _BumpMap; // 물 노멀맵 텍스쳐를 담는 샘플러 변수
        samplerCUBE _Cube; // 큐브맵 텍스쳐를 담는 전용 샘플러 변수인 samplerCUBE 선언
        float4 _SPColor; // 스펙큘러 색상값을 담는 변수
        float _SPPower; // 스펙큘러 광택값(거듭제곱에 사용)을 담는 변수
        float _SPMulti; // HDR Bloom 사용 시, 강렬한 태양빛 반사를 재현하기 위해 곱해주는 값을 담는 변수

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

            float3 viewDir; // 물의 반사 및 투과를 구현하기 위해 필요한 rim값 계산 시 사용할 카메라 벡터

            INTERNAL_DATA // 탄젠트 공간 노멀 벡터(UnpackNormal 에서 구해주는 값)를 월드 공간의 픽셀 노멀 벡터로 변환하기 위해 필요한 키워드 지정!
        };

        void surf (Input IN, inout SurfaceOutput o)
        {
            // UnpackNormal() 로 노말맵 텍스쳐로부터 탄젠트 공간 노멀 벡터를 구함.
            // 이때, 물이 어느 한 방향으로 움직이는게 아닌, 가운데에서 찰랑거리는 느낌을 주기 위해, 동일한 노말맵을 샘플링하는 uv좌표에 각각 
            // 유니티 내장 시간변수 _Time 을 서로 반대방향으로 더하기 or 빼기 해줌으로써,
            // 서로 반대방향으로 샘플링하여 움직이는 두 개의 노말맵(처럼 보이지만 원본은 동일한 노말맵)으로부터 노말벡터를 샘플링한 뒤,
            // 두 노멀의 평균값을 내서 할당하는 방식을 사용할 수 있음. -> 노말맵으로 물 흐름을 표현하는 가장 간단하고 가벼운 방식으로, 실무에서도 많이 사용된다고 함.
            float3 normal1 = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap + _Time.x * 0.1)); 
            float3 normal2 = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap - _Time.x * 0.1));
            o.Normal = (normal1 + normal2) / 2;

            // 큐브맵 텍스쳐로부터 텍셀값을 샘플링함. (샘플링 시 카메라벡터와 노말벡터를 기준으로 역추적한 반사벡터를 사용함.)
            float3 refColor = texCUBE(_Cube, WorldReflectionVector(IN, o.Normal)); // WorldReflectionVector() 내장함수로 월드공간 픽셀 노멀로 변환된 노멀벡터와 카메라벡터로 역추적한 반사벡터를 구함.
            
            // rim term
            /*
                물의 반사 및 투과 
                
                물 재질 구현 시 알아야 할 가장 중요한 점은,
                우리 시야(카메라)에서 가까운, 즉 수직인 지점일수록 투과(투명)이 많고, 반사는 적은 반면,
                우리 시야(카메라)에서 멀어질수록, 즉 평행한 지점일수록 투과(투명)이 적고, 반사가 많음.

                프래그먼트 지점이 카메라 각도와 수직인지 아닌지를 판단하기 적절한 게
                림라이트 구현 시 사용했던 Rim 값을 사용하면 딱 좋음.

                왜냐하면, Rim 값은 카메라 벡터와 프래그먼트의 노말벡터를 내적계산해서 구하므로,
                카메라 벡터와 프래그먼트의 노말벡터가 겹치는 지점, 즉 카메라 벡터와 프래그먼트가 수직인 지점의
                내적값이 1로 표현되고, 수직에서 멀어질수록 내적값이 0에 가까워지다가 
                완전 평행해지면(즉, 노말벡터와 이루는 각도가 90도가 되면) 내적값이 0이 됬었지?

                따라서, 카메라와 가까운 지점의 물은 Rim값이 1에 가까워질테고,
                멀리 있는 지점의 물은 Rim값이 0에 가까워지겠지! (음수인 내적값을 제거했다는 가정 하에)
            */
            float rim = saturate(dot(o.Normal, IN.viewDir)); // 음수인 내적값을 0으로 초기화하는 saturate() 내장함수 사용 (o.Alpha 투명도에 음수값을 넣을 순 없잖아!)
            
            // 1 - rim 해서 rim 값을 뒤집어준 이유는, rim값을 o.Alpha(투명도)에 넣을거기 때문에, 
            // 가까운 지점일수록 rim값이 1에 가까워지지만, 투명도는 0에 가까워야 하고,
            // 멀리 있는 지점일수록 rim값이 0에 가까워지지만, 투명도는 1에 가까워야 하니까 뒤집어주려는 것!
            // 또 림라이트 계산 시 일반적으로 외곽선(역광) 범위를 확 좁히기 위해 Rim 값을 거듭제곱 해주는 것처럼
            // 여기서도 투명한 영역의 범위를 넓히는 반면 반사되는 영역의 범위는 확 좁히기 위해 거듭제곱을 해줌. 
            rim = pow(1 - rim, 1.5); 

            // 반사광은 물체로부터 발산되는 빛(Emission) 의 한 종류로 볼 수 있으므로, 큐브맵으로부터 반사된 조명값 refColor 를 o.Emission 에 할당함.
            // 반면, 스넬의 법칙(p.527)에 따라, 시야에서 멀수록 반사가 줄어둘고, 가까울수록 반사가 많은 성질을 구현하기 위해 rim값을 활용함.
            // 뒤집혀진 rim값은 시야(카메라)에서 멀수록 1에 근접하고, 가까울수록 0에 근접하므로, 이걸 반사된 조명값 refColor 에 바로 곱해주면
            // 시야에서 가까운 프래그먼트일수록 반사된 조명값을 0에 가깝게 만들어버리겠지!
            o.Emission = refColor * rim * 2; // 근데 rim값을 곱해줬더니 전체적으로 refColor값이 너무 어두워져서 전체적으로 2를 한 번 더 곱해준 것.

            // 시선에서 가장 가까운 부분의 투명도가 0이 되면 너무 투명해져서, 
            // 전체적으로 투명도를 0.5씩 곱해주고, 1을 넘는 값은 saturate() 함수로 잘라서 o.Alpha 에 할당함.
            // 참고로, saturate 는 0보다 작은 값은 0으로 잘라주고, 1보다 큰 값은 1로 잘라주는 역할임.
            o.Alpha = saturate(rim + 0.5); 
        }

        // 물 셰이더에 하프벡터를 이용한 블린-퐁 스펙큘러를 계산해서 결과값에 더해주는 커스텀 함수
        float4 LightingWaterSpecular(SurfaceOutput s, float3 lightDir, float3 viewDir, float atten) {
            // specular term
            float3 H = normalize(lightDir + viewDir); // 조명벡터와 뷰벡터 사이의 하프벡터를 구해서 길이를 정규화함.
            float spec = saturate(dot(H, s.Normal)); // surf 함수에서 계산했던 노멀벡터를 끌어와서 하프벡터와 내적계산을 한 뒤, saturate 로 음수값 제거함. 
            spec = pow(spec, _SPPower); // 광택값만큼 내적값을 거듭제곱해서 스펙큘러 값을 계산함. (더 큰 광택값으로 거듭제곱할 수록, 스펙큘러 영역이 확 좁아지면서 더욱 쨍한 느낌을 줌)

            // final term
            float4 finalColor;
            finalColor.rgb = spec * _SPColor.rgb * _SPMulti; // 인터페이스로부터 입력받는 스펙큘러 색상값 및 HDR Bloom 연동 시 강렬한 태양빛이 구현될 수 있도록 곱해주는 _SPMulti 값을 곱해줌.

            // 물 셰이더의 스펙큘러 적용 시, 투명한 픽셀은 스펙큘러가 아무리 쌔도 알파값이 0에 가깝기 때문에 흐려지게 그려질 수밖에 없음.
            // 즉, 스펙큘러가 surf 함수에서 계산한 알파값에 영향을 받는다는 소리임.
            // 이를 위해, s.Alpha 자체에 스펙큘러 값을 더해줌으로써, 
            // 스펙큘러가 쌘 영역은 surf 에서 계산한 투명도가 아무리 0에 가깝더라도 1까지 끌어올려서
            // 스펙큘러를 보여줘야 하는 부분은 확실하게 쨍쨍하게 보여줄 수 있도록 한 것!
            finalColor.a = s.Alpha + spec; 

            return finalColor;
        }
        ENDCG
    }
    FallBack "Legacy Shaders/Transparent/Vertexlit" // 알파블렌딩(반투명) 쉐이더에서 그림자에 적용할 유니티 내장 쉐이더 적용
}
