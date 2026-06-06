///
/// The flow to use for Twitch authentication. This is used to determine how the authentication process should be handled.
/// The [implicit] flow is the recommended flow for client-side applications (i.e. no EBS backend).
/// See https://dev.twitch.tv/docs/authentication/getting-tokens-oauth#implicit-grant-flow for more information.
/// The [authorizationCode] flow is more secure and should be used for server-side applications.
/// See https://dev.twitch.tv/docs/authentication/getting-tokens-oauth#authorization-code-grant-flow for more information.
/// The [notApplicable] flow is used when the authentication flow is not applicable (e.g. for Twitch API calls that do not require authentication).
enum TwitchAuthenticationFlow {
  implicit,
  authorizationCode,
  notApplicable;
}
