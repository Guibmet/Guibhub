# =========================================================
# SCRIPT DE ATUALIZAÇÃO AUTOMATIZADA (GITHUB TO C:\)
# =========================================================

# --- CONFIGURAÇÕES ---
$repoOwner = "Guibmet"
$repoName  = "Guibhub"
$destRoot  = "C:\" 
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=5"

# Verifica Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("Erro: Execute como Administrador!", "Atenção", 0, 16)
    exit
}

try {
    $releases = Invoke-RestMethod -Uri $apiUrl -Method Get
    if ($releases.Count -eq 0) { exit }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Instalador de Updates"
    $form.Size = New-Object System.Drawing.Size(320, 320)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(10, 35)
    $listBox.Size = New-Object System.Drawing.Size(285, 150)
    foreach ($r in $releases) { [void]$listBox.Items.Add($r.tag_name) }
    $form.Controls.Add($listBox)

    $btnInstall = New-Object System.Windows.Forms.Button
    $btnInstall.Text = "Sincronizar Arquivos Novos"
    $btnInstall.Location = New-Object System.Drawing.Point(10, 200)
    $btnInstall.Size = New-Object System.Drawing.Size(285, 40)
    
    $btnInstall.Add_Click({
        $selTag = $listBox.SelectedItem
        if ($null -eq $selTag) { return }
        
        $selected = $releases | Where-Object { $_.tag_name -eq $selTag }
        $asset = $selected.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        
        if ($null -eq $asset) {
            [System.Windows.Forms.MessageBox]::Show("Nenhum .zip encontrado!", "Erro", 0, 16)
            return
        }

        # Nome da pasta baseado no ZIP
        $folderName = $asset.name.Replace(".zip", "")
        $finalPath = Join-Path $destRoot $folderName

        if ([System.Windows.Forms.MessageBox]::Show("Instalar novos arquivos em: $finalPath ?", "Confirmar", 4, 32) -eq "Yes") {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            
            $tempZip = "$env:TEMP\update_file.zip"
            $tempFolder = "$env:TEMP\extracao_temp"
            
            if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
            if (Test-Path $tempFolder) { Remove-Item $tempFolder -Recurse -Force }

            # Download e Extração
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip
            Expand-Archive -Path $tempZip -DestinationPath $tempFolder -Force

            # 1. Cria a pasta mestre no C:\ se não existir
            if (-not (Test-Path $finalPath)) {
                New-Item -ItemType Directory -Path $finalPath -Force | Out-Null
            }

            # 2. Varredura de arquivos (Lógica: Apenas Adicionar)
            $itensNoZip = Get-ChildItem -Path $tempFolder -Recurse
            
            foreach ($item in $itensNoZip) {
                # Calcula o caminho de destino removendo o prefixo da pasta temporária
                $relPath = $item.FullName.Substring($tempFolder.Length).TrimStart('\').TrimStart('/')
                $targetFile = Join-Path $finalPath $relPath

                if ($item.PSIsContainer) {
                    # Se for pasta, garante que existe no C:\
                    if (-not (Test-Path $targetFile)) {
                        New-Item -ItemType Directory -Path $targetFile -Force | Out-Null
                    }
                } else {
                    # Se for arquivo, SÓ COPIA SE NÃO EXISTIR
                    if (-not (Test-Path $targetFile)) {
                        $parent = Split-Path $targetFile
                        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                        Copy-Item -Path $item.FullName -Destination $targetFile -Force
                    }
                }
            }

            # Limpeza
            Remove-Item $tempZip -Force
            Remove-Item $tempFolder -Recurse -Force
            
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            [System.Windows.Forms.MessageBox]::Show("Arquivos sincronizados com sucesso!", "Concluído", 0, 64)
            $form.Close()
        }
    })
    
    $form.Controls.Add($btnInstall)
    $form.ShowDialog() | Out-Null

} catch {
    [System.Windows.Forms.MessageBox]::Show("Erro no processo: $_", "Erro", 0, 16)
}
