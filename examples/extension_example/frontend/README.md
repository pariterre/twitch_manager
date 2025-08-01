# Frontend

This is the frontend (the viewers experience) side of the Twitch extension example project.

## Getting Started

### HTML File Setup

The following line must be added to the `<body>` of the HTML file.

```html
<script src="https://extension-files.twitch.tv/helper/v1/twitch-ext.min.js"></script>
```
This script is necessary for the Twitch extension to function correctly, as it provides the required helper functions, APIs and authentication mechanisms.

### ROBOTO Font

Twitch won't allow for dynamically download resources, so the Roboto font must be downloaded and included in the project. 
You can download the font from [Google Fonts](https://fonts.google.com/specimen/Roboto) and place it in an asset folder. 
You must then reference it in your `pubspec.yaml` file under the `flutter` section.

### canvaskit.js

For the same reason as the Roboto font, the `canvaskit.js` file must be downloaded.
To do that, when compiling the project, you need to run the command: `flutter build web --no-web-resources-cdn --release` 

`See note below until this is fix`

### INCOMPATIBLE FLUTTER VERSION
Since version 3.29.0 of Flutter, `web-renderer html` is no longer available. However, neither `canvaskit` nor `skwasm` can currently be used on Twitch. Therefore, for the frontends, you will have to rely on older version of flutter (we suggest `3.27.4`). You can install previous version by using `fvm`: 
```bash
dart pub global activate fvm
fvm install 3.27.4
```
Please be aware that the Dart sdk cannot be higher than sdk: ^3.6.2 (in the pubspect.yaml file)


Then, in your extension folder
`fvm use 3.27.4`

To build the project you can use the following command:
`fvm flutter build web --web-renderer html --no-web-resources-cdn --release`
