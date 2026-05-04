Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

projectRoot = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(projectRoot, "run_atr_windows.ps1")
command = "powershell.exe -ExecutionPolicy Bypass -File " & Chr(34) & scriptPath & Chr(34)

shell.CurrentDirectory = projectRoot
shell.Run command, 0, False