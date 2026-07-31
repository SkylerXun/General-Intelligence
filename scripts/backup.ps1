param(
    [ValidateSet('local', 'prod')]
    [string]$Environment = 'local'
)

$ErrorActionPreference = 'Stop'
& wsl -d Ubuntu -- bash /mnt/d/gateway/scripts/backup.sh $Environment
exit $LASTEXITCODE
