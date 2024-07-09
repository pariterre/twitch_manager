This is the backend service for authenticating using web base interface 

To launch in debug, one should run 
```bash
flutter run ./bin/twitch_authenticator_service.dart [args]
```
The args are
- --host=<host>: the host to bind the server to. Default is 'localhost'.
- --port=<port>: the port to bind the server to. Default is 3000.
- --ssl=<cert.pem>,<key.pem>: the certificate and key to use for SSL. If

To generate the cert.pem and key.pem file, one can do the following. However, keep in mind this will fails as browser won't accept self-signed certificates

    openssl genrsa -out key.pem 2048
    openssl req -new -key key.pem -out cert.csr
    openssl x509 -req -days 365 -in cert.csr -signkey key.pem -out cert.pem

This backend is intended to receive a POST request (to `/posttoken`) from a website that relays the Twitch response fragment in a json {'fragment': fragment} formatting. An example of such a website can be found at `resources/twitch_redirect_example.html`

It also respond to a GET request (to `/gettoken`) by relaying the fragment part. The request is done by the 'twitch_manager` package. 
