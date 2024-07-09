This is the backend service for authenticating using web base interface 

To launch in debug, one should run 
```bash
flutter run ./bin/twitch_authenticator_service.dart
```

This backend is intended to receive a POST request (to `/posttoken`) from a website that relays the Twitch response fragment in a json {'fragment': fragment} formatting. An example of such a website can be found at `resources/twitch_redirect_example.html`

It also respond to a GET request (to `/gettoken`) by relaying the fragment part. The request is done by the 'twitch_manager` package. 
