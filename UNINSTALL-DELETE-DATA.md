# Uninstall And Delete Data

Use this when a tester is done with SteadyType or wants a clean reset.

## Quit The App

Open the menu bar item and choose `Quit`.

## Remove The App

Delete `SteadyType.app` from `/Applications` or wherever it was installed.

## Remove Local Logs And Traces

Run:

```bash
./script/delete_local_traces.sh
```

This removes local SteadyType trace/log exports that the script knows
about. You can also inspect:

```text
~/Library/Logs/SteadyType
```

## Remove Personal Capture

Personal Capture is off by default and only for local dogfood. If you enabled
it, delete it from Settings or remove:

```text
~/Library/Application Support/SteadyType/Personal Capture
```

## Remove Model Files

Delete the app-owned model cache if you want to reclaim disk space:

```text
~/Library/Application Support/SteadyType/Models
```

## Remove Local Settings

SteadyType uses local user defaults for settings such as pause state,
disabled apps, shortcuts, and debug toggles.

For a full reset, remove the app preferences for the bundle ID
`bar.r3d.steadytype` from the test account.

## Remove Accessibility Trust

Open macOS System Settings, go to Privacy & Security, then Accessibility, and
remove SteadyType if it is still listed.

## Verify Removal

After removal, relaunching the app should require Accessibility permission
again, and Diagnostics should have no prior local trace history.
