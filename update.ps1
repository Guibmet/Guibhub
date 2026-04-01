# =========================================================
# SCRIPT DE ATUALIZAÇÃO AUTOMATIZADA (GITHUB TO C:\)
# =========================================================

# 1. CARREGAMENTO DAS BIBLIOTECAS (Versão Windows 11)
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
} catch {}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- CONFIGURAÇÕES ---
$repoOwner = "Guibmet"
$repoName  = "Guibhub"
$destRoot  = "C:\" 
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=5"

# 2. VERIFICAÇÃO DE ADMIN (Obrigatório no Win 11 para mexer no C:\)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("Por favor, execute o terminal como ADMINISTRADOR.", "Erro de Privilégio")
    exit
}

try {
    $releases = Invoke-RestMethod -Uri $apiUrl -Method Get
    if ($null -eq $releases) { exit }

    # --- CONFIGURAÇÃO DA JANELA ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Atualizador de Arquivos"
    $form.Size = New-Object System.Drawing.Size(320, 320)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false
    $form.TopMost = $true # Garante que a janela apareça na frente no Win 11

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(10, 40)
    $listBox.Size = New-Object System.Drawing.Size(280, 140)
    foreach ($r in $releases) { [void]$listBox.Items.Add($r.tag_name) }
    $form.Controls.Add($listBox)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Sincronizar Novos Arquivos"
    $btn.Location = New-Object System.Drawing.Point(10, 200)
    $btn.Size = New-Object System.Drawing.Size(280, 45)
    
    $btn.Add_Click({
        if ($null -eq $listBox.SelectedItem) { return }
        
        $selected = $releases | Where-Object { $_.tag_name -eq $listBox.SelectedItem }
        $asset = $selected.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        
        if ($null -eq $asset) {
            [System.Windows.Forms.MessageBox]::Show("Nenhum arquivo .zip encontrado.")
            return
        }

        # Nome da pasta baseado no ZIP
        $folderName = $asset.name.Replace(".zip", "")
        $finalPath = Join-Path $destRoot $folderName

        $confirm = [System.Windows.Forms.MessageBox]::Show("Adicionar novos arquivos em: $finalPath ?", "Confirmar", 4)
        
        if ($confirm -eq "Yes") {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            
            $tempZip = "$env:TEMP\update.zip"
            $tempFolder = "$env:TEMP\extracao"
            
            if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
            if (Test-Path $tempFolder) { Remove-Item $tempFolder -Recurse -Force }

            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip
            Expand-Archive -Path $tempZip -DestinationPath $tempFolder -Force

            # Cria pasta se não existir
            if (-not (Test-Path $finalPath)) { New-Item -ItemType Directory -Path $finalPath -Force | Out-Null }

            # Sincronização inteligente
            Get-ChildItem -Path $tempFolder -Recurse | ForEach-Object {
                $relPath = $_.FullName.Substring($tempFolder.Length).TrimStart('\').TrimStart('/')
                $target = Join-Path $finalPath $relPath

                if ($_.PSIsContainer) {
                    if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
                } else {
                    # SÓ COPIA SE O ARQUIVO NÃO EXISTIR NO DESTINO
                    if (-not (Test-Path $target)) {
                        $parent = Split-Path $target
                        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                        Copy-Item -Path $_.FullName -Destination $target -Force
                    }
                }
            }

            Remove-Item $tempZip -Force
            Remove-Item $tempFolder -Recurse -Force
            
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            [System.Windows.Forms.MessageBox]::Show("Sincronização concluída!", "Sucesso")
            $form.Close()
        }
    })
    
    $form.Controls.Add($btn)
    [void]$form.ShowDialog()

} catch {
    Write-Error "Erro: $_"
}
