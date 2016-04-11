$global:targetApp = "HelloWorldMvc"
$global:workspace = [System.IO.Path]::Combine($env:USERPROFILE, "aspnet", "tests", "workspace")

if (! (Test-Path $global:workspace)) {
    mkdir $global:workspace
}

if(($env:PERFTOOLS) -and (Test-Path $env:PERFTOOLS) -and !($env:PATH.StartsWith($env:PERFTOOLS + ";"))){
    $env:PATH = $env:PERFTOOLS + ";" +  $env:PATH
    Write-Host "Adding TOOLS PATH $env:PERFTOOLS"
}

$outputDir = [System.IO.Path]::Combine($global:workspace, "tests", "current")

if (! (Test-Path $outputDir)) {
    mkdir $outputDir
}

$global:outputFile = (Get-ChildItem -filter *.csv $outputDir | Select-Object FullName -Last 1).FullName

if ([System.String]::IsNullOrEmpty($global:outputFile)) {
    $runId = Get-Date -Format yyyy-MM-dd-HH-mm-ss
    $global:outputFile = (Join-Path $outputDir "${runId}.csv")
}

Write-Host "Tests will be recorded in file: $outputFile"
