- (UIButton *)buildMenuButton {

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];

    // Smaller rectangle
    button.frame = CGRectMake(20, 120, 75, 36);

    // Rounded rectangle
    button.layer.cornerRadius = 10;
    button.clipsToBounds = YES;
    button.tag = kM1ButtonTag;

    // Gradient (Blue → Purple)
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = button.bounds;
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.20 green:0.45 blue:1.0 alpha:0.85].CGColor,   // Blue
        (id)[UIColor colorWithRed:0.55 green:0.20 blue:0.95 alpha:0.85].CGColor  // Purple
    ];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    gradient.cornerRadius = 10;

    [button.layer insertSublayer:gradient atIndex:0];

    // Text
    [button setTitle:@"M1" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    // Slight border glow
    button.layer.borderWidth = 1;
    button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.25].CGColor;

    // Action
    [button addTarget:self
               action:@selector(toggleMenuFromButton)
     forControlEvents:UIControlEventTouchUpInside];

    return button;
}
