# Uninstall And Delete Data

Use this when a tester is done with Autocomplete Lab or wants a clean reset.

## Quit The App

Open the menu bar item and choose `Quit`.

## Remove The App

Delete `AutocompleteLab.app` from `/Applications` or wherever it was installed.

## Remove Local Logs And Traces

Run:

```bash
./script/delete_local_traces.sh
```

This removes local Autocomplete Lab trace/log exports that the script knows
about. You can also inspect:

```text
~/Library/Logs/AutocompleteLab
```

## Remove Model Files

Delete the app-owned model cache if you want to reclaim disk space:

```text
~/Library/Application Support/AutocompleteLab/Models
```

## Remove Local Settings

Autocomplete Lab uses local user defaults for settings such as pause state,
disabled apps, shortcuts, and debug toggles.

For a full reset, remove the app preferences for the bundle ID
`bar.r3d.autocomplete-lab` from the test account.

## Remove Accessibility Trust

Open macOS System Settings, go to Privacy & Security, then Accessibility, and
remove Autocomplete Lab if it is still listed.

## Verify Removal

After removal, relaunching the app should require Accessibility permission
again, and Diagnostics should have no prior local trace history.
