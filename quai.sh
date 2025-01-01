#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 색상 초기화

# 초기 선택 메뉴
echo -e "${YELLOW}옵션을 선택하세요:${NC}"
echo -e "${GREEN}1: QUAI 노드 설치 및 구동(스크린에서 실행)${NC}"
echo -e "${GREEN}2: Stratum 프록시 구동${NC}"
echo -e "${GREEN}3: GPU 마이너 구동${NC}"
echo -e "${RED}모든 설치단계는 각각 다른 SCREEN에서 실행하세요.${NC}"
echo -e "${RED}설치진행단계는 번호순서대로 실행하세요.${NC}"

read -p "선택 (1, 2, 3): " option

if [ "$option" == "1" ]; then
    echo "QUAI 노드 새로 설치를 선택했습니다."
    
    echo -e "${YELLOW}NVIDIA 드라이버 설치 옵션을 선택하세요:${NC}"
    echo -e "1: 일반 그래픽카드 (RTX, GTX 시리즈) 드라이버 설치"
    echo -e "2: 서버용 GPU (T4, L4, A100 등) 드라이버 설치"
    echo -e "3: 기존 드라이버 및 CUDA 완전 제거"
    echo -e "4: 드라이버 설치 건너뛰기"
    
    while true; do
        read -p "선택 (1, 2, 3, 4): " driver_option
        
        case $driver_option in
            1)
                sudo apt update
                sudo apt install -y nvidia-utils-550
                sudo apt install -y nvidia-driver-550
                sudo apt-get install -y cuda-drivers-550 
                sudo apt-get install -y cuda-12-3
                ;;
            2)
                distribution=$(. /etc/os-release;echo $ID$VERSION_ID | sed -e 's/\.//g')
                wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
                sudo dpkg -i cuda-keyring_1.1-1_all.deb
                sudo apt-get update
                sudo apt install -y nvidia-utils-550-server
                sudo apt install -y nvidia-driver-550-server
                sudo apt-get install -y cuda-12-3
                ;;
            3)
                echo "기존 드라이버 및 CUDA를 제거합니다..."
                sudo apt-get purge -y nvidia*
                sudo apt-get purge -y cuda*
                sudo apt-get purge -y libnvidia*
                sudo apt autoremove -y
                sudo rm -rf /usr/local/cuda*
                echo "드라이버 및 CUDA가 완전히 제거되었습니다."
                ;;
            4)
                echo "드라이버 설치를 건너뜁니다."
                break
                ;;
            *)
                echo "잘못된 선택입니다. 다시 선택해주세요."
                continue
                ;;
        esac
        
        if [ "$driver_option" != "4" ]; then
            echo -e "\n${YELLOW}NVIDIA 드라이버 설치 옵션을 선택하세요:${NC}"
            echo -e "1: 일반 그래픽카드 (RTX, GTX 시리즈) 드라이버 설치"
            echo -e "2: 서버용 GPU (T4, L4, A100 등) 드라이버 설치"
            echo -e "3: 기존 드라이버 및 CUDA 완전 제거"
            echo -e "4: 드라이버 설치 건너뛰기"
        fi
    done
    
        # CUDA 툴킷 설치 여부 확인
        if command -v nvcc &> /dev/null; then
            echo -e "${GREEN}CUDA 툴킷이 이미 설치되어 있습니다.${NC}"
            nvcc --version
            read -p "CUDA 툴킷을 다시 설치하시겠습니까? 최초설치시 업데이트를 위해 다시설치하세요. (y/n): " reinstall_cuda
            if [ "$reinstall_cuda" == "y" ]; then
                sudo apt-get -y install cuda-toolkit-12-3
                echo 'export PATH=/usr/local/cuda-12.3/bin:$PATH' >> ~/.bashrc
                echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.3/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
                export PATH=/usr/local/cuda/bin:$PATH
                export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
                source ~/.bashrc
                sudo ln -s /usr/local/cuda-12.3 /usr/local/cuda
            fi
        else
            echo -e "${YELLOW}CUDA 툴킷을 설치합니다...${NC}"
            sudo apt-get install -y nvidia-cuda-toolkit
        fi

        export PATH=/usr/local/cuda/bin:$PATH
        export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
        source ~/.bashrc

        # 필수패키지 설치
        sudo apt install snapd
        sudo apt install git make g++
        echo -e "${YELLOW}Go 1.23.0 설치를 시작합니다...${NC}"
         
        #기존 Go 설치 제거
        sudo rm -rf /usr/local/go

        # 시스템 아키텍처 확인
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) ARCH="amd64" ;;
            aarch64) ARCH="arm64" ;;
            armv*) ARCH="armv6l" ;;
        esac

        # Go 다운로드 및 설치
        wget https://golang.org/dl/go1.23.0.linux-${ARCH}.tar.gz
        sudo tar -C /usr/local -xzf go1.23.0.linux-${ARCH}.tar.gz
        rm go1.23.0.linux-${ARCH}.tar.gz

        # 환경 변수 설정
        echo 'export GOROOT=/usr/local/go' >> ~/.bashrc
        echo 'export GOPATH=$HOME/go' >> ~/.bashrc
        echo 'export PATH=$GOROOT/bin:$GOPATH/bin:$PATH' >> ~/.bashrc
        
        # 환경 변수 즉시 적용
        export GOROOT=/usr/local/go
        export GOPATH=$HOME/go
        export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

        # Go 작업 디렉토리 생성
        mkdir -p $HOME/go/src $HOME/go/bin $HOME/go/pkg

        # 설치 확인
        echo -e "${GREEN}Go 설치 버전 확인:${NC}"
        go version

        # 깃클론
        git clone https://github.com/dominant-strategies/go-quai

        echo -e "${GREEN}작업 디렉토리 이동${NC}"
        cd go-quai

        echo -e "${GREEN}Git 최신버전을 확인합니다. (현재:v0.40.1)${NC}"
        echo -e "${Yellow}해당사이트로 이동하세요:https://github.com/dominant-strategies/go-quai/tags${NC}"
        read -p "최신 버전을 입력하세요 (예:0.40.1): " version
        git checkout "v$version"

        # 환경 변수 즉시 적용
        source ~/.bashrc

        # 월렛설정
        echo -e "${GREEN}지갑을 설정합니다. 반드시 해당 단계를 따라주세요.${NC}"
        echo -e "${Yellow}1.해당사이트로 이동하세요:https://chromewebstore.google.com/detail/pelagus/nhccebmfjcbhghphpclcfdkkekheegop${NC}"
        echo -e "${Yellow}2.월렛을 다운받은 후 계정을 생성하세요.${NC}"
        echo -e "${Yellow}3.월렛을 실행하신 후 우측 3단바를 눌러서 메뉴바를 여세요.${NC}"
        echo -e "${Yellow}4.메뉴 중 'Qi mining addresses'를 클릭하세요.${NC}"
        echo -e "${Yellow}5.'add address'를 누른 후 QI주소를 생성하세요.${NC}"
        echo -e "${Yellow}6.quai acoount의 월렛과 qi월렛의 주소를 모두 얻으셨으면 다음단계로 진행하세요.(둘다0x로시작)${NC}"
        read -p "QUAI지갑주소: " quai_wallet
        read -p "QI지갑주소: " qi_wallet

        # 노드빌드
        make go-quai

        # 노드실행
        ./build/bin/go-quai start \
        --node.slices '[0 0]' \
        --node.genesis-nonce 6224362036655375007 \
        --node.quai-coinbases $quai_wallet \
        --node.qi-coinbases $qi_wallet \
        --node.miner-preference 0.5 \
        --node.coinbase-lockup 0

elif [ "$option" == "2" ]; then
    echo "Stratum 프록시 구동을 선택하셨습니다."

    # 깃클론
    git clone https://github.com/dominant-strategies/go-quai-stratum

    echo -e "${GREEN}작업 디렉토리 이동${NC}"
    cd go-quai-stratum

    echo -e "${GREEN}Git 최신버전을 확인합니다. (현재:v0.18.1)${NC}"
    echo -e "${Yellow}해당사이트로 이동하세요:https://github.com/dominant-strategies/go-quai-stratum/tags${NC}"
    read -p "최신 버전을 입력하세요 (예:0.18.1): " proxy_version
    sudo chown -R $(whoami):$(whoami) /home/kangcrypto112/go-quai-stratum
    git config --global --add safe.directory /home/kangcrypto112/go-quai-stratum
    git checkout "v$proxy_version"

    # 환경 변수 즉시 적용
    cp config/config.example.json config/config.json

    # 환경 변수 설정
    echo 'export GOROOT=/usr/local/go' >> ~/.bashrc
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    echo 'export PATH=$GOROOT/bin:$GOPATH/bin:$PATH' >> ~/.bashrc
    
    # 환경 변수 즉시 적용
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
    
    #프록시 빌드
    make go-quai-stratum

    # 환경 변수 즉시 적용
    source ~/.bashrc

    # 현재 사용 중인 포트 확인 및 허용
    echo -e "${GREEN}현재 사용 중인 포트를 확인합니다...${NC}"

    # TCP 포트 확인 및 허용
    echo -e "${YELLOW}TCP 포트 확인 및 허용 중...${NC}"
    sudo ss -tlpn | grep LISTEN | awk '{print $4}' | cut -d':' -f2 | while read port; do
        echo -e "TCP 포트 ${GREEN}$port${NC} 허용"
        sudo ufw allow $port/tcp
        sudo ufw allow 22/tcp
        sudo ufw allow 3333/tcp
    done
    
    # UDP 포트 확인 및 허용
    echo -e "${YELLOW}UDP 포트 확인 및 허용 중...${NC}"
    sudo ss -ulpn | grep LISTEN | awk '{print $4}' | cut -d':' -f2 | while read port; do
        echo -e "UDP 포트 ${GREEN}$port${NC} 허용"
        sudo ufw allow $port/udp
        sudo ufw allow 3333/udp
    done

    #프록시 실행 
    read -p "quai 프록시를 실행합니다.(엔터)"
    ./build/bin/go-quai-stratum --region=cyprus --zone=cyprus1

elif [ "$option" == "3" ]; then
    echo "GPU 마이너 구동을 선택하셨습니다."
    
    # 작업 디렉토리 생성
    cd "$HOME"
    
    # deploy_miner.sh 스크립트 다운로드
    echo -e "${GREEN}마이너 설치 스크립트를 다운로드합니다...${NC}"
    wget https://raw.githubusercontent.com/dominant-strategies/quai-gpu-miner/refs/heads/main/deploy_miner.sh
    
    # 스크립트 실행 권한 부여
    sudo chmod +x deploy_miner.sh

    #필수 패키지 설치
    sudo apt-get update 
    sudo apt-get install -y build-essential cmake libboost-all-dev
    sudo apt-get install -y build-essential libpthread-stubs0-dev
    
    # 스크립트 실행
    echo -e "${YELLOW}마이너를 컴파일하고 빌드합니다. 이 과정은 시간이 걸릴 수 있습니다...${NC}"
    sudo rm -r quai-gpu-miner
    sudo ./deploy_miner.sh

    # 작업공간 이동
    cd quai-gpu-miner
    sudo chown -R $(whoami):$(whoami) ~/quai-gpu-miner

    # GPU 종류 선택
    echo -e "${YELLOW}사용하실 GPU 종류를 선택하세요:${NC}"
    echo -e "1: NVIDIA GPU"
    echo -e "2: AMD GPU"
    read -p "선택 (1, 2): " gpu_option
    
    # GPU 종류에 따른 실행 파일 권한 설정
    if [ "$gpu_option" == "1" ]; then
        chmod +x output/quai-gpu-miner-nvidia
    elif [ "$gpu_option" == "2" ]; then
        chmod +x output/quai-gpu-miner-amd
    else
        echo "잘못된 선택입니다."
        exit 1
    fi
    
    # 시스템 및 드라이버 업데이트
    echo -e "${GREEN}시스템과 드라이버를 업데이트합니다...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install cuda-drivers
    
    # Stratum 프록시 설정
    echo -e "${YELLOW}Stratum 프록시 설정을 진행합니다...${NC}"
    read -p "Stratum 프록시 IP 주소를 입력하세요 (같은 기기인 경우 localhost): " proxy_ip
    read -p "Stratum 프록시 포트를 입력하세요 (기본값:3333): " proxy_port
    
    # 마이너 실행
    echo -e "${GREEN}마이너를 실행합니다...${NC}"
    if [ "$gpu_option" == "1" ]; then
        ./output/quai-gpu-miner-nvidia -U -P stratum://${proxy_ip}:${proxy_port}
    else
        ./output/quai-gpu-miner-amd -G -P stratum://${proxy_ip}:${proxy_port}
    fi

else
    echo "잘못된 선택입니다."
    exit 1
fi

