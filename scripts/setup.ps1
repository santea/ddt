Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DDT 개발 환경 셋업" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command conda -ErrorAction SilentlyContinue)) {
    Write-Host "❌ conda가 설치되어 있지 않습니다." -ForegroundColor Red
    Write-Host "   설치: https://docs.conda.io/en/latest/miniconda.html"
    exit 1
}
Write-Host "✅ conda 설치됨" -ForegroundColor Green

$envList = conda env list 2>&1 | Out-String
if ($envList -match "^ddt\s") {
    Write-Host "📦 conda 환경 'ddt' 업데이트 중..." -ForegroundColor Yellow
    conda env update -f environment.yml --prune
} else {
    Write-Host "📦 conda 환경 'ddt' 생성 중..." -ForegroundColor Yellow
    conda env create -f environment.yml
}

Write-Host ""
Write-Host "⚠️  conda 환경을 활성화하세요:" -ForegroundColor Yellow
Write-Host "   conda activate ddt"
Write-Host ""

if ($env:CONDA_DEFAULT_ENV -ne "ddt") {
    Write-Host "현재 conda 환경이 'ddt'가 아닙니다. 활성화 후 다시 실행해주세요." -ForegroundColor Yellow
    exit 0
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker가 설치되어 있지 않습니다." -ForegroundColor Red
    exit 1
}
Write-Host "✅ Docker 설치됨" -ForegroundColor Green

Write-Host ""
Write-Host "📦 앱 의존성 설치 중..."
Push-Location portal
pnpm install
Pop-Location

Write-Host ""
Write-Host "📦 MCP Server 의존성 설치 중..."
Push-Location mcp-server
pnpm install
Pop-Location

Write-Host ""
Write-Host "📦 SDLC Pod Runner 의존성 설치 중..."
Push-Location sdlc-pod-runner
npm install
Pop-Location

Write-Host ""
Write-Host "📦 Prisma 클라이언트 생성 중..."
Push-Location portal
pnpm db:generate
Pop-Location

Write-Host ""
Write-Host "🔧 Husky git hooks 설정 중..."
Push-Location portal
pnpm exec husky init 2>$null
Set-Content -Path ".husky/pre-commit" -Value "pnpm --dir portal exec lint-staged" -NoNewline
Set-Content -Path ".husky/commit-msg" -Value 'pnpm --dir portal exec commitlint --edit $1' -NoNewline
Pop-Location

if (-not (Test-Path "portal/.env")) {
    Copy-Item "portal/.env.example" "portal/.env"
    Write-Host "📝 portal/.env 파일이 생성되었습니다. GitHub OAuth 설정을 입력해주세요." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "🎉 셋업 완료!" -ForegroundColor Green
Write-Host ""
Write-Host "개발 환경 시작:"
Write-Host "  conda activate ddt"
Write-Host "  skaffold dev"
Write-Host ""
Write-Host "접속 주소:"
Write-Host "  App:        http://localhost:3000"
Write-Host "  n8n:        http://localhost:5678"
Write-Host "  MCP:        http://localhost:3001"
Write-Host "  PostgreSQL: localhost:5432"
Write-Host "============================================" -ForegroundColor Cyan
