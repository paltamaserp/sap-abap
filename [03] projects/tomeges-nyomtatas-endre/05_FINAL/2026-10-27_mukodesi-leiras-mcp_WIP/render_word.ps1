$ErrorActionPreference = 'Stop'
$taskDirectory = $PSScriptRoot
$documentPath = Join-Path $taskDirectory '2026-10-27_tomeges-nyomtatas-mukodesi-technikai-leiras_WIP.docx'
$pdfPath = Join-Path $taskDirectory 'qa/word-render.pdf'
$application = $null
$document = $null
try {
    $application = New-Object -ComObject Word.Application
    $application.Visible = $false
    $application.DisplayAlerts = 0
    $application.AutomationSecurity = 3
    $document = $application.Documents.Open($documentPath, $false, $false)
    $document.Fields.Update() | Out-Null
    foreach ($toc in $document.TablesOfContents) { $toc.Update() }
    $document.Repaginate()
    foreach ($toc in $document.TablesOfContents) { $toc.UpdatePageNumbers() }
    $document.Save()
    $document.ExportAsFixedFormat($pdfPath, 17)
    Write-Output ('Pages: ' + $document.ComputeStatistics(2))
    Write-Output ('PDF: ' + $pdfPath)
} finally {
    if ($null -ne $document) { $document.Close(0); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($document) | Out-Null }
    if ($null -ne $application) { $application.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($application) | Out-Null }
}
