- (void)toggleMenuFromButton {
    NSLog(@"BUTTON PRESSED");

    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:@"Test"
                                        message:@"Button Works"
                                 preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok =
    [UIAlertAction actionWithTitle:@"OK"
                             style:UIAlertActionStyleDefault
                           handler:nil];

    [alert addAction:ok];

    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [window.rootViewController presentViewController:alert animated:YES completion:nil];
}
