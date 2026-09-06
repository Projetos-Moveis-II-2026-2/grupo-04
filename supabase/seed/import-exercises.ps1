# Gera supabase/seed/002_seed_exercises.sql a partir do exercises.json
# (free-exercise-db). Idempotente: ON CONFLICT (external_id) DO NOTHING.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$json = Get-Content (Join-Path $PSScriptRoot 'exercises.json') -Raw | ConvertFrom-Json

function PgText([string]$s) {
  if ($null -eq $s) { return 'NULL' }
  return "'" + $s.Replace("'", "''") + "'"
}

function PgArray($values) {
  if ($null -eq $values -or $values.Count -eq 0) { return 'NULL' }
  $items = @($values) | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }
  return 'ARRAY[' + ($items -join ',') + ']::text[]'
}

$sql = New-Object System.Text.StringBuilder
[void]$sql.AppendLine('-- Seed da biblioteca de exercícios (free-exercise-db, Unlicense).')
[void]$sql.AppendLine('-- Gerado por supabase/seed/import-exercises.ps1 — não editar à mão.')
[void]$sql.AppendLine('-- 876 exercícios; idempotente via ON CONFLICT (external_id).')
[void]$sql.AppendLine('')

$batchSize = 200
for ($start = 0; $start -lt $json.Count; $start += $batchSize) {
  $end = [Math]::Min($start + $batchSize, $json.Count)
  [void]$sql.AppendLine("INSERT INTO exercise_library")
  [void]$sql.AppendLine("  (external_id, name, force, level, mechanic, equipment,")
  [void]$sql.AppendLine("   primary_muscles, secondary_muscles, instructions, category, image_urls)")
  [void]$sql.AppendLine("VALUES")
  $rows = @()
  for ($i = $start; $i -lt $end; $i++) {
    $e = $json[$i]
    $cols = @(
      (PgText $e.id), (PgText $e.name), (PgText $e.force), (PgText $e.level),
      (PgText $e.mechanic), (PgText $e.equipment),
      (PgArray $e.primaryMuscles), (PgArray $e.secondaryMuscles),
      (PgArray $e.instructions), (PgText $e.category), (PgArray $e.images)
    )
    $rows += ('(' + ($cols -join ', ') + ')')
  }
  [void]$sql.AppendLine(($rows -join ",`n"))
  [void]$sql.AppendLine("ON CONFLICT (external_id) DO NOTHING;")
  [void]$sql.AppendLine('')
}

$out = Join-Path $PSScriptRoot '002_seed_exercises.sql'
[System.IO.File]::WriteAllText($out, $sql.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Host "OK: $out ($($json.Count) exercícios)"
