[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Clear-Host
Write-Host "Fingerx Mod Analyzer Ultimate" -ForegroundColor Red
Write-Host "Sinhuini Class Analyzer - Enhanced Edition" -ForegroundColor DarkGray
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
    param([string]$Text)

    if (-not $Text) { return 0 }

    $map = @{}

    foreach ($c in $Text.ToCharArray()) {
        if ($map.ContainsKey($c)) {
            $map[$c]++
        }
        else {
            $map[$c] = 1
        }
    }

    $entropy = 0.0

    foreach ($v in $map.Values) {
        $p = $v / $Text.Length
        $entropy -= $p * [Math]::Log($p, 2)
    }

    return $entropy
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

function Query-Megabase {
    param([string]$Hash)
    try {
        $result = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$Hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if (-not $result.error) { return $result.data }
    } catch { }
    return $null
}

# Высокий риск — точные паттерны с границами слов
$highRiskPatterns = @{
    "KillAura"      = 10
    "AimAssist"     = 10
    "TriggerBot"    = 10
    "AutoCrystal"   = 10
    "AutoTotem"     = 9
    "AntiKnockback" = 9
    "NoFall"        = 8
    "XRay"          = 10
    "Tracers"       = 9
    "Wallhack"      = 10
    "ChestESP"      = 9
    "PlayerESP"     = 9
    "FastBreak"     = 8
    "Nuker"         = 9
    "Scaffold"      = 8
    "Tower"         = 7
    "ChestStealer"  = 8
    "InvMove"       = 7
    "AutoArmor"     = 8
    "Criticals"     = 8
    "ClickAura"     = 10
    "MultiAura"     = 10
    "BowAimbot"     = 10
    "AutoClicker"   = 7
    "AntiBot"       = 7
    "NoSlowdown"    = 8
    "NoSlow"        = 8
    "Jesus"         = 7
    "Blink"         = 8
    "Timer"         = 7
    "FastPlace"     = 7
    "AutoPot"       = 8
    "Regen"         = 8
    "FlyHack"       = 9
    "SpeedHack"     = 8
}

# Точные паттерны ESP отдельно — чтобы не ловить "response" и т.п.
$espPatterns = @{
    "EntityESP"   = 9
    "MobESP"      = 9
    "ItemESP"     = 8
    "NameESP"     = 8
    "BoxESP"      = 9
    "SkeletonESP" = 9
}

# Forge mappings
$obfuscatedForge = @{
    "func_174826_a"  = 1
    "func_226277_ct_" = 1
    "func_174813_aQ" = 1
    "field_72338_b"  = 6
    "func_226281_cx_" = 6
    "field_72337_e"  = 6
}

# Fabric mappings
$obfuscatedFabric = @{
    "method_5829"  = 6
    "class_238"    = 5
    "method_23317" = 6
    "method_23321" = 6
    "method_5857"  = 6
}

# LabyMod / Proguard
$obfuscatedLabymod = @{
    ".cD()"    = 6
    ".cc().b"  = 6
    ".cH()"    = 6
    ".cc().e"  = 6
}

# Средний риск
$mediumRiskPatterns = @{
    "RotationUtil"  = 2
    "MovementUtil"  = 2
    "PlayerUtil"    = 1
    "RayTraceUtil"  = 2
    "RenderUtil"    = 3
}

# Низкий риск
$lowRiskPatterns = @{
    "sendPacket"   = 1
    "channelRead0" = 1
}

# Base64 / Crypto — точные паттерны без коротких слов
$base64Patterns = @{
    "java/util/Base64"  = 1
    "javax/crypto"      = 1
    "SecretKeySpec"     = 5
    "SecretKey"         = 5
    "decodeBase64"      = 5
    "getDecoder"        = 4
    "AESEncrypt"        = 6
    "DESEncrypt"        = 6
    "AESDecrypt"        = 6
    "CipherKey"         = 5
    "CipherSpec"        = 5
    "decryptData"       = 5
    "encryptData"       = 4
    "Base64Encode"      = 4
    "Base64Decode"      = 5
}

# НОВОЕ: Расширенные паттерны читов из второго скрипта
$suspiciousPatterns = @(
    "AimAssist", "AnchorTweaks", "AutoAnchor", "AutoCrystal", "AutoDoubleHand",
    "AutoHitCrystal", "AutoPot", "AutoTotem", "AutoArmor", "InventoryTotem",
    "JumpReset", "LegitTotem", "PingSpoof", "SelfDestruct",
    "ShieldBreaker", "TriggerBot", "AxeSpam", "WebMacro",
    "FastPlace", "WalskyOptimizer", "WalksyOptimizer", "walsky.optimizer",
    "WalksyCrystalOptimizerMod", "Donut", "Replace Mod",
    "ShieldDisabler", "SilentAim", "Totem Hit", "Wtap", "FakeLag",
    "BlockESP", "dev.krypton", "Virgin", "AntiMissClick",
    "LagReach", "PopSwitch", "SprintReset", "ChestSteal", "AntiBot",
    "ElytraSwap", "FastXP", "FastExp", "Refill",  "AirAnchor",
    "jnativehook", "FakeInv", "HoverTotem", "AutoClicker", "AutoFirework",
    "PackSpoof", "Antiknockback", "catlean", "Argon",
    "AuthBypass", "Asteria", "Prestige", "AutoEat", "AutoMine",
    "MaceSwap", "DoubleAnchor", "AutoTPA", "BaseFinder", "Xenon", "gypsy",
    "Grim", "grim",
    "org.chainlibs.module.impl.modules.Crystal.Y",
    "org.chainlibs.module.impl.modules.Crystal.bF",
    "org.chainlibs.module.impl.modules.Crystal.bM",
    "org.chainlibs.module.impl.modules.Crystal.bY",
    "org.chainlibs.module.impl.modules.Crystal.bq",
    "org.chainlibs.module.impl.modules.Crystal.cv",
    "org.chainlibs.module.impl.modules.Crystal.o",
    "org.chainlibs.module.impl.modules.Blatant.I",
    "org.chainlibs.module.impl.modules.Blatant.bR",
    "org.chainlibs.module.impl.modules.Blatant.bx",
    "org.chainlibs.module.impl.modules.Blatant.cj",
    "org.chainlibs.module.impl.modules.Blatant.dk",
    "imgui.gl3", "imgui.glfw",
    "BowAim", "Criticals", "Fakenick", "FakeItem",
    "invsee", "ItemExploit", "Hellion", "hellion",
    "LicenseCheckMixin", "ClientPlayerInteractionManagerAccessor",
    "ClientPlayerEntityMixim", "dev.gambleclient", "obfuscatedAuth",
    "phantom-refmap.json", "xyz.greaj"
)

# НОВОЕ: Fullwidth Unicode и японские символы
$cheatStrings = @(
    "AutoCrystal", "autocrystal", "auto crystal", "cw crystal",
    "dontPlaceCrystal", "dontBreakCrystal",
    "AutoHitCrystal", "autohitcrystal", "canPlaceCrystalServer", "healPotSlot",
    "ＡｕｔｏＣｒｙｓｔａｌ", "Ａｕｔｏ Ｃｒｙｓｔａｌ",
    "ＡｕｔｏＨｉｔＣｒｙｓｔａｌ",
    "AutoAnchor", "autoanchor", "auto anchor", "DoubleAnchor",
     "HasAnchor", "anchortweaks", "anchor macro", "safe anchor", "safeanchor",
    "SafeAnchor", "AirAnchor",
    "ＡｕｔｏＡｎｃｈｏｒ", "Ａｕｔｏ Ａｎｃｈｏｒ",
    "ＤｏｕｂｌｅＡｎｃｈｏｒ", "Ｄｏｕｂｌｅ Ａｎｃｈｏｒ",
    "ＳａｆｅＡｎｃｈｏｒ", "Ｓａｆｅ Ａｎｃｈｏｒ",
    "Ａｎｃｈｏｒ Ｍａｃｒｏ", "anchorMacro",
    "AutoTotem", "autototem", "auto totem", "InventoryTotem",
    "inventorytotem", "HoverTotem", "hover totem", "legittotem",
    "ＡｕｔｏＴｏｔｅｍ", "Ａｕｔｏ Ｔｏｔｅｍ",
    "ＨｏｖｅｒＴｏｔｅｍ", "Ｈｏｖｅｒ Ｔｏｔｅｍ",
    "ＩｎｖｅｎｔｏｒｙＴｏｔｅｍ", "Ａｕｔｏ Ｉｎｖｅｎｔｏｒｙ Ｔｏｔｅｍ",
    "Ａｕｔｏ Ｔｏｔｅｍ Ｈｉｔ",
    "じ.class", "ふ.class", "ぶ.class", "ぷ.class", "た.class",
    "ね.class", "そ.class", "な.class", "ど.class", "ぐ.class",
    "ず.class", "で.class", "つ.class", "べ.class", "せ.class",
    "と.class", "み.class", "び.class", "す.class", "の.class",
    "KillAura", "ClickAura", "MultiAura", "ForceField", "LegitAura",
    "AimBot", "AutoAim", "SilentAim", "AimLock", "HeadSnap",
    "CrystalAura", "AnchorAura", "BedAura", "BowAimbot",
    "ReachHack", "ExtendReach", "LongReach", "HitboxExpand",
    "AntiKB", "NoKnockback", "GrimVelocity", "GrimDisabler",
    "FlyHack", "CreativeFlight", "BoatFly", "PacketFly",
    "WallHack", "XRayHack", "OreFinder", "CaveFinder",
    "SessionStealer", "TokenLogger", "TokenGrabber", "DiscordToken",
    "RemoteAccess", "ReverseShell", "C2Server", "Backdoor", "KeyLogger",
    "meteordevelopment", "cc/novoline", "com/alan/clients",
    "club/maxstats", "wtf/moonlight", "me/zeroeightsix/kami",
    "net/ccbluex", "today/opai", "net/minecraft/injection",
    "org/chainlibs/module/impl/modules", "xyz/greaj",
    "doomsdayclient", "novaclient", "vape.gg", "liquidbounce",
    "fdp-client", "rusherhack", "futureClient", "konas"
)

# НОВОЕ: Regex для fullwidth Unicode
$fullwidthRegex = [regex]::new(
    "[\uFF21-\uFF3A\uFF41-\uFF5A\uFF10-\uFF19]{2,}",
    [System.Text.RegularExpressions.RegexOptions]::Compiled
)

# НОВОЕ: Паттерны для обфускаторов
$cheatObfuscators = @{
    "Skidfuscator"   = @("dev/skidfuscator", "Skidfuscator", "skidfuscator.dev")
    "Paramorphism"   = @("Paramorphism", "paramorphism-", "dev/paramorphism")
    "Radon"          = @("ItzSomebody/Radon", "me/itzsomebody/radon", "Radon Obfuscator")
    "Caesium"        = @("sim0n/Caesium", "Caesium Obfuscator", "dev/sim0n/caesium")
    "Bozar"          = @("vimasig/Bozar", "Bozar Obfuscator", "com/bozar")
    "Branchlock"     = @("Branchlock", "branchlock.dev")
    "Binscure"       = @("Binscure", "com/binscure")
    "SuperBlaubeere" = @("superblaubeere", "superblaubeere27")
    "Qprotect"       = @("Qprotect", "QProtect", "mdma.dev/qprotect")
    "Zelix"          = @("ZKMFLOW", "ZKM", "ZelixKlassMaster", "com/zelix")
    "Stringer"       = @("StringerJavaObfuscator", "com/licel/stringer")
    "JNIC"           = @("JNIC", "jnic.obf", "jnic-obfuscator")
    "Scuti"          = @("ScutiObf", "scuti.obf")
    "Smoke"          = @("SmokeObf", "smoke.obf")
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
    $nestedFullwidth = @()
    $nestedCheatStrings = @()

    foreach ($nested in $nestedJars) {

        $nestedExtract = Join-Path $tempDir ("nested_" + [System.IO.Path]::GetFileNameWithoutExtension($nested.Name) + "_" + (Get-Random))

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

            # НОВОЕ: Собираем fullwidth и cheat strings из вложенных JAR
            foreach ($fw in $result.Fullwidth) {
                if ($nestedFullwidth -notcontains $fw) {
                    $nestedFullwidth += $fw
                }
            }

            foreach ($cs in $result.CheatStrings) {
                if ($nestedCheatStrings -notcontains $cs) {
                    $nestedCheatStrings += $cs
                }
            }
        }
        catch {}
    }

    return @{
        Findings      = $nestedFindings
        Score         = $nestedScore
        Obfuscated    = $nestedObfuscated
        Fullwidth     = $nestedFullwidth
        CheatStrings  = $nestedCheatStrings
    }
}

function Analyze-ClassFiles {
    param([string]$extractPath)

    $findings = @{}
    $score = 0
    $obfuscationDetected = $false
    $foundFullwidth = @()
    $foundCheatStrings = @()

    $classFiles = Get-ChildItem `
        -Path $extractPath `
        -Recurse `
        -Filter *.class `
        -ErrorAction SilentlyContinue

    foreach ($class in $classFiles) {
        try {
            
            $stream = [System.IO.File]::OpenRead($class.FullName)
            $buffer = New-Object byte[] 65536
            $read = $stream.Read($buffer, 0, $buffer.Length)
            $stream.Close()

            $bytes = $buffer[0..($read-1)]


            # FIX: Latin1 вместо ASCII — читает байты 1:1 без потерь
            $text = [System.Text.Encoding]::Latin1.GetString($bytes)
            $utf8 = [System.Text.Encoding]::UTF8.GetString($bytes)

            
            # URL extraction
            $urlRegex = '(https?:\/\/[^\s"]+)'
            $urlMatches = [regex]::Matches($text, $urlRegex)

            foreach ($u in $urlMatches) {
                $url = $u.Value

                if ($url -match "discord|webhook|pastebin|ngrok") {
                    if (-not $findings.ContainsKey("SuspiciousURL")) {
                        $findings["SuspiciousURL"] = 12
                        $score += 12
                    }
                }
            }

            # Entropy detection
            $entropy = Get-Entropy $text

            if ($entropy -gt 7.2) {
                if (-not $findings.ContainsKey("HighEntropy")) {
                    $findings["HighEntropy"] = 8
                    $score += 8
                }
            }

# High risk
            foreach ($pattern in $highRiskPatterns.Keys) {
                if ($text -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = $highRiskPatterns[$pattern]
                        $score += $highRiskPatterns[$pattern]
                    }
                }
            }

            # ESP точные паттерны
            foreach ($pattern in $espPatterns.Keys) {
                if ($text -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = $espPatterns[$pattern]
                        $score += $espPatterns[$pattern]
                    }
                }
            }

            # НОВОЕ: Дополнительные suspicious паттерны
            foreach ($pattern in $suspiciousPatterns) {
                if ($text -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = 8
                        $score += 8
                    }
                }
            }

            # НОВОЕ: Cheat strings с fullwidth
            foreach ($cs in $cheatStrings) {
                if ($text.Contains($cs) -or $utf8.Contains($cs)) {
                    if ($foundCheatStrings -notcontains $cs) {
                        $foundCheatStrings += $cs
                        $score += 7
                    }
                }
            }

            # НОВОЕ: Fullwidth Unicode детекция
            $fwMatches = $fullwidthRegex.Matches($utf8)
            foreach ($m in $fwMatches) {
                $fw = $m.Value
                if ($foundFullwidth -notcontains $fw) {
                    $foundFullwidth += $fw
                    $score += 8
                }
            }

            # Forge
            foreach ($pattern in $obfuscatedForge.Keys) {
                if ($text -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey("ObfuscatedForge")) {
                        $findings["ObfuscatedForge"] = $obfuscatedForge[$pattern]
                        $score += $obfuscatedForge[$pattern]
                        $obfuscationDetected = $true
                    }
                }
            }

            # Fabric
            foreach ($pattern in $obfuscatedFabric.Keys) {
                if ($text -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey("ObfuscatedFabric")) {
                        $findings["ObfuscatedFabric"] = $obfuscatedFabric[$pattern]
                        $score += $obfuscatedFabric[$pattern]
                        $obfuscationDetected = $true
                    }
                }
            }

            # LabyMod
            foreach ($pattern in $obfuscatedLabymod.Keys) {
                if ($text -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey("ObfuscatedLabymod")) {
                        $findings["ObfuscatedLabymod"] = $obfuscatedLabymod[$pattern]
                        $score += $obfuscatedLabymod[$pattern]
                        $obfuscationDetected = $true
                    }
                }
            }

            # Medium risk
            foreach ($pattern in $mediumRiskPatterns.Keys) {
                if ($text -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = $mediumRiskPatterns[$pattern]
                        $score += $mediumRiskPatterns[$pattern]
                    }
                }
            }

            # Low risk
            foreach ($pattern in $lowRiskPatterns.Keys) {
                if ($text -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = $lowRiskPatterns[$pattern]
                        $score += $lowRiskPatterns[$pattern]
                    }
                }
            }

            # Base64 / Crypto — точные паттерны
            foreach ($pattern in $base64Patterns.Keys) {
                if ($text -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = $base64Patterns[$pattern]
                        $score += $base64Patterns[$pattern]
                    }
                }
            }

            # Поиск встроенных Base64 строк
            $b64Regex = '(?:[A-Za-z0-9+/]{4}){20,}(?:==|=)?'

            $b64Matches = [regex]::Matches($text, $b64Regex)

            foreach ($b64Match in $b64Matches) {
                $value = $b64Match.Value
                try {
                    [System.Convert]::FromBase64String($value) | Out-Null
                    if (-not $findings.ContainsKey("EmbeddedBase64")) {
                        $findings["EmbeddedBase64"] = 7
                        $score += 7
                    }
                }
                catch {}
            }

            # НОВОЕ: Детекция известных обфускаторов
            foreach ($obfName in $cheatObfuscators.Keys) {
                foreach ($pat in $cheatObfuscators[$obfName]) {
                    if ($text.Contains($pat)) {
                        $findings["CheatObfuscator:$obfName"] = 10
                        $score += 10
                        $obfuscationDetected = $true
                        break
                    }
                }
            }
        }
        catch {}
    }

    return @{
        Findings      = $findings
        Score         = $score
        Obfuscated    = $obfuscationDetected
        Fullwidth     = $foundFullwidth
        CheatStrings  = $foundCheatStrings
    }
}

# НОВОЕ: Функция для анализа bypass/injection техник
function Analyze-BypassTechniques {
    param([string]$FilePath)

    $bypassFlags = @()
    $bypassScore = 0

    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($FilePath)

        $nestedJars   = @($zip.Entries | Where-Object { $_.FullName -match "^META-INF/jars/.+\.jar$" })
        $outerClasses = @($zip.Entries | Where-Object { $_.FullName -match "\.class$" })

        # Детекция hollow shell
        if ($nestedJars.Count -eq 1 -and $outerClasses.Count -lt 3) {
            $bypassFlags += "HollowShell"
            $bypassScore += 12
        }

        # Детекция подозрительных вложенных JAR
        foreach ($nj in $nestedJars) {
            $njName = [System.IO.Path]::GetFileName($nj.FullName)
            if ($njName -notmatch '\d' -and $njName.Length -lt 20) {
                $bypassFlags += "SuspiciousNestedJAR:$njName"
                $bypassScore += 8
            }
        }

        $allEntries = [System.Collections.Generic.List[object]]::new()
        foreach ($e in $zip.Entries) { $allEntries.Add($e) }

        # Анализ вложенных JAR
        $innerZips = [System.Collections.Generic.List[object]]::new()
        foreach ($nj in $nestedJars) {
            try {
                $ns = $nj.Open()
                $ms = New-Object System.IO.MemoryStream
                $ns.CopyTo($ms); $ns.Close()
                $ms.Position = 0
                $iz = [System.IO.Compression.ZipArchive]::new($ms, [System.IO.Compression.ZipArchiveMode]::Read)
                $innerZips.Add($iz)
                foreach ($ie in $iz.Entries) { $allEntries.Add($ie) }
            } catch { }
        }

        $runtimeExecFound  = $false
        $httpDownloadFound = $false
        $httpExfilFound    = $false

        foreach ($entry in $allEntries) {
            if ($entry.FullName -match "\.class$") {
                try {
                    $st = $entry.Open()
                    $ms2 = New-Object System.IO.MemoryStream
                    $st.CopyTo($ms2)
                    $st.Close()
                    $rawBytes = $ms2.ToArray()
                    $ms2.Dispose()
                    $ct = [System.Text.Encoding]::ASCII.GetString($rawBytes)

                    if ($ct -match "java/lang/Runtime" -and $ct -match "getRuntime" -and $ct -match "exec") {
                        $runtimeExecFound = $true
                    }

                    if ($ct -match "openConnection" -and $ct -match "HttpURLConnection" -and $ct -match "FileOutputStream") {
                        $httpDownloadFound = $true
                    }

                    if ($ct -match "openConnection" -and $ct -match "setDoOutput" -and $ct -match "getOutputStream") {
                        $httpExfilFound = $true
                    }
                } catch { }
            }
        }

        foreach ($iz in $innerZips) { try { $iz.Dispose() } catch { } }
        $zip.Dispose()

        if ($runtimeExecFound) {
            $bypassFlags += "Runtime.exec()"
            $bypassScore += 15
        }
        if ($httpDownloadFound) {
            $bypassFlags += "HTTPDownload"
            $bypassScore += 12
        }
        if ($httpExfilFound) {
            $bypassFlags += "HTTPExfiltration"
            $bypassScore += 15
        }

    } catch { }

    return @{
        Flags = $bypassFlags
        Score = $bypassScore
    }
}

# НОВОЕ: Функция для анализа обфускации
function Analyze-ObfuscationLevel {
    param([string]$FilePath)

    $obfFlags = @()
    $obfScore = 0

    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($FilePath)

        $totalClass    = 0
        $numericCount  = 0
        $unicodeCount  = 0
        $fullwidthCount= 0
        $japaneseCount = 0
        $singleLetterCount = 0

        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -match "\.class$") {
                $totalClass++
                $className = [System.IO.Path]::GetFileNameWithoutExtension(($entry.FullName -split "/")[-1])

                if ($className -match "^\d+$") { $numericCount++ }
                if ($className -match "[^\x00-\x7F]") { $unicodeCount++ }
                if ($className -match "[\uFF21-\uFF3A\uFF41-\uFF5A\uFF10-\uFF19]") { $fullwidthCount++ }
                if ($className -match "[\u3040-\u309F\u30A0-\u30FF]") { $japaneseCount++ }
                if ($className -match "^[a-zA-Z]$") { $singleLetterCount++ }
            }
        }

        $archive.Dispose()

        if ($totalClass -ge 5) {
            $numPct = [math]::Round(($numericCount / $totalClass) * 100)
            $uniPct = [math]::Round(($unicodeCount / $totalClass) * 100)
            $fwPct  = [math]::Round(($fullwidthCount / $totalClass) * 100)
            $jpPct  = [math]::Round(($japaneseCount / $totalClass) * 100)
            $s1Pct  = [math]::Round(($singleLetterCount / $totalClass) * 100)

            if ($numPct -ge 20) { 
                $obfFlags += "NumericClasses:$numPct%"
                $obfScore += 8
            }
            if ($uniPct -ge 10) { 
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
            if ($s1Pct -ge 15) { 
                $obfFlags += "SingleLetterClasses:$s1Pct%"
                $obfScore += 6
            }
        }

    } catch { }

    return @{
        Flags = $obfFlags
        Score = $obfScore
    }
}

# НОВОЕ: Функция для сканирования JVM
function Invoke-JvmScan {
    $jvmFlags = @()
    $jvmScore = 0

    $javaProc = Get-Process javaw -ErrorAction SilentlyContinue
    if (-not $javaProc) { $javaProc = Get-Process java -ErrorAction SilentlyContinue }
    if (-not $javaProc) { return @{ Flags = $jvmFlags; Score = $jvmScore } }

    $javaPid = ($javaProc | Select-Object -First 1).Id

    try {
        $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $javaPid" -ErrorAction Stop
        $cmdLine = $wmi.CommandLine

        if ($cmdLine) {
            # Детекция Java Agents
            $agentMatches = [regex]::Matches($cmdLine, '-javaagent:([^\s"]+)')
            foreach ($m in $agentMatches) {
                $agentPath = $m.Groups[1].Value.Trim('"').Trim("'")
                $agentName = [System.IO.Path]::GetFileName($agentPath)
                
                $legitAgents = @("jmxremote","yjp","jrebel","newrelic","jacoco","theseus")
                $isLegit = $false
                foreach ($la in $legitAgents) { 
                    if ($agentName -match $la) { $isLegit = $true; break } 
                }
                
                if (-not $isLegit) {
                    $jvmFlags += "JavaAgent:$agentName"
                    $jvmScore += 12
                }
            }

            # Детекция опасных JVM флагов
            if ($cmdLine -match "-Xbootclasspath/p:") {
                $jvmFlags += "BootClasspathPrepend"
                $jvmScore += 10
            }
            if ($cmdLine -match "-Xbootclasspath/a:") {
                $jvmFlags += "BootClasspathAppend"
                $jvmScore += 10
            }
            if ($cmdLine -match "-agentlib:jdwp") {
                $jvmFlags += "JDWPDebugAgent"
                $jvmScore += 8
            }
            if ($cmdLine -match "-agentpath:") {
                $jvmFlags += "NativeAgent"
                $jvmScore += 12
            }
        }
    } catch { }

    return @{
        Flags = $jvmFlags
        Score = $jvmScore
    }
}

function Analyze-Metadata {
    param([string]$extractPath)

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

            foreach ($pattern in $highRiskPatterns.Keys) {
                if ($content -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = $highRiskPatterns[$pattern]
                        $score += $highRiskPatterns[$pattern]
                    }
                }
            }

            foreach ($pattern in $espPatterns.Keys) {
                if ($content -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = $espPatterns[$pattern]
                        $score += $espPatterns[$pattern]
                    }
                }
            }

            # НОВОЕ: Проверка suspicious паттернов в метаданных
            foreach ($pattern in $suspiciousPatterns) {
                if ($content -match [regex]::Escape($pattern)) {
                    if (-not $findings.ContainsKey($pattern)) {
                        $findings[$pattern] = 7
                        $score += 7
                    }
                }
            }
        }
        catch {}
    }

    return @{
        Findings = $findings
        Score    = $score
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
            return $Matches[1]
        }
    }
    catch {}

    return $null
}

$verifiedMods   = @()
$unknownMods    = @()
$suspiciousMods = @()
$highRiskMods   = @()
$criticalMods   = @() # НОВОЕ: Критические моды с bypass/injection

$tempDir = Join-Path $env:TEMP "fingerx_analyzer"

if (Test-Path $tempDir) {
    Remove-Item $tempDir -Force -Recurse
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
Write-Host "=== PHASE 1: Hash Verification (Modrinth + Megabase) ===" -ForegroundColor Cyan
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
        if ($modrinth.Slug) {
            $verifiedMods += [PSCustomObject]@{
                ModName  = $modrinth.Name
                FileName = $jar.Name
            }
            continue
        }

        # НОВОЕ: Проверка в Megabase
        $megabase = Query-Megabase $hash
        if ($megabase.name) {
            $verifiedMods += [PSCustomObject]@{
                ModName  = $megabase.name
                FileName = $jar.Name
            }
            continue
        }
    }

    # Мод не верифицирован, переходим к глубокому анализу
}

Write-Host ("`r" + (" " * 120))
Write-Host ""
Write-Host "=== PHASE 2: Deep Pattern Analysis ===" -ForegroundColor Cyan
Write-Host ""

$index = 0

foreach ($jar in $jarFiles) {
    $index++

    # Пропускаем уже верифицированные
    if ($verifiedMods | Where-Object { $_.FileName -eq $jar.Name }) {
        continue
    }

    Write-Host ("`r" + (" " * 120)) -NoNewline
    Write-Host "`r[$index/$total] Deep scanning $($jar.Name)..." `
        -ForegroundColor Yellow `
        -NoNewline

    $extractPath = Join-Path $tempDir ([System.IO.Path]::GetFileNameWithoutExtension($jar.Name))

    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory(
            $jar.FullName,
            $extractPath
        )

        $classResult  = Analyze-ClassFiles $extractPath
        $metaResult   = Analyze-Metadata $extractPath
        $nestedResult = Analyze-NestedJars $extractPath $tempDir

        # НОВОЕ: Bypass и обфускация анализ
        $bypassResult = Analyze-BypassTechniques $jar.FullName
        $obfResult    = Analyze-ObfuscationLevel $jar.FullName

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

        $totalScore = $classResult.Score + $metaResult.Score + $nestedResult.Score + 
                      $bypassResult.Score + $obfResult.Score
        
        $isObfuscated = $classResult.Obfuscated -or $nestedResult.Obfuscated

        # Собираем все fullwidth находки
        $allFullwidth = @()
        $allFullwidth += $classResult.Fullwidth
        $allFullwidth += $nestedResult.Fullwidth
        $allFullwidth = $allFullwidth | Select-Object -Unique

        # Собираем cheat strings
        $allCheatStrings = @()
        $allCheatStrings += $classResult.CheatStrings
        $allCheatStrings += $nestedResult.CheatStrings
        $allCheatStrings = $allCheatStrings | Select-Object -Unique

        # Base64 + Obfuscation бонус
        if ($allFindings.ContainsKey("EmbeddedBase64") -and $isObfuscated) {
            $totalScore += 6
        }

        # Generic obfuscation бонус
        if ($isObfuscated -and $totalScore -ge 3) {
            $totalScore += 5
        }

        # НОВОЕ: Критические моды (bypass/injection)
        if ($bypassResult.Flags.Count -gt 0 -or $totalScore -ge 30) {
            $criticalMods += [PSCustomObject]@{
                FileName       = $jar.Name
                Detections     = ($allFindings.Keys | Sort-Object { $allFindings[$_] } -Descending) -join ", "
                Score          = $totalScore
                Obfuscated     = $isObfuscated
                BypassFlags    = $bypassResult.Flags -join ", "
                ObfuscationFlags = $obfResult.Flags -join ", "
                Fullwidth      = $allFullwidth -join ", "
                CheatStrings   = $allCheatStrings -join ", "
            }
        }
        elseif ($totalScore -ge 15) {
            $highRiskMods += [PSCustomObject]@{
                FileName       = $jar.Name
                Detections     = ($allFindings.Keys | Sort-Object { $allFindings[$_] } -Descending) -join ", "
                Score          = $totalScore
                Obfuscated     = $isObfuscated
                ObfuscationFlags = $obfResult.Flags -join ", "
                Fullwidth      = $allFullwidth -join ", "
                CheatStrings   = $allCheatStrings -join ", "
            }
        }
        elseif ($totalScore -ge 5) {
            $suspiciousMods += [PSCustomObject]@{
                FileName   = $jar.Name
                Detections = ($allFindings.Keys | Sort-Object { $allFindings[$_] } -Descending) -join ", "
                Score      = $totalScore
                Obfuscated = $isObfuscated
                Fullwidth  = $allFullwidth -join ", "
            }
        }
        else {
            $unknownMods += [PSCustomObject]@{
                FileName = $jar.Name
                ZoneId   = Get-ZoneIdentifier $jar.FullName
            }
        }
    }
    catch {
        Write-Host ""
        Write-Host "Failed to analyze $($jar.Name)" -ForegroundColor Red
    }
}

Write-Host ("`r" + (" " * 120))
Write-Host ""
Write-Host "=== PHASE 3: JVM Runtime Analysis ===" -ForegroundColor Magenta
Write-Host ""

$jvmResult = Invoke-JvmScan

Write-Host ("`r" + (" " * 120))
Write-Host ""

# ==================== OUTPUT ====================

if ($verifiedMods.Count -gt 0) {
    Write-Host "{ VERIFIED MODS }" -ForegroundColor DarkCyan

    foreach ($mod in $verifiedMods) {
        Write-Host "> " -NoNewline
        Write-Host $mod.ModName -ForegroundColor Green -NoNewline
        Write-Host " ($($mod.FileName))" -ForegroundColor Gray
    }

    Write-Host ""
}

if ($unknownMods.Count -gt 0) {
    Write-Host "{ UNKNOWN MODS (Clean) }" -ForegroundColor DarkGray

    foreach ($mod in $unknownMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Gray

        if ($mod.ZoneId) {
            Write-Host "  Source: $($mod.ZoneId)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

if ($suspiciousMods.Count -gt 0) {
    Write-Host "{ SUSPICIOUS MODS (Medium Risk) }" -ForegroundColor Yellow

    foreach ($mod in $suspiciousMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Yellow
        Write-Host "  Detections: $($mod.Detections)" -ForegroundColor DarkYellow
        Write-Host "  Risk Score: $($mod.Score)" -ForegroundColor DarkYellow

        if ($mod.Obfuscated) {
            Write-Host "  [!] Obfuscated code detected" -ForegroundColor Red
        }

        if ($mod.Fullwidth) {
            Write-Host "  [!] Fullwidth Unicode: $($mod.Fullwidth)" -ForegroundColor Cyan
        }

        Write-Host ""
    }
}

if ($highRiskMods.Count -gt 0) {
    Write-Host "{ HIGH RISK MODS (Likely Cheat) }" -ForegroundColor Red

    foreach ($mod in $highRiskMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Red
        Write-Host "  Detections: $($mod.Detections)" -ForegroundColor Magenta
        Write-Host "  Risk Score: $($mod.Score)" -ForegroundColor Magenta

        if ($mod.Obfuscated) {
            Write-Host "  [!] OBFUSCATED CODE DETECTED" -ForegroundColor Red
        }

        if ($mod.ObfuscationFlags) {
            Write-Host "  [!] Obfuscation: $($mod.ObfuscationFlags)" -ForegroundColor Yellow
        }

        if ($mod.Fullwidth) {
            Write-Host "  [!] Fullwidth Unicode: $($mod.Fullwidth)" -ForegroundColor Cyan
        }

        if ($mod.CheatStrings) {
            Write-Host "  [!] Cheat Strings: $($mod.CheatStrings)" -ForegroundColor Magenta
        }

        Write-Host ""
    }
}

# НОВОЕ: Критические моды с bypass
if ($criticalMods.Count -gt 0) {
    Write-Host "{ ⚠️  CRITICAL - BYPASS/INJECTION DETECTED ⚠️ }" -ForegroundColor White -BackgroundColor Red

    foreach ($mod in $criticalMods) {
        Write-Host "> $($mod.FileName)" -ForegroundColor Red -BackgroundColor Black
        Write-Host "  Detections: $($mod.Detections)" -ForegroundColor Magenta
        Write-Host "  Risk Score: $($mod.Score)" -ForegroundColor Magenta

        if ($mod.BypassFlags) {
            Write-Host "  [!!!] BYPASS TECHNIQUES: $($mod.BypassFlags)" -ForegroundColor Red -BackgroundColor Yellow
        }

        if ($mod.Obfuscated) {
            Write-Host "  [!] OBFUSCATED CODE DETECTED" -ForegroundColor Red
        }

        if ($mod.ObfuscationFlags) {
            Write-Host "  [!] Obfuscation: $($mod.ObfuscationFlags)" -ForegroundColor Yellow
        }

        if ($mod.Fullwidth) {
            Write-Host "  [!] Fullwidth Unicode: $($mod.Fullwidth)" -ForegroundColor Cyan
        }

        if ($mod.CheatStrings) {
            Write-Host "  [!] Cheat Strings: $($mod.CheatStrings)" -ForegroundColor Magenta
        }

        Write-Host ""
    }
}

# НОВОЕ: JVM инъекции
if ($jvmResult.Flags.Count -gt 0) {
    Write-Host "{ ⚠️  JVM RUNTIME INJECTION DETECTED ⚠️ }" -ForegroundColor White -BackgroundColor DarkRed

    foreach ($flag in $jvmResult.Flags) {
        Write-Host "  [!!!] $flag" -ForegroundColor Red
    }
    
    Write-Host "  JVM Risk Score: $($jvmResult.Score)" -ForegroundColor Magenta
    Write-Host ""
}

try {
    Remove-Item $tempDir -Force -Recurse
}
catch {}

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "SCAN SUMMARY" -ForegroundColor White
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Total Scanned:  $total" -ForegroundColor Gray
Write-Host "Verified:       $($verifiedMods.Count)" -ForegroundColor Green
Write-Host "Unknown:        $($unknownMods.Count)" -ForegroundColor Gray
Write-Host "Suspicious:     $($suspiciousMods.Count)" -ForegroundColor Yellow
Write-Host "High Risk:      $($highRiskMods.Count)" -ForegroundColor Red
Write-Host "CRITICAL:       $($criticalMods.Count)" -ForegroundColor Red -BackgroundColor Black
if ($jvmResult.Flags.Count -gt 0) {
    Write-Host "JVM Injections: $($jvmResult.Flags.Count)" -ForegroundColor Red -BackgroundColor DarkRed
}
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Scan complete. Press Enter to exit." -ForegroundColor Green

Read-Host
