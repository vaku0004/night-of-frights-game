# Night of Frights - narrator generator (ElevenLabs, Eleven v4)
# Keep this file, voice-lines.json and this folder together.
# What it does:
#   1. Reads every line the game says from voice-lines.json.
#   2. Lets you pick the narrator voice (remembered in voice-config.json).
#   3. Shows how many credits it will use and asks before spending anything.
#   4. Saves one MP3 per line in the "audio" folder, plus audio\manifest.json for the game.
# Running it again only voices lines that are new or changed, so credits are never spent twice.
# Your API key is typed into this window only. It is not saved anywhere.

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$api = "https://api.elevenlabs.io"
$preferredModel = "eleven_v4"
$linesPath = Join-Path $here "voice-lines.json"
$audioDir = Join-Path $here "audio"
$parentDir = Split-Path $here -Parent
if ($parentDir -and (Test-Path (Join-Path $parentDir "index.html"))) { $audioDir = Join-Path $parentDir "audio" }   # inside the repo: use the game's audio folder
$configPath = Join-Path $here "voice-config.json"
$reportPath = Join-Path $here "generate-report.txt"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$manifestPath = Join-Path $audioDir "manifest.json"

[IO.File]::WriteAllText($reportPath, ("Night of Frights - narrator generator ({0})`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm")), $utf8)
function Say([string]$t = "", [string]$color = "Gray") { Write-Host $t -ForegroundColor $color; [IO.File]::AppendAllText($reportPath, $t + "`r`n", $utf8) }
function Quit([string]$msg) { Say $msg "Red"; Write-Host ""; Read-Host "Press Enter to close" | Out-Null; exit 1 }

# ---------- lines ----------
if (-not (Test-Path $linesPath)) { Quit "voice-lines.json was not found in this folder: $here" }
$parsed = [IO.File]::ReadAllText($linesPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$lines = @(); foreach ($l in $parsed) { if ($l.file -and $l.text -and $l.tts) { $lines += $l } }
if ($lines.Count -eq 0) { Quit "voice-lines.json has no lines in it." }
Say ("Lines in voice-lines.json: {0}" -f $lines.Count)

# ---------- key ----------
$key = $env:ELEVENLABS_API_KEY
if (-not $key) {
  $sec = Read-Host "Paste your ElevenLabs API key and press Enter (it stays hidden)" -AsSecureString
  $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}
$key = "$key".Trim()
if (-not $key) { Quit "No key entered." }
if ($key.Length -lt 30) { Quit ("That is {0} characters, which is too short for an API key (ElevenLabs keys usually start with sk_ and are about 50 characters). A 20-character value is usually a voice ID. Copy the API key and run again." -f $key.Length) }
$headers = @{ "xi-api-key" = $key }
function Get-Api([string]$path) {
  try { return Invoke-RestMethod -Uri ($api + $path) -Headers $headers -Method Get }
  catch { $code = $_.Exception.Response.StatusCode.value__; Say ("  ! {0} failed (HTTP {1})." -f $path, $code) "Yellow"; return $null }
}

# ---------- credits ----------
$sub = Get-Api "/v1/user/subscription"
if (-not $sub) { Quit "Could not read your plan. Check the key (it needs User read permission)." }
$left = [int64]$sub.character_limit - [int64]$sub.character_count
Say ("Plan: {0}. Credits left: {1:N0}" -f $sub.tier, $left)

# ---------- model ----------
$models = @(); foreach ($m in @(Get-Api "/v1/models")) { if ($m -and $m.can_do_text_to_speech) { $models += $m } }
$model = $models | Where-Object { $_.model_id -eq $preferredModel } | Select-Object -First 1
if (-not $model) {
  Say "Eleven v4 is not available on this key. Available speech models:" "Yellow"
  for ($i = 0; $i -lt $models.Count; $i++) { Say ("  [{0}] {1} ({2})" -f ($i + 1), $models[$i].name, $models[$i].model_id) }
  $pick = Read-Host "Type the number of the model to use"
  if (-not $pick) { Quit "No model chosen." }
  $model = $models[[int]$pick - 1]
}
$mult = 1.0
if ($model.model_rates -and $model.model_rates.character_cost_multiplier) { $mult = [double]$model.model_rates.character_cost_multiplier }
Say ("Model: {0} ({1}), credits per character: {2}" -f $model.name, $model.model_id, $mult)

# ---------- voice ----------
$voiceId = $null; $voiceName = $null
if (Test-Path $configPath) {
  $cfg = [IO.File]::ReadAllText($configPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
  if ($cfg.voice_id) {
    $ans = Read-Host ("Use the narrator voice '{0}'? Press Enter for yes, or type C to choose another" -f $cfg.voice_name)
    if ($ans -ne "C" -and $ans -ne "c") { $voiceId = $cfg.voice_id; $voiceName = $cfg.voice_name }
  }
}
if (-not $voiceId) {
  # Your full voice list is never shown: paste one voice ID, or search by name and see only the matches.
  Write-Host ""
  Write-Host "Choose the narrator voice:" -ForegroundColor Cyan
  Write-Host "  - paste its voice ID (in ElevenLabs open the voice and copy its ID), or"
  Write-Host "  - type S to search your voices by name (only matching voices are shown)."
  $ans = "$(Read-Host 'Voice ID or S')".Trim()
  if ($ans -eq "S" -or $ans -eq "s") {
    $term = "$(Read-Host 'Type part of the voice name')".Trim()
    if (-not $term) { Quit "No search term entered." }
    $vr = Get-Api ("/v2/voices?page_size=100&search=" + [uri]::EscapeDataString($term))
    $voices = @(); if ($vr) { foreach ($v in $vr.voices) { $voices += $v } }
    if ($voices.Count -eq 0) { Quit "No voices match '$term'. Run again and try another name, or paste the voice ID." }
    for ($i = 0; $i -lt $voices.Count; $i++) {
      $desc = @(); if ($voices[$i].labels) { $voices[$i].labels.PSObject.Properties | ForEach-Object { $desc += $_.Value } }
      Write-Host ("  [{0}] {1}  ({2})  {3}" -f ($i + 1), $voices[$i].name, $voices[$i].category, ($desc -join ", "))
    }
    $pick = Read-Host "Type the number of the narrator voice"
    if (-not $pick) { Quit "No voice chosen." }
    $voiceId = $voices[[int]$pick - 1].voice_id; $voiceName = $voices[[int]$pick - 1].name
  } elseif ($ans) {
    $voiceId = $ans
    $info = $null
    try { $info = Invoke-RestMethod -Uri ("{0}/v1/voices/{1}" -f $api, $voiceId) -Headers $headers -Method Get } catch { $info = $null }
    if ($info -and $info.name) { $voiceName = $info.name } else { $voiceName = "$(Read-Host 'Name to show for this voice in the game (Enter = Narrator)')".Trim() }
    if (-not $voiceName) { $voiceName = "Narrator" }
  } else { Quit "No voice chosen." }
  [IO.File]::WriteAllText($configPath, (@{ voice_id = $voiceId; voice_name = $voiceName } | ConvertTo-Json), $utf8)
}
Say ("Voice: {0}" -f $voiceName)

# ---------- what still needs voicing ----------
if (-not (Test-Path $audioDir)) { New-Item -ItemType Directory -Path $audioDir | Out-Null }
$old = $null
if (Test-Path $manifestPath) { try { $old = [IO.File]::ReadAllText($manifestPath, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $old = $null } }
$done = @{}   # file -> tts text that file was made from
if ($old -and $old.voice_id -eq $voiceId -and $old.model -eq $model.model_id -and $old.tts) {
  foreach ($p in $old.tts.PSObject.Properties) { $done[$p.Name] = $p.Value }
}
$todo = @()
foreach ($l in $lines) {
  $f = Join-Path $audioDir $l.file
  if ((Test-Path $f) -and $done.ContainsKey($l.file) -and $done[$l.file] -ceq $l.tts) { continue }
  $todo += $l
}
$chars = 0; foreach ($l in $todo) { $chars += $l.tts.Length }
$cost = [math]::Ceiling($chars * $mult)
Say ""
Say ("Already voiced: {0}. To voice now: {1} lines, {2:N0} characters, about {3:N0} credits (you have {4:N0})." -f ($lines.Count - $todo.Count), $todo.Count, $chars, $cost, $left) "Cyan"

function Save-Manifest {
  $o = [ordered]@{ model = $model.model_id; voice = $voiceName; voice_id = $voiceId; generated = (Get-Date -Format "yyyy-MM-dd HH:mm"); lines = [ordered]@{}; tts = [ordered]@{} }
  foreach ($l in $lines) {
    if ($done.ContainsKey($l.file) -and $done[$l.file] -ceq $l.tts -and (Test-Path (Join-Path $audioDir $l.file))) {
      $o.lines[$l.text] = $l.file; $o.tts[$l.file] = $l.tts
    }
  }
  [IO.File]::WriteAllText($manifestPath, ($o | ConvertTo-Json -Depth 5), $utf8)
}

if ($todo.Count -eq 0) { Save-Manifest; Say "Everything is already voiced. Nothing to spend." "Green"; Read-Host "Press Enter to close" | Out-Null; exit 0 }
if ($cost -gt $left) { Quit "Not enough credits for all lines. Top up or wait for the reset, then run again." }
$go = Read-Host "Type YES to start voicing"
if ($go -ne "YES" -and $go -ne "yes") { Quit "Stopped. No credits were used." }

# ---------- voicing ----------
$n = 0; $failed = 0
foreach ($l in $todo) {
  $n++
  Write-Progress -Activity "Voicing Night of Frights" -Status ("{0} of {1}" -f $n, $todo.Count) -PercentComplete (100 * $n / $todo.Count)
  $out = Join-Path $audioDir $l.file; $tmp = $out + ".part"
  $body = [Text.Encoding]::UTF8.GetBytes((@{ text = $l.tts; model_id = $model.model_id } | ConvertTo-Json))
  $ok = $false
  for ($try = 1; $try -le 3 -and -not $ok; $try++) {
    try {
      Invoke-WebRequest -Uri ("{0}/v1/text-to-speech/{1}?output_format=mp3_44100_128" -f $api, $voiceId) -Method Post -Headers $headers `
        -ContentType "application/json; charset=utf-8" -Body $body -OutFile $tmp -UseBasicParsing
      Move-Item -Force $tmp $out
      $ok = $true
    } catch {
      $code = $_.Exception.Response.StatusCode.value__
      if (Test-Path $tmp) { Remove-Item -Force $tmp }
      if ($code -eq 401 -or $code -eq 402 -or $code -eq 403) { Save-Manifest; Quit ("Stopped at line {0} (HTTP {1}): key, permission or credits problem. Finished lines are kept; run again to continue." -f $n, $code) }
      if ($code -eq 400 -or $code -eq 404 -or $code -eq 422) {
        Save-Manifest
        if ($n -eq 1) { Remove-Item -Force -ErrorAction SilentlyContinue $configPath; Quit ("The first line failed (HTTP {0}). The voice ID is probably wrong. Run again and paste the correct ID." -f $code) }
        Quit ("Stopped at line {0} (HTTP {1}). Finished lines are kept; send generate-report.txt to Claude." -f $n, $code)
      }
      Say ("  ! Line {0} failed (HTTP {1}), try {2} of 3" -f $n, $code, $try) "Yellow"
      Start-Sleep -Seconds (3 * $try)
    }
  }
  if ($ok) { $done[$l.file] = $l.tts; if ($n % 10 -eq 0) { Save-Manifest } } else { $failed++ }
}
Write-Progress -Activity "Voicing Night of Frights" -Completed
Save-Manifest

$after = Get-Api "/v1/user/subscription"
Say ""
Say ("Finished: {0} lines voiced, {1} failed." -f ($todo.Count - $failed), $failed) "Green"
if ($after) { Say ("Credits used: {0:N0}. Credits left: {1:N0}." -f ([int64]$after.character_count - [int64]$sub.character_count), ([int64]$after.character_limit - [int64]$after.character_count)) "Green" }
if ($failed -gt 0) { Say "Run the script again to retry the failed lines." "Yellow" }
Say "The audio folder is ready. Tell Claude it is done."
Write-Host ""
Read-Host "Press Enter to close" | Out-Null
