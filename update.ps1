# 1. FORÇAR ABERTURA EM NOVA JANELA COMO ADMINISTRADOR
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Abre uma nova instância do PowerShell em uma nova janela, como Admin
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" " -Verb RunAs
    exit
}

# --- CONFIGURAÇÕES DO SCRIPT ---
$repoOwner = "Guibmet"
$repoName  = "Guibhub"
$destRoot  = "C:\" 
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=8"

# Otimização de rede e visual
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$progressPreference = 'SilentlyContinue'

# Função para desenhar o menu igual à imagem (MAS)
function Desenhar-Menu {
    Clear-Host
    Write-Host " _________________________________________________________" -ForegroundColor Cyan
    Write-Host "                                                         "
    Write-Host "         GUIBHUB - GERENCIADOR DE ATUALIZACOES           " -ForegroundColor White
    Write-Host " _________________________________________________________" -ForegroundColor Cyan
    Write-Host "  Modo: Administrador | Destino: $destRoot" -ForegroundColor Gray
    Write-Host ""
}

try {
    Desenhar-Menu
    Write-Host " [?] Conectando ao GitHub..." -ForegroundColor Yellow
    $releases = Invoke-RestMethod -Uri $apiUrl -Method Get

    if ($null -eq $releases) { 
        Write-Host " [!] Erro: Nao foi possivel obter as versões." -ForegroundColor Red
        pause; exit 
    }

    Write-Host " Escolha a versao para instalar no Disco local (C:):" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $releases.Count; $i++) {
        # Formatação estilo [1], [2]...
        $index = "[$i]"
        Write-Host "  $($index.PadRight(4)) $($releases[$i].tag_name)" -ForegroundColor Green
    }
    Write-Host "  [X]  Sair" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host " Digite uma opcao "

    if ($choice -eq 'x' -or $choice -eq 'X') { exit }
    
    # Validação simples de entrada
    if ($choice -match '^\d+$' -and [int]$choice -lt $releases.Count) {
        $selected = $releases[[int]$choice]
    } else {
        Write-Host " Opcao invalida!" -ForegroundColor Red
        Start-Sleep -Seconds 2
        & $PSCommandPath # Reinicia o script
        exit
    }

    # --- DOWNLOAD E EXTRAÇÃO ---
    $asset = $selected.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
    if ($null -eq $asset) { throw "Nenhum arquivo .zip encontrado." }

    $tempZip = "$env:TEMP\update_temp.zip"
    
    Desenhar-Menu
    Write-Host " [+] Selecionado: $($selected.tag_name)" -ForegroundColor Cyan
    Write-Host " [+] Baixando arquivos..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip

    if (-not (Test-Path $destRoot)) { 
        New-Item -ItemType Directory -Path $destRoot -Force | Out-Null 
    }

    Write-Host " [+] Extraindo para $destRoot..." -ForegroundColor Gray
    
    # Método Shell.Application (o mais rápido para o Windows)
    $shell = New-Object -ComObject Shell.Application
    $zipFile = $shell.NameSpace($tempZip)
    $destFolder = $shell.NameSpace($destRoot)
    
    # 0x14 = Sobrescrever arquivos sem perguntar + Ocultar barra de progresso nativa
    $destFolder.CopyHere($zipFile.Items(), 0x14)

    Remove-Item $tempZip -Force

    Write-Host ""
    Write-Host " =========================================================" -ForegroundColor Cyan
    Write-Host "  CONCLUIDO: Versao $($selected.tag_name) instalada!" -ForegroundColor Green
    Write-Host " =========================================================" -ForegroundColor Cyan
    Write-Host " Pressione qualquer tecla para fechar esta guia..."
    $null = [Console]::ReadKey($true)

} catch {
    Write-Host "`n [ERRO] Ocorreu um problema: $_" -ForegroundColor Red
    pause
}
