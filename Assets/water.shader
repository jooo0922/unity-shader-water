Shader "Custom/water"
{
    Properties
    {
        _BumpMap ("NormalMap", 2D) = "bump" {} // 물 노말맵 텍스쳐를 받아오는 인터페이스 생성을 위해 프로퍼티 추가
        _Cube ("Cubemap", cube) = "" {} // 큐브맵 텍스쳐를 받아오는 인터페이스 생성을 위해 프로퍼티 추가
        _SPColor("Specular Color", color) = (1, 1, 1, 1) // 스펙큘러 색상을 받아오는 인터페이스 생성을 위해 프로퍼티 추가
        _SPPower("Specular Power", Range(50, 300)) = 150 // 스펙큘러 광택값(shininess) 을 받아오는 인터페이스 생성을 위해 프로퍼티 추가
        _SPMulti("Specular Multiply", Range(1, 10)) = 3 // HDR Bloom 기능을 활성화할 때, 매우 강렬한 태양빛 반사를 재현하기 위해 1 이상의 값을 받아서 최종 스펙큘러에 더해줄 때 사용할 값을 받는 인터페이스 추가
        _WaveH ("Wave Height", Range(0, 0.5)) = 0.1 // 버텍스 y좌표 움직임의 파장 높이를 조절하는 변수를 받는 인터페이스 추가
        _WaveL ("Wave Length", Range(5, 20)) = 12 // 버텍스 y좌표 움직임의 파장 넓이를 조절하는 변수를 받는 인터페이스 추가
        _WaveT ("Wave Timing", Range(0, 10)) = 1 // 버텍스 y좌표 움직임의 속도를 조절하는 변수를 받는 인터페이스 추가
        _RefStrength ("Refraction Strength", Range(0, 0.2)) = 0.1 // 굴절의 강도 조절값을 받아올 인터페이스 추가 
    }
    SubShader
    {
        // 그냥 큐브맵에서 샘플링한 반사광만 적용하니까 너무 금속 느낌이 나서 알파 블렌딩(반투명) 쉐이더로 만들고,
        // o.Alpha 값을 조절해서 물 느낌이 좀 더 나게 만들려고 함.
        // Tags { "RenderType"="Transparent" "Queue"="Transparent"}
        Tags {"RenderType"="Opaque"} // 굴절 효과를 위해 GrabPass 를 사용할 것이므로, 더 이상 반투명 쉐이더를 유지할 필요가 없음. (GrabPass 가 plane의 뒷배경을 모두 캡쳐해주니까!)

        // GrabPass{} 를 선언하면, 현재 이 쉐이더가 적용된 Plane 메쉬를 기준으로 Plane 메쉬 뒷부분의 배경을 캡쳐해 줌.
        // 이렇게 캡쳐한 배경을 텍스쳐로 받아서 사용하려면 아래 CG 쉐이더 부분에 _GrabTexture 라는 이름으로 샘플러 변수를 선언해줘야 함.
        GrabPass{}

        CGPROGRAM
        // 물 셰이더에 하프벡터를 이용한 블린-퐁 스펙큘러를 계산해서 결과값에 더해주는 커스텀 함수 추가
        // plane 버텍스를 움직여서 물 plane 을 실제로 출렁거리게 만들기 위해 버텍스 셰이더를 활성화
        #pragma surface surf WaterSpecular alpha:fade vertex:vert

        sampler2D _GrabTexture; // GrabPass 를 선언하여 캡쳐한 화면을 텍스쳐로 받기 위해 _GrapTexture 샘플러 변수 선언.
        sampler2D _BumpMap; // 물 노멀맵 텍스쳐를 담는 샘플러 변수
        samplerCUBE _Cube; // 큐브맵 텍스쳐를 담는 전용 샘플러 변수인 samplerCUBE 선언
        float4 _SPColor; // 스펙큘러 색상값을 담는 변수
        float _SPPower; // 스펙큘러 광택값(거듭제곱에 사용)을 담는 변수
        float _SPMulti; // HDR Bloom 사용 시, 강렬한 태양빛 반사를 재현하기 위해 곱해주는 값을 담는 변수
        float _WaveH; // 버텍스 y좌표 움직임의 파장 높이를 조절하는 변수
        float _WaveL; // 버텍스 y좌표 움직임의 파장 넓이를 조절하는 변수
        float _WaveT; // 버텍스 y좌표 움직임의 속도를 조절하는 변수
        float _RefStrength; // 굴절의 강도 조절값

        // 물 쉐이더의 plane 버텍스를 움직여서 실제로 물을 출렁거리게 만드는 버텍스 셰이더 함수
        // 물 plane 을 여러개 복붙해서 이어붙임으로써, 여러 개의 물 plane 버텍스가 출렁거리는 모션을 만들거임. 
        // -> 이렇게 여러 개의 plane 을 이어붙이면, 화면에 보이지 않는 물을 계산하지 않아도 되고, 알파소팅 문제를 예방할 수 있다는 장점이 있다고 함.
        void vert(inout appdata_full v){
            // v.vertex.y += v.texcoord.x; // 일단, 버텍스의 y좌표값에 버텍스 uv좌표 중 u축 좌표를 더함으로써, 각 plane 의 오른쪽이 들리게 됨. (why? 버텍스에 지정된 uv좌표 중 u축은 왼쪽 -> 오른쪽으로 갈수록 0 -> 1 로 증가하니까!)

            // 근데, plane마다 u좌표값이 0 ~ 1 / 0 ~ 1 / 0 ~ 1 / ... 이렇게 되니까 plane들이 서로 연결되지 않는 느낌이 들음.
            // 이걸 해결하기 위해, 각 plane의 u좌표값의 범위인 0 ~ 1 을 -1 ~ 0 ~ 1 사이로 맵핑시키고, abs() 절댓값 함수를 이용해 1 ~ 0 ~ 1 범위로 바꿔주면,
            // 모든 plane 들의 u좌표값이 1 ~ 0 ~ 1 1 ~ 0 ~ 1 1 ~ 0 ~ 1 ... 이런식으로 연결될 수 있음. 이 값을 다시 버텍스 y좌표값에 곱해준 것.
            // v.vertex.y += abs(v.texcoord.x * 2 - 1) * 30; // 30을 곱한건, 이후에 sin() 함수로 맵핑된 u좌표값을 계산해서 곡면처리를 하려는데, sin() 함수에 넣어주는 각도값이 1 ~ 0 ~ 1 범위로는 곡면이 만들어진 게 티가 잘 안나서 30으로 규모를 확 키워준거임.

            // sin() 함수를 이용해서 plane 내에서 증가되는 u좌표값을 곡면처리함.
            // 이게 어떻게 가능한 거냐면, 기존에 1 ~ 0 ~ 1 로 늘어나던거는 '선형적'으로 늘어나는 값이었음. 그래서 한 plane 내에서 계곡처럼 가운데가 뾰족하게 들어가는 형태로 버텍스 y좌표값이 계산되었다면,
            // sin() 함수는 이렇게 선형적으로 늘어나는 값(각도)를 인자로 받아 곡선 형태의 리턴값을 계산해 줌. sin 그래프가 곡선형이잖아?
            // 참고로, 그냥 1 ~ 0 ~ 1 을 sin()의 인자로 넣어버리면 그냥 1도에서 0도 사이의 sin값을 리턴하는거밖에 안되기 때문에, sin 그래프 상에서 곡선을 그려줄 만큼의 리턴값들을 전달해주지 못함. -> 그래서 '선형적'으로, 이전과 별 차이가 없이 그려짐.
            // 이를 위해 30 정도의 적당한 값으로 sin() 함수에 넣어줄 각도값 범위를 늘린 것이고, 이를 통해 30 ~ 0 ~ 30 도 사이의 각도값을 받아 sin 그래프처럼 곡선을 그리는 값만큼을 버텍스 y좌표값에 더해준 것!
            // v.vertex.y += sin(abs(v.texcoord.x * 2 - 1) * 30);

            // 파장의 넓이를 줄이기 위해 30 -> 12로 곱하도록 바꾸고, (이유는 당연하지만, 30 ~ 0 ~ 30 도 범위의 값을 넣어 sin값을 도출하는 것보다, 12 ~ 0 ~ 12 도 범위의 값으로 sin값을 도출하는 게 더 오밀조밀하고 변동이 심한 sin값을 도출할테니까)
            // 파장의 높이(강도)를 줄이기 위해 sin 결과값에 전체적으로 0.1을 곱해줌. (어차피 sin값은 -1 ~ 1 사이의 값을 왔다갔다하므로, 1보다 작은 소수를 아무거나 곱해주면 sin값이 전체적으로 0으로 수렴하면서 높이가 낮아짐.)
            // v.vertex.y += sin(abs(v.texcoord.x * 2 - 1) * 12) * 0.1;
            // v.vertex.y += sin((abs(v.texcoord.x * 2 - 1) * 12) + _Time.y) * 0.1; // sin 값에 각도를 넣어주기 이전에 시간변수를 더해줌으로써, 버텍스들의 uv좌표(여기서는 sin 함수의 각도값으로 사용)를 움직여 줌. -> 버텍스가 흘러가는 효과 구현!
           
            // 버텍스 uv좌표의 u컴포넌트, y컴포넌트로 버텍스 y좌표에 더해줄 sin값을 계산해줌으로써, 버텍스가 양쪽 방향으로 흐를 수 있도록 만듦. 
            float movement;
            movement = sin((abs(v.texcoord.x * 2 - 1) * _WaveL) + _Time.y * _WaveT) * _WaveH;
            movement += sin((abs(v.texcoord.y * 2 - 1) * _WaveL) + _Time.y * _WaveT) * _WaveH;
            v.vertex.y += movement / 2; // 노말맵에서 uv 좌표 방향을 다르게 하여 샘플링한 두 노멀벡터의 평균값을 구해서 물의 찰랑거림을 표현했을 때처럼, 여기서도 양쪽 방향으로 버텍스 y좌표를 움직일 sin값의 평균값을 계산하여 버텍스 y좌표에 더해줌. 
        }

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
            float4 screenPos; // 현재 캡쳐된 화면의 UV 좌표계를 Input 구조체에 선언해서 꺼내쓰고자 함.

            INTERNAL_DATA // 탄젠트 공간 노멀 벡터(UnpackNormal 에서 구해주는 값)를 월드 공간의 픽셀 노멀 벡터로 변환하기 위해 필요한 키워드 지정!
        };

        void surf(Input IN, inout SurfaceOutput o)
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

            // refraction term
            float3 screenUV = IN.screenPos.rgb / IN.screenPos.a; // 카메라 거리에 따른 영향을 제거하기 위해 screenPos.rgb 값을 screenPos.a 값으로 나눠줌.
            float3 refraction = tex2D(_GrabTexture, (screenUV.xy + o.Normal.xy * _RefStrength)); // 노말맵에서 샘플링한 노말벡터 값으로 화면좌표계 uv를 구겨주고 있음. -> 여기서는 노말맵이 굴절텍스쳐 역할!

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
            // o.Emission = refColor * rim * 2; // 근데 rim값을 곱해줬더니 전체적으로 refColor값이 너무 어두워져서 전체적으로 2를 한 번 더 곱해준 것.
            //o.Emission = (refColor * rim + refraction) * 0.5; // GrabTexture 에서 샘플링한 굴절된 텍셀값을 더해줌 (이건 책에 있는 그대로 쓴 것)

            // 근데, refraction 은 굴절이고, 굴절은 가까운 부분일수록 커지고, 멀수록 작아지는 게 물리적으로 더 맞지 않나 싶어서 (위에는 굴절을 그냥 일관되게 더하고 있음.)
            // 현재 뒤집어져있는 rim값(가까울수록 0, 멀수록 1)을 다시 1에서 빼서 뒤집은 다음 refraction 에 곱해줌으로써, 가까운 곳일수록 굴절값이 커지고, 먼 곳일수록 굴절값이 작아지게 계산한거임.
            o.Emission = (refColor * rim) + (refraction * (1 - rim)); 

            // 시선에서 가장 가까운 부분의 투명도가 0이 되면 너무 투명해져서, 
            // 전체적으로 투명도를 0.5씩 더해주고, 1을 넘는 값은 saturate() 함수로 잘라서 o.Alpha 에 할당함.
            // 참고로, saturate 는 0보다 작은 값은 0으로 잘라주고, 1보다 큰 값은 1로 잘라주는 역할임.
            // o.Alpha = saturate(rim + 0.5); 
            o.Alpha = 1; // GrabPass 를 사용해서 더 이상 반투명 쉐이더가 필요없으니, Alpha 도 별도 계산 없이 1로 통일시킴.
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
            // finalColor.a = s.Alpha + spec; 
            finalColor.a = s.Alpha; // GrabPass 덕분에 반투명 쉐이더가 더 이상 필요없으니 surf 함수와 마찬가지로 커스텀라이트 함수에서도 알파값과 관련한 별도의 연산을 수행하지 않음.

            return finalColor;
        }
        ENDCG
    }
    FallBack "Legacy Shaders/Transparent/Vertexlit" // 알파블렌딩(반투명) 쉐이더에서 그림자에 적용할 유니티 내장 쉐이더 적용
}
