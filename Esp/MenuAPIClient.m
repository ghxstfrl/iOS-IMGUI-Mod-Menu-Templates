#import "MenuAPIClient.h"
#import <UIKit/UIKit.h>

static NSString * const kMenuAPIBaseURL = @"https://example.com";
static NSString * const kMenuAPIPath = @"/api/menu/validate";
static NSString * const kMenuAPIKey = @"REPLACE_WITH_YOUR_API_KEY";

@implementation MenuAPIClient

+ (instancetype)shared
{
 static MenuAPIClient *client;
 static dispatch_once_t onceToken;
 dispatch_once(&onceToken, ^{
 client = [[MenuAPIClient alloc] init];
 });
 return client;
}

- (void)validateMenuAccessWithCompletion:(void (^)(BOOL allowed, NSString * _Nullable message))completion
{
 NSString *fullURL = [NSString stringWithFormat:@"%@%@", kMenuAPIBaseURL, kMenuAPIPath];
 NSURL *url = [NSURL URLWithString:fullURL];
 if (!url) {
 completion(YES, @"Invalid API URL. Allowing menu as fallback.");
 return;
 }

 NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
 request.HTTPMethod = @"POST";
 [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
 [request setValue:kMenuAPIKey forHTTPHeaderField:@"X-API-Key"];

 UIDevice *device = [UIDevice currentDevice];
 NSDictionary *payload = @{
 @"bundleId": [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown",
 @"deviceName": device.name ?: @"unknown",
 @"systemVersion": device.systemVersion ?: @"unknown"
 };

 NSError *jsonError = nil;
 NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
 if (!body || jsonError) {
 completion(YES, @"Payload encoding failed. Allowing menu as fallback.");
 return;
 }

 request.HTTPBody = body;
 request.timeoutInterval = 8.0;

 NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
 if (error || !data) {
 completion(YES, @"API request failed. Allowing menu as fallback.");
 return;
 }

 NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
 if (![httpResp isKindOfClass:[NSHTTPURLResponse class]] || httpResp.statusCode < 200 || httpResp.statusCode > 299) {
 completion(YES, @"API returned non-2xx. Allowing menu as fallback.");
 return;
 }

 NSError *parseError = nil;
 id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
 if (parseError || ![json isKindOfClass:[NSDictionary class]]) {
 completion(YES, @"Invalid API JSON. Allowing menu as fallback.");
 return;
 }

 NSDictionary *obj = (NSDictionary *)json;
 NSNumber *allowedNum = obj[@"allowed"];
 NSString *message = [obj[@"message"] isKindOfClass:[NSString class]] ? obj[@"message"] : nil;

 BOOL allowed = YES;
 if ([allowedNum isKindOfClass:[NSNumber class]]) {
 allowed = allowedNum.boolValue;
 }

 completion(allowed, message);
 }];

 [task resume];
}

@end
