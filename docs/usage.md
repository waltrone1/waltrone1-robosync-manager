# Usage Guide

This document explains the basic usage of **waltrone1 RoboSync-Manager**.

waltrone1 RoboSync-Manager is a Windows synchronization and directory comparison tool by **WALTRONE**.

It provides a graphical interface for common robocopy-based workflows, directory comparison, optional SHA256 checks and HTML report generation.

---

## Basic Usage

1. Download the latest release.
2. Extract the ZIP file completely.
3. Start the application.
4. Select a source folder.
5. Select a target folder.
6. Review the generated robocopy command preview.
7. Optionally run a compare before synchronization.
8. Configure synchronization options if needed.
9. Start synchronization.
10. Review the output and generated HTML report.

---

## Main Workflow

The typical workflow is:

1. Start waltrone1 RoboSync-Manager.
2. Select the source path.
3. Select the target path.
4. Review the command preview.
5. Use Compare mode if you want to inspect differences first.
6. Decide whether a normal sync, MOVE or MIRROR operation is needed.
7. Start synchronization.
8. Review the live output.
9. Open the generated HTML report.
10. Archive or share the report if needed.

---

## Source and Target Paths

The application supports local paths and network paths.

Examples:

```text
C:\Data
D:\Backup
Z:\Projects
\\server\share\folder
```

Recommended workflow for network shares:

```text
Map the network share to a drive letter first, for example Z:
Then use Z:\Folder as source or target.
```

UNC paths can work, but for larger synchronization jobs mapped network drives are usually more stable and easier to troubleshoot.

---

## Synchronization

Synchronization uses **robocopy** in the background.

The application builds a robocopy command based on the selected source, target and options.

Default behavior:

```text
robocopy.exe "source" "target" /E /R:2 /W:5 /NP /XJ /FFT
```

The command preview is shown before the run starts.

Always review the preview before starting a synchronization job.

---

## Synchronization Options

### Normal Sync

Normal sync copies files and folders from source to target.

It does not intentionally delete extra files in the target.

Use this mode for common copy and update workflows.

---

### MOVE Mode

MOVE mode moves files from source to target.

Important:

```text
MOVE can empty the source.
```

Use MOVE only when you really want to move files away from the source location.

Typical use cases:

- Moving completed exports
- Moving files into an archive folder
- Moving data from an old location to a new location
- Controlled cleanup workflows

---

### MIRROR Mode

MIRROR mode mirrors the target to match the source.

Important:

```text
MIRROR can delete files and folders in the target if they no longer exist in the source.
```

Use MIRROR carefully.

Typical use cases:

- Exact folder replication
- Backup-style mirror copies
- Controlled migration validation
- Keeping a target folder identical to a source folder

Before using MIRROR, check the source and target paths carefully.

---

## Compare Mode

Compare mode checks source and target without changing files.

It can show:

- Files or folders only in source
- Files or folders only in target
- Different files
- Different directories
- Size or timestamp differences
- Optional SHA256 hash differences

Basic workflow:

1. Open the Compare tab.
2. Select source and target.
3. Optionally enable SHA256 comparison.
4. Start compare.
5. Review the results.
6. Use the filter field to search inside the results.
7. Open the generated HTML report if needed.

---

## SHA256 Compare

SHA256 compare performs a more exact file comparison.

It can detect differences based on file content instead of only size and timestamp.

Important:

```text
SHA256 comparison is slower, especially on large folders or network paths.
```

Use SHA256 when accuracy is more important than speed.

Typical use cases:

- Verifying migration results
- Checking if files with same names are truly identical
- Comparing backup folders
- Validating important data sets

---

## Compare Result Types

### Only in source

The item exists in the source but not in the target.

This may mean the file still needs to be copied.

---

### Only in target

The item exists in the target but not in the source.

This may be expected in some workflows, but it should be reviewed before using MIRROR mode.

---

### Different

The item exists in both locations but differs.

Depending on the selected compare mode, this may be based on:

- File size
- Last write time
- SHA256 hash
- Directory metadata

---

## Double-Click Behavior

In Compare mode, double-clicking a result can open or select the related file or folder in Windows Explorer.

For different files, the source or target column can be used to open the corresponding file location.

This helps review differences faster before taking action.

---

## Reports

waltrone1 RoboSync-Manager creates HTML reports for synchronization and compare runs.

Reports are created next to the application.

Example sync report:

```text
Robocopy_YYYY-MM-DD_HH-mm-ss.html
```

Example compare report:

```text
Compare_YYYY-MM-DD_HH-mm-ss.html
```

The reports can be opened directly from the application.

---

## Sync Report

The synchronization report may include:

- Start time
- End time
- Duration
- Exit code
- Source path
- Target path
- Selected mode
- Warnings
- Errors
- Status history
- Log extract

The report is useful for documentation, troubleshooting and handover workflows.

---

## Compare Report

The compare report may include:

- Source path
- Target path
- Compare mode
- SHA256 status
- Count of items only in source
- Count of items only in target
- Count of different items
- Searchable result table
- Optional preview for text-based file differences

The compare report is useful when validating migrations, backups or folder synchronization results.

---

## Robocopy Exit Codes

Robocopy uses special exit codes.

A non-zero exit code does not always mean a critical error.

General interpretation:

```text
0 = No files copied / no changes
1 = Files copied successfully
2 = Extra files or directories detected
3 = Files copied and extra files detected
4 = Mismatched files or directories detected
5-7 = Combination of copy / extra / mismatch states
8 or higher = Usually indicates an error
```

The HTML report shows the robocopy exit code for easier review.

---

## Language Options

The application supports English and German language modes.

Examples:

```text
-Lang en
-Lang de
```

English is the default language.

---

## Network Shares and UNC Paths

The tool can work with UNC paths such as:

```text
\\server\share\folder
```

For larger sync jobs, the recommended workflow is:

```text
1. Map the network share as a drive letter.
2. Use the mapped drive path in the tool.
```

Example:

```text
Z:\ProjectData
D:\Backup
```

This is usually easier to handle than long UNC paths and may reduce permission or reconnect issues.

---

## Credentials

When UNC paths are used, Windows may require credentials.

The tool may ask for credentials when needed.

If authentication fails:

- Check username and password.
- Check share permissions.
- Check NTFS permissions.
- Check whether an existing connection uses different credentials.
- Try disconnecting old network connections.
- Try mapping the share manually in Windows Explorer.

---

## Safety Notes

Please review the following before using the tool:

- Always check source and target before starting.
- Always review the command preview.
- Be very careful with MIRROR mode.
- Be careful with MOVE mode.
- Test with non-critical data first.
- Use Compare mode before destructive workflows.
- Keep a backup before large changes.
- Do not use MIRROR on an unknown target folder.
- Do not use MOVE unless the source may be emptied.
- Review reports after each important run.

---

## Recommended Workflow Before MIRROR

Before running MIRROR mode:

1. Select source and target.
2. Run Compare mode first.
3. Review files only in target.
4. Confirm that deleting extra target files is intended.
5. Start MIRROR only when the result is expected.

---

## Recommended Workflow Before MOVE

Before running MOVE mode:

1. Confirm that the source may be emptied.
2. Confirm that the target has enough free space.
3. Run a small test if possible.
4. Start MOVE only when the workflow is clear.
5. Review the report after completion.

---

## Screenshots

Screenshots are available in the repository under:

```text
screenshots/
```

The main README also includes a visual overview of the application.

---

## Build / Source Notes

The source files are located in:

```text
src/
```

Build-related files for creating a Windows executable are located in:

```text
src/py2exe/
```

Generated build output such as `.exe`, `.zip`, `build/`, `dist/` or release folders should not be committed directly to the repository.

Final release packages should be published through GitHub Releases.

---

## Advanced Notes

The source code contains a headless task mode for future or internal automation workflows.

Example:

```text
--task
```

Important:

```text
This mode should only be used after reviewing and configuring the source/target paths in the source code or configuration workflow.
```

For normal users, the graphical interface is the recommended way to use the tool.

---

## Troubleshooting

### The tool does not start

Try the following:

- Extract the ZIP file completely before starting the application.
- Start the application from a local folder.
- Check whether antivirus or Windows SmartScreen blocks the file.
- Test the tool in a separate folder or test environment.
- Run the tool as Administrator if needed.

---

### Synchronization does not start

Check the following:

- Source path exists.
- Target path exists or can be created.
- You have permission to read the source.
- You have permission to write to the target.
- Network shares are reachable.
- No old network connection is blocking access.
- MOVE and MIRROR are not enabled at the same time.

---

### Compare is slow

Compare can take longer when:

- Many files are involved.
- Network shares are used.
- SHA256 compare is enabled.
- Files are very large.
- Antivirus scans files during access.
- The storage system is slow.

For large network folders, mapped drives are recommended.

---

### Some compare entries are missing in the user interface

For very large folder structures, the application may limit the number of visible rows in the interface.

Use the generated HTML report for the full compare result.

---

### UNC authentication fails

Try the following:

- Check credentials.
- Disconnect existing network sessions.
- Map the share manually in Windows Explorer.
- Use a drive letter instead of a UNC path.
- Check share and NTFS permissions.
- Restart the application after changing network credentials.

---

### MIRROR deleted files in the target

MIRROR is designed to make the target match the source.

This means extra files in the target can be deleted.

Before using MIRROR, always run Compare mode and review items that exist only in the target.

---

## Disclaimer

This tool is provided as-is, without warranty of any kind.

Use it at your own risk.

The author is not responsible for data loss, deleted files, synchronization mistakes, wrong source or target selection, system issues, production issues or damages caused by the use of this software.
