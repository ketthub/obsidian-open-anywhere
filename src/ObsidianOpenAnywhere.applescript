-- ObsidianOpenAnywhere.app
--
-- Receives .md files (via double-click as default app, or drag-and-drop)
-- and forwards them to open-in-obsidian.sh, which lives inside the
-- app bundle at Contents/Resources/.
--
-- Part of: obsidian-open-anywhere
-- https://github.com/Kt-L/obsidian-open-anywhere

on run
	display dialog "Drop .md files onto this app, or set it as the default app for .md files in Finder (Get Info → Open with → Change All)." buttons {"OK"} default button "OK" with title "Obsidian Open Anywhere"
end run

on open theFiles
	-- Resolve the bundled shell script and config relative to this .app.
	set appPath to POSIX path of (path to me)
	set scriptPath to appPath & "Contents/Resources/open-in-obsidian.sh"
	set configPath to appPath & "Contents/Resources/config.sh"

	set quotedArgs to ""
	repeat with f in theFiles
		set posixPath to POSIX path of f
		set quotedArgs to quotedArgs & " " & quoted form of posixPath
	end repeat

	try
		-- Pass the config path through the environment so the shell script
		-- always finds its config inside the .app bundle.
		do shell script "export OOA_CONFIG_PATH=" & quoted form of configPath & "; " & quoted form of scriptPath & quotedArgs
	on error errMsg number errNum
		display notification errMsg with title "Obsidian Open Anywhere"
	end try
end open
