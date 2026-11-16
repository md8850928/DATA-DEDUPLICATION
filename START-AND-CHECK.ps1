# Build, deploy, and smoke-check the local Data Deduplication app on Tomcat 9.
# Run from any PowerShell window; no Administrator session is required if MySQL is running.

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$tomcatHome = Join-Path $env:LOCALAPPDATA 'Programs\apache-tomcat-9.0.124'
$contextName = 'data-deduplication-desktop'
$deployPath = Join-Path $tomcatHome "webapps\$contextName"
$databaseName = 'Datadeduplication-2024'

function Stop-WithMessage([string]$message) {
    Remove-Item Env:DB_PASSWORD -ErrorAction SilentlyContinue
    Write-Host "CHECK FAILED: $message" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command javac -ErrorAction SilentlyContinue)) {
    Stop-WithMessage 'JDK 8 javac was not found on PATH. Install/configure the JDK, then reopen PowerShell.'
}
if (-not (Test-Path -LiteralPath (Join-Path $tomcatHome 'bin\startup.bat'))) {
    Stop-WithMessage "Tomcat 9 was not found at $tomcatHome. Update the tomcatHome value in this script if you installed it elsewhere."
}
 $dbHelper = Join-Path $projectRoot 'src\com\DBConnect\Dataduplicate\DbConnection.java'
if (-not (Test-Path -LiteralPath $dbHelper)) {
	Copy-Item -LiteralPath (Join-Path $projectRoot 'src\com\DBConnect\Dataduplicate\DbConnection.java.example') -Destination $dbHelper
	Write-Host 'Created the ignored local database helper from its safe template.'
}

$mysqlService = Get-Service -Name 'MySQL57' -ErrorAction SilentlyContinue
if ($null -eq $mysqlService -or $mysqlService.Status -ne 'Running') {
    Stop-WithMessage 'MySQL57 is not running. Start the MySQL57 service, then run this script again.'
}

if ([string]::IsNullOrEmpty($env:DB_PASSWORD)) {
    $securePassword = Read-Host 'Enter your local MySQL password (input is hidden)' -AsSecureString
    $env:DB_PASSWORD = [System.Net.NetworkCredential]::new('', $securePassword).Password
}
if ([string]::IsNullOrEmpty($env:DB_PASSWORD)) {
    Stop-WithMessage 'A MySQL password is required. The app reads it from DB_PASSWORD.'
}
if ([string]::IsNullOrEmpty($env:DB_USER)) {
    $env:DB_USER = 'root'
}

$libPath = Join-Path $projectRoot 'WebContent\WEB-INF\lib'
$classesPath = Join-Path $projectRoot 'build\classes'
$sourceFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src') -Recurse -Filter '*.java' |
    ForEach-Object { $_.FullName }
if ($sourceFiles.Count -eq 0) {
    Stop-WithMessage 'No Java source files were found under src.'
}

New-Item -ItemType Directory -Force -Path $classesPath | Out-Null
& javac -cp (Join-Path $libPath '*') -d $classesPath $sourceFiles
if ($LASTEXITCODE -ne 0) {
    Stop-WithMessage 'Java compilation failed. Review the javac errors above.'
}
Write-Host 'Java compilation succeeded.' -ForegroundColor Green

# Verify the configured database and expected base tables before deploying.
$checkDir = Join-Path $projectRoot 'build\db-check'
New-Item -ItemType Directory -Force -Path $checkDir | Out-Null
$checkSource = Join-Path $checkDir 'DatabaseCheck.java'
@'
import com.DBConnect.Dataduplicate.DbConnection;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

public class DatabaseCheck {
    public static void main(String[] args) throws Exception {
        Connection connection = DbConnection.connect();
        if (connection == null) throw new IllegalStateException("Could not connect to MySQL.");
        Set<String> tables = new HashSet<String>();
        DatabaseMetaData metadata = connection.getMetaData();
        try (ResultSet result = metadata.getTables(connection.getCatalog(), null, "%", new String[] {"TABLE"})) {
            while (result.next()) tables.add(result.getString("TABLE_NAME").toLowerCase(Locale.ROOT));
        }
        connection.close();
        String[] required = {"user", "owner", "upload", "upload1", "keyreq", "ukeys", "fcount", "attack", "req"};
        for (String table : required) {
            if (!tables.contains(table)) throw new IllegalStateException("Missing table: " + table + ". Import database/demo-schema.sql first.");
        }
        System.out.println("Database connection and required tables are ready.");
    }
}
'@ | Set-Content -LiteralPath $checkSource -Encoding ASCII
$checkClasses = Join-Path $checkDir 'classes'
New-Item -ItemType Directory -Force -Path $checkClasses | Out-Null
$classpath = "$classesPath;$libPath\*"
& javac -cp $classpath -d $checkClasses $checkSource
if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Could not prepare the database verification check.' }
& java -cp "$checkClasses;$classpath" DatabaseCheck
if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Database verification failed. Check the password and import database/demo-schema.sql.' }

$portInUse = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if ($portInUse) {
	Stop-WithMessage "Port 8080 is already in use. Stop the existing Tomcat process first, then rerun. If this is your Tomcat installation, run: & `"$tomcatHome\bin\shutdown.bat`""
}

New-Item -ItemType Directory -Force -Path $deployPath | Out-Null
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'WebContent') -Force |
    Copy-Item -Destination $deployPath -Recurse -Force
$webInf = Join-Path $deployPath 'WEB-INF'
New-Item -ItemType Directory -Force -Path (Join-Path $webInf 'classes') | Out-Null
Get-ChildItem -LiteralPath $classesPath -Force |
    Copy-Item -Destination (Join-Path $webInf 'classes') -Recurse -Force
Remove-Item -LiteralPath (Join-Path $webInf 'lib\servlet-api.jar') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $webInf 'lib\jsp-api.jar') -Force -ErrorAction SilentlyContinue

$env:CATALINA_HOME = $tomcatHome
$env:CATALINA_BASE = $tomcatHome
& (Join-Path $tomcatHome 'bin\startup.bat')
if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'Tomcat startup did not complete successfully.' }
Remove-Item Env:DB_PASSWORD -ErrorAction SilentlyContinue

$projectUrl = "http://localhost:8080/$contextName/"
$response = $null
for ($attempt = 1; $attempt -le 20; $attempt++) {
    Start-Sleep -Seconds 2
    try {
        $response = Invoke-WebRequest -Uri $projectUrl -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) { break }
    } catch {
        $response = $null
    }
}
if ($null -eq $response -or $response.StatusCode -ne 200) {
    Stop-WithMessage "The app did not return HTTP 200 from $projectUrl. Check Tomcat logs under $tomcatHome\logs."
}

Write-Host "SUCCESS: Java compiled, MySQL schema is present, and the home page returned HTTP 200: $projectUrl" -ForegroundColor Green
Start-Process $projectUrl
