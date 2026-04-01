# =========================================================
# SCRIPT DE ATUALIZAÇÃO AUTOMATIZADA (GITHUB TO C:\)
# =========================================================

# --- CONFIGURAÇÕES ---
$repoOwner = "Guibmet"
$repoName  = "Guibhub"
$destPath  = "C:\" 
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=5"

# 1. VERIFICAÇÃO DE ADMINISTRADOR
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("Erro: Execute como Administrador!", "Erro de Permissão", 0, 16)
    exit
}

try {
    $releases = Invoke-RestMethod -Uri $apiUrl -Method Get
    if ($releases.Count -eq 0) { exit }

    # --- CRIAÇÃO DA JANELA (320x320) ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Updater $repoName"
    $form.Size = New-Object System.Drawing.Size(320, 320)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Selecione a Versão:"
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.AutoSize = $true
    $form.Controls.Add($label)

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
        
        # Mostra Changelog em um popup
        $msg = "Notas da Versão $($selected.tag_name):`n`n$($selected.body)`n`nDeseja instalar?"
        $confirm = [System.Windows.Forms.MessageBox]::Show($msg, "Confirmar Instalação", 4, 32)
        
        if ($confirm -eq "Yes") {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            
            # BUSCA O ZIP NOS ASSETS
            $asset = $selected.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
            if ($null -eq $asset) {
                [System.Windows.Forms.MessageBox]::Show("Nenhum .zip encontrado nos Assets!", "Erro", 0, 16)
                return
            }

            $tempZip = "$env:TEMP\update.zip"
            $tempExtract = "$env:TEMP\extract_tmp"
            
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip
            
            if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
            Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

            # Lógica de cópia sem sobrescrever
            $files = Get-ChildItem -Path $tempExtract -Recurse | Where-Object { -not $_.PSIsContainer }
            foreach ($file in $files) {
                $rel = $file.FullName.Substring($tempExtract.Length + 1)
                $target = Join-Path $destPath $rel
                $dir = Split-Path $target
                if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                if (-not (Test-Path $target)) { Copy-Item $file.FullName -Destination $target }
            }

            Remove-Item $tempZip -Force
            Remove-Item $tempExtract -Recurse -Force
            
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            [System.Windows.Forms.MessageBox]::Show("Concluído!", "Sucesso", 0, 64)
            $form.Close()
        }
    })
    $form.Controls.Add($btnInstall)

    $form.ShowDialog() | Out-Null

} catch {
    [System.Windows.Forms.MessageBox]::Show("Erro: $_", "Erro Crítico", 0, 16)
}
