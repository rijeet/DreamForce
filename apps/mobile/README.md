# Dream Force mobile client

This folder is reserved for the Flutter application. Generate the Android/iOS platform folders with the Flutter SDK after it is installed:

```powershell
flutter create --platforms=android,ios .
```

Then retain the Clean Architecture structure below and add the approved dependencies from `../../Plan/TECHNICAL_REQUIREMENTS.md`.

## Intended structure

```text
lib/
  core/
  features/
    auth/
    profile/
    activities/
    plans/
    timer/
    reviews/
    insights/
```

