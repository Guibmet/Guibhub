# =========================================================
# SCRIPT DE ATUALIZAÇÃO AUTOMATIZADA (GITHUB TO C:\)
# =========================================================

# --- CONFIGURAÇÕES DO REPOSITÓRIO ---
$repoOwner = "Guibmet"
$repoName  = "Guibhub"
$destPath  = "C:\" 
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=5"

# 1. VERIFICAÇÃO DE ADMINISTRADOR
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "![ERRO] Este script precisa ser executado como ADMINISTRADOR." -ForegroundColor Red
    Write-Host "Fechando em 5 segundos..."
    Start-Sleep -Seconds 5
    exit
}

function Show-Menu {
    param ([array]$releases)
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Magenta
    Write-Host "     CENTRAL DE ATUALIZAÇÕES - $repoName" -ForegroundColor Magenta
    Write-Host "==============================================" -ForegroundColor Magenta
    Write-Host "Selecione uma versão para ver detalhes e instalar:`n"

    for ($i = 0; $i -lt $releases.Count; $i++) {
        Write-Host "[$($i + 1)] $($releases[$i].tag_name) - $($releases[$i].name)" -ForegroundColor White
    }
    Write-Host "[Q] Sair" -ForegroundColor Yellow
    
    return Read-Host "`nDigite sua opção"
}

try {
    # 2. BUSCA AS RELEASES
    $releases = Invoke-RestMethod -Uri $apiUrl -Method Get
    if ($releases.Count -eq 0) { 
        Write-Host "Nenhuma versão encontrada no repositório." -ForegroundColor Red
        Pause; exit 
    }

    $running = $true
    while ($running) {
        $choice = Show-Menu -releases $releases
        
        if ($choice -eq 'q') { $running = $false; break }

        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $releases.Count) {
            $selected = $releases[$idx]
            
            # 3. EXIBE CHANGELOG
            Clear-Host
            Write-Host "--- DETALHES DA VERSÃO: $($selected.tag_name) ---" -ForegroundColor Cyan
            Write-Host $selected.body
            Write-Host "`n" + ("-" * 40)
            
            $confirm = Read-Host "Deseja instalar esta atualização agora? (S/N)"
            if ($confirm -eq 's') {
                $tempZip = "$env:TEMP\update.zip"
                $tempExtract = "$env:TEMP\extract_tmp"

                # 4. DOWNLOAD (Buscando nos Assets da Release)
Write-Host "`n[1/3] Procurando arquivo .zip nos Assets..." -ForegroundColor Yellow

# Filtra o primeiro asset que termina com .zip
$asset = $selected.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1

if ($null -eq $asset) {
    Write-Host "![ERRO] Nenhum arquivo .zip encontrado nos Assets desta release." -ForegroundColor Red
    Pause
    continue # Volta para o menu
}

$zipUrl = $asset.browser_download_url
$tempZip = "$env:TEMP\update_download.zip"

Write-Host "Baixando: $($asset.name)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip


                # 5. EXTRAÇÃO TEMPORÁRIA
                Write-Host "[2/3] Extraindo pacote..." -ForegroundColor Yellow
                if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
                Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

                # Localiza a subpasta que o GitHub cria automaticamente
                $subFolder = Get-ChildItem $tempExtract | Select-Object -First 1
                $filesToCopy = Get-ChildItem -Path $subFolder.FullName -Recurse | Where-Object { -not $_.PSIsContainer }

                # 6. INSTALAÇÃO (LÓGICA DE NÃO SOBRESCREVER)
                Write-Host "[3/3] Sincronizando com C:\..." -ForegroundColor Yellow
                
                foreach ($file in $filesToCopy) {
                    $relativePath = $file.FullName.Substring($subFolder.FullName.Length + 1)
                    $targetFile = Join-Path -Path $destPath -ChildPath $relativePath
                    $targetDir = Split-Path -Path $targetFile

                    if (-not (Test-Path $targetDir)) {
                        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    }

                    # SÓ COPIA SE O ARQUIVO NÃO EXISTIR
                    if (-not (Test-Path $targetFile)) {
                        Copy-Item -Path $file.FullName -Destination $targetFile
                        Write-Host "  [+] Novo: $relativePath" -ForegroundColor Green
                    } else {
                        Write-Host "  [.] Mantido: $relativePath" -ForegroundColor Gray
                    }
                }

                # LIMPEZA
                Remove-Item $tempZip -Force
                Remove-Item $tempExtract -Recurse -Force

                Write-Host "`nINSTALAÇÃO CONCLUÍDA!" -ForegroundColor Green
                Pause
            }
        }
    }
}
catch {
    Write-Host "`n![ERRO CRÍTICO]: $_" -ForegroundColor Red
    Pause
}
