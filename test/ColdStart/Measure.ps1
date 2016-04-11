param (
    ## If -PerfView option is on, PerfView.exe needs to be in the tools folder specified by $global:toolsPath
    [switch]
    $PerfView
)

## functions

function EnsureTool {
    param($toolExe, $errorMsg)
    $toolPath = where.exe $toolExe

    if (! $toolPath ) {
        Write-Error $errorMsg
        Exit -1
    }

    if ($toolPath -is [object[]]) {
        $toolPath = $toolPath[0]
    }

    return $toolPath
}

function RunScenario {
    param($appLocation, $port)

    $portQuery = netstat -an | findstr ":$port "
    if (![System.String]::IsNullOrEmpty($portQuery)) {
        Write-Error "$port is in use."
        Exit -1
    }

    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    if ($PerfView) {
        $PerfViewTimestamp = Get-Date -Format yyyy-MM-dd-HH-mm-ss
        $perfviewStartLog = Join-Path $outputFolder "${PerfViewTimestamp}.start.log"
        $perfviewTraceFile = Join-Path $outputFolder "${PerfViewTimestamp}.etl"
        & $perfViewPath -AcceptEULA -NoGui -BufferSizeMB:1024 -clrEvents=default+GCSampledObjectAllocationHigh -KernelEvents=Default+FileIO+FileIOInit+ThreadTime -LogFile:$perfviewStartLog start $perfviewTraceFile
    }

    try {
        ## Provide fullpath to AppDLL
        $appDllLocation = Join-Path $appLocation "${global:targetApp}.dll"
        $process = Start-Process "dotnet" -ArgumentList "$appDllLocation server.urls=http://+:$port/" -PassThru -WorkingDirectory $appLocation

        Write-Host Process started with PID $process.Id

        $timer.Start()
        $success = $false
        ForEach ($ping in 1..$timeoutPeriod) {
            $r = &($curlPath) -s -f "http://localhost:$port"
            if (![System.String]::IsNullOrEmpty($r)) {
                $success = $true
                break
            }
            Start-Sleep -s $curlInterval | Out-Null
        }
        $timer.Stop()

        if (!$success) {
            Write-Error "Unable to connect to service"
            Exit -1
        }

        [System.IO.File]::AppendAllText("$global:outputFile", $timer.ElapsedMilliseconds, [System.Text.Encoding]::Unicode)
        return $process.Id
    }
    finally {
        if ($PerfView) {
            $perfviewStopLog = Join-Path $outputFolder "${PerfViewTimestamp}.stop.log"
            & $perfViewPath -AcceptEULA -LogFile:$perfviewStopLog -Zip:true -NoView -NoNGenRundown stop
        }
    }
}

## Main script

## interval of calling curl in seconds
$curlInterval = 0.01
## number of retries
$timeoutPeriod = 1500

# Set targetApp name and workspace
& (Join-Path $PSScriptRoot SetEnv.ps1)

$curlPath = EnsureTool "curl.exe" "Ensure you have curl on the path"
if ($PerfView) {
    $perfViewPath = EnsureTool "PerfView.exe" "Ensure you have perfview on the path or set $env:PERFTOOLS environment variable"
}

if (! (Test-Path variable:global:targetApp)) {
    Write-Error "Target application is not set"
    Exit -1
}

if (! (Test-Path variable:global:workspace)) {
    Write-Error "Workspace dir is not set"
    Exit -1
}

if (! (Test-Path $global:workspace)) {
    Write-Error "Workspace ${global:workspace} does not exist"
    Exit -1
}

if (! (Test-Path variable:global:outputFile)) {
    Write-Error "Output file is not set"
    Exit -1
}

if (! (Test-Path $global:outputFile)) {
    ## File does not exist yet, write output file header
    "Cold,Warm,NoCache" | Out-File $global:outputFile
}

## TODO: This is not a good logic, we should name the folder with timestamp and have a $global:outputFolder variable instead
$outputFolder = Split-Path $global:outputFile

$coldSitePort = 5001
$warmSitePort = 5002
$warmNoCachePort = 5003

$publishLocation = [System.IO.Path]::Combine($global:workspace, "publish", $global:targetApp)
$coldSiteLocation = [System.IO.Path]::Combine($global:workspace, "publish", $global:targetApp + "Cold")
$warmSiteLocation = [System.IO.Path]::Combine($global:workspace, "publish", $global:targetApp + "WarmPkgCache")
$warmNoCacheLocation = [System.IO.Path]::Combine($global:workspace, "publish", $global:targetApp + "WarmNoPkgCache")

if ((! (Test-Path $publishLocation)) -and (! (Test-Path $coldSiteLocation))) {
    Write-Error "App does not exist in ${publishLocation}, did you run SetupPerfApp.ps1?"
    Exit -1
}

if (! (Test-Path $coldSiteLocation)) {
    Write-Host "Moving published app ${publishLocation} to test location ${coldSiteLocation}..."
    Move-Item $publishLocation $coldSiteLocation
}

if (! (Test-Path $warmSiteLocation)) {
    Write-Host "Warm site location ${warmSiteLocation} does not exist, copying..."
    Copy-Item $coldSiteLocation $warmSiteLocation -Force -Recurse
}

if (! (Test-Path $warmNoCacheLocation)) {
    Write-Host "Warm site, no cache, location ${warmNoCacheLocation} does not exist, copying..."
    Copy-Item $coldSiteLocation $warmNoCacheLocation -Force -Recurse
}

try {
    $env:DOTNET_PACKAGES_CACHE="${env:USERPROFILE}\.nuget\packages"

    $coldPID = RunScenario -appLocation $coldSiteLocation -port $coldSitePort
    [System.IO.File]::AppendAllText("$global:outputFile", ",", [System.Text.Encoding]::Unicode)
    if ($PerfView) {
        Start-Sleep 120    # It takes a while to process the profile even after command finishs
    }

    $warmPID = RunScenario -appLocation $warmSiteLocation -port $warmSitePort
    [System.IO.File]::AppendAllText("$global:outputFile", ",", [System.Text.Encoding]::Unicode)
    if ($PerfView) {
        Start-Sleep 120    # It takes a while to process the profile even after command finishs
    }

    Remove-Item Env:\DOTNET_PACKAGES_CACHE

    $nocachePID = RunScenario -appLocation $warmNoCacheLocation -port $warmNoCachePort
    [System.IO.File]::AppendAllText("$global:outputFile", "`r`n", [System.Text.Encoding]::Unicode)
}
finally {
    try {
        Stop-Process $warmPID
    }
    catch {}

    try {
        Stop-Process $coldPID
    }
    catch {}

    try {
        Stop-Process $nocachePID
    }
    catch {}
}

