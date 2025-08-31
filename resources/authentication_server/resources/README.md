# Test the authentication server

In order to test the authentication server, you will need to host the "twitch_redirect_example_html" file. 
The easiest way to do that is to start a Python server from the `resources` folder like so:

```bash
python -m http.server 8000
```
With 8000 set to the port you want. Don't forget, you need to add this redirect address to your Twitch application settings: `http://localhost:8000/twitch_redirect_example.html`. 

Inside that file, you must change the `https://REDIRECT_URI_HERE/token` for `http://localhost:3000/token` so the `authentication_server` gets the POST request from the page (if you setup the server to be on another port, it must obviously be adjusted accordingly).