$content = Get-Content lib/widgets/file_generator.dart -Raw
$lines = $content -split "`n"
$output = @($lines[0..3271]) + @($lines[3308..($lines.Count-1)])
$output -join "`n" | Out-File lib/widgets/file_generator.dart -Encoding UTF8
Write-Host "Removed problematic fallback section. Total lines: $($output.Count)"
