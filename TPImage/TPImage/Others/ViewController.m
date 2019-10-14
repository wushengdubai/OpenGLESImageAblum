//
//  ViewController.m
//  TPImage
//
//  Created by 张清泉 on 2019/10/10.
//  Copyright © 2019 Tapai. All rights reserved.
//

#import "ViewController.h"
#import "TPDisplayPreview.h"
#import "TPImageTestView.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet TPDisplayPreview *previewView;
@property (weak, nonatomic) IBOutlet UISlider *slider;

@property (nonatomic, strong) TPImageTestView *testView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
//    self.previewView = [[TPDisplayPreview alloc] initWithFrame:CGRectMake(0, 148, 375, 590) withResourceName:@"1"];
//    [self.view addSubview:self.previewView];
//    self.previewView.resourceName = @"1";
    
    self.testView = [[TPImageTestView alloc] initWithFrame:CGRectMake(0, 148, 375, 590)];
    [self.view addSubview:self.testView];
}

- (IBAction)changeProgress:(UISlider *)sender {
}

- (IBAction)exportBtnClick:(id)sender {
}

- (IBAction)changeAE:(UIButton *)sender {
}



- (IBAction)changePictures:(UIButton *)sender {
}

- (IBAction)play:(UIButton *)sender {
}
- (IBAction)pause:(UIButton *)sender {
}
- (IBAction)restart:(UIButton *)sender {
}
@end
