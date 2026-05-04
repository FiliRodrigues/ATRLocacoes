Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

projectRoot = fso.GetParentFolderName(WScript.ScriptFullName)
launcherPath = fso.BuildPath(projectRoot, "run_atr.bat")

shell.CurrentDirectory = projectRoot
shell.Run Chr(34) & launcherPath & Chr(34), 0, False