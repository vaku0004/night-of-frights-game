# Night of Frights - ElevenLabs connection check
# What it does (about 100 credits in total):
#   1. Shows your plan and how many credits you have left.
#   2. Lists the speech models on your account and what one full game would cost with each.
#   3. Lists your voices, lets you pick one, and makes a short test clip (test-voice.mp3) next to this script.
# Your API key is typed into this window only. It is not saved anywhere.
# The report (elevenlabs-report.txt) has no key in it, so it is safe to share.

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$report = Join-Path $here "elevenlabs-report.txt"
$api = "https://api.elevenlabs.io"

# Characters the voice speaks in one full game (counted from the game's code)
$GAME_CHARS = 11415

function Out-Report([string]$line = "") { Write-Host $line; Add-Content -Path $report -Value $line -Encoding UTF8 }
Set-Content -Path $report -Value "Night of Frights - ElevenLabs check ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))" -Encoding UTF8

# ---- API key ----
$key = $env:ELEVENLABS_API_KEY
if (-not $key) {
  $sec = Read-Host "Paste your ElevenLabs API key and press Enter (it stays hidden)" -AsSecureString
  $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}
$key = $key.Trim()
if (-not $key) { Write-Host "No key entered. Stopping." -ForegroundColor Red; Read-Host "Press Enter to close"; exit 1 }
$headers = @{ "xi-api-key" = $key }

function Call-Api([string]$path) {
  try { return Invoke-RestMethod -Uri ($api + $path) -Headers $headers -Method Get }
  catch {
    $code = $_.Exception.Response.StatusCode.value__
    Out-Report "  ! $path failed (HTTP $code). If it is 401, the key is wrong or lacks permission for this part."
    return $null
  }
}

# ---- 1. Plan and credits ----
Out-Report ""
Out-Report "== Your plan =="
$sub = Call-Api "/v1/user/subscription"
$left = $null
if ($sub) {
  $left = $sub.character_limit - $sub.character_count
  $reset = if ($sub.next_character_count_reset_unix) { [DateTimeOffset]::FromUnixTimeSeconds($sub.next_character_count_reset_unix).LocalDateTime.ToString("yyyy-MM-dd") } else { "unknown" }
  Out-Report ("  Tier: {0}" -f $sub.tier)
  Out-Report ("  Credits used: {0:N0} of {1:N0}  ->  left: {2:N0}  (resets {3})" -f $sub.character_count, $sub.character_limit, $left, $reset)
}

# ---- 2. Models and cost of one game ----
Out-Report ""
Out-Report ("== Speech models and cost of one full game ({0:N0} characters) ==" -f $GAME_CHARS)
$models = @(@(Call-Api "/v1/models") | Where-Object { $_ -and $_.can_do_text_to_speech })
$i = 0
foreach ($m in $models) {
  $i++
  $mult = 1.0
  if ($m.model_rates -and $m.model_rates.character_cost_multiplier) { $mult = [double]$m.model_rates.character_cost_multiplier }
  $credits = [math]::Round($GAME_CHARS * $mult)
  $share = if ($left) { " = {0:P0} of what you have left" -f ($credits / [double]$left) } else { "" }
  Out-Report ("  [{0}] {1}  ({2})  x{3}  ->  {4:N0} credits per game{5}" -f $i, $m.name, $m.model_id, $mult, $credits, $share)
}

# ---- 3. Voices ----
Out-Report ""
Out-Report "== Voices on your account =="
$v = Call-Api "/v2/voices?page_size=100"
$voices = @()
if ($v) { $voices = @($v.voices) }
$j = 0
foreach ($vo in $voices) {
  $j++
  $desc = @()
  if ($vo.labels) { $vo.labels.PSObject.Properties | ForEach-Object { $desc += $_.Value } }
  Out-Report ("  [{0}] {1}  ({2})  {3}  id={4}" -f $j, $vo.name, $vo.category, ($desc -join ", "), $vo.voice_id)
}

# ---- 4. Test clip ----
if ($voices.Count -gt 0 -and $models.Count -gt 0) {
  Write-Host ""
  $vn = Read-Host "Type the number of the voice to test (or press Enter to skip the test clip)"
  if ($vn) {
    $mn = Read-Host "Type the number of the model to use (Enter = first in the list)"
    if (-not $mn) { $mn = 1 }
    $voice = $voices[[int]$vn - 1]; $model = $models[[int]$mn - 1]
    $text = "Welcome to Victoria's Night of Frights. Pick a question... if you dare."
    $body = @{ text = $text; model_id = $model.model_id } | ConvertTo-Json
    $out = Join-Path $here "test-voice.mp3"
    try {
      Invoke-WebRequest -Uri ("$api/v1/text-to-speech/{0}?output_format=mp3_44100_128" -f $voice.voice_id) -Method Post -Headers $headers `
        -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body)) -OutFile $out -UseBasicParsing
      Out-Report ""
      Out-Report ("== Test clip made: {0} with {1} -> test-voice.mp3 ==" -f $voice.name, $model.model_id)
      Start-Process $out
      $after = Call-Api "/v1/user/subscription"
      if ($after -and $sub) { Out-Report ("  The test used {0:N0} credits ({1} characters of text)." -f ($after.character_count - $sub.character_count), $text.Length) }
    } catch {
      $code = $_.Exception.Response.StatusCode.value__
      Out-Report "  ! Test clip failed (HTTP $code). 401 = key or permission problem, 402/429 = out of credits or too many requests."
    }
  }
}

Out-Report ""
Out-Report "Done. Send elevenlabs-report.txt to Claude (it contains no key)."
Write-Host ""
Read-Host "Press Enter to close"
