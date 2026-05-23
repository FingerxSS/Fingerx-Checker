[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Clear-Host
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║     Fingerx Mod Analyzer Ultimate v2.0 Enhanced      ║" -ForegroundColor Red
Write-Host "║          Advanced ML-Ready Cheat Detection           ║" -ForegroundColor DarkGray
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host

Write-Host "Enter path to the mods folder: " -NoNewline
Write-Host "(press Enter to use default)" -ForegroundColor DarkGray

$mods = Read-Host "PATH"

if (-not $mods) {
    $mods = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
}

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid mods folder!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# ==================== CONFIGURATION ====================

$Config = @{
    MaxFileSize = 100MB
    ReadBufferSize = 131072  # 128KB вместо 64KB
    EntropyThreshold = 7.2
    MinClassCountForStats = 5
    ConcurrentLimit = 4
}

# ==================== CORE UTILITIES ====================

function Get-SHA1 {
    param([string]$filePath)
    try {
        return (Get-FileHash $filePath -Algorithm SHA1).Hash
    }
    catch {
        return $null
    }
}

function Get-Entropy {
    param([byte[]]$Bytes)

    if (-not $Bytes -or $Bytes.Length -eq 0) { return 0 }

    $map = @{}
    foreach ($b in $Bytes) {
        if ($map.ContainsKey($b)) {
            $map[$b]++
        }
        else {
            $map[$b] = 1
        }
    }

    $entropy = 0.0
    $length = $Bytes.Length

    foreach ($v in $map.Values) {
        $p = $v / $length
        $entropy -= $p * [Math]::Log($p, 2)
    }

    return $entropy
}

# ==================== API INTEGRATIONS ====================

function Fetch-Modrinth {
    param([string]$hash)
    try {
        $response = Invoke-RestMethod `
            -Uri "https://api.modrinth.com/v2/version_file/$hash" `
            -Method Get `
            -TimeoutSec 5 `
            -UseBasicParsing `
            -ErrorAction Stop

        if ($response.project_id) {
            $project = Invoke-RestMethod `
                -Uri "https://api.modrinth.com/v2/project/$($response.project_id)" `
                -Method Get `
                -TimeoutSec 5 `
                -UseBasicParsing `
                -ErrorAction Stop

            return @{
                Name = $project.title
                Slug = $project.slug
                Verified = $true
            }
        }
    }
    catch {}

    return @{ Verified = $false }
}

function Query-Megabase {
    param([string]$Hash)
    try {
        $result = Invoke-RestMethod `
            -Uri "https://megabase.vercel.app/api/query?hash=$Hash" `
            -Method Get `
            -TimeoutSec 5 `
            -UseBasicParsing `
            -ErrorAction Stop
        
        if (-not $result.error) { 
            return @{
                Name = $result.data.name
                Verified = $true
            }
        }
    } catch { }
    
    return @{ Verified = $false }
}

# ==================== PATTERN DATABASES ====================

$HighRiskPatterns = @{
    # Exact word boundaries to reduce false positives
    '\bKillAura\b'      = 10
    '\bAimAssist\b'     = 10
    '\bTriggerBot\b'    = 10
    '\bAutoCrystal\b'   = 10
    '\bAutoTotem\b'     = 9
    '\bAntiKnockback\b' = 9
    '\bAntiKB\b'        = 9
    '\bNoFall\b'        = 8
    '\bXRay\b'          = 10
    '\bTracers\b'       = 9
    '\bChestESP\b'      = 9
    '\bPlayerESP\b'     = 9
    '\bEntityESP\b'     = 9
    '\bMobESP\b'        = 9
    '\bItemESP\b'       = 8
    '\bNameESP\b'       = 8
    '\bBoxESP\b'        = 9
    '\bSkeletonESP\b'   = 9
    '\bFastBreak\b'     = 8
    '\bNuker\b'         = 9
    '\bScaffold\b'      = 8
    '\bTower\b'         = 7
    '\bChestStealer\b'  = 8
    '\bInvMove\b'       = 7
    '\bAutoArmor\b'     = 8
    '\bCriticals\b'     = 8
    '\bClickAura\b'     = 10
    '\bMultiAura\b'     = 10
    '\bBowAimbot\b'     = 10
    '\bAutoClicker\b'   = 7
    '\bAntiBot\b'       = 7
    '\bNoSlowdown\b'    = 8
    '\bNoSlow\b'        = 8
    '\bBlink\b'         = 8
    '\bFastPlace\b'     = 7
    '\bAutoPot\b'       = 8
    '\bRegen\b'         = 8
    '\bFlyHack\b'       = 9
    '\bSpeedHack\b'     = 8
    '\bAutoAnchor\b'    = 9
    '\bAnchorAura\b'    = 9
    '\bCrystalAura\b'   = 10
    '\bBedAura\b'       = 9
    '\bReachHack\b'     = 9
    '\bHitboxExpand\b'  = 9
    '\bSilentAim\b'     = 10
    '\bAimLock\b'       = 10
    '\bHeadSnap\b'      = 10
    '\bForceField\b'    = 10
    '\bLegitAura\b'     = 8
}

$SuspiciousPatterns = @{
    '\bAimAssist\b'          = 8
    '\bAnchorTweaks\b'       = 7
    '\bAutoDoubleHand\b'     = 7
    '\bAutoHitCrystal\b'     = 9
    '\bInventoryTotem\b'     = 6
    '\bJumpReset\b'          = 6
    '\bLegitTotem\b'         = 5
    '\bPingSpoof\b'          = 8
    '\bSelfDestruct\b'       = 9
    '\bShieldBreaker\b'      = 7
    '\bAxeSpam\b'            = 6
    '\bWebMacro\b'           = 6
    '\bWalskyOptimizer\b'    = 8
    '\bWalksyOptimizer\b'    = 8
    'walsky\.optimizer'      = 8
    '\bDonut\b'              = 7
    '\bShieldDisabler\b'     = 8
    '\bTotem\s+Hit\b'        = 7
    '\bWtap\b'               = 6
    '\bFakeLag\b'            = 8
    '\bBlockESP\b'           = 8
    'dev\.krypton'           = 9
    '\bAntiMissClick\b'      = 6
    '\bLagReach\b'           = 8
    '\bPopSwitch\b'          = 7
    '\bSprintReset\b'        = 6
    '\bChestSteal\b'         = 7
    '\bElytraSwap\b'         = 6
    '\bFastXP\b'             = 6
    '\bFastExp\b'            = 6
    '\bRefill\b'             = 5
    '\bAirAnchor\b'          = 8
    'jnativehook'            = 7
    '\bFakeInv\b'            = 7
    '\bHoverTotem\b'         = 7
    '\bAutoFirework\b'       = 7
    '\bPackSpoof\b'          = 8
    'catlean'                = 9
    '\bArgon\b'              = 8
    '\bAuthBypass\b'         = 10
    '\bAsteria\b'            = 8
    '\bPrestige\b'           = 7
    '\bAutoEat\b'            = 6
    '\bAutoMine\b'           = 7
    '\bMaceSwap\b'           = 6
    '\bDoubleAnchor\b'       = 8
    '\bAutoTPA\b'            = 7
    '\bBaseFinder\b'         = 8
    '\bXenon\b'              = 8
    'gypsy'                  = 8
    '\bGrim\b'               = 7
    'imgui\.gl3'             = 9
    'imgui\.glfw'            = 9
    '\bFakenick\b'           = 7
    '\bFakeItem\b'           = 7
    'invsee'                 = 6
    '\bItemExploit\b'        = 8
    '\bHellion\b'            = 8
    'LicenseCheckMixin'      = 7
    'ClientPlayerInteractionManagerAccessor' = 7
    'ClientPlayerEntityMixim' = 7
    'dev\.gambleclient'      = 9
    'obfuscatedAuth'         = 8
    'phantom-refmap\.json'   = 8
    'xyz\.greaj'             = 9
}

$ObfuscationPatterns = @{
    Forge = @{
        'func_174826_a'   = 6
        'func_226277_ct_' = 6
        'func_174813_aQ'  = 6
        'field_72338_b'   = 6
        'func_226281_cx_' = 6
        'field_72337_e'   = 6
    }
    Fabric = @{
        'method_5829'  = 6
        'class_238'    = 5
        'method_23317' = 6
        'method_23321' = 6
        'method_5857'  = 6
    }
    LabyMod = @{
        '\.cD\(\)'   = 6
        '\.cc\(\)\.b' = 6
        '\.cH\(\)'   = 6
        '\.cc\(\)\.e' = 6
    }
}

$CryptoPatterns = @{
    'java/util/Base64'       = 1
    'javax/crypto/Cipher'    = 2
    'javax/crypto/spec'      = 2
    'SecretKeySpec'          = 5
    '\bSecretKey\b'          = 4
    'getDecoder\(\)'         = 3
    'AESEncrypt'             = 6
    'DESEncrypt'             = 6
    'AESDecrypt'             = 6
    'CipherInputStream'      = 4
    'CipherOutputStream'     = 4
    'decryptData'            = 5
    'encryptData'            = 4
}

$UtilityPatterns = @{
    'RotationUtil'  = 2
    'MovementUtil'  = 2
    'PlayerUtil'    = 1
    'RayTraceUtil'  = 2
    'RenderUtil'    = 3
    'sendPacket'    = 1
    'channelRead0'  = 1
}

$KnownCheatClients = @{
    'meteordevelopment'           = 10
    'cc/novoline'                 = 10
    'com/alan/clients'            = 10
    'club/maxstats'               = 10
    'wtf/moonlight'               = 10
    'me/zeroeightsix/kami'        = 10
    'net/ccbluex'                 = 10
    'today/opai'                  = 10
    'org/chainlibs/module'        = 10
    'doomsdayclient'              = 10
    'novaclient'                  = 10
    'vape\.gg'                    = 10
    'liquidbounce'                = 10
    'fdp-client'                  = 10
    'rusherhack'                  = 10
    'futureClient'                = 10
    'konas'                       = 10
    'wurst'                       = 10
    'impact'                      = 10
    'sigma'                       = 10
}

$CheatObfuscators = @{
    'Skidfuscator'   = @('dev/skidfuscator', 'Skidfuscator', 'skidfuscator\.dev')
    'Paramorphism'   = @('Paramorphism', 'paramorphism-', 'dev/paramorphism')
    'Radon'          = @('ItzSomebody/Radon', 'me/itzsomebody/radon', 'Radon Obfuscator')
    'Caesium'        = @('sim0n/Caesium', 'Caesium Obfuscator', 'dev/sim0n/caesium')
    'Bozar'          = @('vimasig/Bozar', 'Bozar Obfuscator', 'com/bozar')
    'Branchlock'     = @('Branchlock', 'branchlock\.dev')
    'Binscure'       = @('Binscure', 'com/binscure')
    'Qprotect'       = @('Qprotect', 'QProtect', 'mdma\.dev/qprotect')
    'Zelix'          = @('ZKMFLOW', '\bZKM\b', 'ZelixKlassMaster', 'com/zelix')
    'Stringer'       = @('StringerJavaObfuscator', 'com/licel/stringer')
    'Allatori'       = @('Allatori', 'allatori')
    'ProGuard'       = @('a/a/a/a', 'b/b/b/b', 'c/c/c/c')
    'JNIC'           = @('JNIC', 'jnic\.obf')
}

# Fullwidth Unicode patterns (used for obfuscation bypass)
$FullwidthPatterns = @(
    'ＡｕｔｏＣｒｙｓｔａｌ', 'Ａｕｔｏ Ｃｒｙｓｔａｌ',
    'ＡｕｔｏＨｉｔＣｒｙｓｔａｌ',
    'ＡｕｔｏＡｎｃｈｏｒ', 'Ａｕｔｏ Ａｎｃｈｏｒ',
    'ＤｏｕｂｌｅＡｎｃｈｏｒ', 'Ｄｏｕｂｌｅ Ａｎｃｈｏｒ',
    'ＳａｆｅＡｎｃｈｏｒ', 'Ｓａｆｅ Ａｎｃｈｏｒ',
    'ＡｕｔｏＴｏｔｅｍ', 'Ａｕｔｏ Ｔｏｔｅｍ',
    'ＨｏｖｅｒＴｏｔｅｍ', 'Ｈｏｖｅｒ Ｔｏｔｅｍ'
)

# Japanese class names (common obfuscation technique)
$JapaneseClassPatterns = @(
    'じ\.class', 'ふ\.class', 'ぶ\.class', 'ぷ\.class', 'た\.class',
    'ね\.class', 'そ\.class', 'な\.class', 'ど\.class', 'ぐ\.class',
    'ず\.class', 'で\.class', 'つ\.class', 'べ\.class', 'せ\.class'
)

# Compiled Regex patterns for performance
$CompiledRegex = @{
    Fullwidth = [regex]::new('[\uFF21-\uFF3A\uFF41-\uFF5A\uFF10-\uFF19]{2,}', 'Compiled')
    Base64 = [regex]::new('(?:[A-Za-z0-9+/]{4}){20,}(?:==|=)?', 'Compiled')
    URL = [regex]::new('(https?://[^\s"<>]+)', 'Compiled')
    Japanese = [regex]::new('[\u3040-\u309F\u30A0-\u30FF]{2,}', 'Compiled')
}

# HashSets for O(1) lookups
$FoundPatterns = [System.Collections.Generic.HashSet[string]]::new()
$FoundFullwidth = [System.Collections.Generic.HashSet[string]]::new()
$FoundURLs = [System.Collections.Generic.HashSet[string]]::new()

# ==================== ANALYSIS FUNCTIONS ====================

function Analyze-ClassContent {
    param(
        [byte[]]$Bytes,
        [ref]$Findings,
        [ref]$Score,
        [ref]$ObfuscationDetected,
        [ref]$Features
    )

    # Convert bytes to text representations
    $latin1Text = [System.Text.Encoding]::Latin1.GetString($Bytes)
    $utf8Text = [System.Text.Encoding]::UTF8.GetString($Bytes)

    # ========== ENTROPY ANALYSIS ==========
    $entropy = Get-Entropy $Bytes
    if ($entropy -gt $Config.EntropyThreshold) {
        if (-not $Findings.Value.ContainsKey('HighEntropy')) {
            $Findings.Value['HighEntropy'] = 8
            $Score.Value += 8
        }
        $Features.Value.HighEntropy = $true
        $Features.Value.EntropyValue = $entropy
    }

    # ========== URL EXTRACTION ==========
    $urlMatches = $CompiledRegex.URL.Matches($latin1Text)
    foreach ($match in $urlMatches) {
        $url = $match.Value
        
        if ($url -match '(discord\.com/api/webhooks|pastebin\.com|ngrok\.io|duckdns\.org)') {
            if (-not $Findings.Value.ContainsKey('SuspiciousURL')) {
                $Findings.Value['SuspiciousURL'] = 12
                $Score.Value += 12
            }
            [void]$FoundURLs.Add($url)
            $Features.Value.SuspiciousURLs++
        }
    }

    # ========== HIGH RISK PATTERNS ==========
    foreach ($pattern in $HighRiskPatterns.Keys) {
        if ($latin1Text -match $pattern) {
            $patternName = $pattern -replace '\\b', ''
            if (-not $Findings.Value.ContainsKey($patternName)) {
                $Findings.Value[$patternName] = $HighRiskPatterns[$pattern]
                $Score.Value += $HighRiskPatterns[$pattern]
            }
            $Features.Value.HighRiskPatterns++
        }
    }

    # ========== SUSPICIOUS PATTERNS ==========
    foreach ($pattern in $SuspiciousPatterns.Keys) {
        if ($latin1Text -match $pattern) {
            $patternName = $pattern -replace '\\b', ''
            if (-not $Findings.Value.ContainsKey($patternName)) {
                $Findings.Value[$patternName] = $SuspiciousPatterns[$pattern]
                $Score.Value += $SuspiciousPatterns[$pattern]
            }
            $Features.Value.SuspiciousPatterns++
        }
    }

    # ========== KNOWN CHEAT CLIENTS ==========
    foreach ($client in $KnownCheatClients.Keys) {
        if ($latin1Text -match $client) {
            $clientName = "CheatClient:$client"
            if (-not $Findings.Value.ContainsKey($clientName)) {
                $Findings.Value[$clientName] = $KnownCheatClients[$client]
                $Score.Value += $KnownCheatClients[$client]
            }
            $Features.Value.KnownCheatClient = $true
        }
    }

    # ========== OBFUSCATION DETECTION ==========
    foreach ($loaderType in $ObfuscationPatterns.Keys) {
        foreach ($pattern in $ObfuscationPatterns[$loaderType].Keys) {
            if ($latin1Text -match $pattern) {
                $obfName = "Obfuscated$loaderType"
                if (-not $Findings.Value.ContainsKey($obfName)) {
                    $Findings.Value[$obfName] = $ObfuscationPatterns[$loaderType][$pattern]
                    $Score.Value += $ObfuscationPatterns[$loaderType][$pattern]
                    $ObfuscationDetected.Value = $true
                }
                $Features.Value.ObfuscationLevel++
            }
        }
    }

    # ========== CHEAT OBFUSCATORS ==========
    foreach ($obfName in $CheatObfuscators.Keys) {
        foreach ($pattern in $CheatObfuscators[$obfName]) {
            if ($latin1Text -match $pattern) {
                $findingName = "CheatObfuscator:$obfName"
                if (-not $Findings.Value.ContainsKey($findingName)) {
                    $Findings.Value[$findingName] = 10
                    $Score.Value += 10
                    $ObfuscationDetected.Value = $true
                }
                $Features.Value.CheatObfuscator = $true
            }
        }
    }

    # ========== CRYPTO PATTERNS ==========
    $cryptoCount = 0
    foreach ($pattern in $CryptoPatterns.Keys) {
        if ($latin1Text -match $pattern) {
            $patternName = $pattern -replace '\\b', ''
            if (-not $Findings.Value.ContainsKey($patternName)) {
                $Findings.Value[$patternName] = $CryptoPatterns[$pattern]
                $Score.Value += $CryptoPatterns[$pattern]
            }
            $cryptoCount++
        }
    }
    $Features.Value.CryptoUsage = $cryptoCount

    # ========== BASE64 DETECTION ==========
    $base64Matches = $CompiledRegex.Base64.Matches($latin1Text)
    if ($base64Matches.Count -gt 0) {
        foreach ($match in $base64Matches) {
            try {
                [void][System.Convert]::FromBase64String($match.Value)
                if (-not $Findings.Value.ContainsKey('EmbeddedBase64')) {
                    $Findings.Value['EmbeddedBase64'] = 7
                    $Score.Value += 7
                }
                $Features.Value.Base64Strings++
                break
            }
            catch {}
        }
    }

    # ========== FULLWIDTH UNICODE ==========
    $fullwidthMatches = $CompiledRegex.Fullwidth.Matches($utf8Text)
    foreach ($match in $fullwidthMatches) {
        [void]$FoundFullwidth.Add($match.Value)
        $Features.Value.FullwidthChars++
    }

    foreach ($pattern in $FullwidthPatterns) {
        if ($utf8Text -match [regex]::Escape($pattern)) {
            if (-not $Findings.Value.ContainsKey('FullwidthCheatString')) {
                $Findings.Value['FullwidthCheatString'] = 9
                $Score.Value += 9
            }
        }
    }

    # ========== JAPANESE CLASS NAMES ==========
    $japaneseMatches = $CompiledRegex.Japanese.Matches($utf8Text)
    if ($japaneseMatches.Count -gt 0) {
        if (-not $Findings.Value.ContainsKey('JapaneseObfuscation')) {
            $Findings.Value['JapaneseObfuscation'] = 8
            $Score.Value += 8
        }
        $Features.Value.JapaneseChars = $japaneseMatches.Count
    }

    # ========== UTILITY PATTERNS (Lower Weight) ==========
    foreach ($pattern in $UtilityPatterns.Keys) {
        if ($latin1Text -match $pattern) {
            $patternName = $pattern -replace '\\b', ''
            if (-not $Findings.Value.ContainsKey($patternName)) {
                $Findings.Value[$patternName] = $UtilityPatterns[$pattern]
                $Score.Value += $UtilityPatterns[$pattern]
            }
        }
    }
}

function Analyze-ClassFiles {
    param([string]$extractPath)

    $findings = @{}
    $score = 0
    $obfuscationDetected = $false
    
    # Feature vector for ML-ready analysis
    $features = @{
        HighEntropy = $false
        EntropyValue = 0.0
        HighRiskPatterns = 0
        SuspiciousPatterns = 0
        SuspiciousURLs = 0
        ObfuscationLevel = 0
        CryptoUsage = 0
        Base64Strings = 0
        FullwidthChars = 0
        JapaneseChars = 0
        KnownCheatClient = $false
        CheatObfuscator = $false
        ClassCount = 0
        NumericClassRatio = 0.0
        SingleLetterRatio = 0.0
    }

    $classFiles = Get-ChildItem `
        -Path $extractPath `
        -Recurse `
        -Filter *.class `
        -ErrorAction SilentlyContinue

    $features.ClassCount = $classFiles.Count

    foreach ($class in $classFiles) {
        try {
            $fileSize = (Get-Item $class.FullName).Length
            if ($fileSize -gt $Config.MaxFileSize) {
                continue
            }

            $stream = [System.IO.File]::OpenRead($class.FullName)
            $buffer = New-Object byte[] $Config.ReadBufferSize
            $read = $stream.Read($buffer, 0, $buffer.Length)
            $stream.Close()

            if ($read -eq 0) { continue }

            $bytes = $buffer[0..($read-1)]

            Analyze-ClassContent `
                -Bytes $bytes `
                -Findings ([ref]$findings) `
                -Score ([ref]$score) `
                -ObfuscationDetected ([ref]$obfuscationDetected) `
                -Features ([ref]$features)
        }
        catch {
            # Silently skip unreadable class files
        }
    }

    return @{
        Findings = $findings
        Score = $score
        Obfuscated = $obfuscationDetected
        Features = $features
    }
}

function Analyze-NestedJars {
    param(
        [string]$extractPath,
        [string]$tempDir
    )

    $nestedJars = Get-ChildItem `
        -Path $extractPath `
        -Recurse `
        -Filter *.jar `
        -ErrorAction SilentlyContinue

    $nestedFindings = @{}
    $nestedScore = 0
    $nestedObfuscated = $false
    $nestedFeatures = @{
        HighRiskPatterns = 0
        SuspiciousPatterns = 0
        ObfuscationLevel = 0
    }

    foreach ($nested in $nestedJars) {
        $nestedExtract = Join-Path $tempDir ("nested_" + [Guid]::NewGuid().ToString("N"))

        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory(
                $nested.FullName,
                $nestedExtract
            )

            $result = Analyze-ClassFiles $nestedExtract

            foreach ($key in $result.Findings.Keys) {
                if (-not $nestedFindings.ContainsKey($key)) {
                    $nestedFindings[$key] = $result.Findings[$key]
                    $nestedScore += $result.Findings[$key]
                }
            }

            if ($result.Obfuscated) {
                $nestedObfuscated = $true
            }

            $nestedFeatures.HighRiskPatterns += $result.Features.HighRiskPatterns
            $nestedFeatures.SuspiciousPatterns += $result.Features.SuspiciousPatterns
            $nestedFeatures.ObfuscationLevel += $result.Features.ObfuscationLevel

            # Cleanup
            Remove-Item $nestedExtract -Force -Recurse -ErrorAction SilentlyContinue
        }
        catch {}
    }

    return @{
        Findings = $nestedFindings
        Score = $nestedScore
        Obfuscated = $nestedObfuscated
        Features = $nestedFeatures
    }
}

function Analyze-Metadata {
    param([string]$extractPath)

    $findings = @{}
    $score = 0

    $metadataFiles = Get-ChildItem `
        -Path $extractPath `
        -Recurse `
        -Include "*.json","fabric.mod.json","mods.toml","mcmod.info" `
        -ErrorAction SilentlyContinue

    foreach ($file in $metadataFiles) {
        try {
            $content = Get-Content $file.FullName -Raw -Encoding UTF8

            foreach ($pattern in $HighRiskPatterns.Keys) {
                if ($content -match $pattern) {
                    $patternName = $pattern -replace '\\b', ''
                    if (-not $findings.ContainsKey($patternName)) {
                        $findings[$patternName] = $HighRiskPatterns[$pattern]
                        $score += $HighRiskPatterns[$pattern]
                    }
                }
            }

            foreach ($pattern in $SuspiciousPatterns.Keys) {
                if ($content -match $pattern) {
                    $patternName = $pattern -replace '\\b', ''
                    if (-not $findings.ContainsKey($patternName)) {
                        $findings[$patternName] = $SuspiciousPatterns[$pattern]
                        $score += $SuspiciousPatterns[$pattern]
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

function Analyze-ObfuscationLevel {
    param([string]$FilePath)

    $obfFlags = @()
    $obfScore = 0

    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($FilePath)

        $totalClass = 0
        $numericCount = 0
        $unicodeCount = 0
        $fullwidthCount = 0
        $japaneseCount = 0
        $singleLetterCount = 0

        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -match '\.class$') {
                $totalClass++
                $pathParts = $entry.FullName -split '/'
                $className = [System.IO.Path]::GetFileNameWithoutExtension($pathParts[-1])

                if ($className -match '^\d+$') { $numericCount++ }
                if ($className -match '[^\x00-\x7F]') { $unicodeCount++ }
                if ($className -match '[\uFF21-\uFF3A\uFF41-\uFF5A\uFF10-\uFF19]') { $fullwidthCount++ }
                if ($className -match '[\u3040-\u309F\u30A0-\u30FF]') { $japaneseCount++ }
                if ($className -match '^[a-zA-Z]$') { $singleLetterCount++ }
            }
        }

        $archive.Dispose()

        if ($totalClass -ge $Config.MinClassCountForStats) {
            $numPct = [math]::Round(($numericCount / $totalClass) * 100, 2)
            $uniPct = [math]::Round(($unicodeCount / $totalClass) * 100, 2)
            $fwPct = [math]::Round(($fullwidthCount / $totalClass) * 100, 2)
            $jpPct = [math]::Round(($japaneseCount / $totalClass) * 100, 2)
            $slPct = [math]::Round(($singleLetterCount / $totalClass) * 100, 2)

            if ($numPct -ge 25) {
                $obfFlags += "NumericClasses:$numPct%"
                $obfScore += 8
            }
            if ($uniPct -ge 15) {
                $obfFlags += "UnicodeClasses:$uniPct%"
                $obfScore += 7
            }
            if ($fwPct -gt 0) {
                $obfFlags += "FullwidthClasses:$fwPct%"
                $obfScore += 10
            }
            if ($jpPct -gt 0) {
                $obfFlags += "JapaneseClasses:$jpPct%"
                $obfScore += 10
            }
            if ($slPct -ge 20) {
                $obfFlags += "SingleLetterClasses:$slPct%"
                $obfScore += 6
            }
        }
    }
    catch {}

    return @{
        Flags = $obfFlags
        Score = $obfScore
    }
}

function Analyze-BypassTechniques {
    param([string]$FilePath)

    $bypassFlags = @()
    $bypassScore = 0

    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($FilePath)

        $nestedJars = @($zip.Entries | Where-Object { $_.FullName -match '^META-INF/jars/.+\.jar$' })
        $outerClasses = @($zip.Entries | Where-Object { $_.FullName -match '\.class$' -and $_.FullName -notmatch '^META-INF/' })

        # Hollow Shell Detection
        if ($nestedJars.Count -ge 1 -and $outerClasses.Count -lt 5) {
            $bypassFlags += 'HollowShell'
            $bypassScore += 12
        }

        # Suspicious nested JAR names
        foreach ($nj in $nestedJars) {
            $njName = [System.IO.Path]::GetFileName($nj.FullName)
            if ($njName -match '^[a-z]{1,3}\.jar$' -or $njName -notmatch '\d') {
                $bypassFlags += "SuspiciousNestedJAR:$njName"
                $bypassScore += 8
            }
        }

        # Deep scan for dangerous API calls
        $allEntries = [System.Collections.Generic.List[object]]::new()
        foreach ($e in $zip.Entries) { [void]$allEntries.Add($e) }

        $innerZips = [System.Collections.Generic.List[object]]::new()
        foreach ($nj in $nestedJars) {
            try {
                $stream = $nj.Open()
                $memStream = New-Object System.IO.MemoryStream
                $stream.CopyTo($memStream)
                $stream.Close()
                $memStream.Position = 0
                
                $innerZip = [System.IO.Compression.ZipArchive]::new($memStream, [System.IO.Compression.ZipArchiveMode]::Read)
                [void]$innerZips.Add($innerZip)
                
                foreach ($ie in $innerZip.Entries) { 
                    [void]$allEntries.Add($ie) 
                }
            }
            catch {}
        }

        $runtimeExec = $false
        $httpDownload = $false
        $httpExfil = $false
        $processBuilder = $false
        $nativeLoad = $false

        foreach ($entry in $allEntries) {
            if ($entry.FullName -match '\.class$') {
                try {
                    $entryStream = $entry.Open()
                    $ms = New-Object System.IO.MemoryStream
                    $entryStream.CopyTo($ms)
                    $entryStream.Close()
                    
                    $classBytes = $ms.ToArray()
                    $ms.Dispose()
                    
                    $classText = [System.Text.Encoding]::ASCII.GetString($classBytes)

                    if ($classText -match 'java/lang/Runtime' -and $classText -match 'getRuntime' -and $classText -match 'exec') {
                        $runtimeExec = $true
                    }

                    if ($classText -match 'java/lang/ProcessBuilder') {
                        $processBuilder = $true
                    }

                    if ($classText -match 'System.*loadLibrary' -or $classText -match 'System.*load\b') {
                        $nativeLoad = $true
                    }

                    if ($classText -match 'HttpURLConnection' -and $classText -match 'FileOutputStream') {
                        $httpDownload = $true
                    }

                    if ($classText -match 'setDoOutput' -and $classText -match 'getOutputStream' -and $classText -match 'connect') {
                        $httpExfil = $true
                    }
                }
                catch {}
            }
        }

        foreach ($iz in $innerZips) { 
            try { $iz.Dispose() } catch {} 
        }
        $zip.Dispose()

        if ($runtimeExec) {
            $bypassFlags += 'Runtime.exec()'
            $bypassScore += 15
        }
        if ($processBuilder) {
            $bypassFlags += 'ProcessBuilder'
            $bypassScore += 15
        }
        if ($nativeLoad) {
            $bypassFlags += 'NativeLibraryLoad'
            $bypassScore += 3
        }
        if ($httpDownload) {
            $bypassFlags += 'HTTPDownload'
            $bypassScore += 12
        }
        if ($httpExfil) {
            $bypassFlags += 'HTTPExfiltration'
            $bypassScore += 15
        }
    }
    catch {}

    return @{
        Flags = $bypassFlags
        Score = $bypassScore
    }
}

function Invoke-JvmScan {
    $jvmFlags = @()
    $jvmScore = 0

    $javaProc = Get-Process javaw -ErrorAction SilentlyContinue
    if (-not $javaProc) { 
        $javaProc = Get-Process java -ErrorAction SilentlyContinue 
    }
    
    if (-not $javaProc) { 
        return @{ Flags = $jvmFlags; Score = $jvmScore } 
    }

    $javaPid = ($javaProc | Select-Object -First 1).Id

    try {
        $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $javaPid" -ErrorAction Stop
        $cmdLine = $wmi.CommandLine

        if ($cmdLine) {
            # Java Agents Detection
            $agentMatches = [regex]::Matches($cmdLine, '-javaagent:([^\s"]+)')
            foreach ($match in $agentMatches) {
                $agentPath = $match.Groups[1].Value.Trim('"').Trim("'")
                $agentName = [System.IO.Path]::GetFileName($agentPath)
                
                $legitAgents = @('jmxremote','yjp','jrebel','newrelic','jacoco','theseus','lombok','aspectjweaver')
                $isLegit = $false
                
                foreach ($la in $legitAgents) { 
                    if ($agentName -match $la) { 
                        $isLegit = $true
                        break 
                    } 
                }
                
                if (-not $isLegit) {
                    $jvmFlags += "JavaAgent:$agentName"
                    $jvmScore += 12
                }
            }

            # Dangerous JVM flags
            if ($cmdLine -match '-Xbootclasspath/p:') {
                $jvmFlags += 'BootClasspathPrepend'
                $jvmScore += 10
            }
            if ($cmdLine -match '-Xbootclasspath/a:') {
                $jvmFlags += 'BootClasspathAppend'
                $jvmScore += 10
            }
            if ($cmdLine -match '-agentlib:jdwp') {
                $jvmFlags += 'JDWPDebugAgent'
                $jvmScore += 8
            }
            if ($cmdLine -match '-agentpath:') {
                $jvmFlags += 'NativeAgent'
                $jvmScore += 12
            }
            if ($cmdLine -match '-XX:\+DisableAttachMechanism') {
                $jvmFlags += 'AttachDisabled'
                $jvmScore += 7
            }
        }
    }
    catch {}

    return @{
        Flags = $jvmFlags
        Score = $jvmScore
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

        if ($ads -match 'HostUrl=(.+)') {
            return $Matches[1]
        }
        if ($ads -match 'ReferrerUrl=(.+)') {
            return $Matches[1]
        }
    }
    catch {}

    return $null
}

# ==================== MAIN ANALYSIS ====================

$verifiedMods = @()
$unknownMods = @()
$suspiciousMods = @()
$highRiskMods = @()
$criticalMods = @()

$tempDir = Join-Path $env:TEMP "fingerx_analyzer_v2"

if (Test-Path $tempDir) {
    Remove-Item $tempDir -Force -Recurse -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $tempDir | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem

$jarFiles = Get-ChildItem `
    -Path $mods `
    -Filter *.jar `
    -ErrorAction SilentlyContinue

$total = $jarFiles.Count
$index = 0

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          PHASE 1: Hash Verification                  ║" -ForegroundColor Cyan
Write-Host "║          (Modrinth + Megabase)                        ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

foreach ($jar in $jarFiles) {
    $index++

    Write-Host ("`r" + (" " * 120)) -NoNewline
    Write-Host "`r[$index/$total] Verifying $($jar.Name)..." `
        -ForegroundColor Yellow `
        -NoNewline

    $hash = Get-SHA1 $jar.FullName
    
    if ($hash) {
        $modrinth = Fetch-Modrinth $hash
        if ($modrinth.Verified) {
            $verifiedMods += [PSCustomObject]@{
                ModName = $modrinth.Name
                FileName = $jar.Name
                Source = 'Modrinth'
            }
            continue
        }

        $megabase = Query-Megabase $hash
        if ($megabase.Verified) {
            $verifiedMods += [PSCustomObject]@{
                ModName = $megabase.Name
                FileName = $jar.Name
                Source = 'Megabase'
            }
            continue
        }
    }
}

Write-Host ("`r" + (" " * 120))
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          PHASE 2: Deep Pattern Analysis              ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$index = 0

foreach ($jar in $jarFiles) {
    $index++

    # Skip verified mods
    if ($verifiedMods | Where-Object { $_.FileName -eq $jar.Name }) {
        continue
    }

    Write-Host ("`r" + (" " * 120)) -NoNewline
    Write-Host "`r[$index/$total] Deep scanning $($jar.Name)..." `
        -ForegroundColor Yellow `
        -NoNewline

    $extractPath = Join-Path $tempDir ([Guid]::NewGuid().ToString("N"))

    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory(
            $jar.FullName,
            $extractPath
        )

        # Clear HashSets for this mod
        $FoundPatterns.Clear()
        $FoundFullwidth.Clear()
        $FoundURLs.Clear()

        $classResult = Analyze-ClassFiles $extractPath
        $metaResult = Analyze-Metadata $extractPath
        $nestedResult = Analyze-NestedJars $extractPath $tempDir
        $bypassResult = Analyze-BypassTechniques $jar.FullName
        $obfResult = Analyze-ObfuscationLevel $jar.FullName

        # Merge findings
        $allFindings = @{}
        foreach ($key in $classResult.Findings.Keys) {
            $allFindings[$key] = $classResult.Findings[$key]
        }
        foreach ($key in $metaResult.Findings.Keys) {
            if (-not $allFindings.ContainsKey($key)) {
                $allFindings[$key] = $metaResult.Findings[$key]
            }
        }
        foreach ($key in $nestedResult.Findings.Keys) {
            if (-not $allFindings.ContainsKey($key)) {
                $allFindings[$key] = $nestedResult.Findings[$key]
            }
        }

        # Calculate total score
        $totalScore = $classResult.Score + $metaResult.Score + $nestedResult.Score + 
                      $bypassResult.Score + $obfResult.Score

        $isObfuscated = $classResult.Obfuscated -or $nestedResult.Obfuscated

        # Advanced scoring bonuses
        if ($allFindings.ContainsKey('EmbeddedBase64') -and $isObfuscated) {
            $totalScore += 6
        }

        if ($isObfuscated -and $totalScore -ge 5) {
            $totalScore += 5
        }

        if ($classResult.Features.KnownCheatClient) {
            $totalScore += 10
        }

        # Combine features
        $combinedFeatures = @{
            HighEntropy = $classResult.Features.HighEntropy
            EntropyValue = $classResult.Features.EntropyValue
            HighRiskPatterns = $classResult.Features.HighRiskPatterns
            SuspiciousPatterns = $classResult.Features.SuspiciousPatterns
            SuspiciousURLs = $classResult.Features.SuspiciousURLs
            ObfuscationLevel = $classResult.Features.ObfuscationLevel
            CryptoUsage = $classResult.Features.CryptoUsage
            Base64Strings = $classResult.Features.Base64Strings
            FullwidthChars = $classResult.Features.FullwidthChars
            JapaneseChars = $classResult.Features.JapaneseChars
            KnownCheatClient = $classResult.Features.KnownCheatClient
            CheatObfuscator = $classResult.Features.CheatObfuscator
            TotalScore = $totalScore
        }

        # Categorize mod
        if (
    $totalScore -ge 35 -or
    $bypassResult.Score -ge 15
) {
            $criticalMods += [PSCustomObject]@{
                FileName = $jar.Name
                Detections = ($allFindings.Keys | Sort-Object { $allFindings[$_] } -Descending | Select-Object -First 10) -join ', '
                Score = $totalScore
                Obfuscated = $isObfuscated
                BypassFlags = $bypassResult.Flags -join ', '
                ObfuscationFlags = $obfResult.Flags -join ', '
                Fullwidth = ($FoundFullwidth | Select-Object -First 5) -join ', '
                SuspiciousURLs = ($FoundURLs | Select-Object -First 3) -join ', '
                Features = $combinedFeatures
            }
        }
        elseif ($totalScore -ge 18) {
            $highRiskMods += [PSCustomObject]@{
                FileName = $jar.Name
                Detections = ($allFindings.Keys | Sort-Object { $allFindings[$_] } -Descending | Select-Object -First 8) -join ', '
                Score = $totalScore
                Obfuscated = $isObfuscated
                ObfuscationFlags = $obfResult.Flags -join ', '
                Fullwidth = ($FoundFullwidth | Select-Object -First 3) -join ', '
                Features = $combinedFeatures
            }
        }
        elseif ($totalScore -ge 7) {
            $suspiciousMods += [PSCustomObject]@{
                FileName = $jar.Name
                Detections = ($allFindings.Keys | Sort-Object { $allFindings[$_] } -Descending | Select-Object -First 5) -join ', '
                Score = $totalScore
                Obfuscated = $isObfuscated
                Features = $combinedFeatures
            }
        }
        else {
            $unknownMods += [PSCustomObject]@{
                FileName = $jar.Name
                ZoneId = Get-ZoneIdentifier $jar.FullName
                Score = $totalScore
            }
        }

        # Cleanup
        Remove-Item $extractPath -Force -Recurse -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host ""
        Write-Host "[!] Failed to analyze $($jar.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ("`r" + (" " * 120))
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║          PHASE 3: JVM Runtime Analysis               ║" -ForegroundColor Magenta
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

$jvmResult = Invoke-JvmScan

Write-Host ("`r" + (" " * 120))
Write-Host ""

# ==================== OUTPUT ====================

if ($verifiedMods.Count -gt 0) {
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "║              ✓ VERIFIED MODS                          ║" -ForegroundColor DarkCyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan

    foreach ($mod in $verifiedMods) {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host $mod.ModName -ForegroundColor Green -NoNewline
        Write-Host " [$($mod.Source)]" -ForegroundColor DarkGray -NoNewline
        Write-Host " ($($mod.FileName))" -ForegroundColor Gray
    }

    Write-Host ""
}

if ($unknownMods.Count -gt 0) {
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor DarkGray
    Write-Host "║              ? UNKNOWN MODS (Clean)                   ║" -ForegroundColor DarkGray
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor DarkGray

    foreach ($mod in $unknownMods) {
        Write-Host "  • $($mod.FileName)" -ForegroundColor Gray -NoNewline
        Write-Host " [Score: $($mod.Score)]" -ForegroundColor DarkGray

        if ($mod.ZoneId) {
            Write-Host "    Source: $($mod.ZoneId)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

if ($suspiciousMods.Count -gt 0) {
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║              ⚠ SUSPICIOUS MODS (Medium Risk)         ║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Yellow

    foreach ($mod in $suspiciousMods) {
        Write-Host "  ⚠ " -NoNewline -ForegroundColor Yellow
        Write-Host $mod.FileName -ForegroundColor Yellow -NoNewline
        Write-Host " [Score: $($mod.Score)]" -ForegroundColor DarkYellow
        
        Write-Host "    Detections: " -NoNewline -ForegroundColor Gray
        Write-Host $mod.Detections -ForegroundColor DarkYellow

        if ($mod.Obfuscated) {
            Write-Host "    [!] Obfuscated code detected" -ForegroundColor Red
        }

        if ($mod.Fullwidth) {
            Write-Host "    [!] Fullwidth Unicode: $($mod.Fullwidth)" -ForegroundColor Cyan
        }

        Write-Host ""
    }
}

if ($highRiskMods.Count -gt 0) {
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║              ⚠⚠ HIGH RISK MODS (Likely Cheat)        ║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Red

    foreach ($mod in $highRiskMods) {
        Write-Host "  ⚠⚠ " -NoNewline -ForegroundColor Red
        Write-Host $mod.FileName -ForegroundColor Red -NoNewline
        Write-Host " [Score: $($mod.Score)]" -ForegroundColor Magenta
        
        Write-Host "    Detections: " -NoNewline -ForegroundColor Gray
        Write-Host $mod.Detections -ForegroundColor Magenta

        if ($mod.Obfuscated) {
            Write-Host "    [!!!] OBFUSCATED CODE DETECTED" -ForegroundColor Red
        }

        if ($mod.ObfuscationFlags) {
            Write-Host "    [!] Obfuscation: $($mod.ObfuscationFlags)" -ForegroundColor Yellow
        }

        if ($mod.Fullwidth) {
            Write-Host "    [!] Fullwidth Unicode: $($mod.Fullwidth)" -ForegroundColor Cyan
        }

        if ($mod.SuspiciousURLs) {
            Write-Host "    [!] Suspicious URLs: $($mod.SuspiciousURLs)" -ForegroundColor Red
        }

        Write-Host ""
    }
}

if ($criticalMods.Count -gt 0) {
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor White -BackgroundColor Red
    Write-Host "║         ⚠⚠⚠ CRITICAL - BYPASS/INJECTION DETECTED     ║" -ForegroundColor White -BackgroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor White -BackgroundColor Red

    foreach ($mod in $criticalMods) {
        Write-Host "  ☠ " -NoNewline -ForegroundColor Red -BackgroundColor Black
        Write-Host $mod.FileName -ForegroundColor Red -BackgroundColor Black -NoNewline
        Write-Host " [Score: $($mod.Score)]" -ForegroundColor Magenta
        
        Write-Host "    Detections: " -NoNewline -ForegroundColor Gray
        Write-Host $mod.Detections -ForegroundColor Magenta

        if ($mod.BypassFlags) {
            Write-Host "    [!!!] BYPASS TECHNIQUES: " -NoNewline -ForegroundColor Red -BackgroundColor Yellow
            Write-Host $mod.BypassFlags -ForegroundColor Black -BackgroundColor Yellow
        }

        if ($mod.Obfuscated) {
            Write-Host "    [!!!] OBFUSCATED CODE DETECTED" -ForegroundColor Red
        }

        if ($mod.ObfuscationFlags) {
            Write-Host "    [!] Obfuscation: $($mod.ObfuscationFlags)" -ForegroundColor Yellow
        }

        if ($mod.Fullwidth) {
            Write-Host "    [!] Fullwidth Unicode: $($mod.Fullwidth)" -ForegroundColor Cyan
        }

        if ($mod.SuspiciousURLs) {
            Write-Host "    [!!!] Suspicious URLs: $($mod.SuspiciousURLs)" -ForegroundColor Red -BackgroundColor Yellow
        }

        Write-Host ""
    }
}

if ($jvmResult.Flags.Count -gt 0) {
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host "║         ⚠⚠⚠ JVM RUNTIME INJECTION DETECTED           ║" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor White -BackgroundColor DarkRed

    foreach ($flag in $jvmResult.Flags) {
        Write-Host "  ☠ [JVM] $flag" -ForegroundColor Red
    }
    
    Write-Host "    JVM Risk Score: $($jvmResult.Score)" -ForegroundColor Magenta
    Write-Host ""
}

# Cleanup
try {
    Remove-Item $tempDir -Force -Recurse -ErrorAction SilentlyContinue
}
catch {}

Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                  SCAN SUMMARY                         ║" -ForegroundColor White
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  Total Scanned:  " -NoNewline -ForegroundColor Gray
Write-Host $total -ForegroundColor White
Write-Host "  Verified:       " -NoNewline -ForegroundColor Gray
Write-Host $verifiedMods.Count -ForegroundColor Green
Write-Host "  Unknown/Clean:  " -NoNewline -ForegroundColor Gray
Write-Host $unknownMods.Count -ForegroundColor Gray
Write-Host "  Suspicious:     " -NoNewline -ForegroundColor Gray
Write-Host $suspiciousMods.Count -ForegroundColor Yellow
Write-Host "  High Risk:      " -NoNewline -ForegroundColor Gray
Write-Host $highRiskMods.Count -ForegroundColor Red
Write-Host "  CRITICAL:       " -NoNewline -ForegroundColor Gray
Write-Host $criticalMods.Count -ForegroundColor Red -BackgroundColor Black

if ($jvmResult.Flags.Count -gt 0) {
    Write-Host "  JVM Injections: " -NoNewline -ForegroundColor Gray
    Write-Host $jvmResult.Flags.Count -ForegroundColor Red -BackgroundColor DarkRed
}

Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host ""

if ($criticalMods.Count -gt 0 -or $highRiskMods.Count -gt 0) {
    Write-Host "⚠ WARNING: Potential cheats detected!" -ForegroundColor Red
    Write-Host "Recommended action: Remove flagged mods immediately" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Scan complete. Press Enter to exit." -ForegroundColor Green
Read-Host
