param(
    [string]$GodotPath = 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe',
    [string[]]$TestNames = @('generated_mirror_test', 'lunnopuh_assets_test', 'portal_mirror_properties_test', 'protective_cloth_smoke_test', 'ghost_followup_smoke_test', 'ghost_properties_test', 'ghost_interaction_animation_test', 'ghost_mirror_reopen_test', 'lunnopuh_care_test')
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$overridePath = Join-Path $projectRoot 'override.cfg'
if (Test-Path -LiteralPath $overridePath) {
    throw 'override.cfg уже существует. Проверки не заменяют пользовательскую конфигурацию.'
}
$profileName = 'MagicEmergencyService_MirrorTests_' + [guid]::NewGuid().ToString('N')
$testConfig = "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$profileName`"`n"
$preservedTestFiles = @{}
$fixturePaths = @('tests/.generated_wardrobe_smoke_test.json', 'tests/.generated_wardrobe_v14_smoke_test.json', 'tests/.bath_damage_roundtrip.json')
foreach ($relativePath in $fixturePaths) {
    $fixturePath = Join-Path $projectRoot $relativePath
    if (Test-Path -LiteralPath $fixturePath) {
        $preservedTestFiles[$fixturePath] = [IO.File]::ReadAllBytes($fixturePath)
    }
}
try {
    [IO.File]::WriteAllText($overridePath, $testConfig)
    foreach ($testName in $TestNames) {
        $logPath = Join-Path $env:TEMP ($profileName + '_' + $testName + '.log')
        & $GodotPath --headless --path $projectRoot --script ("res://tests/$testName.gd") --quit-after 3000 --log-file $logPath
        if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText($logPath).Contains('SCRIPT ERROR:')) {
            throw "Проверка $testName завершилась с ошибкой. Лог: $logPath"
        }
    }
} finally {
    foreach ($relativePath in $fixturePaths) {
        $fixturePath = Join-Path $projectRoot $relativePath
        if ($preservedTestFiles.ContainsKey($fixturePath)) {
            [IO.File]::WriteAllBytes($fixturePath, $preservedTestFiles[$fixturePath])
        } elseif (Test-Path -LiteralPath $fixturePath) {
            Remove-Item -LiteralPath $fixturePath
        }
    }
    if (Test-Path -LiteralPath $overridePath) {
        Remove-Item -LiteralPath $overridePath
    }
}