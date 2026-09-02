$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0

$docPath = "C:\flutter_dev\deresegn\INSA_Documentation_Final.docx"
$outPath = "C:\flutter_dev\deresegn\insa_doc_text.txt"

try {
    $doc = $word.Documents.Open($docPath)
    $text = $doc.Content.Text
    Set-Content -Path $outPath -Value $text -Encoding UTF8
    Write-Host "DOCX text extracted successfully."
} catch {
    Write-Host "Error: $_"
} finally {
    if ($doc) {
        $doc.Close(0)
    }
    $word.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
}
