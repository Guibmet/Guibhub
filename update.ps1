# 1. FORÇAR ABERTURA EM NOVA JANELA COMO ADMINISTRADOR
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" " -Verb RunAs
    exit
}

# --- CONFIGURAÇÕES ---
$repoOwner = "Guibmet"
$repoName  = "Guibhub"
$destRoot  = "C:\$repoName" 
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=8"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$progressPreference = 'SilentlyContinue'

# Função para desenhar o cabeçalho (Visual MAS)
function Desenhar-Cabecalho {
    Clear-Host
    Write-Host " _________________________________________________________" -ForegroundColor Cyan
    Write-Host "                                                         "
    Write-Host "         GUIBHUB - GERENCIADOR DE ATUALIZACOES           " -ForegroundColor White
    Write-Host " _________________________________________________________" -ForegroundColor Cyan
    Write-Host "  ADMIN: ATIVO | DESTINO: $destRoot" -ForegroundColor Gray
    Write-Host ""
}

# LOOP PRINCIPAL (Faz o script voltar ao início)
while ($true) {
    try {
        Desenhar-Cabecalho
        Write-Host " [?] Buscando versoes no GitHub..." -ForegroundColor Yellow
        $releases = Invoke-RestMethod -Uri $apiUrl -Method Get

        if ($null -eq $releases) { 
            Write-Host " [!] Erro ao obter dados. Tentando novamente em 3s..." -ForegroundColor Red
            Start-Sleep -Seconds 3
            continue 
        }

        Write-Host " Escolha a versao para instalar no Disco local (C:):" -ForegroundColor White
        Write-Host ""
        for ($i = 0; $i -lt $releases.Count; $i++) {
            $index = "[$i]"
            Write-Host "  $($index.PadRight(4)) $($releases[$i].tag_name)" -ForegroundColor Green
        }
        Write-Host "  [X]  Sair do Programa" -ForegroundColor Red
        Write-Host ""
        
        $choice = Read-Host " Digite uma opcao "

        # Sair do Loop e fechar o script
        if ($choice -eq 'x' -or $choice -eq 'X') { 
            Write-Host " Fechando..." -ForegroundColor Gray
            break 
        }
        
        # Validação da escolha
        if ($choice -match '^\d+$' -and [int]$choice -lt $releases.Count) {
            $selected = $releases[[int]$choice]
        
