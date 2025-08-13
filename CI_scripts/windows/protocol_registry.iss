[Registry]
; Register towdow:// protocol to launch the installed app with the URL argument
Root: HKCR; Subkey: "towdow"; ValueType: string; ValueName: ""; ValueData: "URL:Towdow Protocol"; Flags: uninsdeletekey
Root: HKCR; Subkey: "towdow"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Flags: uninsdeletevalue
Root: HKCR; Subkey: "towdow\shell"; ValueType: string; ValueName: ""; ValueData: "open"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "towdow\shell\open"; ValueType: string; ValueName: ""; ValueData: ""; Flags: uninsdeletevalue
Root: HKCR; Subkey: "towdow\shell\open\command"; ValueType: string; ValueName: ""; ValueData: '"{app}\\TowDow.exe" "%1"'


