# =========================================================
# SCRIPT DE ATUALIZAÇÃO ULTRA-RÁPIDO (ESTILO CONSOLE)
# =========================================================

$repoOwner = "Guibmet"
$repoName  = "Guibhub"
# DICA: Usar $env:USERPROFILE torna o script funcional SEM ADMIN
$destRoot  = "$env:C:\" 
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=5"

# Configura segurança de TLS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "      ATUALIZADOR DE RELEASES - $repoName" -ForegroundColor White
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Buscando versões disponíveis..." -ForegroundColor Gray

try {
    $releases = Invoke-RestMethod -Uri $apiUrl -Method Get
    if ($null -eq $releases) { 
        Write-Host "Nenhuma release encontrada." -ForegroundColor Red
        pause; exit 
    }

    # --- MENU DE SELEÇÃO ---
    Write-Host "`nEscolha uma versão para sincronizar:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $releases.Count; $i++) {
        Write-Host "[$i] $($releases[$i].tag_name)" -ForegroundColor White
    }
    Write-Host "[X] Sair" -ForegroundColor Red

    $choice = Read-Host "`nDigite o número"

    if ($choice -eq 'x') { exit }
    $selected = $releases[$choice]

    # --- BUSCA O ZIP ---
    $asset = $selected.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
    if ($null -eq $asset) {
        Write-Host "Erro: Nenhum arquivo .zip nesta release." -ForegroundColor Red
        pause; exit
    }

    # --- PREPARAÇÃO ---
    $folderName = $asset.name.Replace(".zip", "")
    $finalPath = Join-Path $destRoot $folderName
    $tempZip = "$env:TEMP\update_$folderName.zip"

    Write-Host "`nIniciando: $($asset.name)" -ForegroundColor Cyan
    Write-Host "Destino: $finalPath" -ForegroundColor Gray

    # Download silencioso e rápido
    Write-Host "Fazendo download..." -ForegroundColor Gray
    $progressPreference = 'SilentlyContinue' # Desativa barra de progresso lenta
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip

    # Extração
    Write-Host "Extraindo arquivos..." -ForegroundColor Gray
    if (-not (Test-Path $finalPath)) { New-Item -ItemType Directory -Path $finalPath -Force | Out-Null }
    
    # Uso do Shell.Application para extração rápida (estilo Windows)
    $shell = New-Object -ComObject Shell.Application
    $zipFile = $shell.NameSpace($tempZip)
    $destFolder = $shell.NameSpace($finalPath)
    $destFolder.CopyHere($zipFile.Items(), 0x14) # 0x14 = Silencioso + Sobrescrever

    # Limpeza
    Remove-Item $tempZip -Force

    Write-Host "`n[SUCESSO] Sincronização concluída!" -ForegroundColor Green
    Write-Host "Pressione qualquer tecla para sair..."
    $null = [Console]::ReadKey($true)

} catch {
    Write-Host "`nERRO CRÍTICO: $_" -ForegroundColor Red
    pause
}
