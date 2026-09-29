param(
	[string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$sourceFolders = @(
	(Join-Path $ProjectRoot 'scripts'),
	(Join-Path $ProjectRoot 'scenes')
)
$stringPattern = '"(?:[^"\\\r\n]|\\.)*[\u0400-\u04FF](?:[^"\\\r\n]|\\.)*"'
$strings = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

foreach ($file in Get-ChildItem -Path $sourceFolders -Recurse -File) {
	if ($file.Extension -notin '.gd', '.tscn') { continue }
	$content = Get-Content -LiteralPath $file.FullName -Raw
	foreach ($match in [regex]::Matches($content, $stringPattern)) {
		$raw = $match.Value.Substring(1, $match.Value.Length - 2)
		$decoded = [regex]::Unescape($raw)
		[void]$strings.Add($decoded)
	}
}

$orderedStrings = @($strings | Sort-Object)
$translations = @{}
$batch = [System.Collections.Generic.List[string]]::new()
$batchLength = 0

function Protect-Text([string]$Text) {
	return $Text.Replace("`r`n", '__MES_NL__').Replace("`n", '__MES_NL__')
}

function Invoke-TranslationBatch([System.Collections.Generic.List[string]]$Items) {
	if ($Items.Count -eq 0) { return }
	$parts = [System.Collections.Generic.List[string]]::new()
	for ($index = 0; $index -lt $Items.Count; $index++) {
		$parts.Add("__MES_$($index.ToString('D4'))__")
		$parts.Add((Protect-Text $Items[$index]))
	}
	$parts.Add('__MES_END__')
	$query = $parts -join "`n"
	$uri = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=ru&tl=en&dt=t&q=' + [uri]::EscapeDataString($query)
	$response = Invoke-RestMethod -Uri $uri -TimeoutSec 60
	$translated = (($response[0] | ForEach-Object { $_[0] }) -join '')
	for ($index = 0; $index -lt $Items.Count; $index++) {
		$startMarker = "__MES_$($index.ToString('D4'))__"
		$endMarker = if ($index + 1 -lt $Items.Count) { "__MES_$(($index + 1).ToString('D4'))__" } else { '__MES_END__' }
		$start = $translated.IndexOf($startMarker, [System.StringComparison]::Ordinal)
		$end = $translated.IndexOf($endMarker, [System.StringComparison]::Ordinal)
		if ($start -lt 0 -or $end -lt 0 -or $end -le $start) {
			throw "Translation markers were damaged near item $index."
		}
		$valueStart = $start + $startMarker.Length
		$value = $translated.Substring($valueStart, $end - $valueStart).Trim()
		$value = $value.Replace('__MES_NL__', "`n")
		# Keep recurring game terminology consistent with the English title and UI.
		$value = $value.Replace('MAGICAL EMERGENCY SERVICE', 'ARCANE EMERGENCY SERVICE').Replace('Magical Emergency Service', 'Arcane Emergency Service')
		$value = $value.Replace('APPLICATIONS', 'JOBS').Replace('APPLICATION', 'JOB').Replace('Applications', 'Jobs').Replace('Application', 'Job').Replace('applications', 'jobs').Replace('application', 'job')
		$value = $value.Replace('BRIGADES', 'CREWS').Replace('BRIGADE', 'CREW').Replace('Brigades', 'Crews').Replace('Brigade', 'Crew').Replace('brigades', 'crews').Replace('brigade', 'crew')
		$value = $value.Replace('TENANTS', 'RESIDENTS').Replace('TENANT', 'RESIDENT').Replace('Tenants', 'Residents').Replace('Tenant', 'Resident').Replace('tenants', 'residents').Replace('tenant', 'resident')
		$value = $value.Replace('TREASURY', 'FUNDS').Replace('Treasury', 'Funds').Replace('treasury', 'funds')
		$value = $value.Replace('CRANES', 'FAUCETS').Replace('CRANE', 'FAUCET').Replace('Cranes', 'Faucets').Replace('Crane', 'Faucet').Replace('cranes', 'faucets').Replace('crane', 'faucet')
		$value = $value.Replace('TAPS', 'FAUCETS').Replace('TAP', 'FAUCET').Replace('Taps', 'Faucets').Replace('Tap', 'Faucet').Replace('taps', 'faucets').Replace('tap', 'faucet')
		$value = $value.Replace('CABINETS', 'WARDROBES').Replace('CABINET', 'WARDROBE').Replace('Cabinets', 'Wardrobes').Replace('Cabinet', 'Wardrobe').Replace('cabinets', 'wardrobes').Replace('cabinet', 'wardrobe')
		$value = $value.Replace('Mistress Mirabelle', 'Lady Mirabelle').Replace('Mistress Celeste', 'Lady Celeste').Replace('Mistress Eleanor', 'Lady Eleanor').Replace('Mister Ragnar', 'Lord Ragnar')
		if ($Items[$index] -in @('Свободен', 'Свободна', 'Доступен', 'Доступна')) {
			$value = 'Available'
		}
		$sourcePlaceholders = @([regex]::Matches($Items[$index], '%(?:\d+\$)?[sdf]') | ForEach-Object Value | Sort-Object)
		$targetPlaceholders = @([regex]::Matches($value, '%(?:\d+\$)?[sdf]') | ForEach-Object Value | Sort-Object)
		if (($sourcePlaceholders -join '|') -ne ($targetPlaceholders -join '|')) {
			throw "Formatting placeholders changed in: $($Items[$index])"
		}
		$translations[$Items[$index]] = $value
	}
}

foreach ($source in $orderedStrings) {
	$protectedLength = (Protect-Text $source).Length + 20
	if ($batch.Count -gt 0 -and $batchLength + $protectedLength -gt 2800) {
		Invoke-TranslationBatch $batch
		$batch.Clear()
		$batchLength = 0
		Start-Sleep -Milliseconds 120
	}
	$batch.Add($source)
	$batchLength += $protectedLength
}
Invoke-TranslationBatch $batch

function ConvertTo-PoQuoted([string]$Text) {
	$escaped = $Text.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", '\n')
	return '"' + $escaped + '"'
}

$localizationFolder = Join-Path $ProjectRoot 'localization'
New-Item -ItemType Directory -Path $localizationFolder -Force | Out-Null
$outputPath = Join-Path $localizationFolder 'en.po'
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('msgid ""')
$lines.Add('msgstr ""')
$lines.Add('"Project-Id-Version: Magic Emergency Service\n"')
$lines.Add('"Language: en\n"')
$lines.Add('"MIME-Version: 1.0\n"')
$lines.Add('"Content-Type: text/plain; charset=UTF-8\n"')
$lines.Add('"Content-Transfer-Encoding: 8bit\n"')
$lines.Add('')
foreach ($source in $orderedStrings) {
	$lines.Add('msgid ' + (ConvertTo-PoQuoted $source))
	$lines.Add('msgstr ' + (ConvertTo-PoQuoted ([string]$translations[$source])))
	$lines.Add('')
}
[System.IO.File]::WriteAllLines($outputPath, $lines, [System.Text.UTF8Encoding]::new($false))
Write-Output "Created $outputPath with $($orderedStrings.Count) translations."
