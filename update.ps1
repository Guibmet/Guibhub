# 1. GARANTE PRIVILÉGIOS DE ADMINISTRADOR (Abre nova guia se necessário)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# --- CONFIGURAÇÕES ---
$repoOwner = "Guibmet"
$repoName  = "Guibhub"
$destRoot  = "C:\"
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=8"

# Configurações de Download
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$progressPreference = 'SilentlyContinue'

# --- CRIAÇÃO DA JANELA PRINCIPAL ---
$form = New-Object Windows.Forms.Form
$form.Text = "Guibhub Manager - Modo Administrador"
$form.Size = New-Object Drawing.Size(420, 500)
$form.BackColor = [Drawing.Color]::FromArgb(25, 25, 25) # Dark Mode
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Título
$label = New-Object Windows.Forms.Label
$label.Text = "Selecione a Versão para Instalar no C:\"
$label.Location = New-Object Drawing.Point(20, 20)
$label.Size = New-Object Drawing.Size(360, 20)
$label.ForeColor = [Drawing.Color]::Cyan
$form.Controls.Add($label)

# Lista de Versões
$listBox = New-Object Windows.Forms.ListBox
$listBox.Location = New-Object Drawing.Point(20, 50)
$listBox.Size = New-Object Drawing.Size(360, 250)
$listBox.BackColor = [Drawing.Color]::FromArgb(40, 40, 40)
$listBox.ForeColor = [Drawing.Color]::White
$listBox.BorderStyle = "FixedSingle"
$listBox.Font = New-Object Drawing.Font("Consolas", 10)
$form.Controls.Add($listBox)

# Status
$statusLabel = New-Object Windows.Forms.Label
$statusLabel.Text = "Aguardando seleção..."
$statusLabel.Location = New-Object Drawing.Point(20, 410)
$statusLabel.Size = New-Object Drawing.Size(360, 20)
$statusLabel.ForeColor = [Drawing.Color]::Gray
$form.Controls.Add($statusLabel)

# ---
