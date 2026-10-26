# Native Windows support (draft)

Tracked by #27. This branch develops native Windows x64 with PowerShell 7,
without administrator privileges, symlinks, junctions, or persistent system PATH
changes. Node uses the official Windows ZIP layout. Switching changes only the
current PowerShell process. Existing macOS/Linux behavior must remain unchanged.

Validation targets: unit tests, Linux/macOS regression suites, and native
`windows-latest` smoke tests with temporary HOME/USERPROFILE/NVM_DIR. Cross
compilation is a build check, not Windows runtime validation.

The first implementation targets install/list/which/current/use/run/exec,
aliases and removal. cmd.exe integration, automatic directory hooks, native
interactive arrow-key menus and Windows ARM64 runtime validation are not part
of the initial support claim. No release is published by this PR.

Implementation and verification are in progress; see the PR checks for results.
