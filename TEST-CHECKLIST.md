# Data Deduplication: Run and Test Checklist

## Start the application

1. Start the Windows `MySQL57` service.
2. In MySQL Workbench, open and execute `database/demo-schema.sql` once. It creates empty tables only.
3. Open PowerShell in the project folder and run:

   ```powershell
   .\START-AND-CHECK.ps1
   ```

4. Enter the local MySQL password at the hidden prompt. The script compiles Java, verifies MySQL tables, deploys the app, starts Tomcat, and opens `http://localhost:8080/data-deduplication-desktop/` after an HTTP 200 response.

## Test the main workflow

Use dummy accounts and a small text file such as `test-file.txt`. Do not use personal files or real passwords.

| Check | What to do | Expected result |
| --- | --- | --- |
| Home page | Open the project URL. | The page loads without a blank screen or server error. |
| Data-owner account | Register and log in through the owner flow. | Registration/login completes and owner pages open. |
| Upload | Upload `test-file.txt`. | A success message and file ID/key information appear. |
| Duplicate handling | Upload the same file again. | The app reports or handles the duplicate. |
| User account | Register a user and complete the project approval flow. | Registration/login completes. |
| Search | Search for the uploaded file as a user. | The uploaded file appears. |
| Key request | Request access to that file. | The request appears in the owner key/share page. |
| Owner approval | Approve the pending request as the owner. | The request is approved and keys are shared. |
| Download | Download using the valid file ID and keys. | The file downloads successfully. |
| Invalid key | Try an incorrect key with a dummy file. | The download is refused or an error is shown. |
| Demo roles | Open Proxy Server and Malicious User pages. | Pages load; do not use real credentials or attack real systems. |

## If a check fails

- If MySQL is stopped, start the `MySQL57` service.
- If the script reports missing tables, execute `database/demo-schema.sql` in MySQL Workbench.
- If the browser check fails, review the newest Tomcat logs under `%LOCALAPPDATA%\Programs\apache-tomcat-9.0.124\logs`.
- Never send passwords in screenshots or chat.

## Important

This is a local academic demo. It stores passwords in plain text and includes SQL injection risks and a hard-coded demo administrator account. Use only dummy data, and do not deploy it publicly.
