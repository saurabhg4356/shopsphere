$root = "C:\CI CD DevOps Project\shopsphere"

$services = @(
    @{ Name = "user-service"; Path = "$root\user-services"; Port = 8001 },
    @{ Name = "product-service"; Path = "$root\product-service"; Port = 8002 },
    @{ Name = "order-service"; Path = "$root\order-service"; Port = 8003 }
)

foreach ($service in $services) {
    $command = "Set-Location '$($service.Path)'; python -m uvicorn main:app --reload --port $($service.Port)"
    Start-Process powershell -ArgumentList '-NoExit', '-Command', $command
    Write-Host "Started $($service.Name) on port $($service.Port)"
}
