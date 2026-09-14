Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ff   = Join-Path $root 'ffmpeg.exe'

$VF = 'scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1,noise=alls=1.5:allf=t,eq=brightness=0.015:contrast=1.02:saturation=1.03,unsharp=3:3:0.4'

$bg   = [System.Drawing.Color]::FromArgb(24,24,27)
$card = [System.Drawing.Color]::FromArgb(39,39,42)
$acc  = [System.Drawing.Color]::FromArgb(139,92,246)
$fg   = [System.Drawing.Color]::FromArgb(228,228,231)
$dim  = [System.Drawing.Color]::FromArgb(140,140,150)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Reel Processor'
$form.Size = New-Object System.Drawing.Size(560,520)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $bg
$form.Font = New-Object System.Drawing.Font('Segoe UI',10)
$form.AllowDrop = $true

$drop = New-Object System.Windows.Forms.Panel
$drop.Location = New-Object System.Drawing.Point(20,20)
$drop.Size = New-Object System.Drawing.Size(500,200)
$drop.BackColor = $card
$drop.AllowDrop = $true
$form.Controls.Add($drop)

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = "ПЕРЕТАЩИТЕ РОЛИКИ СЮДА"
$lbl.ForeColor = $fg
$lbl.Font = New-Object System.Drawing.Font('Segoe UI',15,[System.Drawing.FontStyle]::Bold)
$lbl.TextAlign = 'MiddleCenter'
$lbl.Dock = 'Fill'
$lbl.AllowDrop = $true
$drop.Controls.Add($lbl)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = "1080x1920  •  H.264 CRF 20  •  AAC 160k  •  метаданные вычищены"
$sub.ForeColor = $dim
$sub.TextAlign = 'MiddleCenter'
$sub.Location = New-Object System.Drawing.Point(20,226)
$sub.Size = New-Object System.Drawing.Size(500,22)
$form.Controls.Add($sub)

$btn = New-Object System.Windows.Forms.Button
$btn.Text = 'Выбрать файлы...'
$btn.Location = New-Object System.Drawing.Point(20,256)
$btn.Size = New-Object System.Drawing.Size(500,40)
$btn.FlatStyle = 'Flat'
$btn.FlatAppearance.BorderSize = 0
$btn.BackColor = $acc
$btn.ForeColor = [System.Drawing.Color]::White
$btn.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btn)

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ScrollBars = 'Vertical'
$log.ReadOnly = $true
$log.Location = New-Object System.Drawing.Point(20,308)
$log.Size = New-Object System.Drawing.Size(500,150)
$log.BackColor = $card
$log.ForeColor = $dim
$log.BorderStyle = 'None'
$log.Font = New-Object System.Drawing.Font('Consolas',9)
$form.Controls.Add($log)

function Write-Log($t) {
  $log.AppendText($t + "`r`n")
  [System.Windows.Forms.Application]::DoEvents()
}

function Process-Files($files) {
  if (-not (Test-Path $ff)) {
    [System.Windows.Forms.MessageBox]::Show("Рядом с программой нет ffmpeg.exe`n`nПоложите ffmpeg.exe в папку:`n$root",'Нет ffmpeg')
    return
  }
  $vids = @($files | Where-Object { $_ -match '\.(mp4|mov|m4v|mkv|avi|webm)$' })
  if ($vids.Count -eq 0) { Write-Log 'Это не видеофайлы.'; return }

  $btn.Enabled = $false
  $drop.BackColor = [System.Drawing.Color]::FromArgb(30,41,59)
  $i = 0
  foreach ($f in $vids) {
    $i++
    $name = [System.IO.Path]::GetFileName($f)
    $lbl.Text = "ОБРАБОТКА $i / $($vids.Count)"
    Write-Log "-> $name"
    [System.Windows.Forms.Application]::DoEvents()

    $out = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($f), [System.IO.Path]::GetFileNameWithoutExtension($f) + '_processed.mp4')
    $args = @('-hide_banner','-loglevel','error','-y','-i',$f,'-map_metadata','-1','-vf',$VF,
      '-c:v','libx264','-crf','20','-preset','medium','-profile:v','high','-level','4.1',
      '-c:a','aac','-b:a','160k','-ar','44100','-movflags','+faststart',
      '-fflags','+bitexact','-flags:v','+bitexact','-flags:a','+bitexact',
      '-metadata','title=','-metadata','artist=','-metadata','comment=','-metadata','description=',$out)
    $p = Start-Process -FilePath $ff -ArgumentList $args -NoNewWindow -PassThru
    while (-not $p.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 120 }

    if ($p.ExitCode -eq 0) { Write-Log "   OK: $([System.IO.Path]::GetFileName($out))" }
    else { Write-Log "   ОШИБКА (код $($p.ExitCode))" }
  }
  $lbl.Text = "ГОТОВО"
  $drop.BackColor = [System.Drawing.Color]::FromArgb(22,78,52)
  Write-Log 'Готово. Файлы _processed лежат рядом с исходниками.'
  $btn.Enabled = $true
}

$enter = {
  param($s,$e)
  if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
    $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    $drop.BackColor = [System.Drawing.Color]::FromArgb(55,48,90)
  }
}
$leave = { $drop.BackColor = $card }
$dropped = {
  param($s,$e)
  $files = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
  Process-Files $files
}

foreach ($c in @($form,$drop,$lbl)) {
  $c.Add_DragEnter($enter)
  $c.Add_DragLeave($leave)
  $c.Add_DragDrop($dropped)
}

$btn.Add_Click({
  $d = New-Object System.Windows.Forms.OpenFileDialog
  $d.Multiselect = $true
  $d.Filter = 'Видео|*.mp4;*.mov;*.m4v;*.mkv;*.avi;*.webm|Все файлы|*.*'
  if ($d.ShowDialog() -eq 'OK') { Process-Files $d.FileNames }
})

if (-not (Test-Path $ff)) { Write-Log 'ВНИМАНИЕ: ffmpeg.exe не найден в папке программы.' }
else { Write-Log 'ffmpeg найден. Готов к работе.' }

[void]$form.ShowDialog()
