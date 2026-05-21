Clear-Host
Write-Host "Fingerx Mod Analyzer" -ForegroundColor Red
Write-Host "Enhanced Class Analyzer v3" -ForegroundColor DarkGray
Write-Host

Write-Host "Enter path to the mods folder: " -NoNewline
Write-Host "(press Enter to use default)" -ForegroundColor DarkGray

$mods = Read-Host "PATH"

if (-not $mods) {
    $mods = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
}

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid mods folder!" -ForegroundColor Red
    exit 1
}

function Get-SHA1 {
    param([string]$filePath)

    try {
        return (Get-FileHash $filePath -Algorithm SHA1).Hash
    }
    catch {
        return $null
    }
}

function Fetch-Modrinth {
    param([string]$hash)

    try {
        $response = Invoke-RestMethod `
            -Uri "https://api.modrinth.com/v2/version_file/$hash" `
            -Method Get `
            -UseBasicParsing `
            -ErrorAction Stop

        if ($response.project_id) {

            $project = Invoke-RestMethod `
                -Uri "https://api.modrinth.com/v2/project/$($response.project_id)" `
                -Method Get `
                -UseBasicParsing `
                -ErrorAction Stop

            return @{
                Name = $project.title
                Slug = $project.slug
            }
        }
    }
    catch {}

    return @{
        Name = ""
        Slug = ""
    }
}

# Высокий риск - явные чит-модули
$highRiskPatterns = @{
    "KillAura" = 10
    "AimAssist" = 10
    "TriggerBot" = 10
    "AutoCrystal" = 10
    "AutoTotem" = 9
    "AntiKnockback" = 9
    "NoFall" = 8
    "XRay" = 10
    "Tracers" = 9
    "ESP" = 9
    "Wallhack" = 10
    "ChestESP" = 9
    "PlayerESP" = 9
    "FastBreak" = 8
    "Nuker" = 9
    "Scaffold" = 8
    "Tower" = 7
    "ChestStealer" = 8
    "InvMove" = 7
    "AutoArmor" = 8
    "Criticals" = 8
    "ClickAura" = 10
    "MultiAura" = 10
    "BowAimbot" = 10
    "AutoClicker" = 7
    "AntiBot" = 7
    "NoSlowdown" = 8
    "NoSlow" = 8
    "Jesus" = 7
    "Blink" = 8
    "Timer" = 7
    "FastPlace" = 7
    "AutoPot" = 8
    "Regen" = 8
    "FlyHack" = 9
    "SpeedHack" = 8
}

# Обфусцированные методы Minecraft (Forge mappings)
$obfuscatedForge = @{
    "func_174826_a" = 6  # getBoundingBox / expand
    "func_226277_ct_" = 6  # getPosX
    "func_174813_aQ" = 6  # getEntityBoundingBox
    "field_72338_b" = 6  # minY
    "func_226281_cx_" = 6  # getPosZ
    "field_72337_e" = 6  # maxZ
}

# Обфусцированные методы Minecraft (Fabric mappings)
$obfuscatedFabric = @{
    "method_5829" = 6  # expand
    "class_238" = 5    # Box class
    "method_23317" = 6 # getX
    "method_23321" = 6 # getZ
    "method_5857" = 6  # getBoundingBox
}

# Обфусцированные методы Minecraft (LabyMod/Proguard)
$obfuscatedLabymod = @{
    ".cD()" = 6
    ".cc().b" = 6
    ".cH()" = 6
    ".cc().e" = 6
}

# Средний риск
$mediumRiskPatterns = @{
    "RotationUtil" = 5
    "MovementUtil" = 4
    "PlayerUtil" = 3
    "RayTraceUtil" = 5
    "RenderUtil" = 3
}

# Низкий риск
$lowRiskPatterns = @{
    "sendPacket" = 2
    "channelRead0" = 2
}

function Analyze-ClassFiles {
    param(
        [string]$extractPath
    )

    $findings = @{}
    $score = 0
    $obfuscationDetected = $false

    $classFiles = Get-ChildItem `
        -Path $extractPath `
        -Recurse `
        -Filter *.class `
        -ErrorAction SilentlyContinue

    foreach ($class in $classFiles) {

        try {

            $bytes = [System.IO.File]::ReadAllBytes($class.FullName)
            $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)

            # Проверка высокого риска
            foreach ($pattern in $highRiskPatterns.Keys) {
                if ($ascii -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = $highRiskPatterns[$pattern]
                        $score += $highRiskPatterns[$pattern]
                    }
                }
            }

            # Проверка обфусцированных методов Forge
            foreach ($pattern in $obfuscatedForge.Keys) {
                if ($ascii -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey("ObfuscatedForge")) {
                        $findings["ObfuscatedForge"] = $obfuscatedForge[$pattern]
                        $score += $obfuscatedForge[$pattern]
                        $obfuscationDetected = $true
                    }
                }
            }

            # Проверка обфусцированных методов Fabric
            foreach ($pattern in $obfuscatedFabric.Keys) {
                if ($ascii -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey("ObfuscatedFabric")) {
                        $findings["ObfuscatedFabric"] = $obfuscatedFabric[$pattern]
                        $score += $obfuscatedFabric[$pattern]
                        $obfuscationDetected = $true
                    }
                }
            }

            # Проверка обфусцированных методов LabyMod
            foreach ($pattern in $obfuscatedLabymod.Keys) {
                if ($ascii -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey("ObfuscatedLabymod")) {
                        $findings["ObfuscatedLabymod"] = $obfuscatedLabymod[$pattern]
                        $score += $obfuscatedLabymod[$pattern]
                        $obfuscationDetected = $true
                    }
                }
            }

            # Проверка среднего риска
            foreach ($pattern in $mediumRiskPatterns.Keys) {
                if ($ascii -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = $mediumRiskPatterns[$pattern]
                        $score += $mediumRiskPatterns[$pattern]
                    }
                }
            }

            # Проверка низкого риска
            foreach ($pattern in $lowRiskPatterns.Keys) {
                if ($ascii -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = $lowRiskPatterns[$pattern]
                        $score += $lowRiskPatterns[$pattern]
                    }
                }
            }
        }
        catch {}
    }

    return @{
        Findings = $findings
        Score = $score
        Obfuscated = $obfuscationDetected
    }
}

function Analyze-Metadata {
    param(
        [string]$extractPath
    )

    $findings = @{}
    $score = 0

    $jsonFiles = Get-ChildItem `
        -Path $extractPath `
        -Recurse `
        -Include "*.json","fabric.mod.json","mods.toml" `
        -ErrorAction SilentlyContinue

    foreach ($json in $jsonFiles) {

        try {

            $content = Get-Content $json.FullName -Raw

            # Проверка высокого риска
            foreach ($pattern in $highRiskPatterns.Keys) {
                if ($content -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = $highRiskPatterns[$pattern]
                        $score += $highRiskPatterns[$pattern]
                    }
                }
            }
        }
        catch {}
    }

    return @{
        Findings = $findings
        Score = $score
    }
}

function Get-ZoneIdentifier {
    param([string]$filePath)

    try {

        $ads = Get-Content `
            -Raw `
            -Stream Zone.Identifier `
            $filePath `
            -ErrorAction SilentlyContinue

        if ($ads -match "HostUrl=(.+)") {
            return $matches[1]
        }
    }
    catch {}

    return $null
}

$verifiedMods = @()
$unknownMods = @()
$suspiciousMods = @()
$highRiskMods = @()

$tempDir = Join-Path $env:TEMP "habibi_analyzer"

if (Test-Path $tempDir) {
    Remove-Item $tempDir -Force -Recurse
}

New-Item `
    -ItemType Directory `
    -Path $tempDir | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem

$jarFiles = Get-ChildItem `
    -Path $mods `
    -Filter *.jar `
    -ErrorAction SilentlyContinue

$total = $jarFiles.Count
$index = 0

foreach ($jar in $jarFiles) {

    $index++

    # Очищаем строку
    Write-Host ("`r" + (" " * 120)) -NoNewline
    
    # Выводим прогресс
    Write-Host "`r[$index/$total] Scanning $($jar.Name)..." `
        -ForegroundColor Yellow `
        -NoNewline

    $hash = Get-SHA1 $jar.FullName

    $modrinth = Fetch-Modrinth $hash

    if ($modrinth.Slug) {

        $verifiedMods += [PSCustomObject]@{
            ModName = $modrinth.Name
            FileName = $jar.Name
        }

        continue
    }

    $extractPath = Join-Path `
        $tempDir `
        ([System.IO.Path]::GetFileNameWithoutExtension($jar.Name))

    try {

        [System.IO.Compression.ZipFile]::ExtractToDirectory(
            $jar.FullName,
            $extractPath
        )

        $classResult = Analyze-ClassFiles $extractPath
        $metaResult = Analyze-Metadata $extractPath

        # Объединяем находки
        $allFindings = @{}
        $totalScore = 0

        foreach ($key in $classResult.Findings.Keys) {
            $allFindings[$key] = $classResult.Findings[$key]
        }

        foreach ($key in $metaResult.Findings.Keys) {
            if (-not $allFindings.ContainsKey($key)) {
                $allFindings[$key] = $metaResult.Findings[$key]
            }
        }

        $totalScore = $classResult.Score + $metaResult.Score

        # Бонус за обфускацию + подозрительные паттерны
        if ($classResult.Obfuscated -and $totalScore -ge 3) {
            $totalScore += 5
        }

        # Классификация по score
        if ($totalScore -ge 15) {
            # Высокий риск
            $highRiskMods += [PSCustomObject]@{
                FileName = $jar.Name
                Detections = ($allFindings.Keys | Sort-Object { $allFindings[$_] } -Descending) -join ", "
                Score = $totalScore
                Obfuscated = $classResult.Obfuscated
            }
        }
        elseif ($totalScore -ge 5) {
            # Подозрительный
            $suspiciousMods += [PSCustomObject]@{
                FileName = $jar.Name
                Detections = ($allFindings.Keys | Sort-Object { $allFindings[$_] } -Descending) -join ", "
                Score = $totalScore
                Obfuscated = $classResult.Obfuscated
            }
        }
        else {
            # Неизвестный (чистый)
            $unknownMods += [PSCustomObject]@{
                FileName = $jar.Name
                ZoneId = Get-ZoneIdentifier $jar.FullName
            }
        }
    }
    catch {
        Write-Host ""
        Write-Host "Failed to analyze $($jar.Name)" `
            -ForegroundColor Red
    }
}

# Очищаем строку прогресса
Write-Host ("`r" + (" " * 120))
Write-Host ""

if ($verifiedMods.Count -gt 0) {

    Write-Host "{ VERIFIED MODS }" `
        -ForegroundColor DarkCyan

    foreach ($mod in $verifiedMods) {

        Write-Host "> " -NoNewline
        Write-Host $mod.ModName `
            -ForegroundColor Green `
            -NoNewline

        Write-Host " ($($mod.FileName))" `
            -ForegroundColor Gray
    }

    Write-Host ""
}

if ($unknownMods.Count -gt 0) {

    Write-Host "{ UNKNOWN MODS (Clean) }" `
        -ForegroundColor DarkGray

    foreach ($mod in $unknownMods) {

        Write-Host "> $($mod.FileName)" `
            -ForegroundColor Gray

        if ($mod.ZoneId) {

            Write-Host "  Source: $($mod.ZoneId)" `
                -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

if ($suspiciousMods.Count -gt 0) {

    Write-Host "{ SUSPICIOUS MODS (Medium Risk) }" `
        -ForegroundColor Yellow

    foreach ($mod in $suspiciousMods) {

        Write-Host "> $($mod.FileName)" `
            -ForegroundColor Yellow

        Write-Host "  Detections: $($mod.Detections)" `
            -ForegroundColor DarkYellow

        Write-Host "  Risk Score: $($mod.Score)" `
            -ForegroundColor DarkYellow

        if ($mod.Obfuscated) {
            Write-Host "  [!] Obfuscated code detected" `
                -ForegroundColor Red
        }

        Write-Host ""
    }
}

if ($highRiskMods.Count -gt 0) {

    Write-Host "{ HIGH RISK MODS (Likely Cheat) }" `
        -ForegroundColor Red

    foreach ($mod in $highRiskMods) {

        Write-Host "> $($mod.FileName)" `
            -ForegroundColor Red

        Write-Host "  Detections: $($mod.Detections)" `
            -ForegroundColor Magenta

        Write-Host "  Risk Score: $($mod.Score)" `
            -ForegroundColor Magenta

        if ($mod.Obfuscated) {
            Write-Host "  [!] OBFUSCATED CODE DETECTED" `
                -ForegroundColor Red
        }

        Write-Host ""
    }
}

try {
    Remove-Item `
        $tempDir `
        -Force `
        -Recurse
}
catch {}

Write-Host "Scan complete." -ForegroundColor Green
Write-Host ""

pause