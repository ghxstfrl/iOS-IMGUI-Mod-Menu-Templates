#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MenuAPIClient : NSObject

+ (instancetype)shared;
- (void)validateMenuAccessWithCompletion:(void (^)(BOOL allowed, NSString * _Nullable message))completion;

@end

NS_ASSUME_NONNULL_END
