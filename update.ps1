# 1. FORÇAR ADMINISTRADOR (Necessário para escrever no C:\)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- CONFIGURAÇÕES ---
$repoOwner = "Guibmet"
$repoName  = "Guibhub"
$destRoot  = "C:\" # Extração direta no C:\
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=8"

# Configurações de performance e segurança
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$progressPreference = 'SilentlyContinue'

function Show-Interface {
    Clear-Host
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host "          GUIBHUB - GERENCIADOR DE ATUALIZAÇÕES          " -ForegroundColor White
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host " Status: ADMINISTRADOR ATIVO | Destino: $destRoot" -ForegroundColor Gray
    Write-Host ""
}

try {
    Show-Interface
    Write-Host " [?] Buscando releases no GitHub..." -ForegroundColor Yellow
    $releases = Invoke-RestMethod -Uri $apiUrl -Method Get

    if ($null -eq $releases) { 
        Write-Host " [!] Nenhuma release encontrada." -ForegroundColor Red
        pause; exit 
    }

    # --- MENU DE SELEÇÃO ESTILO MAS ---
    Write-Host " Escolha uma versão para extrair no C:\:" -ForegroundColor White
    for ($i = 0; $i -lt $releases.Count; $i++) {
        Write-Host "  [$i] $($releases[$i].tag_name)" -ForegroundColor Green
    }
    Write-Host "  [X] Sair" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host " Digite a opção "

    if ($choice -eq 'x' -or $choice -eq 'X') { exit }
    $selected = $releases[[int]$choice]

    # --- PROCESSAMENTO ---
    $asset = $selected.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
    if ($null -eq $asset) { throw "Nenhum arquivo .zip encontrado nesta release." }

    $tempZip = "$env:TEMP\update_temp.zip"
    
    Show-Interface
    Write-Host " [+] Versão Selecionada: $($selected.tag_name)" -ForegroundColor Cyan
    Write-Host " [+] Baixando pacote..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip

    Write-Host " [+] Preparando diretório $destRoot..." -ForegroundColor Gray
    if (-not (Test-Path $destRoot)) { New-Item -ItemType Directory -Path $destRoot -Force | Out-Null }

    Write-Host " [+] Extraindo arquivos (Sobrescrevendo)..." -ForegroundColor Gray
    
    # Motor de extração ultra-rápido (Shell.Application)
    $shell = New-Object -ComObject Shell.Application
    $zipFile = $shell.NameSpace($tempZip)
    $destFolder = $shell.NameSpace($destRoot)
    
    # 0x14 = 4 (sem barra de progresso) + 16 (sim para tudo/sobrescrever)
    $destFolder.CopyHere($zipFile.Items(), 0x14)

    # Limpeza
    Remove-Item $tempZip -Force

    Write-Host ""
    Write-Host " =========================================================" -ForegroundColor Cyan
    Write-Host "  SUCESSO: Arquivos atualizados em $destRoot" -ForegroundColor Green
    Write-Host " =========================================================" -ForegroundColor Cyan
    Write-Host " Pressione qualquer tecla para fechar..."
    $null = [Console]::ReadKey($true)

} catch {
    Write-Host "`n [ERRO] $_" -ForegroundColor Red
    pause
}
