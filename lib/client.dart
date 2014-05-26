/** Client support for OAuth 1.0a with [http.BaseClient]
 */
library oauth.client;
import 'dart:async';
import 'dart:io';
import 'package:oauth/src/utils.dart';
import 'package:oauth/src/core.dart';
import 'package:oauth/src/token.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' as crypto;
export 'package:oauth/src/token.dart' show Token;

/** Generate the parameters to be included in the `Authorization:` header of a
 *  request. Generally you should prefer use of [signRequest] or [Client] 
 */
Map<String, String> generateParameters(
    http.BaseRequest request, 
    Token consumerToken, 
    Token userToken, 
    String nonce,
    int timestamp) {
  Map<String, String> params = new Map<String, String>();
  params["oauth_consumer_key"] = consumerToken.key;
  if(userToken != null) {
    params["oauth_token"] = userToken.key;
  }
  
  params["oauth_signature_method"] = "HMAC-SHA1";
  params["oauth_version"] = "1.0";
  params["oauth_nonce"] = nonce;
  params["oauth_timestamp"] = timestamp.toString();
  
  List<Parameter> requestParams = new List<Parameter>();
  requestParams.addAll(mapParameters(request.url.queryParameters));
  requestParams.addAll(mapParameters(params));
  
  if(request.contentLength != 0
      && ContentType.parse(request.headers["Content-Type"]).mimeType == "application/x-www-form-urlencoded") {
    requestParams.addAll(mapParameters(request.bodyFields));
  } 
  
  var sigBase = computeSignatureBase(request.method, request.url, requestParams);
  var sigKey = computeKey(consumerToken, userToken);
  params["oauth_signature"] = computeSignature(sigKey, sigBase);
  
  return params;
}

/// Produces a correctly formatted Authorization header given a parameter map
String produceAuthorizationHeader(Map<String, String> parameters) {
  return "OAuth " + encodeAuthParameters(parameters);
}

/** Signs [request] using consumer token [consumerToken] and user authorization
 *  [userToken]
 *
 *  If the body of [request] has content type 
 *  `application/x-www-form-urlencoded`, then the request body cannot be 
 *  streaming as the body parameters are required as part of the signature.
 * 
 *  The combination of [consumerToken], [userToken], [nonce] and [timestamp]
 *  must be unique. [timestamp] must be specified in Unix time format (i.e. 
 *  seconds since 1970-01-01T00:00Z)
 */
void signRequest(http.BaseRequest request,
                 Token consumerToken,
                 Token userToken,
                 String nonce,
                 int timestamp) {
  
  var params = generateParameters(request, consumerToken, userToken,
      nonce, timestamp);
  
  request.headers["Authorization"] = produceAuthorizationHeader(params);
}

/** An implementation of [http.BaseClient] which signs all requests with the
 * provided credentials.
 * 
 */
class Client extends http.BaseClient {
  /// The OAuth consumer/client token. Required.
  Token consumerToken;
  
  /// The OAuth user/authorization token. Optional.
  Token userToken;
  http.BaseClient _client;
  
  /// The wrapped client
  http.BaseClient get client => _client;
  
  /** Constructs a new client, with tokens [consumerToken] and optionally 
   * [userToken]. If [client] is provided, it will be wrapped, else a new 
   * [http.Client] will be created.
   * 
   *  If the body of any request has content type 
   * `application/x-www-form-urlencoded`, then the request cannot be 
   *  streaming as the body parameters are required as part of the signature.
   */
  Client(this.consumerToken, {http.BaseClient client, Token userToken}) {
    _client = client != null ? client : new http.Client();
    userToken = userToken;
  }
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => async
    .then((_) => getRandomBytes(8))
    .then((nonce) {
      String nonceStr = crypto.CryptoUtils.bytesToBase64(nonce, urlSafe: true);
      signRequest(request, consumerToken, userToken, nonceStr,
                  new DateTime.now().millisecondsSinceEpoch ~/ 1000);
      return _client.send(request);
    });
}
