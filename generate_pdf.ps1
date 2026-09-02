$ErrorActionPreference = "Stop"
$word = New-Object -ComObject Word.Application
$word.Visible = $true
$word.DisplayAlerts = 0

$letterheadPath = "C:\Users\Abel Seyoum\Downloads\Telegram Desktop\MSS Letter head sample.docx"
$docPath = "C:\flutter_dev\deresegn\INSA_Documentation_Combined.html"
$pdfPath = "C:\flutter_dev\deresegn\INSA_Documentation_Final_Combined.pdf"

try {
    Write-Host "Opening letterhead..."
    $doc = $word.Documents.Open($letterheadPath)
    
    Write-Host "Clearing letterhead content..."
    $doc.Content.Delete()
    
    Write-Host "Inserting INSA documentation..."
    $doc.Content.InsertFile($docPath)
    
    Write-Host "Exporting to PDF..."
    $doc.ExportAsFixedFormat($pdfPath, 17)
    
    Write-Host "PDF generated successfully at $pdfPath"
} catch {
    Write-Host "Error: $_"
} finally {
    if ($doc) {
        $doc.Close(0)
    }
    $word.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
}
