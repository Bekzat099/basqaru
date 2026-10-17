# Stops the Basqaru game and its local AI service.
Get-CimInstance Win32_Process -Filter "Name='python.exe'" | Where-Object { $_.CommandLine -like '*service/server.py*' } | ForEach-Object {
  Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
  Write-Output "service stopped: $($_.ProcessId)"
}
Get-Process -Name Basqaru -ErrorAction SilentlyContinue | ForEach-Object {
  Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
  Write-Output "game stopped: $($_.ProcessId)"
}
Write-Output "Basqaru stopped."
