# WezCrypt MAX — iOS app (unsigned)

Native iOS shell for **https://max.wezcrypt.site**. All features (chat, web
search, autonomous agent with background jobs, file uploads, image generator
and gallery) run from the live web app inside a full-screen `WKWebView` with
native chrome: pull-to-refresh, progress bar, native download → share sheet,
external links open in Safari, offline retry screen.

- Swift 5 · UIKit · iOS 15.0+
- Bundle ID: `com.wezcrypt.max` (change freely before signing)
- Project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  from `project.yml` — there is intentionally no checked-in `.xcodeproj`.

## Build (unsigned IPA)

Push to GitHub and the **Build unsigned IPA** workflow produces
`WezCryptMAX-unsigned.ipa` as a run artifact. The build uses
`CODE_SIGNING_ALLOWED=NO`, so the `.ipa` contains **no signature** — sign it
with your own setup (AltStore / SideStore / Sideloadly / ESign / your cert).

Local build on a Mac:

```bash
brew install xcodegen
xcodegen generate
xcodebuild build -project WezCryptMAX.xcodeproj -scheme WezCryptMAX \
  -configuration Release -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  -derivedDataPath build/DD
mkdir -p Payload && cp -R build/DD/Build/Products/Release-iphoneos/WezCryptMAX.app Payload/
zip -r WezCryptMAX-unsigned.ipa Payload
```

## Notes

- The app sends the UA token `WezCryptMAXApp/1.0`; the website hides its
  "install the PWA" banner when it sees it.
- App icon and launch logo are the same W/MAX artwork as the website PWA.
- App updates: the app is a live shell — website changes apply instantly,
  no new IPA needed unless the native shell itself changes.
