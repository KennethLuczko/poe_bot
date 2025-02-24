# Setup Environment Script for POE Bot
# Run this script with administrator privileges
param([switch]$Elevated)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Self-elevate the script if required
if ((Test-Admin) -eq $false) {
    if ($elevated) {
        Write-Error "Failed to elevate to administrator privileges"
        exit 1
    }

    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    exit
}

# Enable TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Function to log messages
function Write-Log {
    param($Message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

# Function to handle errors
function Handle-Error {
    param($ErrorMessage)
    Write-Log "ERROR: $ErrorMessage"
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

# Create temporary directory for downloads
$tempDir = "C:\temp\poe_bot_setup"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

try {
    # 1. Install Git
    Write-Log "Installing Git..."
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe"
    $gitInstaller = "$tempDir\GitInstaller.exe"
    Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT /NORESTART" -Wait

    # Refresh PATH environment
    Write-Log "Refreshing environment PATH..."
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Verify Git installation
    Write-Log "Verifying Git installation..."
    $retryCount = 0
    $maxRetries = 3
    while ($retryCount -lt $maxRetries) {
        try {
            Start-Sleep -Seconds 10  # Give some time for installation to complete
            $gitVersion = & "C:\Program Files\Git\cmd\git.exe" --version
            Write-Log "Git installed successfully: $gitVersion"
            break
        }
        catch {
            $retryCount++
            if ($retryCount -eq $maxRetries) {
                throw "Failed to verify Git installation after $maxRetries attempts"
            }
            Write-Log "Waiting for Git installation to complete... (Attempt $retryCount of $maxRetries)"
            Start-Sleep -Seconds 10
        }
    }

    # 2. Clone Repository
    Write-Log "Cloning POE Bot repository..."
    $repoPath = "C:\poe_bot"
    git clone git@github.com:KennethLuczko/poe_bot.git $repoPath

    # 3. Install .NET SDK 8.0
    Write-Log "Installing .NET SDK 8.0..."
    $dotnetUrl = "https://download.visualstudio.microsoft.com/download/pr/9b3fac7c-e363-4527-b64c-83c9cfd87b3a/2ccb3b4267477dc3366e7b9fb00f7047/dotnet-sdk-8.0.101-win-x64.exe"
    $dotnetInstaller = "$tempDir\dotnet-sdk-8.0-x64.exe"
    Invoke-WebRequest -Uri $dotnetUrl -OutFile $dotnetInstaller
    Start-Process -FilePath $dotnetInstaller -ArgumentList "/install /quiet /norestart" -Wait

    # 4. Install VC 2015 Redistributable
    Write-Log "Installing VC 2015 Redistributable..."
    $vcUrl = "https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe"
    $vcInstaller = "$tempDir\vc_redist.x64.exe"
    Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller
    Start-Process -FilePath $vcInstaller -ArgumentList "/install /quiet /norestart" -Wait

    # 5. Run Python installation script
    Write-Log "Installing Python..."
    $pythonScript = Join-Path $repoPath "0_guest\1_install_python.bat"
    Start-Process -FilePath $pythonScript -Wait

    # 6. Install Python libraries
    Write-Log "Installing Python libraries..."
    $libScript = Join-Path $repoPath "0_guest\2_install_venv.bat"
    Start-Process -FilePath $libScript -Wait

    # 7. Install ExileCore2
    Write-Log "Installing ExileCore2..."
    $exScript = Join-Path $repoPath "0_guest\3_install_ex2_hud.bat"
    Start-Process -FilePath $exScript -Wait

    Write-Log "Setup completed successfully!"
}
catch {
    Handle-Error $_.Exception.Message
}
finally {
    # Cleanup
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')