Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# --- CONFIGURAÇÕES ---
$repoOwner = "Guibmet"
$repoName  = "Guibhub"
$destRoot  = "C:\" # Se mudar para C:\ precisa de Admin. Para evitar, use "$env:USERPROFILE\Desktop"
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=5"

# --- INTERFACE ---
$form = New-Object Windows.Forms.Form
$form.Text = "Guibhub Update Manager"
$form.Size = New-Object Drawing.Size(400, 450)
$form.BackColor = [Drawing.Color]::FromArgb(30, 30, 30) # Dark Gray
$form.ForeColor = [Drawing.Color]::White
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$label = New-Object Windows.Forms.Label
$label.Text = "Selecione a Versão:"
$label.Location = New-Object Drawing.Point(20, 20)
$label.AutoSize = $true
$form.Controls.Add($label)

$listBox = New-Object Windows.Forms.ListBox
$listBox.Location = New-Object Drawing.Point(20, 50)
$listBox.Size = New-Object Drawing.Size(340, 200)
$listBox.BackColor = [Drawing.Color]::FromArgb(45, 45, 45)
$listBox.ForeColor = [Drawing.Color]::LimeGreen
$listBox.BorderStyle = "FixedSingle"
$form.Controls.Add($listBox)

$statusLabel = New-Object Windows.Forms.Label
$statusLabel.Text = "Pronto."
$statusLabel.Location = New-Object Drawing.Point(20, 350)
$statusLabel.Size = New-Object Drawing.Size(340, 20)
$statusLabel.ForeColor = [Drawing.Color]::Gray
$form.Controls.Add($statusLabel)

# --- LÓGICA DE DOWNLOAD ---
try {
    $releases = Invoke-RestMethod -Uri $apiUrl
    foreach ($r in $releases) { [void]$listBox.Items.Add($r.tag_name) }
} catch {
    [Windows.Forms.MessageBox]::Show("Erro ao conectar ao GitHub.")
}

$btnSync = New-Object Windows.Forms.Button
$btnSync.Text = "SINCRONIZAR AGORA"
$btnSync.Location = New-Object Drawing.Point(20, 280)
$btnSync.Size = New-Object Drawing.Size(340, 50)
$btnSync.FlatStyle = "Flat"
$btnSync.FlatAppearance.BorderColor = [Drawing.Color]::LimeGreen
$btnSync.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnSync)

$btnSync.Add_Click({
    if ($null -eq $listBox.SelectedItem) { return }
    
    $selected = $releases | Where-Object { $_.tag_name -eq $listBox.SelectedItem }
    $asset = $selected.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
    
    if ($null -eq $asset) {
        $statusLabel.Text = "Nenhum ZIP encontrado."
        return
    }

    $statusLabel.Text = "Baixando... aguarde."
    $statusLabel.ForeColor = [Drawing.Color]::Yellow
    $form.Refresh()

    $tempZip = "$env:TEMP\update.zip"
    $finalPath = Join-Path $destRoot $selected.tag_name

    # Download de alta performance
    $progressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip

    # Extração veloz
    if (-not (Test-Path $finalPath)) { New-Item -ItemType Directory -Path $finalPath -Force }
    
    $shell = New-Object -ComObject Shell.Application
    $zip = $shell.NameSpace($tempZip)
    $dest = $shell.NameSpace($finalPath)
    $dest.CopyHere($zip.Items(), 0x14) # 0x14 sobrescreve tudo sem perguntar

    Remove-Item $tempZip -Force
    
    $statusLabel.Text = "Sincronizado com sucesso!"
    $statusLabel.ForeColor = [Drawing.Color]::LimeGreen
    [Windows.Forms.MessageBox]::Show("Arquivos salvos em: $finalPath", "Sucesso")
})

[void]$form.ShowDialog()
