///
/// This is the port opened to the internet
final int twitchPort = 3000;

///
/// This is the port listened that have the [twitchPort] redirected
final int twitchPortLocal = 3000;

///
/// This is the port opened for the app
final int appPort = 3002;

///
/// This is the port listened that have the [appPort] redirected
final int appPortLocal = 3002;

///
/// The address of the host where this server runs on
final String hostAddress = 'localhost';

///
/// The expected protocol of this server
final String _protocol = 'http';

///
/// The address to redirect the user once the service connect with Twitch
final redirectAddress = '$_protocol://$hostAddress:$twitchPort';
