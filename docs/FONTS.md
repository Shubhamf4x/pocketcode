# Fonts

`assets/fonts/` contains the font binaries bundled with the app. The family is
declared in `pubspec.yaml` and applied app-wide through the theme in
`lib/app.dart`, so every widget renders with it.

To replace or update the files, drop new TTFs here and keep the names referenced
in `pubspec.yaml`. Additional font files you add under `assets/fonts/` are
git-ignored by default; the two bundled files are explicitly un-ignored in
`.gitignore`.
