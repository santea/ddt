Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DDT 개발 환경 셋업" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command conda -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Conda가 설치되어 있지 않습니다. 자동 설치를 진행합니다..." -ForegroundColor Yellow
    Write-Host "Windows용 Miniconda 다운로드 중..."
    
    $minicondaUrl = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
    Invoke-WebRequest -Uri $minicondaUrl -OutFile "miniconda.exe"
    
    Write-Host "Miniconda 설치 중 (약 1~2분 소요)..."
    $installDir = Join-Path $env:USERPROFILE "miniconda3"
    $argsList = "/InstallationType=JustMe /RegisterPython=0 /AddToPath=0 /S /D=$installDir"
    
    Start-Process -FilePath ".\miniconda.exe" -ArgumentList $argsList -Wait -NoNewWindow
    Remove-Item ".\miniconda.exe" -Force
    
    # PATH 환경 변수에 추가
    $env:PATH = "$installDir\Scripts;$installDir\condabin;$installDir;" + $env:PATH
    
    # PowerShell용 초기화 (에러 무시)
    & "$installDir\Scripts\conda.exe" init powershell | Out-Null
    
    Write-Host "✅ Conda 자동 설치 완료!" -ForegroundColor Green
    Write-Host "⚠️ 지금 바로 환경을 적용하려면 터미널에 아래 명령어를 실행하거나 껐다 켜주세요:" -ForegroundColor Yellow
    Write-Host "   . `$PROFILE"
    Write-Host "적용 후 본 스크립트를 다시 실행해 주세요!" -ForegroundColor Yellow
    exit 0
}
Write-Host "✅ conda 준비됨" -ForegroundColor Green

Write-Host "📜 Conda 채널 ToS 자동 동의 처리 중..." -ForegroundColor Yellow
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>$null
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>$null

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

Write-Host ""
Write-Host "📦 Skaffold 설치 확인 중..." -ForegroundColor Yellow
if (-not (Get-Command skaffold -ErrorAction SilentlyContinue)) {
    Write-Host "Windows용 Skaffold 바이너리를 다운로드합니다."
    $skaffoldUrl = "https://storage.googleapis.com/skaffold/releases/latest/skaffold-windows-amd64.exe"
    $binDir = Join-Path $HOME "bin"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir | Out-Null
    }
    $skaffoldPath = Join-Path $binDir "skaffold.exe"
    Invoke-WebRequest -Uri $skaffoldUrl -OutFile $skaffoldPath
    Write-Host "⚠️ PATH 환경 변수에 $binDir 경로를 추가해주세요." -ForegroundColor Yellow
    $env:PATH = "$binDir;" + $env:PATH
    Write-Host "✅ Skaffold 설치 완료" -ForegroundColor Green
} else {
    Write-Host "✅ Skaffold 이미 설치됨" -ForegroundColor Green
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
Write-Host "⚙️  kubectl 자동 완성(Autocompletion) 설정 중..." -ForegroundColor Yellow
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }
    $content = Get-Content $PROFILE -ErrorAction SilentlyContinue
    if ($content -notmatch "kubectl completion powershell") {
        Add-Content -Path $PROFILE -Value "`n# kubectl autocompletion & alias"
        Add-Content -Path $PROFILE -Value "kubectl completion powershell | Out-String | Invoke-Expression"
        Add-Content -Path $PROFILE -Value "Set-Alias -Name k -Value kubectl"
    }
    Write-Host "✅ 터미널 재시작 시 kubectl 자동 완성이 적용됩니다." -ForegroundColor Green
} else {
    Write-Host "❌ kubectl을 찾을 수 없어 자동 완성 설정을 건너뜁니다." -ForegroundColor Red
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
Write-Host "  Minio (S3): http://localhost:9001 (API: 9000)"
Write-Host "============================================" -ForegroundColor Cyan
