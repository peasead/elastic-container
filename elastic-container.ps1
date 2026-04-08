param(
    [Alias('v')]
    [switch]$VerboseMode,

    [Parameter(Position = 0)]
    [string]$Action = 'help'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ComposeMode = $null
$script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function show-usage {
    @"
usage: ./elastic-container.ps1 [-v] (stage|start|stop|restart|status|help)
actions:
    stage     downloads all necessary images to local storage
    start     creates a container network and starts containers
    stop      stops running containers without removing them
    destroy   stops and removes the containers, the network, and volumes created
    restart   restarts all the stack containers
    status    check the status of the stack containers
    clear     clear all documents in logs and metrics indexes
    help      print this message
flags:
    -v        enable verbose output
"@ | Write-Host
}

function import-env {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw ".env missing at path: $Path"
    }

    $map = @{}

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()

        if (-not $trimmed -or $trimmed.StartsWith('#')) {
            continue
        }
        
        $parts = $trimmed -split '=', 2
        if ($parts.Count -ne 2) {
            continue
        }

        $key = $parts[0].Trim()
        $val = $parts[1].Trim()

        if ($val.Length -ge 2) {
            if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
                $val = $val.Substring(1, $val.Length - 2)
            }
        }

        $map[$key] = $val
        Set-Item -Path "Env:$key" -Value $val
    }
    return $map
}

function resolve-compose-command {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        & docker compose version *> $null
        if ($LASTEXITCODE -eq 0) {
            $script:ComposeMode = 'plugin'
            return
        }
    }

    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        & docker-compose version *> $null
        if ($LASTEXITCODE -eq 0) {
            $script:ComposeMode = 'standalone'
            return
        }
    }

    throw "elastic-container requires docker compose plugin or docker-compose standalone."
}

function invoke-compose {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$CaptureOutput
    )

    if (-not $script:ComposeMode) {
        resolve-compose-command
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    try {
        if ($script:ComposeMode -eq 'plugin') {
            $output = & docker compose @Arguments 2>&1 | ForEach-Object { "$_" }
        }
        else {
            $output = & docker-compose @Arguments 2>&1 | ForEach-Object { "$_" }
        }

        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw "docker compose command failed with exit code $exitCode. Output: $($output -join [Environment]::NewLine)"
    }

    if ($CaptureOutput) {
        return ($output -join [Environment]::NewLine)
    }

    $output | ForEach-Object { Write-Host $_ }
}

function test-docker-ready {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "docker command not found. Please install Docker and ensure it's in your PATH."
    }

    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        throw "curl command not found. Please ensure curl is installed and in your PATH."
    }

    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "docker command is not responding. Please ensure Docker is running and you have permission to access it."
    }
}

function assert-password-changed {
    param([hashtable]$config)

    $pending = @()

    foreach ($name in @('ELASTIC_PASSWORD', 'KIBANA_PASSWORD')) {
        if (-not $config.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($config[$name]) -or $config[$name] -eq 'changeme') {
            $pending += $name
        } 
    }

    if ($pending.Count -gt 0) {
        throw "Please update the .env values before starting: $($pending -join ', ')"
    }

    Write-Host "Password values look good."
}

function get-host-ip {
    param([hashtable]$config)

    if ($config.ContainsKey('HOST_IP') -and -not [string]::IsNullOrWhiteSpace($config['HOST_IP'])) {
        return $config['HOST_IP']
    }

    try {
        $routes = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Sort-Object RouteMetric, InterfaceMetric

        foreach ($route in $routes) {
            $ip = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue | 
                Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } | 
                Select-Object -First 1 -ExpandProperty IPAddress
            
                if ($ip) {
                    return $ip
                }
        }
    } catch {
        # fall back below
    }

    $fallback = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
        Where-Object {
            $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and
            $_.IPAddressToString -notlike '169.254*' -and
            $_.IPAddressToString -ne '127.0.0.1'
        } |
        Select-Object -First 1 -ExpandProperty IPAddressToString

    if ($fallback) {
        return $fallback
    }
    throw "Unable to determine host IP address. Please set HOST_IP in the .env file."
}

function get-host-port {
    param(
        [string]$val,
        [string]$DefaultPort
    )

    if ([string]::IsNullOrWhiteSpace($val)) {
        return $DefaultPort
    }

    $parts = $val.Split(':')
    return $parts[$parts.Count - 1]
}

function get-basic-auth-value {
    param(
        [string]$username,
        [string]$password
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$username`:$password")
    return "Basic " + [Convert]::ToBase64String($bytes)
}

function new-kibana-headers {
    param([hashtable]$config)
    return @{
        Authorization = get-basic-auth-value -username $config['ELASTIC_USERNAME'] -password $config['ELASTIC_PASSWORD']
        'kbn-version' = $config['STACK_VERSION']
        'kbn-xsrf' = 'kibana'
        'Content-Type' = 'application/json'
    }
}

function new-elastic-headers {
    param([hashtable]$config)
    return @{
        Authorization = get-basic-auth-value -username $config['ELASTIC_USERNAME'] -password $config['ELASTIC_PASSWORD']
        'Content-Type' = 'application/json'
    }
}

function invoke-curl {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$CaptureOutput
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    try {
        $output = & curl.exe @Arguments 2>&1 | ForEach-Object { "$_" }
        $exitcode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitcode -ne 0) {
        throw "curl command failed with exit code $exitcode. Output: $($output -join [Environment]::NewLine)"
    }

    if ($CaptureOutput) {
        return ($output -join [Environment]::NewLine)
    }

    $output | ForEach-Object { Write-Host $_ }
}

function invoke-api-request {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][hashtable]$Headers,
        $Body,
        [switch]$ExpectJson
    )
    # rargs = request arguments
    $rargs = @('-k', '-sS', '-X', $Method, $Uri)

    foreach ($header in $Headers.GetEnumerator()) {
        $rargs += '-H'
        $rargs += "$($header.Key): $($header.Value)"
    }

    $tempFile = $null

    if ($null -ne $Body) {
        $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 30 -Compress }

        $tempFile = [System.IO.Path]::GetTempFileName()
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tempFile, $json, $utf8NoBom)

        $rargs += '--data-binary'
        $rargs += "@$tempFile"
    }

    try {
        $raw = invoke-curl -Arguments $rargs -CaptureOutput
    }
    finally {
        if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    if ($ExpectJson -and -not [string]::IsNullOrWhitespace($raw)) {
        return $raw | ConvertFrom-Json
    }

    return $raw
}

function get-http-code {
    param([Parameter(Mandatory)][string]$Uri)

    $raw = invoke-curl -Arguments @('-k', '-sS', '-o', 'NUL', '-w', '%{http_code}', $Uri) -CaptureOutput
    return [int]$raw.Trim()
}

function configure-kibana {
    param([hashtable]$config)

    $maxTries = 15
    $headers = new-kibana-headers -config $config
    for ($i = 0; $i -lt $maxTries; $i++) {
        Write-Host ''
        Write-Host 'Attempting to enable the Detection Engine and install prebuilt Detection Rules..'

        $status = 0
        try {
            $status = get-http-code -Uri $config['LOCAL_KBN_URL']
        } catch {
            $status = 0
        }

        if ($status -eq 302) {
            Write-Host ''
            Write-Host 'Kibana is up. Proceeding..'
            Write-Host ''

            $indexRaw = invoke-api-request -Method 'POST' -Uri "$($config['LOCAL_KBN_URL'])/api/detection_engine/index" -Headers $headers
            $indexResponse = $null

            if (-not [string]::IsNullOrWhiteSpace($indexRaw)) {
                try {
                    $indexResponse = $indexRaw | ConvertFrom-Json
                } catch {
                    $indexResponse = $null
                }
            }

            if (-not (($indexResponse -and $indexResponse.acknowledged -eq $true) -or ($indexRaw -match 'already'))) {
                throw 'Detection Engine setup failed'
            }

            Write-Host 'Detection engine enabled. Installing prepackaged rules.'
            [void](invoke-api-request -Method 'PUT' -Uri "$($config['LOCAL_KBN_URL'])/api/detection_engine/rules/prepackaged" -Headers $headers)

            Write-Host ''
            Write-Host 'Prepackaged rules installed!'
            Write-Host ''

            $linuxEnabled = [int]$config['LinuxDR']
            $windowsEnabled = [int]$config['WindowsDR']
            $macEnabled = [int]$config['MacOSDR']

            if ($linuxEnabled -eq 0 -and $windowsEnabled -eq 0 -and $macEnabled -eq 0) {
                Write-Host 'No detection rules enabled in the .env file, skipping detection rules enablement.'
                Write-Host ''
                return
            }

            if ($linuxEnabled -eq 1) {
                [void](invoke-api-request -Method 'POST' -Uri "$($config['LOCAL_KBN_URL'])/api/detection_engine/rules/_bulk_action" -Headers $headers -Body @{
                    query = 'alert.attributes.tags: ("Linux" OR "OS: Linux")'
                    action = 'enable'
                })
                Write-Host ''
                Write-Host 'Successfully enabled Linux detection rules.'
            }

            if ($windowsEnabled -eq 1) {
                [void](invoke-api-request -Method 'POST' -Uri "$($config['LOCAL_KBN_URL'])/api/detection_engine/rules/_bulk_action" -Headers $headers -Body @{
                    query = 'alert.attributes.tags: ("Windows" OR "OS: Windows")'
                    action = 'enable'
                })
                Write-Host ''
                Write-Host 'Successfully enabled Windows detection rules.'
            }

            if ($macEnabled -eq 1) {
                [void](invoke-api-request -Method 'POST' -Uri "$($config['LOCAL_KBN_URL'])/api/detection_engine/rules/_bulk_action" -Headers $headers -Body @{
                    query = 'alert.attributes.tags: ("macOS" OR "OS: macOS")'
                    action = 'enable'
                })
                Write-Host ''
                Write-Host 'Successfully enabled MacOS detection rules.'
            }
            
            Write-Host ''
            return
        }

        Write-Host ''
        Write-Host 'Kibana still loading. Trying again in 40 seconds'
        Start-Sleep -Seconds 40
    }
    throw "Exceeded MAXTRIES ($maxTries) while waiting for Kibana."
}

function get-ca-fingerprint {
    $pem = invoke-compose -Arguments @('exec', '-T', 'elasticsearch', 'cat', '/usr/share/elasticsearch/config/certs/ca/ca.crt') -CaptureOutput
    if ([string]::IsNullOrWhiteSpace($pem)) {
        throw 'Unable to read the CA certificate from the elasticsearch container.'
    }

    $base64 = (($pem -split "\r?\n") | Where-Object {
        $_ -and $_ -notmatch '-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----'
    }) -join ''

    $rawBytes = [Convert]::FromBase64String($base64)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()

    try {
        $hashBytes = $sha256.ComputeHash($rawBytes)
    } finally {
        $sha256.Dispose()
    }

    return (-join ($hashBytes | ForEach-Object { $_.ToString('X2') }))
}

function set-fleet-values {
    param([hashtable]$config,
    [Parameter(Mandatory)][string]$HostIp
    )

    $headers = new-kibana-headers -config $config
    $fleetPort = get-host-port -val $config['FLEET_PORT'] -DefaultPort '8220'
    $esPort = get-host-port -val $config['ES_PORT'] -DefaultPort '9200'

    $current_settings = invoke-api-request -Method 'GET' -Uri "$($config['LOCAL_KBN_URL'])/api/fleet/agents/setup" -Headers $headers

    if ($current_settings -match '"isInitialized"\s*:\s*true') {
        Write-Host 'Fleet settings are already configured.'
        return
    }

    Write-Host 'Fleet is not initialized, setting up Fleet...'

    $fingerprint = get-ca-fingerprint

    [void](invoke-api-request -Method 'POST' -Uri "$($config['LOCAL_KBN_URL'])/api/fleet/fleet_server_hosts" -Headers $headers -Body @{
        host_urls  = @("https://$HostIp`:$fleetPort")
        name       = 'default'
        is_default = $true
    })

    [void](invoke-api-request -Method 'PUT' -Uri "$($config['LOCAL_KBN_URL'])/api/fleet/outputs/fleet-default-output" -Headers $headers -Body @{
        hosts = @("https://$HostIP`:$esPort")
    })

    [void](invoke-api-request -Method 'PUT' -Uri "$($config['LOCAL_KBN_URL'])/api/fleet/outputs/fleet-default-output" -Headers $headers -Body @{
        ca_trusted_fingerprint = $fingerprint
    })

    [void](invoke-api-request -Method 'PUT' -Uri "$($config['LOCAL_KBN_URL'])/api/fleet/outputs/fleet-default-output" -Headers $headers -Body @{
        config_yaml = 'ssl.verification_mode: certificate'
    })

    $policyResponse = invoke-api-request -Method 'POST' -Uri "$($config['LOCAL_KBN_URL'])/api/fleet/agent_policies?sys_monitoring=true" -Headers $headers -Body @{
        name                = 'Endpoint Policy'
        description         = ''
        namespace           = 'default'
        monitoring_enabled  = @('logs', 'metrics')
        inactivity_timeout  = 1209600
    } -ExpectJson

    $policyId = $policyResponse.item.id

    $packageResponse = invoke-api-request -Method 'GET' -Uri "$($Config['LOCAL_KBN_URL'])/api/fleet/epm/packages/endpoint" -Headers $headers -ExpectJson
    $packageVersion = $packageResponse.item.version
    
    [void](invoke-api-request -Method 'POST' -Uri "$($config['LOCAL_KBN_URL'])/api/fleet/package_policies" -Headers $headers -Body @{
    name        = 'Elastic Defend'
    description = ''
    namespace   = 'default'
    policy_id   = $policyId
    enabled     = $true
    inputs      = @(
    @{
        enabled = $true
        streams = @()
        type    = 'ENDPOINT_INTEGRATION_CONFIG'
        config  = @{
            _config = @{
                value = @{
                    type = 'endpoint'
                    endpointConfig = @{
                        preset = 'EDRComplete'
                        }
                    }
                }
            }   
        }
    )
    package = @{
        name    = 'endpoint'
        title   = 'Elastic Defend'
        version = $packageVersion
    }
    })
}

function clear-documents {
    param([hashtable]$config)

    $headers = new-elastic-headers -config $config

    try {
        $logsResponse = invoke-api-request -Method 'DELETE' -Uri "$($config['LOCAL_ES_URL'])/_data_stream/logs-*" -Headers $headers -ExpectJson
        if ($logsResponse.acknowledged -eq $true) {
            Write-host 'Successfully cleared logs data stream.'
        } else {
            Write-host 'Failed to clear logs data stream.'
        }
    } catch {
        Write-Host 'Failed to clear logs data stream.'
    }

    try {
        $metricsResponse = invoke-api-request -Method 'DELETE' -Uri "$($config['LOCAL_ES_URL'])/_data_stream/metrics-*" -Headers $headers -ExpectJson
        if ($metricsResponse.acknowledged -eq $true) {
            Write-host 'Successfully cleared metrics data stream.'
        } else {
            Write-Host 'Failed to clear metrics data stream.'
        }
    } catch {
        Write-Host 'Failed to clear metrics data stream.'
    }
}

function invoke-docker-pull {
    param(
        [Parameter(Mandatory)][string]$Image
    )

    & docker pull $Image
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to pull image: $Image"
    }
}

Push-Location $script:ScriptRoot

try {
    $actionName = $Action.ToLowerInvariant()

    if ($actionName -eq 'help') {
        show-usage
        return
    }

    $config = import-env -Path (Join-Path $script:ScriptRoot '.env')

    switch ($actionName) {
        'stage' {
            test-docker-ready
            Write-Host 'Staging Elastic images locally.'
            invoke-docker-pull -Image "docker.elastic.co/elasticsearch/elasticsearch:$($config['STACK_VERSION'])"
            invoke-docker-pull -Image "docker.elastic.co/kibana/kibana:$($config['STACK_VERSION'])"
            invoke-docker-pull -Image "docker.elastic.co/elastic-agent/elastic-agent:$($config['STACK_VERSION'])"
        }

        'start' {
            assert-password-changed -config $config
            test-docker-ready

            $hostIp = get-host-ip -config $config
            if ($VerboseMode) {
                Write-host "Using host IP: $hostIP"
            }

            Write-Host 'Starting Elastic Stack network and containers'
            invoke-compose -Arguments @('up', '-d', '--no-deps')

            configure-kibana -config $config

            Write-Host 'Waiting 40 seconds for Fleet Server setup.'
            Write-Host ''
            Start-Sleep -Seconds 40

            Write-host 'Populating Fleet Settings.'
            set-fleet-values -config $config -HostIp $hostIp
            Write-Host ''

            $kibanaPort = get-host-port -val $config['KIBANA_PORT'] -DefaultPort '5601'

            Write-Host 'READY SET GO'
            Write-Host ''
            Write-Host "Browse to https://localhost:$kibanaPort"
            Write-Host "Username: $($config['ELASTIC_USERNAME'])"
            If ($VerboseMode) {
                Write-Host 'Password is the ELASTIC_PASSWORD value from your .env file.'
            }
            Write-Host ''
        }

        'stop' {
            test-docker-ready
            Write-Host 'Stopping running containers.'
            invoke-compose -Arguments @('stop')
        }

        'destroy' {
            test-docker-ready
            Write-Host '#####'
            Write-Host 'Stopping and removing containers, networks, and volumes created.'
            Write-Host '#####'
            invoke-compose -Arguments @('down', '-v')
        }

        'restart' {
            test-docker-ready
            Write-Host '#####'
            Write-Host 'Restarting all Elastic Stack components.'
            Write-Host '#####'
            invoke-compose -Arguments @('restart', 'elasticsearch', 'kibana', 'fleet-server')
        }

        'status' {
            test-docker-ready
            $psOutput = invoke-compose -Arguments @('ps') -CaptureOutput
            ($psOutput -split "\r?\n" | Where-Object { $_ -notmatch 'setup' }) | ForEach-Object { Write-Host $_ }
        }

        'clear' {
            test-docker-ready
            clear-documents -config $config
        }

        default {
            Write-Host 'Proper syntax not used. See the usage.'
            Write-Host ''
            show-usage
        }
    } 
} finally {
    Pop-Location
}