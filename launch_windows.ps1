$ErrorActionPreference = 'Stop'
Set-Location C:\Users\2022\basqaru
if (-not (Test-Path data)) { New-Item -ItemType Directory data | Out-Null }

# kill previous service and game instances
Get-CimInstance Win32_Process -Filter "Name='python.exe'" | Where-Object { $_.CommandLine -like '*basqaru*server.py*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; Write-Output ("old service stopped: " + $_.ProcessId) }
Get-Process -Name Basqaru -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# token + free port
$token = (New-Guid).ToString('N')
$port = (python -c "import socket; s=socket.socket(); s.bind(('127.0.0.1',0)); print(s.getsockname()[1]); s.close()").Trim()
$api = "http://127.0.0.1:$port"
"port=$port api=$api"

# start service in background with env
$env:BASQARU_TOKEN = $token
$env:BASQARU_PORT = "$port"
$env:BASQARU_API_URL = $api
$svc = Start-Process -FilePath python -ArgumentList "service/server.py" `
        -WorkingDirectory C:\Users\2022\basqaru `
        -RedirectStandardOutput C:\Users\2022\basqaru\data\service.log `
        -RedirectStandardError C:\Users\2022\basqaru\data\service.err.log `
        -PassThru -WindowStyle Hidden
"service pid=$($svc.Id)"

# wait for health
$ok = $false
for ($i=0; $i -lt 100; $i++) {
  try { $r = Invoke-WebRequest -UseBasicParsing -Uri "$api/health" -TimeoutSec 1; if ($r.StatusCode -eq 200) { $ok=$true; break } } catch {}
  Start-Sleep -Milliseconds 100
}
"service healthy: $ok"

# launch game client with env
$env:BASQARU_API_URL = $api
$env:BASQARU_TOKEN = $token
Start-Process -FilePath C:\Users\2022\basqaru\build\Basqaru.exe -WorkingDirectory C:\Users\2022\basqaru
"game launched"
"SAVE: port=$port token=$token"
