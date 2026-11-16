# Data Deduplication System

A Java/JSP/Servlet academic project that stores uploaded files, tracks duplicate content, manages key requests, and demonstrates owner, user, proxy, and administrator workflows.

## Stack

- JDK 8
- Apache Tomcat 9
- MySQL 5.7
- MySQL Connector/J and Gson, included under `WebContent/WEB-INF/lib`

## Project layout

```text
src/                         Java servlets, database helper, and model classes
WebContent/                  JSP pages, static assets, and web.xml
database/demo-schema.sql     Empty local demo tables (no accounts or files)
START-AND-CHECK.ps1          Compile, verify MySQL, deploy, start Tomcat, and check the home page
```

## First-time setup on Windows

1. Install JDK 8, MySQL Server 5.7, and Apache Tomcat 9. The startup script expects Tomcat at `%LOCALAPPDATA%\Programs\apache-tomcat-9.0.124`; edit `$tomcatHome` in the script if yours is elsewhere.
2. Start the `MySQL57` Windows service and open `database/demo-schema.sql` in MySQL Workbench. Execute the script to create the empty `Datadeduplication-2024` database and required tables. It does not create demo users or include personal data.
3. In VS Code, open **Terminal → New Terminal** in the project folder and run:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\START-AND-CHECK.ps1"
   ```

   This uses a temporary execution-policy bypass for the child PowerShell process, avoiding the common “running scripts is disabled” error. The script asks for your MySQL password without displaying it, compiles the Java sources, confirms the required tables exist, deploys to Tomcat, and opens the app at `http://localhost:8080/data-deduplication-desktop/`.

The database helper reads `DB_PASSWORD` from the process environment. It is intentionally ignored by Git (`src/com/DBConnect/Dataduplicate/DbConnection.java`), so never commit it. If that local file is missing, the startup script creates it from the tracked `DbConnection.java.example` template. The script does not write the password into source files.

## Manual build and deploy

From PowerShell in the project folder:

```powershell
$src = Get-ChildItem .\src -Recurse -Filter *.java | ForEach-Object FullName
New-Item -ItemType Directory -Force .\build\classes | Out-Null
javac -cp ".\WebContent\WEB-INF\lib\*" -d .\build\classes $src
```

For normal local use, prefer `START-AND-CHECK.ps1`, which also deploys the web assets and compiled classes and checks the result.

## Smoke-test workflow

Use dummy accounts and a small text file. Follow [TEST-CHECKLIST.md](TEST-CHECKLIST.md) to check registration, approval, duplicate upload handling, key requests, and downloads.

## Known limitations

- This is a legacy academic demo, not production-ready software. Some servlet queries still build SQL by concatenating request values, login passwords are stored as plain text, and the demo admin login is hard-coded. Do not expose it to the public internet or use real credentials/data.
- Some older demo routes are not connected to the included schema. The startup script checks the core schema and static/JSP home page, not every user workflow.
- `START-AND-CHECK.ps1` uses Tomcat's default HTTP port 8080 and expects that port to be free so the started Tomcat process inherits the database password.
- Tomcat requires the Servlet/JSP APIs from its own installation. The startup script removes the duplicate `servlet-api.jar` and `jsp-api.jar` from the deployed app.

## Troubleshooting

- **`javac` not found:** Install/configure the JDK and reopen PowerShell.
- **MySQL service stopped:** Start `MySQL57`, then rerun the script.
- **Missing tables or connection failed:** Execute `database/demo-schema.sql` in MySQL Workbench, check that the server is running, then rerun the script and enter the correct local password.
- **Port 8080 is in use:** Stop the existing Tomcat process before running the script.
- **HTTP check failed:** Review the newest logs in `%LOCALAPPDATA%\Programs\apache-tomcat-9.0.124\logs`.
