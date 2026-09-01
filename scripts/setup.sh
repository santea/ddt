#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo "  DDT 개발 환경 셋업"
echo "============================================"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. conda 확인
if ! command -v conda &> /dev/null; then
  echo -e "${RED}❌ conda가 설치되어 있지 않습니다.${NC}"
  echo "   설치: https://docs.conda.io/en/latest/miniconda.html"
  exit 1
fi
echo -e "${GREEN}✅ conda 설치됨${NC}"

# 2. conda 환경 생성/업데이트
if conda env list | grep -q "^ddt "; then
  echo -e "${YELLOW}📦 conda 환경 'ddt' 업데이트 중...${NC}"
  conda env update -f environment.yml --prune
else
  echo -e "${YELLOW}📦 conda 환경 'ddt' 생성 중...${NC}"
  conda env create -f environment.yml
fi

echo ""
echo -e "${YELLOW}⚠️  conda 환경을 활성화하세요:${NC}"
echo "   conda activate ddt"
echo ""

if [[ "${CONDA_DEFAULT_ENV:-}" != "ddt" ]]; then
  echo -e "${YELLOW}현재 conda 환경이 'ddt'가 아닙니다. 활성화 후 다시 실행해주세요.${NC}"
  exit 0
fi

# 3. Docker 및 OS별 K8s 확인
OS="$(uname -s)"
if [ "$OS" = "Linux" ]; then
  echo -e "${YELLOW}🐧 Linux 환경을 감지했습니다.${NC}"
  
  if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}📦 Docker Engine을 자동 설치합니다...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh || { echo -e "${RED}❌ Docker 설치 실패. 수동으로 설치해주세요.${NC}"; exit 1; }
    sudo usermod -aG docker "$USER"
    rm get-docker.sh
    echo -e "${YELLOW}⚠️ Docker 권한 부여를 위해 로그아웃 후 다시 로그인해야 할 수 있습니다.${NC}"
  else
    echo -e "${GREEN}✅ Docker 설치됨${NC}"
  fi

  if ! command -v k3d &> /dev/null; then
    echo -e "${YELLOW}📦 k3d(가벼운 쿠버네티스)를 설치합니다...${NC}"
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  else
    echo -e "${GREEN}✅ k3d 설치됨${NC}"
  fi

  if ! k3d cluster list | grep -q "^ddt-cluster "; then
    echo -e "${YELLOW}📦 k3d 클러스터(ddt-cluster)를 생성합니다...${NC}"
    k3d cluster create ddt-cluster
  else
    echo -e "${GREEN}✅ k3d 클러스터가 이미 실행 중입니다.${NC}"
  fi

  kubectl config use-context k3d-ddt-cluster
else
  # Mac / Windows(Git Bash)
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker가 설치되어 있지 않습니다.${NC}"
    echo "   설치: https://docker.com (Docker Desktop 설치 후 Kubernetes를 Enable 해주세요)"
    exit 1
  fi
  echo -e "${GREEN}✅ Docker 설치됨${NC}"
fi

# 4. 의존성 설치
echo ""
echo "📦 앱 의존성 설치 중..."
(cd portal && pnpm install)

echo ""
echo "📦 MCP Server 의존성 설치 중..."
(cd mcp-server && pnpm install)

echo ""
echo "📦 SDLC Pod Runner 의존성 설치 중..."
(cd sdlc-pod-runner && npm install)

echo ""
echo "📦 Prisma 클라이언트 생성 중..."
(cd portal && pnpm db:generate)

# 5. Husky 설정
echo ""
echo "🔧 Husky git hooks 설정 중..."
(cd portal && pnpm exec husky init) 2>/dev/null || true
echo 'pnpm --dir portal exec lint-staged' > portal/.husky/pre-commit
echo 'pnpm --dir portal exec commitlint --edit $1' > portal/.husky/commit-msg

# 6. .env 생성
if [ ! -f .env ]; then
  cp portal/.env.example portal/.env
  echo -e "${YELLOW}📝 .env 파일이 생성되었습니다. GitHub OAuth 설정을 입력해주세요.${NC}"
fi

echo ""
echo "============================================"
echo -e "${GREEN}🎉 셋업 완료!${NC}"
echo ""
echo "개발 환경 시작:"
echo "  conda activate ddt"
echo "  skaffold dev"
echo ""
echo "접속 주소:"
echo "  App:        http://localhost:3000"
echo "  n8n:        http://localhost:5678"
echo "  MCP:        http://localhost:3001"
echo "  PostgreSQL: localhost:5432"
echo "============================================"
