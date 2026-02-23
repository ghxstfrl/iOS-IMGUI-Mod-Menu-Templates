diff --git a/Esp/MenuAPIClient.h b/Esp/MenuAPIClient.h
new file mode 100644
index 0000000000000000000000000000000000000000..eb5ad43aa596d2f27b3f0beb6d840e377fc13a4b
--- /dev/null
+++ b/Esp/MenuAPIClient.h
@@ -0,0 +1,12 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+@interface MenuAPIClient : NSObject
+
++ (instancetype)shared;
+- (void)validateMenuAccessWithCompletion:(void (^)(BOOL allowed, NSString * _Nullable message))completion;
+
+@end
+
+NS_ASSUME_NONNULL_END
