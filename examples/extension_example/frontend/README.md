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