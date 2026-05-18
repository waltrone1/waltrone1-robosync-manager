<#
============================================================
waltrone1-RoboSync-Manager
- Sync (robocopy) + Compare (Dir snapshot)
- Multi-language: EN default, DE via -Lang de  (or -Lang en)
- Logs:
  1) Sync:   Robocopy_YYYY-MM-DD_HH-mm-ss.log  (raw)
             + HTML report in default format: Robocopy_...html
  2) Compare: Compare_YYYY-MM-DD_HH-mm-ss.json (data)
             + HTML report in default format: Compare_...html

Functions/logic: based on your existing script (robocopy async queue, UNC auth, compare with optional SHA256, UI tabs)
============================================================
#>

# ----------------------------
# App Identity (Single Source of Truth)
# ----------------------------
$script:AppName    = "waltrone1 Admin Activity Inspector"
$script:AppVersion = [version]"1.1.0.0"
$script:BuildDate  = (Get-Date).ToString("yyyy-MM-dd")

# =========================
# HEADLEss TASK MODE (must be before GUI)
# =========================
if ($args -contains "--task") {

    $ErrorActionPreference = 'Stop'
    try {
        # TODO: Load source/target (e.g. from config.json)
        $src = "C:\Daten"
        $dst = "D:\Backup"

        $argsLine = @("`"$src`"","`"$dst`"","/E","/R:2","/W:5","/NP","/XJ","/FFT") -join " "
        $p = Start-Process -FilePath "robocopy.exe" -ArgumentList $argsLine -Wait -PassThru -WindowStyle Hidden

        $rc = $p.ExitCode
        if ($rc -ge 8) { exit $rc } else { exit 0 }

    } catch {
        exit 1
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

# =========================
# BRANDING
# =========================
$script:OfficialWebsite  = "https://waltrone1.de/wltones-admin-tools/"
$script:ToolExeName      = "waltrone1-RoboSync-Manager.exe"
$script:ToolDisplayName  = "waltrone1 RoboSync Manager"
$script:ToolWindowTitle  = "waltrone1 RoboSync Manager"
$script:ToolTaskName     = "waltrone1 - RoboSync Manager"
$script:ToolTaskPath     = "\waltrone1\"
if (-not $script:ToolTaskPath.StartsWith("\")) { $script:ToolTaskPath = "\" + $script:ToolTaskPath }
if (-not $script:ToolTaskPath.EndsWith("\"))   { $script:ToolTaskPath = $script:ToolTaskPath + "\" }

# =========================
# LANGUAGE (EN default, DE optional)
# =========================
$script:Lang = "en"
for ($i=0; $i -lt $args.Count; $i++) {
    if ($args[$i] -ieq "-Lang" -and ($i+1) -lt $args.Count) {
        $val = ($args[$i+1] | ForEach-Object { $_.ToString().ToLowerInvariant() })
        if ($val -in @("de","en")) { $script:Lang = $val }
    }
    if ($args[$i] -match '^-Lang(de|en)$') {
        $script:Lang = $Matches[1].ToLowerInvariant()
    }
}

# Central strings (add keys here; use T "Key")
$script:I18N = @{
    en = @{
        Info="Info"; Ok="OK"; Error="Error"; Warning="Warning"; Note="Note"; Ready="Ready"; Done="Done"
        Source="Source"; Target="Target"; Browse="Browse..."; Reset="Reset"

		CmpBestEffortNote="Note: Compare is best effort. With very large folders or access issues, the UI may not show every entry."
		CmpUiTruncated="UI shows only the first {0:n0} of {1:n0} entries (best effort). Use the HTML report for the full list."

	    UncBestPractice="UNC paths work, but are not recommended for large sync jobs. Best practice: map the share as a network drive first (e.g. Z:) and sync using the drive letter."

        HeaderTitle="Advanced Sync and File Compare"
        HeaderHint="Hint: Prefer mapped drives (e.g. Z:) for shares. Optional: SHA256 compare (slow, exact)."
        GroupPaths="Source and Target"
        TabSync="Synchronization"
        TabCompare="Compare"
        TabHelp="Help"
        TabInfo="Info"

        OptTitle="Options"
        OptDesc="Choose source/target, verify preview, then sync. MOVE empties source; MIRROR mirrors target (includes deletes)."
        Move="MOVE - move files (source will be emptied)"
        Mirror="MIRROR - mirror target (includes deletions in target)"
        MirrorWarn="Warning: MIRROR deletes files/folders in the TARGET that are not present in SOURCE!"
        PreviewTitle="Full robocopy command (preview)"
        StatusCopying="Copy in progress..."
        StatusCancelReq="Cancel requested..."
        StatusAborted="Aborted"
        StatusNoRun="No running job."
        Start="Start"
        Cancel="Cancel"
        ClearOutput="Clear output"
        OpenLog="Open report"
        CopyCmdClipboard="Command copied to clipboard."
        MissingPaths="Please provide source and target."
        InvalidCombo="MOVE and MIRROR cannot be combined."
        MirrorConfirm="WARNING:`nMIRROR deletes extra files/folders in the TARGET (not the source).`nThis cannot be undone.`n`nContinue?"
        MultiThread="MULTITHREAD - copy in parallel (/MT)"
        MultiThreadThreads="Threads:"
        SafetyThreshold="MIR safety threshold"
        SafetyThresholdPct="Threshold (%):"
        MirrorSafetyScan="Running MIR safety check..."
        MirrorSafetyOk="MIR safety check OK: {0} changed items ({1:n2}%, threshold {2}%)."
        MirrorSafetyCancelled="MIR safety check cancelled by user."
        MirrorSafetyExceeded="Safety threshold exceeded.`n`nPlanned changes: {0} items ({1:n2}%).`nDelete from target: {2}`nCopy from source: {3}`nDifferent: {4}`nThreshold: {5}%`n`nContinue anyway?"
        MirrorSafetyDisableConfirm="Disable MIR safety threshold?`n`nWith MIRROR enabled, files that are missing in the source can be deleted from the target. The safety threshold helps prevent accidental mass deletions.`n`nContinue without safety threshold?"

        CmpOptTitle="Compare options"
        CmpOptDesc="Compares source/target: only in source, only in target, or different. Optional SHA256 hash (slower but exact)."
        HashCompare="Compare hashes (SHA256) - slow, but exact"
        Filter="Filter:"
        CmpTip="Tip: Double-click = open/select in Explorer. In 'Different' rows: double-click Source/Target column opens that file."
        CompareStart="Start compare"
        CompareDone="Compare finished"
        CompareRunning="Compare running..."
        ClearResult="Clear result"
        ReportOpen="Open HTML report"
        RunCompareFirst="Please run a compare first."
        CmpMissing="Please provide source and target for compare."
        PathMissing="Path does not exist:"

        HelpTitle="Quick guide"
        HelpSub="Short: set paths, verify preview, optionally compare, then sync."
        HelpText=(
            "Source and Target",
            "Choose source and target (local, mapped drive, or UNC).",
            "Examples:",
			"  - Local:  C:\Data   ->   D:\Backup",
			"  - Network share (recommended):  Z:\Folder   ->   D:\Backup   (map \\server\share to Z:)",
			"  - UNC (fallback):   \\server\share\Folder   ->   \\server\share\Backup",
            "For UNC, the tool may ask once for credentials.",
            "Best practice: map share to a drive (e.g. Z:) then use Z:\Folder -> D:\Backup.",
            "",
            "Language",
            "The tool supports English and German.",
            "Start with -Lang en for English or -Lang de for German.",
            "Example: waltrone1-RoboSync-Manager.exe -Lang de",
            "",
            "Synchronization",
            "Transfers data from source to target via robocopy.",
            "Always check the preview before starting.",
            "Options:",
            "  - MOVE   = moves files. The source is emptied after successful copy.",
            "  - MIRROR = target matches source. Extra files in the target are deleted.",
            "  - /MT    = multi-threaded copy. Robocopy copies multiple files in parallel.",
            "            Useful for many small files. Start with 8 or 16 threads.",
            "            Very high values can slow down NAS or network shares.",
            "  - MIR safety threshold = pre-check before a mirror job starts.",
            "            It is enabled automatically when MIRROR is selected.",
            "            Source and target are scanned first. If the planned changes exceed",
            "            the selected percentage, the job stops and asks for confirmation.",
            "            This helps prevent accidental mass deletions, a wrong source path,",
            "            or ransomware-encrypted files from being mirrored to the target.",
            "",
            "Important",
            "MIRROR can delete files in the target. The safety threshold is a guard rail,",
            "but it is not a replacement for real backups and careful testing.",
            "",
            "Compare",
            "Checks source and target without changes and shows differences.",
            "Option:",
            "  - SHA256 hash compare = slower, exact",
            "Tip: Double-click a result to open it in Explorer."
        ) -join "`r`n"

		HelpUncCompareLim="Note: UNC compare may be slow and requires permissions. If it fails, try mapping a drive or re-authenticate."
        InfoSub="Version, build and tool details - at a glance."
        InfoDesc="Synchronization and directory comparison (sync + compare) based on robocopy."
        OfficialWebsite="Visit Official Website"

        # -------------------------
        # REPORT / HTML (NEW + FULL)
        # -------------------------
        ReportTitle="Report"
        ReportGenerated="Report generated with"
        ReportCreatedOn="Created on"
        ReportMode="Mode"
        ReportScanned="Scanned"
        ReportFiles="Files"
        ReportDuration="Duration"
        ReportErrors="Errors"
        ReportWarnings="Warnings"
        ReportSummary="Summary"
        ReportLogExtract="Log (extract)"
        ReportSearchPlaceholder="Search (file, folder, error, code, ...)"
        ReportReset="Reset"

        CompareReportTitle="Compare Report"
        CompareSummary="Compare Summary"
        OnlyInSource="Only in source"
        OnlyInTarget="Only in target"
        Different="Different"

        # KPI labels (for HTML tiles)
        StartLbl="Start"
        EndLbl="End"
        ExitCodeLbl="ExitCode"

        # Generic table headers
        Metric="Metric"
        Value="Value"
        Notes="Notes"

        # Meta labels
        HostLbl="Host"

        # Status history section
        StatusHistoryTitle="Status (History)"

        # Log/Status table headers
        TimeLbl="Time"
        TypeLbl="Type"
        MessageLbl="Message"

        # Compare report table headers
        StatusLbl="Status"
        TypeColLbl="Type"
        PathLbl="Path"
        SourceLbl="Source"
        TargetLbl="Target"

        # Notes text used in summary table
        NoteStartBtn="Time when Start button was pressed"
        NoteEndOrAbort="Time when finished or aborted"
        NoteRuntimeTotal="Total runtime"
        NoteRcExitCode="robocopy ExitCode (>=8 = error)"
        NoteBestEffortParse="Best-effort parse"

        FooterLangHint="Language/Sprache: waltrone1-RoboSync-Manager.exe -Lang de | -Lang en"
    }

    de = @{
        Info="Info"; Ok="OK"; Error="Fehler"; Warning="Warnung"; Note="Hinweis"; Ready="Bereit"; Done="Fertig"
        Source="Quelle"; Target="Ziel"; Browse="Durchsuchen..."; Reset="Reset"

		CmpBestEffortNote="Hinweis: Der Vergleich ist Best-Effort. Bei sehr vielen Dateien oder Zugriffsproblemen werden moeglicherweise nicht alle Eintraege angezeigt."
		CmpUiTruncated="UI zeigt nur die ersten {0:n0} von {1:n0} Eintraegen (Best-Effort). Nutze den HTML-Report fuer die komplette Liste."

	    UncBestPractice="UNC-Pfade funktionieren, sind aber fuer grosse Sync-Jobs nicht empfohlen. Best Practice: Share zuerst als Netzlaufwerk verbinden (z.B. Z:) und dann ueber den Laufwerksbuchstaben synchronisieren."

        HeaderTitle="Synchronisation & Vergleich"
        HeaderHint="Hinweis: Fuer Shares besser Netzlaufwerk nutzen (z.B. Z:). Optional: SHA256-Vergleich (langsam, exakt)."
        GroupPaths="Quelle und Ziel"
        TabSync="Synchronisation"
        TabCompare="Vergleich"
        TabHelp="Hilfe"
        TabInfo="Info"

        OptTitle="Optionen"
        OptDesc="Quelle/Ziel waehlen, Vorschau pruefen, synchronisieren. MOVE leert Quelle; MIRROR spiegelt inkl. Loeschen im Ziel."
        Move="MOVE - Dateien verschieben (Quelle wird geleert)"
        Mirror="MIRROR - Ziel spiegeln (inkl. Loeschen im Ziel)"
        MirrorWarn="Achtung: MIRROR loescht im ZIEL alles, was nicht in der QUELLE ist!"
        PreviewTitle="Vollstaendiger Robocopy-Befehl (Vorschau)"
        StatusCopying="Kopiervorgang laeuft..."
        StatusCancelReq="Abbruch angefordert..."
        StatusAborted="Abgebrochen"
        StatusNoRun="Kein laufender Vorgang."
        Start="Start"
        Cancel="Abbrechen"
        ClearOutput="Ausgabe leeren"
        OpenLog="Report oeffnen"
        CopyCmdClipboard="Befehl in Zwischenablage kopiert."
        MissingPaths="Bitte Quelle und Ziel angeben."
        InvalidCombo="MOVE und MIRROR duerfen nicht kombiniert werden."
        MirrorConfirm="ACHTUNG:`nMIRROR loescht zusaetzliche Dateien/Ordner im ZIEL (nicht in der Quelle).`nDas ist nicht rueckgaengig.`n`nFortfahren?"
        MultiThread="MULTITHREAD - parallel kopieren (/MT)"
        MultiThreadThreads="Threads:"
        SafetyThreshold="MIR-Sicherheitslimit"
        SafetyThresholdPct="Limit (%):"
        MirrorSafetyScan="MIR-Sicherheitscheck laeuft..."
        MirrorSafetyOk="MIR-Sicherheitscheck OK: {0} geaenderte Eintraege ({1:n2}%, Limit {2}%)."
        MirrorSafetyCancelled="MIR-Sicherheitscheck durch Benutzer abgebrochen."
        MirrorSafetyExceeded="Sicherheitslimit ueberschritten.`n`nGeplante Aenderungen: {0} Eintraege ({1:n2}%).`nLoeschen im Ziel: {2}`nKopieren aus Quelle: {3}`nUnterschiedlich: {4}`nLimit: {5}%`n`nTrotzdem fortfahren?"
        MirrorSafetyDisableConfirm="MIR-Sicherheitslimit deaktivieren?`n`nWenn MIRROR aktiv ist, koennen Dateien, die in der Quelle fehlen, im Ziel geloescht werden. Das Sicherheitslimit schuetzt vor versehentlichen Massenloeschungen.`n`nOhne Sicherheitslimit fortfahren?"

        CmpOptTitle="Vergleichsoptionen"
        CmpOptDesc="Vergleicht Quelle/Ziel: nur in Quelle, nur in Ziel oder unterschiedlich. Optional SHA256 Hash (langsamer aber exakt)."
        HashCompare="Hash vergleichen (SHA256) - langsam, aber exakt"
        Filter="Filter:"
        CmpTip="Tipp: Doppelklick = im Explorer oeffnen/markieren. Bei 'Unterschiedlich': Doppelklick auf Source/Target oeffnet die Datei."
        CompareStart="Vergleich starten"
        CompareDone="Vergleich fertig"
        CompareRunning="Vergleich laeuft..."
        ClearResult="Ergebnis leeren"
        ReportOpen="HTML-Report oeffnen"
        RunCompareFirst="Bitte zuerst einen Vergleich starten."
        CmpMissing="Bitte Quelle und Ziel fuer den Vergleich angeben."
        PathMissing="Pfad existiert nicht:"

        HelpTitle="Kurzanleitung"
        HelpSub="Kurz: Pfade setzen, Vorschau pruefen, ggf. vergleichen, dann synchronisieren."
        HelpText=(
            "Quelle und Ziel",
            "Quelle und Ziel waehlen (lokal, Netzlaufwerk oder UNC). Beispiele:",
			"  - Lokal:  C:\Daten   ->   D:\Backup",
			"  - Netzlaufwerk (empfohlen):  Z:\Ordner   ->   D:\Backup   (\\server\share als Z: verbinden)",
			"  - UNC (Notloesung):   \\server\share\Ordner   ->   \\server\share\Backup",
            "Bei UNC fragt das Tool ggf. einmalig nach Zugangsdaten.",
            "Best Practice: Share als Netzlaufwerk verbinden (z.B. Z:) und dann Z:\Ordner -> D:\Backup nutzen.",
            "",
            "Sprache",
            "Das Tool unterstuetzt Deutsch und Englisch.",
            "Mit -Lang de auf Deutsch starten oder mit -Lang en auf Englisch.",
            "Beispiel: waltrone1-RoboSync-Manager.exe -Lang de",
            "",
            "Synchronisation",
            "Uebertraegt Daten von Quelle nach Ziel via robocopy.",
            "Vor dem Start immer die Vorschau pruefen.",
            "Optionen:",
            "  - MOVE   = verschiebt Dateien. Die Quelle wird nach erfolgreichem Kopieren geleert.",
            "  - MIRROR = Ziel entspricht Quelle. Zusaetzliche Dateien im Ziel werden geloescht.",
            "  - /MT    = Multithread-Kopie. Robocopy kopiert mehrere Dateien parallel.",
            "            Sinnvoll bei vielen kleinen Dateien. Starte z.B. mit 8 oder 16 Threads.",
            "            Sehr hohe Werte koennen NAS- oder Netzwerkshares ausbremsen.",
            "  - MIR-Sicherheitslimit = Vorabpruefung vor einem Spiegel-Lauf.",
            "            Es wird automatisch aktiviert, sobald MIRROR ausgewaehlt wird.",
            "            Quelle und Ziel werden zuerst gescannt. Wenn die geplanten Aenderungen",
            "            den eingestellten Prozentwert ueberschreiten, stoppt der Job und fragt nach.",
            "            Das schuetzt vor versehentlichem Massenloeschen, falscher Quelle",
            "            oder davor, Ransomware-verschluesselte Dateien ins Ziel zu spiegeln.",
            "",
            "Wichtig",
            "MIRROR kann Dateien im Ziel loeschen. Das Sicherheitslimit ist eine Schutzbremse,",
            "aber kein Ersatz fuer echte Backups und sorgfaeltiges Testen.",
            "",
            "Vergleich",
            "Prueft Quelle und Ziel ohne Aenderungen und zeigt Abweichungen.",
            "Option:",
            "  - SHA256 Hash-Vergleich = langsamer, aber exakt",
            "Tipp: Doppelklick oeffnet ein Ergebnis im Explorer."
        ) -join "`r`n"

		HelpUncCompareLim="Hinweis: UNC-Vergleich kann langsam sein und benoetigt Rechte. Wenn es hakt: Netzlaufwerk mappen oder neu authentifizieren."
        InfoSub="Version, Build und Tool-Details - kompakt auf einen Blick."
        InfoDesc="Synchronisation und Verzeichnisvergleich (Sync + Compare) auf Basis von robocopy."
        OfficialWebsite="Offizielle Webseite besuchen"

        # -------------------------
        # REPORT / HTML (NEW + FULL)
        # -------------------------
        ReportTitle="Report"
        ReportGenerated="Report erstellt mit"
        ReportCreatedOn="Erstellt am"
        ReportMode="Modus"
        ReportScanned="Gescanned"
        ReportFiles="Dateien"
        ReportDuration="Dauer"
        ReportErrors="Fehler"
        ReportWarnings="Warnungen"
        ReportSummary="Zusammenfassung"
        ReportLogExtract="Log (Auszug)"
        ReportSearchPlaceholder="Suche (Datei, Ordner, Fehler, Code, ...)"
        ReportReset="Reset"

        CompareReportTitle="Vergleichs-Report"
        CompareSummary="Vergleich-Zusammenfassung"
        OnlyInSource="Nur in Quelle"
        OnlyInTarget="Nur in Ziel"
        Different="Unterschiedlich"

        # KPI labels (for HTML tiles)
        StartLbl="Start"
        EndLbl="Ende"
        ExitCodeLbl="ExitCode"

        # Generic table headers
        Metric="Metrik"
        Value="Wert"
        Notes="Hinweis"

        # Meta labels
        HostLbl="Host"

        # Status history section
        StatusHistoryTitle="Status (Verlauf)"

        # Log/Status table headers
        TimeLbl="Zeit"
        TypeLbl="Typ"
        MessageLbl="Meldung"

        # Compare report table headers
        StatusLbl="Status"
        TypeColLbl="Typ"
        PathLbl="Pfad"
        SourceLbl="Quelle"
        TargetLbl="Ziel"

        # Notes text used in summary table
        NoteStartBtn="Zeitpunkt: Start-Button gedrueckt"
        NoteEndOrAbort="Zeitpunkt: Ende oder Abbruch"
        NoteRuntimeTotal="Gesamtlaufzeit"
        NoteRcExitCode="robocopy ExitCode (>=8 = Fehler)"
        NoteBestEffortParse="Best-effort Parse"

        FooterLangHint="Language/Sprache: waltrone1-RoboSync-Manager.exe -Lang de | -Lang en"
    }
}

function T([string]$key) {
    $lang = if ($script:I18N.ContainsKey($script:Lang)) { $script:Lang } else { "en" }
    if ($script:I18N[$lang].ContainsKey($key)) { return [string]$script:I18N[$lang][$key] }
    if ($script:I18N["en"].ContainsKey($key)) { return [string]$script:I18N["en"][$key] }
    return $key
}

# =========================
# GLOBALS
# =========================
$script:CachedCred        = $null
$script:CurrentProc       = $null
$script:CancelRequested   = $false
$script:OutQueue          = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$script:CompareUiMaxRows = 25000
$script:LblCmpUiLimit    = $null

# In-memory Sync log buffer (no .log file)
$script:SyncLines         = New-Object System.Collections.Generic.List[string]

# HTML write throttling (avoid rewriting too often)
$script:LastSyncHtmlWriteUtc = $null

# Sync runtime meta (for HTML KPIs + status history)
$script:SyncStart         = $null   # [datetime] local time
$script:SyncEnd           = $null   # [datetime] local time
$script:SyncExitCode      = $null   # int robocopy exit code

# Keep a short status timeline (objects with Time/Text)
$script:StatusHistory     = New-Object System.Collections.Generic.List[object]

# BaseDir (PS2EXE safe)
$script:BaseDir = if ($PsscriptRoot -and $PsscriptRoot.Trim()) {
    $PsscriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    (Get-Location).Path
}

# Sync HTML report timestamp (ONLY HTML)
$script:SyncStamp = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
$script:SyncHtml  = Join-Path $script:BaseDir ("Robocopy_{0}.html" -f $script:SyncStamp)

# Compare cache
$script:LastCompareResult = @()
$script:CompareRan        = $false
$script:LastCompareStamp  = $null
$script:LastCompareJson   = $null
$script:LastCompareHtml   = $null

# =========================
# THEME
# =========================
$Theme = @{
    Bg           = [System.Drawing.Color]::White
    HeaderBg     = [System.Drawing.Color]::FromArgb(245, 247, 250)
    Surface      = [System.Drawing.Color]::White
    Border       = [System.Drawing.Color]::FromArgb(215, 220, 228)
    MutedText    = [System.Drawing.Color]::FromArgb(95, 105, 115)
    Text         = [System.Drawing.Color]::FromArgb(25, 32, 40)

    Primary      = [System.Drawing.Color]::FromArgb(33, 150, 243)
    PrimaryHover = [System.Drawing.Color]::FromArgb(25, 118, 210)

    Success      = [System.Drawing.Color]::FromArgb(76, 175, 80)
    SuccessHover = [System.Drawing.Color]::FromArgb(56, 142, 60)
}

# Friendly Yellow output fields
$uiOutYellow   = [System.Drawing.Color]::FromArgb(255, 251, 230)
$uiOutText     = [System.Drawing.Color]::FromArgb(60, 50, 20)

function UI-Message([string]$text, [string]$title="Info", $icon=[System.Windows.Forms.MessageBoxIcon]::Information) {
    [void][System.Windows.Forms.MessageBox]::Show(
        $text, $title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        $icon
    )
}

function Style-PrimaryButton {
    param([System.Windows.Forms.Button]$Button, [System.Drawing.Color]$Back, [System.Drawing.Color]$Hover)
    $Button.FlatStyle = 'Flat'
    $Button.FlatAppearance.BorderSize = 0
    $Button.BackColor = $Back
    $Button.ForeColor = [System.Drawing.Color]::White
    $Button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $Button.Cursor = 'Hand'
    $Button.Height = 38
    $Button.Tag = @{ Back = $Back; Hover = $Hover }
    $Button.Add_MouseEnter({ if ($this.Tag -and $this.Tag.Hover) { $this.BackColor = $this.Tag.Hover } })
    $Button.Add_MouseLeave({ if ($this.Tag -and $this.Tag.Back)  { $this.BackColor = $this.Tag.Back } })
}

function Style-SecondaryButton {
    param([System.Windows.Forms.Button]$Button)
    $Button.FlatStyle = 'Flat'
    $Button.FlatAppearance.BorderSize = 1
    $Button.FlatAppearance.BorderColor = $Theme.Border
    $Button.BackColor = [System.Drawing.Color]::White
    $Button.ForeColor = [System.Drawing.Color]::FromArgb(35,45,55)
    $Button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    $Button.Cursor = 'Hand'
    $Button.Height = 38
    $Button.Tag = @{ Back = [System.Drawing.Color]::White; Hover = [System.Drawing.Color]::FromArgb(245, 247, 250) }
    $Button.Add_MouseEnter({ $this.BackColor = $this.Tag.Hover })
    $Button.Add_MouseLeave({ $this.BackColor = $this.Tag.Back })
}

function Style-GroupBoxCard {
    param([System.Windows.Forms.GroupBox]$Group)
    $Group.BackColor = $Theme.Surface
    $Group.ForeColor = [System.Drawing.Color]::FromArgb(35,45,55)
    $Group.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
}

function New-CardPanel {
    param([int]$PaddingAll = 12)
    $p = New-Object System.Windows.Forms.Panel
    $p.BackColor   = $Theme.Surface
    $p.Padding     = New-Object System.Windows.Forms.Padding($PaddingAll)
    $p.Margin      = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
    $p.BorderStyle = 'FixedSingle'
    return $p
}

# =========================
# Inputs (Shadow style)
# =========================
function New-ShadowInput {
    param([Parameter(Mandatory=$true)][System.Windows.Forms.TextBox]$TextBox)

    $blueCard   = [System.Drawing.Color]::FromArgb(232, 242, 255)
    $blueShadow = [System.Drawing.Color]::FromArgb(240, 245, 252)
    $blueText   = [System.Drawing.Color]::FromArgb(25, 58, 92)

    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Dock      = 'Fill'
    $wrap.BackColor = $blueShadow
    $wrap.Margin    = New-Object System.Windows.Forms.Padding(0, 6, 10, 6)
    $wrap.Padding   = New-Object System.Windows.Forms.Padding(0, 0, 2, 2)

    $card = New-Object System.Windows.Forms.Panel
    $card.Dock        = 'Fill'
    $card.BackColor   = $blueCard
    $card.Padding     = New-Object System.Windows.Forms.Padding(10, 7, 10, 7)
    $card.BorderStyle = 'FixedSingle'
    [void]$wrap.Controls.Add($card)

    $TextBox.BorderStyle = 'None'
    $TextBox.Dock        = 'Fill'
    $TextBox.BackColor   = $blueCard
    $TextBox.ForeColor   = $blueText
    $TextBox.Font        = New-Object System.Drawing.Font("Segoe UI", 10)
    $TextBox.Multiline   = $false
    $TextBox.Margin      = New-Object System.Windows.Forms.Padding(0)

    [void]$card.Controls.Add($TextBox)
    return $wrap
}

function New-InputRow {
    param(
        [string]$LabelText,
        [System.Windows.Forms.TextBox]$TextBox,
        [System.Windows.Forms.Button]$Button
    )

    $row = New-Object System.Windows.Forms.TableLayoutPanel
    $row.ColumnCount = 3
    $row.RowCount    = 1
    $row.Dock        = 'Top'
    $row.Height      = 44
    $row.Margin      = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)
    $row.BackColor   = [System.Drawing.Color]::Transparent

    [void]$row.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 70)))
    [void]$row.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$row.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 110)))
    [void]$row.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = $LabelText
    $lbl.ForeColor = $Theme.MutedText
    $lbl.AutoSize  = $true
    $lbl.Anchor    = 'Left'
    $lbl.Margin    = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)

    $shadowInput = New-ShadowInput -TextBox $TextBox
    $shadowInput.Dock   = 'Fill'
    $shadowInput.Margin = New-Object System.Windows.Forms.Padding(0, 6, 10, 6)

    $Button.Width  = 110
    $Button.Height = 32
    Style-SecondaryButton $Button
    $Button.Anchor = 'Right'
    $Button.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 6)

    [void]$row.Controls.Add($lbl,         0, 0)
    [void]$row.Controls.Add($shadowInput, 1, 0)
    [void]$row.Controls.Add($Button,      2, 0)
    return $row
}

function Open-ExplorerToPath {
    param([Parameter(Mandatory=$true)][string]$Path, [switch]$Select)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if ($Select -and -not (Test-Path -LiteralPath $Path -PathType Container)) {
        Start-Process explorer.exe -ArgumentList "/select,`"$Path`""
    } else {
        Start-Process explorer.exe -ArgumentList "`"$Path`""
    }
}

# =========================
# TASK SCHEDULER HELPERS
# =========================
function Get-ExePath {
    if ($MyInvocation.MyCommand.Path) { return $MyInvocation.MyCommand.Path }
    return (Join-Path $script:BaseDir $script:ToolExeName)
}

function Install-RoboSyncTask {
    param(
        [ValidateSet("ATSTARTUP","DAILY")]
        [string]$Mode = "ATSTARTUP",
        [string]$DailyTime = "02:00"
    )

    Import-Module ScheduledTasks -ErrorAction Stop

    $exe = Get-ExePath
    if (-not (Test-Path -LiteralPath $exe)) {
        UI-Message "EXE not found:`n$exe" (T "Error") ([System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $action  = New-ScheduledTaskAction -Execute $exe -Argument "--task"
    $trigger = if ($Mode -eq "ATSTARTUP") {
        New-ScheduledTaskTrigger -AtStartup
    } else {
        $t = [datetime]::ParseExact($DailyTime, "HH:mm", $null)
        New-ScheduledTaskTrigger -Daily -At $t
    }

    $settings = New-ScheduledTaskSettingsset `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 12)

    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal

    try {
        Register-ScheduledTask -TaskName $script:ToolTaskName -TaskPath $script:ToolTaskPath -InputObject $task -Force | Out-Null
        UI-Message ("Task installed:`n{0}{1}" -f $script:ToolTaskPath, $script:ToolTaskName) (T "Ok")
    } catch {
        UI-Message ("Task install failed:`n{0}" -f $_.Exception.Message) (T "Error") ([System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Remove-RoboSyncTask {
    try {
        Unregister-ScheduledTask -TaskName $script:ToolTaskName -TaskPath $script:ToolTaskPath -Confirm:$false -ErrorAction Stop
        UI-Message ("Task removed:`n{0}{1}" -f $script:ToolTaskPath, $script:ToolTaskName) (T "Ok")
    } catch {
        UI-Message ("Task not found / could not remove:`n{0}" -f $_.Exception.Message) (T "Note") ([System.Windows.Forms.MessageBoxIcon]::Warning)
    }
}

function Run-RoboSyncTaskOnce {
    try {
        Start-ScheduledTask -TaskName $script:ToolTaskName -TaskPath $script:ToolTaskPath
        UI-Message "Task started once." (T "Ok")
    } catch {
        UI-Message ("Task start failed:`n{0}" -f $_.Exception.Message) (T "Error") ([System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# =========================
# LOG + LATEST REPORT (HTML ONLY)
# =========================

function Log([string]$Text) {
    if (-not $Text) { return }

    # UI output
    if ($txtOut -and -not $txtOut.IsDisposed) {
        $txtOut.AppendText($Text + "`r`n")
    }

    # In-memory log buffer (no .log file)
    if (-not $script:SyncLines) {
        $script:SyncLines = New-Object System.Collections.Generic.List[string]
    }

    # Cap to avoid endless growth
    $maxLines = 6000
    if ($script:SyncLines.Count -ge $maxLines) {
        $script:SyncLines.RemoveAt(0)
    }

    [void]$script:SyncLines.Add($Text)

    # Enable button + update HTML report
    Set-LogButtonState
    try { Write-SyncHtmlReport -Force:$false } catch { }
}

function Push-Status([string]$Text) {
    if (-not $Text) { return }

    if (-not $script:StatusHistory) {
        $script:StatusHistory = New-Object System.Collections.Generic.List[string]
    }

    # Cap to avoid endless growth
    $max = 200
    if ($script:StatusHistory.Count -ge $max) {
        $script:StatusHistory.RemoveAt(0)
    }

    [void]$script:StatusHistory.Add($Text)

    # Ensure HTML updates even if no new log lines arrive
    Set-LogButtonState
    try { Write-SyncHtmlReport -Force:$false } catch { }
}

function Get-LatestRobocopyHtml {
    Get-ChildItem -LiteralPath $script:BaseDir -Filter "Robocopy_*.html" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Set-LogButtonState {
    if (-not $btnLog -or $btnLog.IsDisposed) { return }

    # Prefer current run report if exists, else latest html
    $hasCurrent = ($script:SyncHtml -and (Test-Path -LiteralPath $script:SyncHtml))
    $latest = if ($hasCurrent) {
        Get-Item -LiteralPath $script:SyncHtml -ErrorAction SilentlyContinue
    } else {
        Get-LatestRobocopyHtml
    }

    if (-not $latest) {
        $btnLog.Enabled   = $false
        $btnLog.BackColor = [System.Drawing.Color]::Gainsboro
        $btnLog.ForeColor = [System.Drawing.Color]::FromArgb(80,80,80)
        return
    }

    $btnLog.Enabled = $true
    Style-SecondaryButton $btnLog
}

# =========================
# BROWSE + UNC AUTH
# =========================
function BrowseFolder($tb) {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog

    if ($script:LastBrowsePath -and (Test-Path -LiteralPath $script:LastBrowsePath)) {
        $dlg.SelectedPath = $script:LastBrowsePath
    } elseif ($tb.Text -and (Test-Path -LiteralPath $tb.Text)) {
        $dlg.SelectedPath = $tb.Text
    }

    if ($dlg.ShowDialog() -eq 'OK') {
        $tb.Text = $dlg.SelectedPath
        $script:LastBrowsePath = $dlg.SelectedPath
    }
}

function IsUNC($path) { $path -is [string] -and $path.StartsWith("\\") }

function GetShareRoot($path) {
    $clean = $path.TrimStart('\')
    $p = $clean -split '\\'
    if ($p.Count -lt 2) { return $null }
    "\\$($p[0])\$($p[1])"
}

function Ensure-UNCAuthIfNeeded([string]$pathA, [string]$pathB) {

    if (-not (IsUNC $pathA) -and -not (IsUNC $pathB)) { return }

    $uncPath = if (IsUNC $pathA) { $pathA } else { $pathB }
    $root = GetShareRoot $uncPath
    if (-not $root) { return }

    $maxTries = 3

    for ($try = 1; $try -le $maxTries; $try++) {

        if (-not $script:CachedCred) {
            $script:CachedCred = Get-Credential -Message ("Credentials for {0}" -f $root)
            if (-not $script:CachedCred) { throw "No credentials provided." }
        }

        $user = $script:CachedCred.UserName
        $pass = $script:CachedCred.GetNetworkCredential().Password

        $out  = cmd.exe /c "net use `"$root`" `"$pass`" /user:`"$user`" /persistent:no" 2>&1
        $exit = $LASTEXITCODE
        $msg  = ($out | Out-String).Trim()

        if ($exit -eq 0) {
            Log ("UNC authenticated: {0}" -f $root)
            return
        }

        $is1326 = ($msg -match '\b1326\b')
        $is1219 = ($msg -match '\b1219\b')

        if ($is1326) {
            $script:CachedCred = $null
            if ($try -lt $maxTries) {
                UI-Message ("Username or password is wrong.`n`nPlease re-enter (try {0}/{1})." -f ($try+1), $maxTries) (T "Warning") ([System.Windows.Forms.MessageBoxIcon]::Warning)
                continue
            }
            throw "Username or password is wrong (after $maxTries tries)."
        }

        if ($is1219) {
            # Existing connection with other credentials -> remove, ask again
            cmd.exe /c "net use `"$root`" /delete /y" | Out-Null
            $script:CachedCred = $null

            if ($try -lt $maxTries) {
                UI-Message ("There is already a connection to {0} with different credentials.`n`nConnection removed - please authenticate again (try {1}/{2})." -f $root, ($try+1), $maxTries) `
                    (T "Info") ([System.Windows.Forms.MessageBoxIcon]::Warning)
                continue
            }

            throw "System error 1219: A connection already exists with different credentials."
        }

        # Any other net use error:
        if ($try -lt $maxTries) {
            $script:CachedCred = $null
            UI-Message ("UNC login failed (ExitCode {0}).`n{1}`n`nPlease try again (try {2}/{3})." -f $exit, $msg, ($try+1), $maxTries) `
                (T "Warning") ([System.Windows.Forms.MessageBoxIcon]::Warning)
            continue
        }

        throw ("UNC login failed (ExitCode {0}).`n{1}" -f $exit, $msg)
    }

    throw ("UNC login failed after {0} tries." -f $maxTries)
}

# =========================
# COMMAND BUILD
# =========================
function BuildCmd {
    $src = $txtSrc.Text.Trim()
    $dst = $txtDst.Text.Trim()

    if ($dst -match '^[A-Z]:\\$') { $dst += '.' }

    $args = @("`"$src`"","`"$dst`"","/E","/R:2","/W:5","/NP","/XJ","/FFT")
    if ($chkMove.Checked)   { $args += "/MOVE" }
    if ($chkMirror.Checked) { $args += "/MIR" }

    if ($chkMT -and $chkMT.Checked) {
        $threads = [int]$numMT.Value
        if ($threads -lt 1) { $threads = 1 }
        if ($threads -gt 128) { $threads = 128 }
        $args += ("/MT:{0}" -f $threads)
    }

    return ($args -join " ")
}

# =========================
# COMPARE CORE
# =========================
function Get-DirSnapshot {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [switch]$UseHash
    )

    $root  = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
    $items = Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction Stop

    $list = New-Object System.Collections.Generic.List[object]

    foreach ($i in $items) {
        $rel = $i.FullName.Substring($root.Length).TrimStart('\')

        if ($i.PSIsContainer) {
            $list.Add([pscustomobject]@{
                Key              = "Dir|$rel"
                RelativePath     = $rel
                Type             = 'Dir'
                Length           = $null
                LastWriteTimeUtc = $i.LastWriteTimeUtc
                Hash             = $null
            }) | Out-Null
        }
        else {
            $h = $null
            if ($UseHash) {
                try { $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $i.FullName -ErrorAction Stop).Hash }
                catch { $h = "HASH_ERROR" }
            }

            $list.Add([pscustomobject]@{
                Key              = "File|$rel"
                RelativePath     = $rel
                Type             = 'File'
                Length           = $i.Length
                LastWriteTimeUtc = $i.LastWriteTimeUtc
                Hash             = $h
            }) | Out-Null
        }
    }

    return $list
}

function Compare-Directories {
    param([Parameter(Mandatory=$true)][string]$Source, [Parameter(Mandatory=$true)][string]$Target, [switch]$UseHash)

    $srcSnap = Get-DirSnapshot -Path $Source -UseHash:$UseHash
    $dstSnap = Get-DirSnapshot -Path $Target -UseHash:$UseHash

    $srcMap = @{}; foreach ($s in $srcSnap) { $srcMap[$s.Key] = $s }
    $dstMap = @{}; foreach ($d in $dstSnap) { $dstMap[$d.Key] = $d }

    $keys = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in $srcMap.Keys) { [void]$keys.Add($k) }
    foreach ($k in $dstMap.Keys) { [void]$keys.Add($k) }

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($k in $keys) {
        $inSrc = $srcMap.ContainsKey($k)
        $inDst = $dstMap.ContainsKey($k)

        if ($inSrc -and -not $inDst) {
            $s = $srcMap[$k]
            $out.Add([pscustomobject]@{ Status=(T "OnlyInSource"); Type=$s.Type; Path=$s.RelativePath; Src=""; Dst="" }) | Out-Null
            continue
        }
        if (-not $inSrc -and $inDst) {
            $d = $dstMap[$k]
            $out.Add([pscustomobject]@{ Status=(T "OnlyInTarget"); Type=$d.Type; Path=$d.RelativePath; Src=""; Dst="" }) | Out-Null
            continue
        }

        $s = $srcMap[$k]; $d = $dstMap[$k]
        if ($s.Type -eq 'File') {
            $diff = $false
            if ($UseHash) { if ($s.Hash -ne $d.Hash) { $diff = $true } }
            else { if ($s.Length -ne $d.Length -or $s.LastWriteTimeUtc -ne $d.LastWriteTimeUtc) { $diff = $true } }

            if ($diff) {
                $out.Add([pscustomobject]@{
                    Status=(T "Different"); Type="File"; Path=$s.RelativePath
                    Src=$(if($UseHash){$s.Hash}else{"{0} | {1}" -f $s.Length, $s.LastWriteTimeUtc})
                    Dst=$(if($UseHash){$d.Hash}else{"{0} | {1}" -f $d.Length, $d.LastWriteTimeUtc})
                }) | Out-Null
            }
        } else {
            if ($s.LastWriteTimeUtc -ne $d.LastWriteTimeUtc) {
                $out.Add([pscustomobject]@{ Status=(T "Different"); Type="Dir"; Path=$s.RelativePath; Src=$s.LastWriteTimeUtc; Dst=$d.LastWriteTimeUtc }) | Out-Null
            }
        }
    }
    return $out
}


function Test-MirrorSafetyThreshold {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Target,
        [int]$ThresholdPercent = 10
    )

    if ($ThresholdPercent -lt 1) { $ThresholdPercent = 1 }
    if ($ThresholdPercent -gt 100) { $ThresholdPercent = 100 }

    $srcSnap = @(Get-DirSnapshot -Path $Source)
    $dstSnap = @(Get-DirSnapshot -Path $Target)

    $srcMap = @{}
    foreach ($s in $srcSnap) { $srcMap[$s.Key] = $s }

    $dstMap = @{}
    foreach ($d in $dstSnap) { $dstMap[$d.Key] = $d }

    $keys = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in $srcMap.Keys) { [void]$keys.Add($k) }
    foreach ($k in $dstMap.Keys) { [void]$keys.Add($k) }

    $copy = 0
    $delete = 0
    $different = 0

    foreach ($k in $keys) {
        $inSrc = $srcMap.ContainsKey($k)
        $inDst = $dstMap.ContainsKey($k)

        if ($inSrc -and -not $inDst) { $copy++; continue }
        if (-not $inSrc -and $inDst) { $delete++; continue }

        $s = $srcMap[$k]
        $d = $dstMap[$k]

        # Count changed files. Directory timestamp differences are ignored to avoid false positives.
        if ($s.Type -eq 'File') {
            if ($s.Length -ne $d.Length -or $s.LastWriteTimeUtc -ne $d.LastWriteTimeUtc) {
                $different++
            }
        }
    }

    $affected = $copy + $delete + $different
    $basis = [Math]::Max([Math]::Max($srcSnap.Count, $dstSnap.Count), 1)
    $percent = [Math]::Round((($affected / $basis) * 100), 2)

    return [pscustomobject]@{
        Affected         = $affected
        Percent          = $percent
        ThresholdPercent = $ThresholdPercent
        Copy             = $copy
        Delete           = $delete
        Different        = $different
        SourceCount      = $srcSnap.Count
        TargetCount      = $dstSnap.Count
        Basis            = $basis
        Exceeds          = ($percent -gt $ThresholdPercent)
    }
}

function Render-CompareList {
    param([object[]]$Rows)

    $listCmp.BeginUpdate()
    $listCmp.Items.Clear()

    $prio = @{
        (T "Different")    = 0
        (T "OnlyInSource") = 1
        (T "OnlyInTarget") = 2
    }

    $all = @($Rows)
    $total = $all.Count

    $sorted = $all | Sort-Object @{ Expression = { $prio[$_.Status] } }, Type, Path

    $limit = [int]$script:CompareUiMaxRows
    $toRender = $sorted
    $isTruncated = $false

    if ($limit -gt 0 -and $total -gt $limit) {
        $toRender = $sorted | Select-Object -First $limit
        $isTruncated = $true
    }

    # Update UI hint label (below buttons)
    if ($script:LblCmpUiLimit -and -not $script:LblCmpUiLimit.IsDisposed) {
        if ($isTruncated) {
            $script:LblCmpUiLimit.Text = ((T "CmpUiTruncated") -f $limit, $total)
        } else {
            $script:LblCmpUiLimit.Text = ""
        }
    }

    foreach ($row in $toRender) {

        $item = New-Object System.Windows.Forms.ListViewItem($row.Status)
        [void]$item.SubItems.Add($row.Type)
        [void]$item.SubItems.Add($row.Path)
        [void]$item.SubItems.Add([string]$row.Src)
        [void]$item.SubItems.Add([string]$row.Dst)
        $item.Tag = $row

        switch ($row.Status) {
            (T "OnlyInSource") { $item.ForeColor = [System.Drawing.Color]::FromArgb(255, 111, 0) }
            (T "OnlyInTarget") { $item.ForeColor = [System.Drawing.Color]::FromArgb(93, 64, 55) }
            (T "Different")    { $item.ForeColor = [System.Drawing.Color]::FromArgb(211, 47, 47) }
        }

        [void]$listCmp.Items.Add($item)
    }

    $listCmp.EndUpdate()
}

function Apply-CompareFilter {
    $q = $txtSearch.Text.Trim().ToLowerInvariant()
    $rows = $script:LastCompareResult
    if ($null -eq $rows) { return }

    if ($q) {
        $rows = $rows | Where-Object {
            ($_.Status -as [string]).ToLowerInvariant().Contains($q) -or
            ($_.Type   -as [string]).ToLowerInvariant().Contains($q) -or
            ($_.Path   -as [string]).ToLowerInvariant().Contains($q)
        }
    }

    Render-CompareList -Rows $rows
}

# =========================
# DEFAULT HTML TEMPLATE (shared for Sync + Compare)
# =========================
function HtmlEnc([string]$s) {
    if ($null -eq $s) { return "" }
    [System.Net.WebUtility]::HtmlEncode($s)
}

function New-DefaultHtml {
    param(
        [Parameter(Mandatory=$true)][string]$PageTitle,
        [Parameter(Mandatory=$true)][string]$H1,

        [Parameter()][AllowEmptyString()][string]$MetaHtml = "",
        [Parameter()][AllowEmptyString()][string]$KpiHtml  = "",
        [Parameter()][AllowEmptyString()][string]$MainHtml = "",

        [Parameter(Mandatory=$true)][string]$RevisionText,
        [Parameter(Mandatory=$true)][string]$LinkUrl,
        [Parameter(Mandatory=$true)][string]$LinkText,
        [ValidateSet("de","en")]
        [string]$HtmlLang = "en"
    )

@"
<!DOCTYPE html>
<html lang="$(HtmlEnc $HtmlLang)">
<head>
<meta charset="UTF-8">
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title>$PageTitle</title>

<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet">
<style>
:root{
  --brand:#0b3a67;
  --bg:#f4f6f8;
  --card:#ffffff;
  --muted:#6b7280;
  --line:#e5e7eb;
  --shadow:0 6px 18px rgba(16,24,40,.08);
  --radius:12px;
}
*{box-sizing:border-box}
body{
  font-family:Segoe UI, Roboto, Arial, sans-serif;
  background:var(--bg);
  margin:20px;
  color:#1f2933;
}
h1{margin:0 0 6px 0;font-size:28px}
h2{margin:18px 0 8px 0;font-size:18px}
.small{font-size:12px;color:var(--muted)}
.meta{line-height:1.35}
hr.sep{border:none;border-top:1px solid var(--line);margin:16px 0}

.pathgrid{
  display:grid;
  grid-template-columns: 90px 1fr;
  gap:8px 12px;
  margin-top:10px;
  padding-top:10px;
  border-top:1px dashed var(--line);
}
.badge{
  display:inline-block;
  padding:4px 10px;
  border-radius:999px;
  font-weight:700;
  font-size:12px;
  border:1px solid rgba(0,0,0,.08);
}
.badge.src{ background:#e8f0ff; color:#0b3a67; }
.badge.dst{ background:#e6f3f1; color:#14532d; }
.pathval{
  background:#f8fafc;
  border:1px solid var(--line);
  border-radius:10px;
  padding:6px 10px;
  font-family:Consolas, monospace;
  font-size:12px;
  color:#111827;
  word-break:break-word;
}

.header{
  display:flex;
  justify-content:space-between;
  gap:20px;
  align-items:flex-start;
  margin-bottom:14px;
}
.brandbox{
  background:var(--card);
  padding:16px 18px;
  border-radius:var(--radius);
  box-shadow:var(--shadow);
  border:1px solid rgba(0,0,0,.04);
  flex:1;
}
.logo-wrap{
  display:flex;
  align-items:flex-start;
  justify-content:flex-end;
  min-width:190px;
}
.logo-link{display:inline-block;text-decoration:none}
.logo{
  height:120px;
  width:auto;
  border-radius:14px;
  box-shadow:0 4px 10px rgba(0,0,0,.10);
  border:1px solid rgba(0,0,0,.06);
}

.section{
  background:var(--card);
  padding:20px;
  border-radius:var(--radius);
  box-shadow:var(--shadow);
  margin-bottom:20px;
  border:1px solid rgba(0,0,0,.04);
}

/* KPIs: 6 Kacheln sauber in einer Zeile */
.kpis{
  display:grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap:10px;
  margin-top:10px;
  align-items:stretch;
}

.kpi{
  background:#f8fafc;
  border:1px solid var(--line);
  border-radius:12px;
  padding:10px 12px;
  min-width:0; /* wichtig fuer Grid */
}

.kpi b{font-size:18px;display:block}
.kpi span{font-size:12px;color:var(--muted)}

/* Responsive: wenn das Fenster wirklich zu schmal wird, darf es umbrechen */
@media (max-width: 1100px){
  .kpis{
    grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  }
}

.kpi b{font-size:18px;display:block}
.kpi span{font-size:12px;color:var(--muted)}

table{
  width:100%;
  border-collapse:collapse;
  border-radius:10px;
  overflow:hidden;
}
th{
  background:var(--brand);
  color:#fff;
  padding:10px;
  font-size:13px;
  text-align:left;
}
td{
  padding:9px;
  border-bottom:1px solid var(--line);
  font-size:13px;
  vertical-align:top;
}
tr.system{background:#ffffff}
tr.valid{background:#e6f3f1}
tr.expiring{background:#fff4e6}
tr.expired{background:#ffe7e7}
tr.info{background:#e8f0ff}

.toolbar{
  display:flex;
  gap:10px;
  align-items:center;
  flex-wrap:wrap;
}
input[type="text"]{
  padding:8px 10px;
  width:460px;
  max-width:100%;
  border-radius:10px;
  border:1px solid #d1d5db;
  outline:none;
}
input[type="text"]:focus{
  border-color:var(--brand);
  box-shadow:0 0 0 3px rgba(11,58,103,.15);
}
button{
  padding:8px 14px;
  border-radius:10px;
  font-weight:700;
  border:1px solid rgba(0,0,0,.08);
  cursor:pointer;
  background:#ffffff;
  transition: transform .08s ease, filter .15s ease, box-shadow .15s ease;
}
button:hover{
  filter: brightness(1.03);
  box-shadow: 0 8px 18px rgba(0,0,0,.10);
  transform: translateY(-1px);
}
button:active{
  transform: translateY(0px);
  filter: brightness(.98);
  box-shadow: 0 2px 6px rgba(0,0,0,.10);
}
button:focus-visible{
  outline: 3px solid rgba(11,58,103,.25);
  outline-offset: 2px;
}

footer.footer{
  margin-top:18px;
  font-size:12px;
  color:var(--muted);
  text-align:right;
  padding:10px 12px;
  width:100%;
  background:var(--card);
  border:1px solid var(--line);
  border-radius:10px;
  box-shadow:0 2px 4px rgba(0,0,0,.06);
  line-height:1.35;
}
footer.footer b{color:#374151}
.rev{
  display:inline-block;
  padding:2px 8px;
  margin-left:6px;
  border-radius:999px;
  border:1px solid var(--line);
  background:#f8fafc;
  color:var(--muted);
  font-weight:800;
  font-size:11px;
}
footer.footer a{
  display:inline-block;
  padding:4px 10px;
  border-radius:999px;
  background:var(--brand);
  color:#fff;
  text-decoration:none;
  font-family:Roboto,Segoe UI,Arial,sans-serif;
  font-weight:500;
  letter-spacing:.3px;
  transition: transform .08s ease, filter .15s ease, box-shadow .15s ease;
}
footer.footer a:hover{
  filter:brightness(1.07);
  box-shadow:0 6px 14px rgba(0,0,0,.12);
  transform: translateY(-1px);
}
footer.footer a:active{
  transform: translateY(0px);
  filter:brightness(.98);
  box-shadow:0 2px 6px rgba(0,0,0,.10);
}
footer.footer a:focus-visible{
  outline: 3px solid rgba(11,58,103,.25);
  outline-offset: 2px;
}
.footer-row{
  display:flex;
  justify-content:space-between;
  align-items:center;
  gap:10px;
  flex-wrap:wrap;
}
.footer-hint{
  display:inline-block;
  padding:4px 10px;
  border-radius:999px;
  background:var(--brand);
  color:#fff;
  font-family:Roboto,Segoe UI,Arial,sans-serif;
  font-weight:500;
  letter-spacing:.3px;
  white-space:nowrap;
}
</style>

<script>
function normalize(s){
  s = (s === null || s === undefined) ? "" : String(s);
  return s.toLowerCase()
          .replace(/[^a-z0-9\u00C0-\u024F:.\[\]\-\\\/]+/g," ")
          .replace(/\s+/g," ")
          .trim();
}
function applySearch(){
  let q = normalize(document.getElementById("searchBox").value);
  document.querySelectorAll("tr.row").forEach(r=>{
    if(!q){ r.style.display=""; return; }
    let t = normalize(r.innerText);
    r.style.display = t.includes(q) ? "" : "none";
  });
}
function resetAll(){
  document.getElementById("searchBox").value="";
  applySearch();
}
</script>
</head>

<body onload="applySearch();">

<div class="header">
  <div class="brandbox">
    <h1>$H1</h1>
    <div class="meta">
      $MetaHtml
    </div>

    <div class="kpis">
      $KpiHtml
    </div>
  </div>

  <div class="logo-wrap">
    <a class="logo-link" href="$LinkUrl" target="_blank" rel="noopener noreferrer" title="$LinkUrl">
      <img class="logo" src="https://yt3.googleusercontent.com/zXzem7bbA0rm0FKIe8svIoqYl6FS3re2kqx31psWGF3W8SAzpc_kxg_N-y_LLwIHQHOc90nS8w=s900-c-k-c0x00ffffff-no-rj" alt="Logo">
    </a>
  </div>
</div>

<div class="section">
  <div class="toolbar">
    <input id="searchBox" type="text" placeholder="$(HtmlEnc (T "ReportSearchPlaceholder"))" oninput="applySearch()">
    <button onclick="resetAll()">$(HtmlEnc (T "ReportReset"))</button>
  </div>

  <hr class="sep">

  $MainHtml
</div>

<footer class="footer">
  <div class="footer-line1">
    $(HtmlEnc (T "ReportGenerated")) <b>$($script:ToolDisplayName)</b>
    <span class="rev">v$(HtmlEnc $script:AppVersion)</span>
  </div>

  <div class="footer-row" style="margin-top:6px">
    <div class="footer-hint">
      $(HtmlEnc (T "FooterLangHint"))
    </div>
    <div class="footer-line3">
      <a href="$LinkUrl" target="_blank" rel="noopener noreferrer">$LinkText</a>
    </div>
  </div>
</footer>
</body>
</html>
"@
}

function Format-Bytes([double]$bytes) {
    if ($bytes -lt 1024) { return ("{0:n0} B" -f $bytes) }
    if ($bytes -lt 1024*1024) { return ("{0:n1} KB" -f ($bytes/1024)) }
    if ($bytes -lt 1024*1024*1024) { return ("{0:n1} MB" -f ($bytes/1024/1024)) }
    return ("{0:n1} GB" -f ($bytes/1024/1024/1024))
}

function Get-RobocopyKpisFromLog {
    param([string]$LogPath)

    $k = [ordered]@{
        ScannedBytes = $null
        FilesTotal   = $null
        Duration     = $null
        Errors       = $null
        Warnings     = $null
    }

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) { return $k }

    # Best effort parsing (robocopy formats vary by locale); fallback: use file stats
    $lines = Get-Content -LiteralPath $LogPath -ErrorAction SilentlyContinue
    if (-not $lines) { return $k }

    # Errors/Warn: naive parse by keywords
    $k.Errors   = ($lines | Where-Object { $_ -match '\bERROR\b' -or $_ -match '\bFehler\b' }).Count
    $k.Warnings = ($lines | Where-Object { $_ -match '\bWARN\b'  -or $_ -match '\bWarn\b' }).Count

    # Duration: take last timestamp span if present (not guaranteed)
    # fallback: file age
    $fi = Get-Item -LiteralPath $LogPath -ErrorAction SilentlyContinue
    if ($fi) {
        $k.Duration = ""
    }

    return $k
}

function Get-LogExtractRows {
    param(
        [string]$LogPath,
        [int]$MaxLines = 120
    )
    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) { return @() }

    $lines = Get-Content -LiteralPath $LogPath -ErrorAction SilentlyContinue
    if (-not $lines) { return @() }
    $tail = $lines | Select-Object -Last $MaxLines
    return $tail
}

# =========================
# 3) WRITE-SYNCHTMLREPORT (mit Start/Ende/ExitCode + StatusHistory + Log Extract)
# =========================
function Write-SyncHtmlReport {
    param([switch]$Force)

    $hasLines  = ($script:SyncLines -and $script:SyncLines.Count -gt 0)
    $hasstatus = ($script:StatusHistory -and $script:StatusHistory.Count -gt 0)
    if (-not $hasLines -and -not $hasstatus) { return }

	# Avoid rewriting too often unless Force (throttle)
	if (-not $Force -and $script:LastSyncHtmlWriteUtc) {
		$now = (Get-Date).ToUniversalTime()
		if ( ($now - $script:LastSyncHtmlWriteUtc).TotalMilliseconds -lt 800 ) { return }
	}

    $hostName = $env:COMPUTERNAME

    $mode = if ($chkMirror -and $chkMirror.Checked) { "MIRROR" } else { "SYNC" }
    if ($chkMove -and $chkMove.Checked) { $mode = "MOVE" }

    $src = if ($txtSrc) { $txtSrc.Text.Trim() } else { "" }
    $dst = if ($txtDst) { $txtDst.Text.Trim() } else { "" }

    # Runtime meta
    $startTxt = if ($script:SyncStart) { $script:SyncStart.ToString("dd.MM.yyyy HH:mm:ss") } else { "-" }
    $endTxt   = if ($script:SyncEnd)   { $script:SyncEnd.ToString("dd.MM.yyyy HH:mm:ss") } else { "-" }
    $durTxt   = "-"
    if ($script:SyncStart) {
        $endForDur = if ($script:SyncEnd) { $script:SyncEnd } else { Get-Date }
        $ts = New-TimeSpan -Start $script:SyncStart -End $endForDur
        $durTxt = ("{0:00}:{1:00}:{2:00}" -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds)
    }

    $exitCodeTxt = if ($null -ne $script:SyncExitCode) { [string]$script:SyncExitCode } else { "-" }

    # Errors/Warn from in-memory lines
    $lines = if ($hasLines) { @($script:SyncLines) } else { @() }
    $errs  = ($lines | Where-Object { $_ -match '(?i)\berror\b|fehler' }).Count
    $warns = ($lines | Where-Object { $_ -match '(?i)\bwarn\b|warnung' }).Count

# KPIs (du kannst spaeter "Scanned/Files" aus robocopy summary parsen)
$kpiHtml = @"
<div class="kpi"><b>$(HtmlEnc $startTxt)</b><span>$(HtmlEnc (T "StartLbl"))</span></div>
<div class="kpi"><b>$(HtmlEnc $endTxt)</b><span>$(HtmlEnc (T "EndLbl"))</span></div>
<div class="kpi"><b>$(HtmlEnc $durTxt)</b><span>$(HtmlEnc (T "ReportDuration"))</span></div>
<div class="kpi"><b>$(HtmlEnc $exitCodeTxt)</b><span>$(HtmlEnc (T "ExitCodeLbl"))</span></div>
<div class="kpi"><b>$(HtmlEnc $errs)</b><span>$(HtmlEnc (T "ReportErrors"))</span></div>
<div class="kpi"><b>$(HtmlEnc $warns)</b><span>$(HtmlEnc (T "ReportWarnings"))</span></div>
"@.Trim()

$metaHtml = @"
$(HtmlEnc "Host"): <b>$(HtmlEnc $hostName)</b><br>
$(HtmlEnc (T "ReportCreatedOn")): $(HtmlEnc $startTxt)<br>
$(HtmlEnc (T "ReportMode")): <b>$(HtmlEnc $mode)</b>

<div class="pathgrid">
  <div><span class="badge src">$(HtmlEnc (T "Source"))</span></div>
  <div class="pathval">$(HtmlEnc $src)</div>

  <div><span class="badge dst">$(HtmlEnc (T "Target"))</span></div>
  <div class="pathval">$(HtmlEnc $dst)</div>
</div>
"@.Trim()

# Summary table
$summaryHtml = @"
<h2>$(HtmlEnc (T "ReportSummary"))</h2>
<table>
  <tr>
    <th>$(HtmlEnc (T "Metric"))</th>
    <th>$(HtmlEnc (T "Value"))</th>
    <th>$(HtmlEnc (T "Notes"))</th>
  </tr>

  <tr class="row system">
    <td>$(HtmlEnc (T "StartLbl"))</td>
    <td>$(HtmlEnc $startTxt)</td>
    <td class="small">$(HtmlEnc (T "NoteStartBtn"))</td>
  </tr>

  <tr class="row system">
    <td>$(HtmlEnc (T "EndLbl"))</td>
    <td>$(HtmlEnc $endTxt)</td>
    <td class="small">$(HtmlEnc (T "NoteEndOrAbort"))</td>
  </tr>

  <tr class="row valid">
    <td>$(HtmlEnc (T "ReportDuration"))</td>
    <td>$(HtmlEnc $durTxt)</td>
    <td class="small">$(HtmlEnc (T "NoteRuntimeTotal"))</td>
  </tr>

  <tr class="row info">
    <td>$(HtmlEnc (T "ExitCodeLbl"))</td>
    <td>$(HtmlEnc $exitCodeTxt)</td>
    <td class="small">$(HtmlEnc (T "NoteRcExitCode"))</td>
  </tr>

  <tr class="row expiring">
    <td>$(HtmlEnc (T "ReportWarnings"))</td>
    <td>$(HtmlEnc $warns)</td>
    <td class="small">$(HtmlEnc (T "NoteBestEffortParse"))</td>
  </tr>

  <tr class="row expired">
    <td>$(HtmlEnc (T "ReportErrors"))</td>
    <td>$(HtmlEnc $errs)</td>
    <td class="small">$(HtmlEnc (T "NoteBestEffortParse"))</td>
  </tr>
</table>
"@.Trim()

    # Status history (vom Statusfeld / Push-Status)
    $statusHtml = ""
    if ($hasstatus) {
        $sb = New-Object System.Text.StringBuilder
        foreach ($s in (@($script:StatusHistory) | Select-Object -Last 40)) {
            $cls="system"
            if ($s -match '(?i)abort|abbruch|cancel') { $cls="expired" }
            elseif ($s -match '(?i)done|fertig|end')  { $cls="valid" }
            elseif ($s -match '(?i)copy|lauf|progress') { $cls="info" }
            [void]$sb.AppendLine("<tr class='row $cls'><td>&mdash;</td><td>STATUS</td><td class='small'>$(HtmlEnc $s)</td></tr>")
        }

        $statusHtml = @"
<h2>$(HtmlEnc (T "StatusHistoryTitle"))</h2>
<table>
  <tr><th>$(HtmlEnc (T "TimeLbl"))</th><th>$(HtmlEnc (T "TypeLbl"))</th><th>$(HtmlEnc (T "MessageLbl"))</th></tr>
  $($sb.ToString())
</table>
"@.Trim()
    }

    # Log extract (letzte 60 Zeilen)
    $extract = @($lines | Select-Object -Last 60)
    $logRows = New-Object System.Text.StringBuilder
    foreach ($ln in $extract) {
        $type = "INFO"; $cls="system"
        if ($ln -match '(?i)\bwarn\b|warnung') { $type="WARN";  $cls="expiring" }
        elseif ($ln -match '(?i)\berror\b|fehler') { $type="ERROR"; $cls="expired" }
        elseif ($ln -match '(?i)\bfinish\b|fertig|ended|ende|===== END') { $type="OK"; $cls="valid" }

        [void]$logRows.AppendLine("<tr class='row $cls'><td>&mdash;</td><td>$type</td><td class='small'>$(HtmlEnc $ln)</td></tr>")
    }

    $logHtml = @"
<h2>$(HtmlEnc (T "ReportLogExtract"))</h2>
<table>
  <tr><th>$(HtmlEnc (T "TimeLbl"))</th><th>$(HtmlEnc (T "TypeLbl"))</th><th>$(HtmlEnc (T "MessageLbl"))</th></tr>
  $($logRows.ToString())
</table>
"@.Trim()

    $main = @($summaryHtml, $statusHtml, $logHtml) -join "`n`n"

    $html = New-DefaultHtml `
        -PageTitle ("{0} - {1}" -f $script:ToolDisplayName, (T "ReportTitle")) `
        -H1       ("{0} - {1}" -f $script:ToolDisplayName, (T "ReportTitle")) `
        -MetaHtml $metaHtml `
        -KpiHtml  $kpiHtml `
        -MainHtml $main `
        -RevisionText (T "Revision") `
        -LinkUrl  $script:OfficialWebsite `
        -LinkText "w@lt&reg;one1"

    # Write sync HTML (UTF-8 with BOM)
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($script:SyncHtml, $html, $utf8Bom)

    $script:LastSyncHtmlWriteUtc = (Get-Date).ToUniversalTime()
}

# =========================
# WRITE-COMPAREHTMLREPORT
# =========================
function Write-CompareHtmlReport {
    param(
        [Parameter(Mandatory=$false)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Rows = @(),

        [Parameter(Mandatory=$true)][string]$SourceRoot,
        [Parameter(Mandatory=$true)][string]$TargetRoot,
        [switch]$HashUsed
    )

    # normalize
    if ($null -eq $Rows) { $Rows = @() } else { $Rows = @($Rows) }

    # Stamp + paths
    $script:LastCompareStamp = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    $script:LastCompareHtml  = Join-Path $script:BaseDir ("Compare_{0}.html" -f $script:LastCompareStamp)

    $hostName = $env:COMPUTERNAME
    $startTxt = (Get-Date).ToString("dd.MM.yyyy HH:mm:ss")
    $modeTxt  = if ($HashUsed) { "COMPARE (SHA256)" } else { "COMPARE" }

    $onlySrc = ($Rows | Where-Object Status -eq (T "OnlyInSource")).Count
    $onlyDst = ($Rows | Where-Object Status -eq (T "OnlyInTarget")).Count
    $diff    = ($Rows | Where-Object Status -eq (T "Different")).Count

	# ---- Text-Preview Settings (nur fuer Compare-HTML) ----
	$textExts = @(
	  ".txt",".log",".csv",".tsv",
	  ".xml",".json",".yaml",".yml",
	  ".ini",".cfg",".conf",".env",
	  ".md",".html",".htm",".css",".js",".ts",".sql",
	  ".ps1",".psm1",".psd1",".bat",".cmd"
	)
	$maxPreviewBytes = 524288   # 512 KB pro Datei (Sicherheit/Performance)
	$maxDiffLines    = 5        # "erste fuenf Bereiche"

    $kpiHtml = @"
<div class="kpi"><b>$(HtmlEnc $onlySrc)</b><span>$(HtmlEnc (T "OnlyInSource"))</span></div>
<div class="kpi"><b>$(HtmlEnc $onlyDst)</b><span>$(HtmlEnc (T "OnlyInTarget"))</span></div>
<div class="kpi"><b>$(HtmlEnc $diff)</b><span>$(HtmlEnc (T "Different"))</span></div>
<div class="kpi"><b>$(HtmlEnc $modeTxt)</b><span>Mode</span></div>
"@.Trim()

    $metaHtml = @"
$(HtmlEnc "Host"): <b>$(HtmlEnc $hostName)</b><br>
$(HtmlEnc (T "ReportCreatedOn")): $(HtmlEnc $startTxt)<br>
$(HtmlEnc (T "ReportMode")): <b>$(HtmlEnc $modeTxt)</b>

<div class="pathgrid">
  <div><span class="badge src">$(HtmlEnc (T "Source"))</span></div>
  <div class="pathval">$(HtmlEnc $SourceRoot)</div>

  <div><span class="badge dst">$(HtmlEnc (T "Target"))</span></div>
  <div class="pathval">$(HtmlEnc $TargetRoot)</div>
</div>
"@.Trim()

# Table rows
$sb = New-Object System.Text.StringBuilder
foreach ($r in $Rows) {

    $cls = "system"
    if ($r.Status -eq (T "Different"))    { $cls = "expired" }
    if ($r.Status -eq (T "OnlyInSource")) { $cls = "expiring" }
    if ($r.Status -eq (T "OnlyInTarget")) { $cls = "info" }

    $previewHtml = ""

    # Nur bei "Different" + File: bis zu 3 Text-Unterschiede anzeigen
    if ($r.Status -eq (T "Different") -and $r.Type -eq "File" -and $r.Path) {

        $srcFile = Join-Path $SourceRoot $r.Path
        $dstFile = Join-Path $TargetRoot $r.Path

        if ((Test-Path -LiteralPath $srcFile -PathType Leaf) -and (Test-Path -LiteralPath $dstFile -PathType Leaf)) {

            $ext = [System.IO.Path]::GetExtension([string]$r.Path).ToLowerInvariant()

            # "Textartig" ueber Whitelist ODER heuristisch (keine Nullbytes im Header)
            $isText = $false
            if ($textExts -contains $ext) {
                $isText = $true
            } else {
                try {
                    $fs = [System.IO.File]::OpenRead($srcFile)
                    try {
                        $buf = New-Object byte[] 4096
                        $n = $fs.Read($buf, 0, $buf.Length)
                        if ($n -gt 0) {
                            $hasNull = $false
                            for ($i=0; $i -lt $n; $i++) { if ($buf[$i] -eq 0) { $hasNull = $true; break } }
                            if (-not $hasNull) { $isText = $true }
                        }
                    } finally { $fs.Dispose() }
                } catch { }
            }

            if ($isText) {
                try {
                    $fiS = Get-Item -LiteralPath $srcFile -ErrorAction Stop
                    $fiD = Get-Item -LiteralPath $dstFile -ErrorAction Stop

                    if ($fiS.Length -le $maxPreviewBytes -and $fiD.Length -le $maxPreviewBytes) {

                        # Zeilenweise vergleichen und bis zu 3 Unterschiede sammeln
                        $a = Get-Content -LiteralPath $srcFile -ErrorAction Stop
                        $b = Get-Content -LiteralPath $dstFile -ErrorAction Stop

                        $max = [Math]::Max($a.Count, $b.Count)
                        $diffs = New-Object System.Collections.Generic.List[string]

                        for ($i=0; $i -lt $max; $i++) {
                            $sa = if ($i -lt $a.Count) { [string]$a[$i] } else { "" }
                            $sb2 = if ($i -lt $b.Count) { [string]$b[$i] } else { "" }

                            if ($sa -ne $sb2) {
                                $diffs.Add(("Line {0}: SRC: {1}`n         DST: {2}" -f ($i+1), $sa, $sb2)) | Out-Null
                                if ($diffs.Count -ge $maxDiffLines) { break }
                            }
                        }

                        if ($diffs.Count -gt 0) {
                            $txt = ($diffs -join "`n`n")
                            $previewHtml = "<details style='margin-top:6px'><summary><b>Preview</b> (first $($diffs.Count) diffs)</summary><pre style='white-space:pre-wrap;background:#f8fafc;border:1px solid #e5e7eb;border-radius:10px;padding:10px;margin-top:8px'>$(HtmlEnc $txt)</pre></details>"
                        }
                        else {
                            # Keine Zeilen-Diffs gefunden -> oft "unsichtbare" Unterschiede (BOM, CRLF/LF, trailing newline, Tabs/Spaces)
                            # Wir zeigen einen RAW-Preview der ersten Bytes beider Dateien (max 256).

                            $maxRaw = 256
                            $bs = [System.IO.File]::ReadAllBytes($srcFile)
                            $bd = [System.IO.File]::ReadAllBytes($dstFile)

                            $takeS = [Math]::Min($bs.Length, $maxRaw)
                            $takeD = [Math]::Min($bd.Length, $maxRaw)

                            $showBytes = {
                                param([byte[]]$buf, [int]$count)
                                $sb3 = New-Object System.Text.StringBuilder
                                for ($j=0; $j -lt $count; $j++) {
                                    $bb = $buf[$j]
                                    switch ($bb) {
                                        13 { [void]$sb3.Append("\r") }   # CR
                                        10 { [void]$sb3.Append("\n") }   # LF
                                        9  { [void]$sb3.Append("\t") }   # TAB
                                        default {
                                            if ($bb -ge 32 -and $bb -le 126) { [void]$sb3.Append([char]$bb) }
                                            else { [void]$sb3.Append(("\x{0:X2}" -f $bb)) }
                                        }
                                    }
                                }
                                $sb3.ToString()
                            }

                            $rawS = & $showBytes $bs $takeS
                            $rawD = & $showBytes $bd $takeD

                            $txt = @"
(Text file, but no line-diffs detected)

RAW preview (first $maxRaw bytes; CR/LF/TAB shown as \r \n \t, others as \xHH)

SRC bytes: $($bs.Length)
$rawS

DST bytes: $($bd.Length)
$rawD
"@.Trim()

                            $previewHtml = "<details style='margin-top:6px'><summary><b>Preview</b> (raw bytes; invisible diffs)</summary><pre style='white-space:pre-wrap;background:#f8fafc;border:1px solid #e5e7eb;border-radius:10px;padding:10px;margin-top:8px'>$(HtmlEnc $txt)</pre></details>"
                        }

                    } else {
                        $previewHtml = "<div class='small' style='margin-top:6px'>(Preview skipped: file too large)</div>"
                    }
                } catch {
                    $previewHtml = "<div class='small' style='margin-top:6px'>(Preview error: $(HtmlEnc $_.Exception.Message))</div>"
                }
            }
        }
    }

    # Path-Spalte enthaelt Preview (wenn vorhanden)
    [void]$sb.AppendLine(("<tr class='row {0}'><td>{1}</td><td>{2}</td><td>{3}{6}</td><td class='small'>{4}</td><td class='small'>{5}</td></tr>" -f
        $cls,
        (HtmlEnc $r.Status),
        (HtmlEnc $r.Type),
        (HtmlEnc $r.Path),
        (HtmlEnc ([string]$r.Src)),
        (HtmlEnc ([string]$r.Dst)),
        $previewHtml
    ))
}

$mainHtml = @"
<h2>$(HtmlEnc (T "CompareSummary"))</h2>
<table>
  <tr><th>Status</th><th>Type</th><th>Path</th><th>Source</th><th>Target</th></tr>
  $($sb.ToString())
</table>
"@.Trim()

    $html = New-DefaultHtml `
        -PageTitle ("{0} - {1}" -f $script:ToolDisplayName, (T "CompareReportTitle")) `
        -H1       ("{0} - {1}" -f $script:ToolDisplayName, (T "CompareReportTitle")) `
        -MetaHtml $metaHtml `
        -KpiHtml  $kpiHtml `
        -MainHtml $mainHtml `
        -RevisionText (T "Revision") `
        -LinkUrl  "https://waltrone1.de/wltones-admin-tools/" `
        -LinkText "w@lt&reg;one1"

    # Write compare HTML (UTF-8 with BOM)
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($script:LastCompareHtml, $html, $utf8Bom)
}

# =========================
# RUN STATE + OUTPUT QUEUE
# =========================
function Update-MirrorSafetyUi([bool]$running) {
    if (-not $chkMirrorSafety) { return }

    $mirrorOn = $false
    try { $mirrorOn = ($chkMirror -and $chkMirror.Checked) } catch { $mirrorOn = $false }

    if (-not $mirrorOn) {
        if ($chkMirrorSafety.Checked) { $chkMirrorSafety.Checked = $false }
    }

    $safetyOn = $false
    try { $safetyOn = ($mirrorOn -and $chkMirrorSafety.Checked) } catch { $safetyOn = $false }

    $chkMirrorSafety.Enabled = ((-not $running) -and $mirrorOn)

    if ($numMirrorThreshold) {
        $numMirrorThreshold.Enabled = ((-not $running) -and $safetyOn)
    }

    if ($lblMirrorThreshold) {
        $lblMirrorThreshold.Enabled = ((-not $running) -and $safetyOn)
    }
}

function Set-RunState([bool]$running) {
    $btnStart.Enabled  = -not $running
    $btnCancel.Enabled = $running
    $chkMove.Enabled   = -not $running
    $chkMirror.Enabled = -not $running
    if ($chkMT) { $chkMT.Enabled = -not $running }
    if ($numMT) { $numMT.Enabled = ((-not $running) -and $chkMT.Checked) }
    Update-MirrorSafetyUi $running
    $txtSrc.Enabled    = -not $running
    $txtDst.Enabled    = -not $running
    $btnSrc.Enabled    = -not $running
    $btnDst.Enabled    = -not $running
}

function Drain-OutQueue {

    if (-not $script:OutQueue) { return }

    $line = $null
    while ($script:OutQueue.TryDequeue([ref]$line)) {

        if ($line) {
            # Timestamp prefix for HTML readability
            $ts = (Get-Date).ToString("HH:mm:ss")
            $msg = "[{0}] {1}" -f $ts, $line

            Log $msg

            # Optional: status timeline enrichment (only if function exists)
            if (Get-Command Push-Status -ErrorAction SilentlyContinue) {
                # keep status timeline meaningful: only certain lines
                if ($line -match '(?i)\b(error|fehler|warn|warnung|aborted|abbruch|ended|ende|finish|fertig)\b') {
                    Push-Status $msg
                }
            }
        }

        $line = $null
    }
}

# =========================
# FORM
# =========================
$form = New-Object System.Windows.Forms.Form
$form.Text = "$($script:ToolWindowTitle) v$($script:AppVersion)"
$form.Size = New-Object System.Drawing.Size(1100, 920)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.MaximizeBox = $false
$form.FormBorderStyle = 'FixedDialog'
$form.BackColor = $Theme.Bg

$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 5000
$toolTip.InitialDelay = 300
$toolTip.ReshowDelay = 200
$toolTip.ShowAlways = $true

$layout = New-Object System.Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'
$layout.ColumnCount = 1
$layout.RowCount = 3
$layout.BackColor = [System.Drawing.Color]::White
[void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 78)))
[void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 190)))
[void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$form.Controls.Add($layout)

# Header
$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Fill'
$header.BackColor = $Theme.HeaderBg
$header.Padding = New-Object System.Windows.Forms.Padding(18, 12, 18, 12)

$lblHeader = New-Object System.Windows.Forms.Label
$lblHeader.Text = "$($script:ToolDisplayName) - $(T "HeaderTitle")"
$lblHeader.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblHeader.ForeColor = $Theme.Text
$lblHeader.AutoSize = $true
$lblHeader.Location = New-Object System.Drawing.Point(0, 0)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text = (T "HeaderHint")
$lblHint.AutoSize = $true
$lblHint.ForeColor = $Theme.MutedText
$lblHint.Location = New-Object System.Drawing.Point(2, 36)

$header.Controls.AddRange(@($lblHeader,$lblHint))
$layout.Controls.Add($header, 0, 0)

# Paths host
$pathsHost = New-Object System.Windows.Forms.Panel
$pathsHost.Dock = 'Fill'
$pathsHost.Padding = New-Object System.Windows.Forms.Padding(15, 12, 15, 0)
$pathsHost.BackColor = [System.Drawing.Color]::White
$layout.Controls.Add($pathsHost, 0, 1)

$grpPaths = New-Object System.Windows.Forms.GroupBox
$grpPaths.Text = (T "GroupPaths")
$grpPaths.Dock = 'Top'
$grpPaths.Height = 175
Style-GroupBoxCard $grpPaths
$grpPaths.Padding = New-Object System.Windows.Forms.Padding(12, 18, 12, 12)
$pathsHost.Controls.Add($grpPaths)

$txtSrc = New-Object System.Windows.Forms.TextBox
$btnSrc = New-Object System.Windows.Forms.Button
$btnSrc.Text = (T "Browse")

$txtDst = New-Object System.Windows.Forms.TextBox
$btnDst = New-Object System.Windows.Forms.Button
$btnDst.Text = (T "Browse")

$btnSrc.TabStop = $false
$btnDst.TabStop = $false

$txtSrc.TabIndex = 0
$txtDst.TabIndex = 1
$btnSrc.TabIndex = 2
$btnDst.TabIndex = 3

$txtSrc.Add_PreviewKeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Tab) { $_.IsInputKey = $true } })
$txtDst.Add_PreviewKeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Tab) { $_.IsInputKey = $true } })
$txtSrc.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Tab -and -not $_.Shift) { $_.SuppressKeyPress = $true; $txtDst.Focus() } })
$txtDst.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Tab -and $_.Shift) { $_.SuppressKeyPress = $true; $txtSrc.Focus() } })

try {
    $txtSrc.PlaceholderText = if ($script:Lang -eq "de") { "z.B. C:\Daten oder \\server\share\Ordner" } else { "e.g. C:\Data or \\server\share\Folder" }
    $txtDst.PlaceholderText = if ($script:Lang -eq "de") { "z.B. D:\Backup oder \\server\share\Backup" } else { "e.g. D:\Backup or \\server\share\Backup" }
} catch { }

$rowSrc = New-InputRow -LabelText (T "Source") -TextBox $txtSrc -Button $btnSrc
$rowDst = New-InputRow -LabelText (T "Target") -TextBox $txtDst -Button $btnDst

$grpPaths.Controls.Add($rowDst)
$grpPaths.Controls.Add($rowSrc)

# Tabs host
$tabsHost = New-Object System.Windows.Forms.Panel
$tabsHost.Dock = 'Fill'
$tabsHost.Padding = New-Object System.Windows.Forms.Padding(15, 0, 15, 10)
$tabsHost.BackColor = [System.Drawing.Color]::White
$layout.Controls.Add($tabsHost, 0, 2)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$tabs.ItemSize = New-Object System.Drawing.Size(140, 30)
$tabs.TabStop = $false

$tabSync = New-Object System.Windows.Forms.TabPage
$tabSync.Text = (T "TabSync")
$tabSync.BackColor = [System.Drawing.Color]::White

$tabCompare = New-Object System.Windows.Forms.TabPage
$tabCompare.Text = (T "TabCompare")
$tabCompare.BackColor = [System.Drawing.Color]::White

$tabHelp = New-Object System.Windows.Forms.TabPage
$tabHelp.Text = (T "TabHelp")
$tabHelp.BackColor = [System.Drawing.Color]::White

$tabInfo = New-Object System.Windows.Forms.TabPage
$tabInfo.Text = (T "TabInfo")
$tabInfo.BackColor = [System.Drawing.Color]::White

$tabs.TabPages.AddRange(@($tabSync, $tabCompare, $tabHelp, $tabInfo))
$tabsHost.Controls.Add($tabs)

# =========================
# TAB: Sync
# =========================
$syncLayout = New-Object System.Windows.Forms.TableLayoutPanel
$syncLayout.Dock = 'Fill'
$syncLayout.ColumnCount = 1
$syncLayout.RowCount = 5
[void]$syncLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
[void]$syncLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 130)))
[void]$syncLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
[void]$syncLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$syncLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 56)))
$tabSync.Controls.Add($syncLayout)

$optCard = New-CardPanel
$optCard.Dock = 'Fill'

$optTitle = New-Object System.Windows.Forms.Label
$optTitle.Text = (T "OptTitle")
$optTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$optTitle.ForeColor = $Theme.Text
$optTitle.AutoSize = $true

$optDesc = New-Object System.Windows.Forms.Label
$optDesc.Text = (T "OptDesc")
$optDesc.AutoSize = $true
$optDesc.MaximumSize = New-Object System.Drawing.Size(980, 0)
$optDesc.ForeColor = $Theme.MutedText
$optDesc.Location = New-Object System.Drawing.Point(2, 18)

$chkMove = New-Object System.Windows.Forms.CheckBox
$chkMove.Text = (T "Move")
$chkMove.AutoSize = $true
$chkMove.Location = New-Object System.Drawing.Point(2, 52)

$chkMirror = New-Object System.Windows.Forms.CheckBox
$chkMirror.Text = (T "Mirror")
$chkMirror.AutoSize = $true
$chkMirror.Location = New-Object System.Drawing.Point(520, 52)

$lblMirrorWarn = New-Object System.Windows.Forms.Label
$lblMirrorWarn.Text = (T "MirrorWarn")
$lblMirrorWarn.AutoSize = $true
$lblMirrorWarn.ForeColor = [System.Drawing.Color]::FromArgb(198, 40, 40)
$lblMirrorWarn.Location = New-Object System.Drawing.Point(520, 78)
$lblMirrorWarn.Visible = $false

$chkMT = New-Object System.Windows.Forms.CheckBox
$chkMT.Text = (T "MultiThread")
$chkMT.AutoSize = $true
$chkMT.Location = New-Object System.Drawing.Point(2, 82)

$lblMT = New-Object System.Windows.Forms.Label
$lblMT.Text = (T "MultiThreadThreads")
$lblMT.AutoSize = $true
$lblMT.ForeColor = $Theme.MutedText
$lblMT.Location = New-Object System.Drawing.Point(280, 84)

$numMT = New-Object System.Windows.Forms.NumericUpDown
$numMT.Minimum = 1
$numMT.Maximum = 128
$numMT.Value = 8
$numMT.Width = 70
$numMT.Location = New-Object System.Drawing.Point(350, 80)
$numMT.Enabled = $false

$chkMirrorSafety = New-Object System.Windows.Forms.CheckBox
$chkMirrorSafety.Text = (T "SafetyThreshold")
$chkMirrorSafety.AutoSize = $true
$chkMirrorSafety.Checked = $false
$chkMirrorSafety.Enabled = $false
$chkMirrorSafety.Location = New-Object System.Drawing.Point(520, 104)

$lblMirrorThreshold = New-Object System.Windows.Forms.Label
$lblMirrorThreshold.Text = (T "SafetyThresholdPct")
$lblMirrorThreshold.AutoSize = $true
$lblMirrorThreshold.ForeColor = $Theme.MutedText
$lblMirrorThreshold.Enabled = $false
$lblMirrorThreshold.Location = New-Object System.Drawing.Point(760, 106)

$numMirrorThreshold = New-Object System.Windows.Forms.NumericUpDown
$numMirrorThreshold.Minimum = 1
$numMirrorThreshold.Maximum = 100
$numMirrorThreshold.Value = 10
$numMirrorThreshold.Enabled = $false
$numMirrorThreshold.Width = 70
$numMirrorThreshold.Location = New-Object System.Drawing.Point(850, 102)

$optCard.Controls.AddRange(@($optTitle,$optDesc,$chkMove,$chkMirror,$lblMirrorWarn,$chkMT,$lblMT,$numMT,$chkMirrorSafety,$lblMirrorThreshold,$numMirrorThreshold))
$syncLayout.Controls.Add($optCard, 0, 0)

$cmdCard = New-CardPanel
$cmdCard.Dock = 'Fill'

$cmdTitle = New-Object System.Windows.Forms.Label
$cmdTitle.Text = (T "PreviewTitle")
$cmdTitle.ForeColor = $Theme.Text
$cmdTitle.AutoSize = $true

$cmdWrap = New-Object System.Windows.Forms.Panel
$cmdWrap.Location = New-Object System.Drawing.Point(0, 38)
$cmdWrap.Size = New-Object System.Drawing.Size(800, 75)
$cmdWrap.Anchor = 'Top,Left,Right'
$cmdWrap.Padding = New-Object System.Windows.Forms.Padding(8, 7, 8, 7)
$cmdWrap.BorderStyle = 'FixedSingle'
$cmdWrap.BackColor = [System.Drawing.Color]::FromArgb(236, 253, 245)

$txtCmd = New-Object System.Windows.Forms.RichTextBox
$txtCmd.ReadOnly    = $true
$txtCmd.BorderStyle = 'None'
$txtCmd.Dock        = 'Fill'
$txtCmd.WordWrap    = $true
$txtCmd.ScrollBars  = 'Vertical'
$txtCmd.DetectUrls  = $false
$txtCmd.BackColor   = $cmdWrap.BackColor
$txtCmd.ForeColor   = [System.Drawing.Color]::FromArgb(20, 83, 45)
$txtCmd.Font        = New-Object System.Drawing.Font("Consolas", 9)
$txtCmd.TabStop     = $false
$txtCmd.Cursor      = [System.Windows.Forms.Cursors]::Hand

$cmdWrap.Controls.Add($txtCmd)
$cmdCard.Controls.AddRange(@($cmdTitle,$cmdWrap))
$syncLayout.Controls.Add($cmdCard, 0, 1)

$sidePad = 14
$cmdWrap.Left  = $sidePad
$cmdWrap.Width = $cmdCard.ClientSize.Width - ($sidePad * 2)
$cmdCard.Add_SizeChanged({
    $cmdWrap.Left  = $sidePad
    $cmdWrap.Width = $cmdCard.ClientSize.Width - ($sidePad * 2)
})

$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Dock = 'Fill'
$statusPanel.Padding = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = (T "Ready")
$lblStatus.AutoSize = $true
$lblStatus.ForeColor = $Theme.MutedText

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Style = 'Marquee'
$progress.Visible = $false
$progress.Width = 280
$progress.Height = 18
$progress.Location = New-Object System.Drawing.Point(0, 20)

$statusPanel.Controls.AddRange(@($lblStatus,$progress))
$syncLayout.Controls.Add($statusPanel, 0, 2)

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Multiline = $true
$txtOut.ReadOnly = $true
$txtOut.ScrollBars = 'Vertical'
$txtOut.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtOut.BorderStyle = 'FixedSingle'
$txtOut.Dock = 'Fill'
$txtOut.BackColor = $uiOutYellow
$txtOut.ForeColor = $uiOutText
$syncLayout.Controls.Add($txtOut, 0, 3)

$syncBottom = New-Object System.Windows.Forms.Panel
$syncBottom.Dock = 'Fill'
$syncBottom.BackColor = $Theme.HeaderBg

$syncButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$syncButtons.Dock = 'Fill'
$syncButtons.WrapContents = $false
$syncButtons.Padding = New-Object System.Windows.Forms.Padding(12, 9, 12, 9)
$syncButtons.BackColor = $syncBottom.BackColor
$syncBottom.Controls.Add($syncButtons)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = (T "Start")
$btnStart.Width = 140
Style-PrimaryButton $btnStart $Theme.Success $Theme.SuccessHover

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = (T "Cancel")
$btnCancel.Width = 140
Style-PrimaryButton $btnCancel ([System.Drawing.Color]::FromArgb(198, 40, 40)) ([System.Drawing.Color]::FromArgb(176, 32, 32))
$btnCancel.Enabled = $false

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = (T "ClearOutput")
$btnClear.Width = 160
Style-SecondaryButton $btnClear

$btnLog = New-Object System.Windows.Forms.Button
$btnLog.Text = (T "OpenLog")
$btnLog.Width = 160
Style-SecondaryButton $btnLog
Set-LogButtonState

$btnReset = New-Object System.Windows.Forms.Button
$btnReset.Text = (T "Reset")
$btnReset.Width = 120
Style-SecondaryButton $btnReset

$syncButtons.Controls.AddRange(@($btnStart,$btnCancel,$btnClear,$btnLog,$btnReset))
$syncLayout.Controls.Add($syncBottom, 0, 4)

# =========================
# TAB: Compare
# =========================
$cmpLayout = New-Object System.Windows.Forms.TableLayoutPanel
$cmpLayout.Dock = 'Fill'
$cmpLayout.ColumnCount = 1
$cmpLayout.RowCount = 4
[void]$cmpLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
[void]$cmpLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
[void]$cmpLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$cmpLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 56)))
$tabCompare.Controls.Add($cmpLayout)

$cmpOptCard = New-CardPanel
$cmpOptCard.Dock = 'Fill'

$cmpTitle = New-Object System.Windows.Forms.Label
$cmpTitle.Text = (T "CmpOptTitle")
$cmpTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$cmpTitle.ForeColor = $Theme.Text
$cmpTitle.AutoSize = $true

$cmpDesc = New-Object System.Windows.Forms.Label
$cmpDesc.Text = (T "CmpOptDesc")
$cmpDesc.AutoSize = $true
$cmpDesc.MaximumSize = New-Object System.Drawing.Size(980, 0)
$cmpDesc.ForeColor = $Theme.MutedText
$cmpDesc.Location = New-Object System.Drawing.Point(2, 18)

$chkCmpHash = New-Object System.Windows.Forms.CheckBox
$chkCmpHash.Text = (T "HashCompare")
$chkCmpHash.AutoSize = $true
$chkCmpHash.Location = New-Object System.Drawing.Point(2, 52)

$lblSearch = New-Object System.Windows.Forms.Label
$lblSearch.Text = (T "Filter")
$lblSearch.AutoSize = $true
$lblSearch.ForeColor = [System.Drawing.Color]::FromArgb(60, 90, 120)
$lblSearch.Location = New-Object System.Drawing.Point(620, 54)

$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Width = 300
$txtSearch.Location = New-Object System.Drawing.Point(670, 50)
$txtSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$txtSearch.BackColor = [System.Drawing.Color]::FromArgb(232, 242, 255)
$txtSearch.ForeColor = [System.Drawing.Color]::FromArgb(25, 58, 92)
$txtSearch.BorderStyle = 'FixedSingle'

$cmpHint = New-Object System.Windows.Forms.Label
$cmpHint.Text = (T "CmpTip")
$cmpHint.AutoSize = $true
$cmpHint.ForeColor = $Theme.MutedText
$cmpHint.Location = New-Object System.Drawing.Point(2, 82)

$lblCmpDisclaimer = New-Object System.Windows.Forms.Label
$lblCmpDisclaimer.Text = (T "CmpBestEffortNote")
$lblCmpDisclaimer.AutoSize = $true
$lblCmpDisclaimer.MaximumSize = New-Object System.Drawing.Size(980, 0)
$lblCmpDisclaimer.ForeColor = $Theme.MutedText
$lblCmpDisclaimer.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblCmpDisclaimer.Location = New-Object System.Drawing.Point(2, 100)

$cmpOptCard.Controls.Add($lblCmpDisclaimer)

$cmpOptCard.Controls.AddRange(@($cmpTitle,$cmpDesc,$chkCmpHash,$lblSearch,$txtSearch,$cmpHint))
$cmpLayout.Controls.Add($cmpOptCard, 0, 0)

$cmpStatusPanel = New-Object System.Windows.Forms.Panel
$cmpStatusPanel.Dock = 'Fill'
$cmpStatusPanel.Padding = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)

$lblCmpStatus = New-Object System.Windows.Forms.Label
$lblCmpStatus.Text = (T "Ready")
$lblCmpStatus.AutoSize = $true
$lblCmpStatus.ForeColor = $Theme.MutedText

$progressCmp = New-Object System.Windows.Forms.ProgressBar
$progressCmp.Style = 'Marquee'
$progressCmp.Visible = $false
$progressCmp.Width = 280
$progressCmp.Height = 18
$progressCmp.Location = New-Object System.Drawing.Point(0, 20)

$cmpStatusPanel.Controls.AddRange(@($lblCmpStatus,$progressCmp))
$cmpLayout.Controls.Add($cmpStatusPanel, 0, 1)

$listCmp = New-Object System.Windows.Forms.ListView
$listCmp.Dock = 'Fill'
$listCmp.View = 'Details'
$listCmp.FullRowSelect = $true
$listCmp.GridLines = $true
$listCmp.HideSelection = $false
$listCmp.BorderStyle = 'FixedSingle'
$listCmp.BackColor = $uiOutYellow

[void]$listCmp.Columns.Add((T "StatusLbl"), 150)
[void]$listCmp.Columns.Add((T "TypeColLbl"), 70)
[void]$listCmp.Columns.Add((T "PathLbl"), 520)
[void]$listCmp.Columns.Add((T "SourceLbl"), 170)
[void]$listCmp.Columns.Add((T "TargetLbl"), 170)

$cmpLayout.Controls.Add($listCmp, 0, 2)

$cmpBottom = New-Object System.Windows.Forms.Panel
$cmpBottom.Dock = 'Fill'
$cmpBottom.BackColor = $Theme.HeaderBg

$cmpButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$cmpButtons.Dock = 'Fill'
$cmpButtons.WrapContents = $false
$cmpButtons.Padding = New-Object System.Windows.Forms.Padding(12, 9, 12, 9)
$cmpButtons.BackColor = $cmpBottom.BackColor
$cmpBottom.Controls.Add($cmpButtons)

$btnCompare = New-Object System.Windows.Forms.Button
$btnCompare.Text = (T "CompareStart")
$btnCompare.Width = 170
Style-PrimaryButton $btnCompare $Theme.Primary $Theme.PrimaryHover

$btnExportCompare = New-Object System.Windows.Forms.Button
$btnExportCompare.Text = (T "ReportOpen")
$btnExportCompare.Width = 170
Style-SecondaryButton $btnExportCompare
$btnExportCompare.BackColor = [System.Drawing.Color]::FromArgb(0, 128, 128)
$btnExportCompare.ForeColor = [System.Drawing.Color]::White
$btnExportCompare.FlatAppearance.BorderColor = $btnExportCompare.BackColor
$btnExportCompare.Tag = @{ Back = $btnExportCompare.BackColor; Hover = [System.Drawing.Color]::FromArgb(0, 110, 110) }
$btnExportCompare.Add_MouseEnter({ $this.BackColor = $this.Tag.Hover })
$btnExportCompare.Add_MouseLeave({ $this.BackColor = $this.Tag.Back })

$btnCompareClear = New-Object System.Windows.Forms.Button
$btnCompareClear.Text = (T "ClearResult")
$btnCompareClear.Width = 150
Style-SecondaryButton $btnCompareClear

$txtCmpOut = New-Object System.Windows.Forms.TextBox
$txtCmpOut.Multiline = $false
$txtCmpOut.ReadOnly = $true
$txtCmpOut.BorderStyle = 'FixedSingle'
$txtCmpOut.Width = 420
$txtCmpOut.Height = 26
$txtCmpOut.BackColor = $uiOutYellow
$txtCmpOut.ForeColor = $uiOutText
$txtCmpOut.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$txtCmpOut.Margin = New-Object System.Windows.Forms.Padding(10, 13, 0, 0)
$txtCmpOut.Text = "0 / 0 / 0"

$lblCmpUiLimit = New-Object System.Windows.Forms.Label
$lblCmpUiLimit.ForeColor = $Theme.MutedText
$lblCmpUiLimit.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblCmpUiLimit.Margin = New-Object System.Windows.Forms.Padding(10, 16, 0, 0)
$lblCmpUiLimit.Text = ""
$lblCmpUiLimit.AutoSize = $false
$lblCmpUiLimit.Width = 420
$lblCmpUiLimit.AutoEllipsis = $true

$script:LblCmpUiLimit = $lblCmpUiLimit

$cmpButtons.Controls.AddRange(@(
  $btnCompare,
  $btnExportCompare,
  $btnCompareClear,
  $txtCmpOut,
  $lblCmpUiLimit
))

$cmpLayout.Controls.Add($cmpBottom, 0, 3)

# =========================
# TAB: Help
# =========================
function Get-HelpHtml {
    if ($script:Lang -eq "de") {
        return @'
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<style>
    body { margin:0; padding:0; background:#f4f8ff; font-family:"Segoe UI", Arial, sans-serif; color:#142033; font-size:13px; line-height:1.55; }
    .page { padding:22px 26px 30px 26px; }
    .hero { background:#ffffff; border:1px solid #d8e7fb; border-radius:12px; padding:18px 20px; margin-bottom:16px; box-shadow:0 2px 8px rgba(30,70,120,0.08); }
    h1 { margin:0 0 5px 0; font-size:24px; color:#1f5eff; font-weight:700; }
    .subtitle { color:#52687f; font-size:13px; }
    .grid { width:100%; border-spacing:14px; margin-left:-14px; }
    .card { vertical-align:top; background:#ffffff; border:1px solid #d8e7fb; border-radius:12px; padding:14px 16px; box-shadow:0 2px 8px rgba(30,70,120,0.06); }
    h2 { margin:0 0 9px 0; font-size:17px; color:#1f5eff; font-weight:700; }
    h3 { margin:10px 0 5px 0; font-size:14px; color:#193a5c; }
    p { margin:6px 0; }
    ul { margin:7px 0 3px 20px; padding:0; }
    li { margin:4px 0; }
    .code { display:inline-block; background:#eef5ff; border:1px solid #cfe2fb; border-radius:6px; padding:2px 7px; font-family:Consolas, monospace; color:#0f365d; }
    .note { border-left:5px solid #1f5eff; background:#eef5ff; padding:10px 12px; margin-top:8px; border-radius:8px; }
    .warn { border-left:5px solid #d32f2f; background:#fff3f3; color:#621616; padding:10px 12px; margin-top:8px; border-radius:8px; }
    .ok { border-left:5px solid #2e7d32; background:#f1fbf2; color:#173d1c; padding:10px 12px; margin-top:8px; border-radius:8px; }
    .pill { display:inline-block; background:#1f5eff; color:#fff; border-radius:999px; padding:2px 9px; font-size:12px; margin-right:5px; }
    .small { color:#66798c; font-size:12px; }
    .footer { color:#66798c; font-size:12px; padding:0 14px 8px 14px; }
</style>
</head>
<body>
<div class="page">
    <div class="hero">
        <h1>waltrone1 RoboSync Manager Hilfe</h1>
        <div class="subtitle">Kurz und praktisch: Pfade setzen, Vorschau prüfen, optional vergleichen, dann synchronisieren.</div>
    </div>

    <table class="grid">
        <tr>
            <td class="card" style="width:50%;">
                <h2>Grundprinzip</h2>
                <p>RoboSync Manager ist eine grafische Oberfläche für <b>Robocopy</b>. Das Tool soll Robocopy einfacher bedienbar machen, ohne zu verstecken, was tatsächlich ausgeführt wird.</p>
                <div class="note"><b>Wichtig:</b> Prüfe vor jedem Start die Befehlsvorschau. Dort siehst du den vollständigen Robocopy-Befehl.</div>
            </td>
            <td class="card" style="width:50%;">
                <h2>Schnellstart</h2>
                <ul>
                    <li><b>Quelle</b> auswählen</li>
                    <li><b>Ziel</b> auswählen</li>
                    <li>Optionen prüfen, z. B. <span class="code">/MT</span> oder <span class="code">/MIR</span></li>
                    <li>Befehlsvorschau kontrollieren</li>
                    <li>Optional zuerst <b>Vergleichen</b>, dann <b>Start</b></li>
                </ul>
            </td>
        </tr>
        <tr>
            <td class="card">
                <h2>Quelle und Ziel</h2>
                <p>Unterstützt werden lokale Ordner, Netzlaufwerke und UNC-Pfade.</p>
                <p><span class="pill">Lokal</span> <span class="code">C:\Daten</span> → <span class="code">D:\Backup</span></p>
                <p><span class="pill">Empfohlen</span> <span class="code">Z:\Ordner</span> → <span class="code">D:\Backup</span></p>
                <p><span class="pill">UNC</span> <span class="code">\\server\share\Ordner</span> → <span class="code">D:\Backup</span></p>
                <div class="ok"><b>Best Practice:</b> Große Netzfreigaben möglichst zuerst als Netzlaufwerk verbinden, z. B. <span class="code">Z:</span>.</div>
            </td>
            <td class="card">
                <h2>Sprache</h2>
                <p>Das Tool unterstützt Deutsch und Englisch.</p>
                <p><span class="code">waltrone1-RoboSync-Manager.exe -Lang de</span></p>
                <p><span class="code">waltrone1-RoboSync-Manager.exe -Lang en</span></p>
                <p class="small">Ohne Parameter startet das Tool standardmäßig auf Englisch.</p>
            </td>
        </tr>
        <tr>
            <td class="card">
                <h2>Synchronisation</h2>
                <p>Die Synchronisation überträgt Daten von der Quelle ins Ziel über Robocopy.</p>
                <h3>MOVE</h3>
                <p><span class="code">/MOVE</span> verschiebt Dateien. Die Quelle wird nach erfolgreichem Kopieren geleert.</p>
                <h3>MIRROR</h3>
                <p><span class="code">/MIR</span> spiegelt das Ziel auf den Stand der Quelle.</p>
                <div class="warn"><b>Achtung:</b> MIRROR löscht im Ziel Dateien und Ordner, die in der Quelle nicht vorhanden sind.</div>
            </td>
            <td class="card">
                <h2>Neue Funktionen</h2>
                <h3>Multithread /MT</h3>
                <p><span class="code">/MT</span> bedeutet paralleles Kopieren. Robocopy kann mehrere Dateien gleichzeitig kopieren.</p>
                <p>Empfohlen zum Start: <span class="code">/MT:8</span> oder <span class="code">/MT:16</span>.</p>
                <p class="small">Bei NAS- oder Netzwerkshares können sehr hohe Werte auch langsamer sein.</p>
                <h3>MIR-Sicherheitslimit</h3>
                <p>Das Sicherheitslimit wird automatisch aktiviert, sobald MIRROR ausgewählt wird.</p>
                <p>Vor dem echten Lauf scannt das Tool Quelle und Ziel. Wenn zu viele Dateien betroffen wären, stoppt es und fragt nach Bestätigung.</p>
                <div class="ok"><b>Ziel:</b> Schutz vor Massenlöschungen, falscher Quelle oder Ransomware-Änderungen.</div>
            </td>
        </tr>
        <tr>
            <td class="card">
                <h2>Vergleich</h2>
                <p>Der Vergleich prüft Quelle und Ziel ohne Änderungen.</p>
                <ul>
                    <li><b>Nur in Quelle</b></li>
                    <li><b>Nur im Ziel</b></li>
                    <li><b>Unterschiedlich</b></li>
                </ul>
                <p>Optional kann ein <span class="code">SHA256</span>-Hash-Vergleich aktiviert werden. Das ist langsamer, aber genauer.</p>
            </td>
            <td class="card">
                <h2>Reports und Hinweise</h2>
                <p>Nach Sync oder Vergleich können HTML-Reports geöffnet werden. Diese sind besonders hilfreich für Kontrolle, Dokumentation und Fehlersuche.</p>
                <div class="note"><b>Hinweis:</b> UNC-Vergleiche können langsam sein und benötigen passende Rechte. Wenn es hakt: Netzlaufwerk mappen oder neu authentifizieren.</div>
            </td>
        </tr>
    </table>
    <div class="footer">Tipp: Erst mit kleinen Testordnern prüfen, besonders bei MIRROR und Sicherheitslimit.</div>
</div>
</body>
</html>
'@
    }

    return @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<style>
    body { margin:0; padding:0; background:#f4f8ff; font-family:"Segoe UI", Arial, sans-serif; color:#142033; font-size:13px; line-height:1.55; }
    .page { padding:22px 26px 30px 26px; }
    .hero { background:#ffffff; border:1px solid #d8e7fb; border-radius:12px; padding:18px 20px; margin-bottom:16px; box-shadow:0 2px 8px rgba(30,70,120,0.08); }
    h1 { margin:0 0 5px 0; font-size:24px; color:#1f5eff; font-weight:700; }
    .subtitle { color:#52687f; font-size:13px; }
    .grid { width:100%; border-spacing:14px; margin-left:-14px; }
    .card { vertical-align:top; background:#ffffff; border:1px solid #d8e7fb; border-radius:12px; padding:14px 16px; box-shadow:0 2px 8px rgba(30,70,120,0.06); }
    h2 { margin:0 0 9px 0; font-size:17px; color:#1f5eff; font-weight:700; }
    h3 { margin:10px 0 5px 0; font-size:14px; color:#193a5c; }
    p { margin:6px 0; }
    ul { margin:7px 0 3px 20px; padding:0; }
    li { margin:4px 0; }
    .code { display:inline-block; background:#eef5ff; border:1px solid #cfe2fb; border-radius:6px; padding:2px 7px; font-family:Consolas, monospace; color:#0f365d; }
    .note { border-left:5px solid #1f5eff; background:#eef5ff; padding:10px 12px; margin-top:8px; border-radius:8px; }
    .warn { border-left:5px solid #d32f2f; background:#fff3f3; color:#621616; padding:10px 12px; margin-top:8px; border-radius:8px; }
    .ok { border-left:5px solid #2e7d32; background:#f1fbf2; color:#173d1c; padding:10px 12px; margin-top:8px; border-radius:8px; }
    .pill { display:inline-block; background:#1f5eff; color:#fff; border-radius:999px; padding:2px 9px; font-size:12px; margin-right:5px; }
    .small { color:#66798c; font-size:12px; }
    .footer { color:#66798c; font-size:12px; padding:0 14px 8px 14px; }
</style>
</head>
<body>
<div class="page">
    <div class="hero">
        <h1>waltrone1 RoboSync Manager Help</h1>
        <div class="subtitle">Short and practical: set paths, check the preview, optionally compare, then sync.</div>
    </div>

    <table class="grid">
        <tr>
            <td class="card" style="width:50%;">
                <h2>Basic idea</h2>
                <p>RoboSync Manager is a graphical interface for <b>Robocopy</b>. The tool makes Robocopy easier to use without hiding what will actually be executed.</p>
                <div class="note"><b>Important:</b> Always check the command preview before starting. It shows the full Robocopy command.</div>
            </td>
            <td class="card" style="width:50%;">
                <h2>Quick start</h2>
                <ul>
                    <li>Select the <b>source</b></li>
                    <li>Select the <b>target</b></li>
                    <li>Check options such as <span class="code">/MT</span> or <span class="code">/MIR</span></li>
                    <li>Review the command preview</li>
                    <li>Optionally run <b>Compare</b> first, then <b>Start</b></li>
                </ul>
            </td>
        </tr>
        <tr>
            <td class="card">
                <h2>Source and target</h2>
                <p>Local folders, mapped drives and UNC paths are supported.</p>
                <p><span class="pill">Local</span> <span class="code">C:\Data</span> → <span class="code">D:\Backup</span></p>
                <p><span class="pill">Recommended</span> <span class="code">Z:\Folder</span> → <span class="code">D:\Backup</span></p>
                <p><span class="pill">UNC</span> <span class="code">\\server\share\Folder</span> → <span class="code">D:\Backup</span></p>
                <div class="ok"><b>Best practice:</b> For large network shares, map the share as a drive first, for example <span class="code">Z:</span>.</div>
            </td>
            <td class="card">
                <h2>Language</h2>
                <p>The tool supports English and German.</p>
                <p><span class="code">waltrone1-RoboSync-Manager.exe -Lang en</span></p>
                <p><span class="code">waltrone1-RoboSync-Manager.exe -Lang de</span></p>
                <p class="small">Without a parameter, the tool starts in English by default.</p>
            </td>
        </tr>
        <tr>
            <td class="card">
                <h2>Synchronization</h2>
                <p>Synchronization transfers data from source to target using Robocopy.</p>
                <h3>MOVE</h3>
                <p><span class="code">/MOVE</span> moves files. The source is emptied after a successful copy.</p>
                <h3>MIRROR</h3>
                <p><span class="code">/MIR</span> mirrors the target to match the source.</p>
                <div class="warn"><b>Warning:</b> MIRROR deletes files and folders in the target that are not present in the source.</div>
            </td>
            <td class="card">
                <h2>New features</h2>
                <h3>Multithread /MT</h3>
                <p><span class="code">/MT</span> means parallel copying. Robocopy can copy multiple files at the same time.</p>
                <p>Good starting values: <span class="code">/MT:8</span> or <span class="code">/MT:16</span>.</p>
                <p class="small">On NAS or network shares, very high values may also slow things down.</p>
                <h3>MIR safety threshold</h3>
                <p>The safety threshold is enabled automatically when MIRROR is selected.</p>
                <p>Before the real run, the tool scans source and target. If too many files would be affected, it stops and asks for confirmation.</p>
                <div class="ok"><b>Goal:</b> Protection against mass deletions, a wrong source path or ransomware-related changes.</div>
            </td>
        </tr>
        <tr>
            <td class="card">
                <h2>Compare</h2>
                <p>Compare checks source and target without making changes.</p>
                <ul>
                    <li><b>Only in source</b></li>
                    <li><b>Only in target</b></li>
                    <li><b>Different</b></li>
                </ul>
                <p>An optional <span class="code">SHA256</span> hash comparison can be enabled. It is slower, but more exact.</p>
            </td>
            <td class="card">
                <h2>Reports and notes</h2>
                <p>After sync or compare, HTML reports can be opened. They are useful for review, documentation and troubleshooting.</p>
                <div class="note"><b>Note:</b> UNC compare may be slow and requires permissions. If it fails, try mapping a drive or re-authenticate.</div>
            </td>
        </tr>
    </table>
    <div class="footer">Tip: Test with small folders first, especially when using MIRROR and the safety threshold.</div>
</div>
</body>
</html>
'@
}

$tabHelp.Controls.Clear()
$helpRoot = New-Object System.Windows.Forms.Panel
$helpRoot.Dock = 'Fill'
$helpRoot.BackColor = [System.Drawing.Color]::White
$helpRoot.Padding = New-Object System.Windows.Forms.Padding(18, 16, 18, 16)
$tabHelp.Controls.Add($helpRoot)

$helpCard = New-CardPanel
$helpCard.Dock = 'Fill'
$helpCard.Padding = New-Object System.Windows.Forms.Padding(0)
$helpCard.BackColor = [System.Drawing.Color]::White
$helpRoot.Controls.Add($helpCard)

$helpBrowser = New-Object System.Windows.Forms.WebBrowser
$helpBrowser.Dock = 'Fill'
$helpBrowser.ScriptErrorsSuppressed = $true
$helpBrowser.AllowWebBrowserDrop = $false
$helpBrowser.IsWebBrowserContextMenuEnabled = $false
$helpBrowser.WebBrowserShortcutsEnabled = $true
$helpBrowser.DocumentText = Get-HelpHtml

$helpCard.Controls.Add($helpBrowser)

# =========================
# TAB: Info
# =========================
$tabInfo.Controls.Clear()

$reg = [char]0x00AE   # ®
$AppName  = $script:ToolDisplayName
$AppVer   = "v$($script:AppVersion)"
$BuildDate = $script:BuildDate
$DevLine   = "waltrone1"
$MoreUrl = $script:OfficialWebsite
$LogoUrl   = "https://yt3.googleusercontent.com/zXzem7bbA0rm0FKIe8svIoqYl6FS3re2kqx31psWGF3W8SAzpc_kxg_N-y_LLwIHQHOc90nS8w=s900-c-k-c0x00ffffff-no-rj"

$infoRoot = New-Object System.Windows.Forms.Panel
$infoRoot.Dock = 'Fill'
$infoRoot.BackColor = [System.Drawing.Color]::White
$infoRoot.Padding = New-Object System.Windows.Forms.Padding(18, 16, 18, 16)
$tabInfo.Controls.Add($infoRoot)

$infoCard = New-CardPanel
$infoCard.Dock = 'Fill'
$infoCard.Padding = New-Object System.Windows.Forms.Padding(16)
$infoCard.BackColor = [System.Drawing.Color]::FromArgb(232, 242, 255)
$infoRoot.Controls.Add($infoCard)

$infoTitle = New-Object System.Windows.Forms.Label
$infoTitle.Text = (T "Info")
$infoTitle.AutoSize = $true
$infoTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$infoTitle.ForeColor = [System.Drawing.Color]::FromArgb(25, 58, 92)

$infoSub = New-Object System.Windows.Forms.Label
$infoSub.Text = (T "InfoSub")
$infoSub.AutoSize = $true
$infoSub.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$infoSub.ForeColor = [System.Drawing.Color]::FromArgb(60, 90, 120)
$infoSub.Location = New-Object System.Drawing.Point(2, 30)

$infoWrap = New-Object System.Windows.Forms.Panel
$infoWrap.Location = New-Object System.Drawing.Point(12, 62)
$infoWrap.Anchor   = 'Top,Left,Right,Bottom'
$infoWrap.Padding  = New-Object System.Windows.Forms.Padding(14, 12, 14, 12)
$infoWrap.BackColor = [System.Drawing.Color]::FromArgb(245, 250, 255)
$infoWrap.BorderStyle = 'FixedSingle'
$infoCard.Controls.Add($infoWrap)

$grid = New-Object System.Windows.Forms.TableLayoutPanel
$grid.Dock = 'Fill'
$grid.BackColor = $infoWrap.BackColor
$grid.ColumnCount = 2
$grid.RowCount = 1
[void]$grid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 190)))
[void]$grid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$infoWrap.Controls.Add($grid)

$pic = New-Object System.Windows.Forms.PictureBox
$pic.SizeMode = 'Zoom'
$pic.Width  = 160
$pic.Height = 160
$pic.Margin = New-Object System.Windows.Forms.Padding(0, 0, 14, 0)
$pic.Anchor = 'Top,Left'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $logoPath = Join-Path $env:TEMP "robosync_logo.png"
    Invoke-WebRequest -Uri $LogoUrl -OutFile $logoPath -UseBasicParsing
    $pic.Image = [System.Drawing.Image]::FromFile($logoPath)
} catch {
    $pic.BackColor = [System.Drawing.Color]::FromArgb(235, 242, 252)
}

$right = New-Object System.Windows.Forms.TableLayoutPanel
$right.Dock        = 'Fill'
$right.ColumnCount = 1
$right.RowCount    = 5
$right.BackColor   = $infoWrap.BackColor

$lblName = New-Object System.Windows.Forms.Label
$lblName.Text = $AppName
$lblName.AutoSize = $true
$lblName.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblName.ForeColor = [System.Drawing.Color]::FromArgb(25, 58, 92)

$lblDesc = New-Object System.Windows.Forms.Label
$lblDesc.Text = (T "InfoDesc")
$lblDesc.AutoSize = $true
$lblDesc.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblDesc.ForeColor = [System.Drawing.Color]::FromArgb(60, 90, 120)
$lblDesc.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)

$detailsCard = New-Object System.Windows.Forms.Panel
$detailsCard.BackColor   = [System.Drawing.Color]::White
$detailsCard.BorderStyle = 'FixedSingle'
$detailsCard.Padding     = New-Object System.Windows.Forms.Padding(12, 10, 12, 10)
$detailsCard.Margin      = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
$detailsCard.Dock        = 'Top'
$detailsCard.AutoSize    = $true
$detailsCard.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

$details = New-Object System.Windows.Forms.TableLayoutPanel
$details.AutoSize    = $true
$details.Dock        = 'Top'
$details.ColumnCount = 2
$details.BackColor   = [System.Drawing.Color]::White
[void]$details.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 78)))
[void]$details.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))

function Add-InfoRow([string]$key, [string]$value) {
    $r = $details.RowCount
    $details.RowCount = $r + 1
    [void]$details.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))

    $k = New-Object System.Windows.Forms.Label
    $k.Text      = $key
    $k.AutoSize  = $true
    $k.ForeColor = [System.Drawing.Color]::FromArgb(60, 90, 120)
    $k.Margin    = New-Object System.Windows.Forms.Padding(0, 0, 14, 6)

    $v = New-Object System.Windows.Forms.Label
    $v.Text      = $value
    $v.AutoSize  = $true
    $v.ForeColor = [System.Drawing.Color]::FromArgb(25, 58, 92)
    $v.Margin    = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)

    [void]$details.Controls.Add($k, 0, $r)
    [void]$details.Controls.Add($v, 1, $r)
}

Add-InfoRow "Version:" $AppVer
Add-InfoRow "Build:"   $BuildDate
Add-InfoRow "Author:"  $DevLine

[void]$detailsCard.Controls.Add($details)

$link = New-Object System.Windows.Forms.LinkLabel
$link.Text = (T "OfficialWebsite")
$link.Add_LinkClicked({ try { Start-Process $MoreUrl } catch { } })
$link.AutoSize = $true
$link.LinkColor = $Theme.Primary
$link.ActiveLinkColor = $Theme.PrimaryHover
$link.VisitedLinkColor = $Theme.Primary
$link.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)

$right.Controls.Add($lblName,     0, 0)
$right.Controls.Add($lblDesc,     0, 1)
$right.Controls.Add($detailsCard, 0, 2)
$right.Controls.Add($link,        0, 3)

$grid.Controls.Add($pic,   0, 0) | Out-Null
$grid.Controls.Add($right, 1, 0) | Out-Null

$infoCard.Controls.Add($infoTitle)
$infoCard.Controls.Add($infoSub)

$infoCard.Add_Resize({
    if ($infoWrap -and -not $infoWrap.IsDisposed) {
        $infoWrap.Size = New-Object System.Drawing.Size(($infoCard.ClientSize.Width - 24), ($infoCard.ClientSize.Height - 78))
    }
})
$infoWrap.Size = New-Object System.Drawing.Size(($infoCard.ClientSize.Width - 24), ($infoCard.ClientSize.Height - 78))

# =========================
# LIVE COMMAND UPDATE
# =========================
$script:UpdatingMirrorSafety = $false
$updateCmd = {
    if ($txtSrc.Text -and $txtDst.Text) { $txtCmd.Text = 'robocopy.exe ' + (BuildCmd) }
    else { $txtCmd.Text = "" }
}
$txtSrc.Add_TextChanged($updateCmd)
$txtDst.Add_TextChanged($updateCmd)
$chkMove.Add_CheckedChanged($updateCmd)
$chkMirror.Add_CheckedChanged({
    $lblMirrorWarn.Visible = $chkMirror.Checked

    # Safety guard belongs to MIRROR: enable it automatically when MIRROR is selected,
    # and disable/gray it out again when MIRROR is not active.
    $script:UpdatingMirrorSafety = $true
    try {
        if ($chkMirror.Checked) {
            $chkMirrorSafety.Checked = $true
        } else {
            $chkMirrorSafety.Checked = $false
        }
    } finally {
        $script:UpdatingMirrorSafety = $false
    }

    Update-MirrorSafetyUi $false
    & $updateCmd
})
$chkMT.Add_CheckedChanged({
    $numMT.Enabled = $chkMT.Checked
    & $updateCmd
})
$numMT.Add_ValueChanged($updateCmd)
$chkMirrorSafety.Add_CheckedChanged({
    if ((-not $script:UpdatingMirrorSafety) -and $chkMirror.Checked -and (-not $chkMirrorSafety.Checked)) {
        $resSafetyToggle = [System.Windows.Forms.MessageBox]::Show(
            (T "MirrorSafetyDisableConfirm"),
            (T "Warning"),
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($resSafetyToggle -ne 'Yes') {
            $script:UpdatingMirrorSafety = $true
            try { $chkMirrorSafety.Checked = $true } finally { $script:UpdatingMirrorSafety = $false }
            Update-MirrorSafetyUi $false
            & $updateCmd
            return
        }
    }

    Update-MirrorSafetyUi $false
    & $updateCmd
})
$numMirrorThreshold.Add_ValueChanged($updateCmd)

# Initialize MIR safety UI coupling
Update-MirrorSafetyUi $false

# =========================
# RESET
# =========================
function script:Reset-All {

    $srcRoot = $null
    $dstRoot = $null
    try {
        if ($txtSrc.Text -and (IsUNC $txtSrc.Text)) { $srcRoot = GetShareRoot $txtSrc.Text }
        if ($txtDst.Text -and (IsUNC $txtDst.Text)) { $dstRoot = GetShareRoot $txtDst.Text }
    } catch { }

    try {
        if ($srcRoot) { cmd.exe /c "net use `"$srcRoot`" /delete /y" | Out-Null }
        if ($dstRoot -and $dstRoot -ne $srcRoot) { cmd.exe /c "net use `"$dstRoot`" /delete /y" | Out-Null }
    } catch { }

    # Kill running process (optional safety on reset)
    try {
        if ($script:CurrentProc -and -not $script:CurrentProc.HasExited) {
            $script:CancelRequested = $true
            try { $script:CurrentProc.Kill() } catch { }
        }
    } catch { }

    # Clear async output queue
    try {
        $line = $null
        while ($script:OutQueue -and $script:OutQueue.TryDequeue([ref]$line)) { $line = $null }
    } catch { }

    $script:CachedCred       = $null
    $script:CurrentProc      = $null
    $script:CancelRequested  = $false

    $txtSrc.Clear()
    $txtDst.Clear()

    $chkMove.Checked    = $false
    $chkMirror.Checked  = $false
    if ($chkMT) { $chkMT.Checked = $false }
    if ($numMT) { $numMT.Value = 8; $numMT.Enabled = $false }
    if ($chkMirrorSafety) { $chkMirrorSafety.Checked = $false }
    if ($numMirrorThreshold) { $numMirrorThreshold.Value = 10 }
    Update-MirrorSafetyUi $false
    $chkCmpHash.Checked = $false
    $txtSearch.Clear()

    $txtOut.Clear()
    $txtCmd.Clear()

    $listCmp.Items.Clear()
    $script:LastCompareResult = @()
    $txtCmpOut.Text = "0 / 0 / 0"
    $script:CompareRan = $false

    $lblStatus.Text    = (T "Ready")
    $lblCmpStatus.Text = (T "Ready")
    $progress.Visible  = $false
    $progressCmp.Visible = $false
    $lblMirrorWarn.Visible = $false

    # New sync HTML for next run (HTML-only)
    $script:SyncStamp = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    $script:SyncHtml  = Join-Path $script:BaseDir ("Robocopy_{0}.html" -f $script:SyncStamp)

    # Reset in-memory sync log buffer + html write marker
    if ($script:SyncLines) { $script:SyncLines.Clear() }
    $script:LastSyncHtmlWriteUtc = $null

    Set-LogButtonState
    Set-RunState $false
}

# =========================
# EVENTS
# =========================
function Copy-CmdToClipboard {
    if ($txtCmd.Text) {
        [System.Windows.Forms.Clipboard]::SetText($txtCmd.Text)
        $lblStatus.Text = (T "CopyCmdClipboard")
    }
}
$txtCmd.Add_MouseDown({ if ($_.Clicks -ge 2) { $txtCmd.SelectAll() }; Copy-CmdToClipboard })
$cmdWrap.Add_MouseDown({ Copy-CmdToClipboard })

$btnSrc.Add_Click({ BrowseFolder $txtSrc; $txtDst.Focus(); $txtDst.SelectAll() })
$btnDst.Add_Click({
    BrowseFolder $txtDst
    if ($tabs.SelectedTab -eq $tabSync) { $btnStart.Focus() }
    elseif ($tabs.SelectedTab -eq $tabCompare) { $btnCompare.Focus() }
})

$btnReset.Add_Click({ Reset-All })

$btnCancel.Add_Click({
    if ($script:CurrentProc -and -not $script:CurrentProc.HasExited) {
        $script:CancelRequested = $true
        $lblStatus.Text = (T "StatusCancelReq")
    } else {
        $lblStatus.Text = (T "StatusNoRun")
    }
})

$btnClear.Add_Click({ $txtOut.Clear() })

$btnLog.Add_Click({
    $latest = Get-LatestRobocopyHtml
    if (-not $latest) { Set-LogButtonState; return }

    try {
        # HTML im Standardbrowser oeffnen
        Start-Process -FilePath $latest.FullName
    } catch {
        try { Start-Process $latest.FullName } catch { }
    }
})

# Compare list: double click -> open path
$listCmp.Add_MouseDoubleClick({
    param($sender, $e)

    $hit = $listCmp.HitTest($e.Location)
    if (-not $hit -or -not $hit.Item) { return }

    $row = $hit.Item.Tag
    if (-not $row) { return }

    $srcRoot = $txtSrc.Text.Trim()
    $dstRoot = $txtDst.Text.Trim()
    $rel     = $row.Path
    if (-not $rel) { return }

    $srcPath = if ($srcRoot) { Join-Path $srcRoot $rel } else { $null }
    $dstPath = if ($dstRoot) { Join-Path $dstRoot $rel } else { $null }

    # Column index: 0 Status,1 Type,2 Path,3 Src,4 Dst
    $colIndex = 0
    if ($hit.SubItem) {
        $colIndex = $hit.Item.SubItems.IndexOf($hit.SubItem)
        if ($colIndex -lt 0) { $colIndex = 0 }
    }

    function Open-ExplorerSelect([string]$p, [string]$type) {
        if (-not $p -or -not (Test-Path -LiteralPath $p)) { return }
        if ($type -eq 'Dir') { Start-Process explorer.exe -ArgumentList "`"$p`"" }
        else { Start-Process explorer.exe -ArgumentList "/select,`"$p`"" }
    }

    if ($row.Status -eq (T "Different")) {
        if ($colIndex -eq 3) { if (Test-Path -LiteralPath $srcPath) { Start-Process -FilePath $srcPath }; return }
        if ($colIndex -eq 4) { if (Test-Path -LiteralPath $dstPath) { Start-Process -FilePath $dstPath }; return }

        if (Test-Path -LiteralPath $srcPath) { Open-ExplorerSelect $srcPath $row.Type; return }
        if (Test-Path -LiteralPath $dstPath) { Open-ExplorerSelect $dstPath $row.Type; return }
        return
    }

    if ($row.Status -eq (T "OnlyInSource")) { Open-ExplorerSelect $srcPath $row.Type; return }
    if ($row.Status -eq (T "OnlyInTarget")) { Open-ExplorerSelect $dstPath $row.Type; return }

    if (Test-Path -LiteralPath $srcPath) { Open-ExplorerSelect $srcPath $row.Type }
    elseif (Test-Path -LiteralPath $dstPath) { Open-ExplorerSelect $dstPath $row.Type }
})

$txtSearch.Add_TextChanged({ Apply-CompareFilter })

# =========================
# COMPARE BUTTONS
# =========================
$btnCompare.Add_Click({
    $src = $txtSrc.Text.Trim()
    $dst = $txtDst.Text.Trim()

    if (-not $src -or -not $dst) {
        UI-Message (T "CmpMissing") (T "Warning") ([System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    if (-not (Test-Path -LiteralPath $src)) {
        UI-Message ("{0}`n{1}" -f (T "PathMissing"), $src) (T "Warning") ([System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    if (-not (Test-Path -LiteralPath $dst)) {
        UI-Message ("{0}`n{1}" -f (T "PathMissing"), $dst) (T "Warning") ([System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    try {
        Ensure-UNCAuthIfNeeded $src $dst

        $lblCmpStatus.Text = (T "CompareRunning")
        $progressCmp.Visible = $true
        $listCmp.Items.Clear()
        [System.Windows.Forms.Application]::DoEvents()

		$useHash = [bool]$chkCmpHash.Checked
		$res = Compare-Directories -Source $src -Target $dst -UseHash:$useHash

		# NULL-sicher: immer ein Array
		if ($null -eq $res) { $res = @() } else { $res = @($res) }

		$script:LastCompareResult = $res
		$script:CompareRan = $true

        $onlySrc = ($res | Where-Object Status -eq (T "OnlyInSource")).Count
        $onlyDst = ($res | Where-Object Status -eq (T "OnlyInTarget")).Count
        $diff    = ($res | Where-Object Status -eq (T "Different")).Count
        $txtCmpOut.Text = "$(T "OnlyInSource"): $onlySrc | $(T "OnlyInTarget"): $onlyDst | $(T "Different"): $diff"

        Render-CompareList -Rows $res
        Apply-CompareFilter

        $lblCmpStatus.Text = (T "CompareDone")
        $progressCmp.Visible = $false

		# Generate compare HTML report immediately (default template)
		Write-CompareHtmlReport -Rows $res -SourceRoot $src -TargetRoot $dst -HashUsed:$useHash

    } catch {
        $progressCmp.Visible = $false
        UI-Message $_.Exception.Message (T "Error") ([System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$btnCompareClear.Add_Click({
    $listCmp.BeginUpdate()
    $listCmp.Items.Clear()
    $listCmp.EndUpdate()

    $script:LastCompareResult = @()
    $script:CompareRan = $false

    $txtCmpOut.Text    = "0 / 0 / 0"
    $lblCmpStatus.Text = (T "Ready")
    $txtSearch.Text = ""
    $txtSearch.Focus()
})

$btnExportCompare.Add_Click({
    if (-not $script:CompareRan -or -not $script:LastCompareHtml -or -not (Test-Path -LiteralPath $script:LastCompareHtml)) {
        UI-Message (T "RunCompareFirst") (T "Note") ([System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    try { Start-Process $script:LastCompareHtml } catch { }
})

# =========================
# SYNC START
# =========================
$btnStart.Add_Click({

    if (-not $txtSrc.Text -or -not $txtDst.Text) {
        UI-Message (T "MissingPaths") (T "Warning") ([System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    if ($chkMove.Checked -and $chkMirror.Checked) {
        UI-Message (T "InvalidCombo") (T "Warning") ([System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    if ($chkMirror.Checked) {
        $res = [System.Windows.Forms.MessageBox]::Show(
            (T "MirrorConfirm"),
            (T "Warning"),
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($res -ne 'Yes') { return }
    }

    try {
        Ensure-UNCAuthIfNeeded $txtSrc.Text $txtDst.Text

        if ($chkMirror.Checked -and $chkMirrorSafety.Checked) {
            $lblStatus.Text = (T "MirrorSafetyScan")
            $progress.Visible = $true
            Set-RunState $true
            [System.Windows.Forms.Application]::DoEvents()

            $threshold = [int]$numMirrorThreshold.Value
            $safety = Test-MirrorSafetyThreshold -Source $txtSrc.Text.Trim() -Target $txtDst.Text.Trim() -ThresholdPercent $threshold

            if ($safety.Exceeds) {
                $msg = (T "MirrorSafetyExceeded") -f $safety.Affected, $safety.Percent, $safety.Delete, $safety.Copy, $safety.Different, $safety.ThresholdPercent
                $resSafety = [System.Windows.Forms.MessageBox]::Show(
                    $msg,
                    (T "Warning"),
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )

                if ($resSafety -ne 'Yes') {
                    $lblStatus.Text = (T "Ready")
                    $progress.Visible = $false
                    Set-RunState $false
                    UI-Message (T "MirrorSafetyCancelled") (T "Note") ([System.Windows.Forms.MessageBoxIcon]::Information)
                    return
                }
            } else {
                Push-Status ((T "MirrorSafetyOk") -f $safety.Affected, $safety.Percent, $safety.ThresholdPercent)
            }
        }

        $lblStatus.Text = (T "StatusCopying")
        $progress.Visible = $true
        $script:CancelRequested = $false
        Set-RunState $true
        [System.Windows.Forms.Application]::DoEvents()

        # New stamp per run (so each run gets its own default HTML/log)
        $script:SyncStamp = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
        $script:LogFile   = Join-Path $script:BaseDir ("Robocopy_{0}.log"  -f $script:SyncStamp)
        $script:SyncHtml  = Join-Path $script:BaseDir ("Robocopy_{0}.html" -f $script:SyncStamp)

        $argsLine = BuildCmd
        Log "===== START $(Get-Date) ====="
        Log ("robocopy.exe " + $argsLine)
        Log ""

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "robocopy.exe"
        $psi.Arguments = $argsLine
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow = $true

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        $p.EnableRaisingEvents = $true

        $null = Register-ObjectEvent -InputObject $p -EventName OutputDataReceived -SourceIdentifier "RC_OUT" -MessageData $script:OutQueue -Action {
            if ($EventArgs.Data) { $Event.MessageData.Enqueue($EventArgs.Data) | Out-Null }
        }

        $null = Register-ObjectEvent -InputObject $p -EventName ErrorDataReceived -SourceIdentifier "RC_ERR" -MessageData $script:OutQueue -Action {
            if ($EventArgs.Data) { $Event.MessageData.Enqueue($EventArgs.Data) | Out-Null }
        }

        $null = $p.Start()
        $script:CurrentProc = $p

        # ---- Sync meta start ----
        $script:SyncStart    = Get-Date
        $script:SyncEnd      = $null
        $script:SyncExitCode = $null
        if ($script:StatusHistory) { $script:StatusHistory.Clear() } else { $script:StatusHistory = New-Object System.Collections.Generic.List[string] }
        Push-Status ("{0} {1}" -f (T "StatusCopying"), $script:SyncStart.ToString("dd.MM.yyyy HH:mm:ss"))
        # -------------------------

        $p.BeginOutputReadLine()
        $p.BeginErrorReadLine()

        while (-not $p.HasExited) {

            Drain-OutQueue

            if ($script:CancelRequested) {
                try { $p.Kill() } catch { }
                try { $p.WaitForExit(2000) | Out-Null } catch { }
                Drain-OutQueue

                # ---- Sync meta end (aborted) ----
                $script:SyncEnd      = Get-Date
                $script:SyncExitCode = $null
                Push-Status ("{0} {1}" -f (T "StatusAborted"), $script:SyncEnd.ToString("dd.MM.yyyy HH:mm:ss"))
                # ---------------------------------

                Log "===== ABORTED by user $(Get-Date) ====="
                $lblStatus.Text = (T "StatusAborted")
                $progress.Visible = $false

                # ensure report is up to date even on abort
                try { Write-SyncHtmlReport -Force } catch { }
                break
            }

            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 80
        }

        Drain-OutQueue

        try { Unregister-Event -SourceIdentifier "RC_OUT" -ErrorAction SilentlyContinue } catch { }
        try { Unregister-Event -SourceIdentifier "RC_ERR" -ErrorAction SilentlyContinue } catch { }
        try { Get-Event -SourceIdentifier "RC_OUT" -ErrorAction SilentlyContinue | Remove-Event -ErrorAction SilentlyContinue } catch { }
        try { Get-Event -SourceIdentifier "RC_ERR" -ErrorAction SilentlyContinue | Remove-Event -ErrorAction SilentlyContinue } catch { }

        if (-not $script:CancelRequested) {

            # ---- Sync meta end (normal) ----
            $script:SyncEnd      = Get-Date
            $script:SyncExitCode = $p.ExitCode
            Push-Status ("{0} {1}" -f (T "Done"), $script:SyncEnd.ToString("dd.MM.yyyy HH:mm:ss"))
            Push-Status ("ExitCode: {0}" -f $script:SyncExitCode)
            # --------------------------------

            Log "===== END (ExitCode $($p.ExitCode)) ====="
            $lblStatus.Text = (T "Done")
            $progress.Visible = $false
        }

        $script:CurrentProc = $null
        Set-RunState $false

        # Final write of default HTML format report for sync
        Write-SyncHtmlReport -Force

        # Optional: auto-open HTML report after sync
        # Start-Process $script:SyncHtml

    } catch {

        # ---- Sync meta end (error) ----
        $script:SyncEnd      = Get-Date
        $script:SyncExitCode = $null
        Push-Status ("ERROR: {0}" -f $_.Exception.Message)
        # -------------------------------

        $progress.Visible = $false
        $script:CurrentProc = $null
        Set-RunState $false

        # best effort: write report even if something exploded
        try { Write-SyncHtmlReport -Force } catch { }

        UI-Message $_.Exception.Message (T "Error") ([System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# =========================
# CLOSE
# =========================
$form.Add_FormClosing({
    $script:CachedCred = $null
    if ($script:CurrentProc -and -not $script:CurrentProc.HasExited) {
        try { $script:CurrentProc.Kill() } catch { }
    }
})

$form.Add_Shown({ $txtSrc.Focus() })
[void]$form.ShowDialog()
