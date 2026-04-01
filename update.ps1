# =========================================================
# SCRIPT DE ATUALIZAÇÃO AUTOMATIZADA (GITHUB TO C:\)
# =========================================================

# --- CONFIGURAÇÕES ---
$repoOwner = "Guibmet"
$repoName  = "Guibhub"
$destRoot  = "C:\"  # Raiz onde a pasta do zip será criada
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=5"

# 1. VERIFICAÇÃO DE ADMINISTRADOR
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("Erro: Execute como Administrador!", "Erro de Permissão", 0, 16)
    exit
}

try {
    $releases = Invoke-RestMethod -Uri $apiUrl -Method Get
    if ($releases.Count -eq 0) { exit }

    # --- JANELA 320x320 ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Updater $repoName"
    $form.Size = New-Object System.Drawing.Size(320, 320)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(10, 35)
    $listBox.Size = New-Object System.Drawing.Size(285, 150)
    foreach ($r in $releases) { $listBox.Items.Add($r.tag_name) }
    $form.Controls.Add($listBox)

    $btnInstall = New-Object System.Windows.Forms.Button
    $btnInstall.Text = "Ver Notas e Instalar"
    $btnInstall.Location = New-Object System.Drawing.Point(10, 200)
    $btnInstall.Size = New-Object System.Drawing.Size(285, 30)
    
    $btnInstall.Add_Click({
        $selTag = $listBox.SelectedItem
        if ($null -eq $selTag) { return }
        
        $selected = $releases | Where-Object { $_.tag_name -eq $selTag }
        $asset = $selected.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        
        if ($null -eq $asset) {
            [System.Windows.Forms.MessageBox]::Show("Nenhum .zip encontrado!", "Erro", 0, 16)
            return
        }

        # --- Lógica de Nome da Pasta ---
        $zipFileName = $asset.name
        $folderName = [System.IO.Path]::GetFileNameWithoutExtension($zipFileName)
        $finalDestPath = Join-Path $destRoot $folderName

        $msg = "Versão: $($selected.tag_name)`nArquivo: $zipFileName`nDestino: $finalDestPath`n`nNotas: $($selected.body)`n`nDeseja continuar?"
        $confirm = [System.Windows.Forms.MessageBox]::Show($msg, "Confirmar", 4, 32)
        
        if ($confirm -eq "Yes") {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            
            $tempZip = "$env:TEMP\update_download.zip"
            $tempExtract = "$env:TEMP\extract_tmp"
            
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip
            
            if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
            Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

            # Cria a pasta principal se não existir
            if (-not (Test-Path $finalDestPath)) {
                New-Item -ItemType Directory -Path $finalDestPath -Force | Out-Null
            }

            # Sincroniza arquivos (Adiciona novos, mantém antigos)
            $files = Get-ChildItem -Path $tempExtract -Recurse | Where-Object { -not $_.PSIsContainer }
            foreach ($file in $files) {
                # Calcula caminho relativo dentro do ZIP extraído
                $rel = $file.FullName.Substring($tempExtract.Length + 1)
                $targetFile = Join-Path $finalDestPath $rel
                $targetDir = Split-Path $targetFile

                if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
                
                # SÓ COPIA SE NÃO EXISTIR NO C:\NOME_DO_ZIP\
                if (-not (Test-Path $targetFile)) {
                    Copy-Item $file.FullName -Destination $targetFile
                }
            }

            Remove-Item $tempZip -Force
            Remove-Item $tempExtract -Recurse -Force
            
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            [System.Windows.Forms.MessageBox]::Show("Sincronização concluída em: $folderName", "Sucesso", 0, 64)
            $form.Close()
        }
    })
    $form.Controls.Add($btnInstall)
    $form.ShowDialog() | Out-Null

} catch {
    [System.Windows.Forms.MessageBox]::Show("Erro: $_", "Erro Crítico", 0, 16)
}
