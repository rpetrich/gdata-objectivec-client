/* Copyright (c) 2010 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <SenTestingKit/SenTestingKit.h>

#import "GDataOAuthAuthentication.h"

//
// Test cases from http://wiki.oauth.net/TestCases
//

@interface GDataOAuthTest : SenTestCase
@end

@implementation GDataOAuthTest

- (void)testParameterEncoding {
  // test that the keys encode to the values
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                        // expected, input
                        @"", @"",
                        @"abcABC123", @"abcABC123",
                        @"-._~", @"-._~",
                        @"%25", @"%",
                        @"%2B", @"+",
                        @"%26%3D%2A", @"&=*",
                        @"%0A", [NSString stringWithFormat:@"%C", 0x0a], // LF
                        @"%20", @" ",
                        @"%7F", [NSString stringWithFormat:@"%C", 0x7f],
                        @"%C2%80", [NSString stringWithFormat:@"%C", 0x80],
                        @"%E3%80%81", [NSString stringWithFormat:@"%C", 0x3001],
                        nil];

  for (NSString *key in dict) {
    NSString *input = key;
    NSString *expected = [dict objectForKey:key];

    NSString *output = [GDataOAuthAuthentication encodedOAuthParameterForString:input];
    STAssertEqualObjects(output, expected, @"encoding for '%@'", input);
  }
}

- (void)testRequestParameterNormalization {
  // test that the keys normalize to the values
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                        // expected, input
                        @"name=", @"name",
                        @"a=b", @"a=b",
                        @"a=b&c=d", @"a=b&c=d",
                        @"a=x%20y&a=x%21y", @"a=x!y&a=x+y",
                        @"x=a&x%21y=a", @"x!y=a&x=a",
                        nil];

  for (NSString *key in dict) {
    NSString *input = key;
    NSString *expected = [dict objectForKey:key];

    NSString *output = [GDataOAuthAuthentication normalizeQueryString:input];
    STAssertEqualObjects(output, expected, @"normalization for '%@'", input);
  }
}

- (void)testHMACSHA1Signing {
  NSString *result, *expected;

  result = [GDataOAuthAuthentication HMACSHA1HashForConsumerSecret:nil
                                                       tokenSecret:nil
                                                              body:nil];
  expected = @"5CoEcoq7XoKFjwYCieQvuzadeUA=";
  STAssertEqualObjects(result, expected, @"HMAC SHA-1 failed (cs)");

  result = [GDataOAuthAuthentication HMACSHA1HashForConsumerSecret:@"cs"
                                                       tokenSecret:nil
                                                              body:@"bs"];
  expected = @"egQqG5AJep5sJ7anhXju1unge2I=";
  STAssertEqualObjects(result, expected, @"HMAC SHA-1 failed (cs)");

  result = [GDataOAuthAuthentication HMACSHA1HashForConsumerSecret:@"cs"
                                                       tokenSecret:@"ts"
                                                              body:@"bs"];
  expected = @"VZVjXceV7JgPq/dOTnNmEfO0Fv8=";
  STAssertEqualObjects(result, expected, @"HMAC SHA-1 failed (cs ts)");

  NSString *body = @"GET&http%3A%2F%2Fphotos.example.net%2Fphotos&file%3D"
    "vacation.jpg%26oauth_consumer_key%3Ddpf43f3p2l4k3l03%26oauth_nonce%3D"
    "kllo9940pd9333jh%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D"
    "1191242096%26oauth_token%3Dnnch734d00sl2jdk%26oauth_version%3D1.0%26"
    "size%3Doriginal";
  NSString *cs = @"kd94hf93k423kf44";
  NSString *ts = @"pfkkdhi9sl3r4s00";
  result = [GDataOAuthAuthentication HMACSHA1HashForConsumerSecret:cs
                                                       tokenSecret:ts
                                                              body:body];
  expected = @"tR3+Ty81lMeYAr/Fid0kMTYa/WM=";
  STAssertEqualObjects(result, expected, @"HMAC SHA-1 failed (full)");
}

- (void)testFullAuthorizationWithHeader {
  // pack up an auth object ready to be used
  GDataOAuthAuthentication *auth = [GDataOAuthAuthentication authForInstalledApp];

  [auth setToken:@"1/t879BQIwF6nl1Yb4HN5sPoUbp8r5fwTt1lS5R9Z4ST8"];
  [auth setTokenSecret:@"qFm4CwGplmGKUtKwD0JTBK5e"];
  [auth setHasAccessToken:YES];
  [auth setTimestamp:@"1272418292"];
  [auth setNonce:@"133475076490566881"];

  // make and sign a request, and check the resulting Authorization header
  NSString *urlStr = @"http://www.google.com/m8/feeds/contacts/default/thin";
  NSURL *url = [NSURL URLWithString:urlStr];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  [auth authorizeRequest:request];

  NSDictionary *headers = [request allHTTPHeaderFields];
  NSString *authHdr = [headers objectForKey:@"Authorization"];

  NSString *expected = @"OAuth oauth_consumer_key=\"anonymous\", "
    "oauth_token=\"1%2Ft879BQIwF6nl1Yb4HN5sPoUbp8r5fwTt1lS5R9Z4ST8\", "
    "oauth_signature_method=\"HMAC-SHA1\", oauth_version=\"1.0\", "
    "oauth_nonce=\"133475076490566881\", oauth_timestamp=\"1272418292\", "
    "oauth_signature=\"mwa8C1Rqb1uKxaAvfjuErn7m1ck%3D\"";
  STAssertEqualObjects(authHdr, expected, @"full auth with header");

  // the request URL should be unchanged
  STAssertEqualObjects(url, [request URL], @"unexpected URL change");
}

- (void)testFullAuthorizationWithParameters {
  // pack up an auth object ready to be used
  GDataOAuthAuthentication *auth = [GDataOAuthAuthentication authForInstalledApp];

  [auth setToken:@"1/X8VjGxlhq86xq7DJMRlOE5shlnu_sLMJUKLxGDOHItw"];
  [auth setTokenSecret:@"TovvPxLfea3h79AKsyZv4aZG"];
  [auth setHasAccessToken:YES];
  [auth setTimestamp:@"1272419916"];
  [auth setNonce:@"12380151942758697516"];
  [auth setShouldUseParamsToAuthorize:YES];

  // make and sign a request, and check the resulting Authorization header
  NSString *urlStr = @"http://www.google.com/m8/feeds/contacts/default/thin";
  NSURL *url = [NSURL URLWithString:urlStr];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  [auth authorizeRequest:request];

  NSString *resultURLStr = [[request URL] absoluteString];
  NSString *expected = @"http://www.google.com/m8/feeds/contacts/default/thin?"
    "oauth_consumer_key=anonymous&oauth_token=1%2FX8VjGxlhq86xq7DJMRlOE5shlnu"
    "_sLMJUKLxGDOHItw&oauth_signature_method=HMAC-SHA1&oauth_version=1.0&"
    "oauth_nonce=12380151942758697516&oauth_timestamp=1272419916&"
    "oauth_signature=CbyN79VjyXiwXHCN6RKNB2LMUAk%3D";
  STAssertEqualObjects(resultURLStr, expected, @"full auth with params");

  // no header should be added
  NSDictionary *headers = [request allHTTPHeaderFields];
  NSString *authHdr = [headers objectForKey:@"Authorization"];
  STAssertNil(authHdr, @"auth header unexpected");
}
@end
