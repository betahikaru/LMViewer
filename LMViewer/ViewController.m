//
//  ViewController.m
//  LMViewer
//
//  Created by 鈴木 光 on 2016/12/03.
//  Copyright © 2016年 betahikaru. All rights reserved.
//

#import "ViewController.h"
@import CoreBluetooth;

#define PERIPHERAL_PREFIX_MAG             @"MAG"
#define SERVICE_UUID_LEAFEE_MAG           @"3C111002-C75C-50C4-1F1A-6789E2AFDE4E"
#define CHARACTERISTICS_UUID_LEAFEE_MAG   @"3C113000-C75C-50C4-1F1A-6789E2AFDE4E"

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate> {
    BOOL isScanning;
}
@property (nonatomic, strong) CBCentralManager *centralManager; // BLE Central Manager
@property (nonatomic, strong) NSMutableArray *peripherals;      // Connected BLE Pripheral(s)
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSNumber*> *switchValues;  // Switch value for Peripheral(s)
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSDate*> *lastUpdatedTimes;     // Last time to updated switch value for Peripheral(s)

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // BLE Central Managerを初期化
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                               queue:nil];

    // Key/Value Storeを初期化
    self.switchValues = [[NSMutableDictionary alloc] init];
    self.lastUpdatedTimes = [[NSMutableDictionary alloc] init];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// =============================================================================
#pragma mark - Method

// ペリフェラルの探索を開始する
- (BOOL)startPeripheralScan {
    if (!isScanning) {
        isScanning = YES;
        NSDictionary *option = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
                                                           forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
        [self.centralManager scanForPeripheralsWithServices:nil
                                                    options:option];
        NSLog(@"MSG-0001-I Started Scan.");
    }
    return YES;
}

// ペリフェラルの探索を終了する
- (BOOL)stopPeripheralScan {
    if (isScanning) {
        [self.centralManager stopScan];
        isScanning = NO;
        for (CBPeripheral *peripheral in self.peripherals) {
            [self.centralManager cancelPeripheralConnection:peripheral];
            NSLog(@"MSG-0003-I Cannelled peripherals connection. peripheral:%@" ,peripheral);
        }
//        self.peripherals = nil;
        NSLog(@"MSG-0002-I Stopped Scan.");
    }
    return YES;
}

// ペリフェラルとの接続を開始する
// @param peripheral 発見したペリフェラル
- (BOOL)connectPeripheral:(CBPeripheral *)peripheral {
    BOOL existsAlready = NO;
    if (!self.peripherals) {
        self.peripherals = [[NSMutableArray alloc] init];
    }
    for (CBPeripheral *aPeripheral in self.peripherals) {
        if ([aPeripheral isEqual:peripheral]) {
            existsAlready = YES;
            break;
        }
    }
    if (!existsAlready) {
        [self.centralManager connectPeripheral:peripheral
                                       options:nil];
        [self.peripherals addObject:peripheral];
        NSLog(@"MSG-0006-I Start to connect to peripheral:%@", peripheral.identifier);
    }
    return YES;
}

// キャラクタリスティック探索開始
- (void)discoverCharacteristics:(CBPeripheral *)peripheral services:(NSArray *)services
{
    BOOL foundTargetServices = NO;
    for (CBService *service in services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:SERVICE_UUID_LEAFEE_MAG]]) {
            NSLog(@"MSG-0011-I Found service. UUID String:%@, Primary:%d, UUID:%@", service.UUID.UUIDString, service.isPrimary, service.UUID);
            [peripheral discoverCharacteristics:nil
                                     forService:service];
            foundTargetServices = YES;
        }
    }
    if (!foundTargetServices) {
        NSLog(@"MSG-0017-E Not found target services. services:%@", services);
    }
}

// キャラクタリスティックの値取得開始
- (void)readValueForCharasteristic:(CBPeripheral *)peripheral characteristics:(NSArray *)characteristics
{
    BOOL foundTargetCharasteristics = NO;
    for (CBCharacteristic *characteristic in characteristics) {
        // ReadとNotifyのビットが立っている，かつ，Writeのビットが立っていないすべてのキャラクタリスティックに対して読み出し開始
        if (((characteristic.properties & CBCharacteristicPropertyRead) != 0)
            && ((characteristic.properties & CBCharacteristicPropertyNotify) != 0)
            && ((characteristic.properties & CBCharacteristicPropertyWrite) == 0)) {
            // あらかじめ想定していたUUIDの場合のみ値取得
            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTICS_UUID_LEAFEE_MAG]]) {
                NSLog(@"MSG-0014-I Read value for charasteristic. uuid:%@", CHARACTERISTICS_UUID_LEAFEE_MAG);
                [peripheral readValueForCharacteristic:characteristic];
                foundTargetCharasteristics = YES;
            } else {
                NSLog(@"MSG-0015-W Read value for charasteristic. Properties(Read:ON, Notify:ON, Write:OFF). characteristic:%@", characteristic);
            }
        }
    }
    if (!foundTargetCharasteristics) {
        NSLog(@"MSG-0016-E Not found target charasteristic. characteristics:%@", characteristics);
    }
}

- (void)dumpCurrentStatus {
    for (CBPeripheral *peripheral in self.peripherals) {
        NSString *key = [peripheral.identifier UUIDString];
        NSNumber *switchValue = [self.switchValues valueForKey:key];
        NSDate *lastUpdatedTime = [self.lastUpdatedTimes valueForKey:key];
        NSLog(@"MSG-0021-I Dump Value. peripheral:%@, switchValue:%@, lastUpdatedTime:%@", key, switchValue, lastUpdatedTime);
    }
}


// =============================================================================
#pragma mark - IBOutlet

- (IBAction)tapStopBtn:(UIButton *)sender {
    [self stopPeripheralScan];
}


// =============================================================================
#pragma mark - CBCentralManagerDelegate

// セントラルマネージャの状態が変化すると呼ばれる
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSLog(@"MSG-0004-I Called centralManagerDidUpdateState. state:%ld", (long)central.state);
    switch (central.state) {
        case CBManagerStatePoweredOn:
            [self startPeripheralScan];
            break;
        case CBManagerStatePoweredOff:
            [self stopPeripheralScan];
            break;
        default:
            break;
    }
}

// ペリフェラルを発見すると呼ばれる
- (void)   centralManager:(CBCentralManager *)central
    didDiscoverPeripheral:(CBPeripheral *)peripheral
        advertisementData:(NSDictionary *)advertisementData
                     RSSI:(NSNumber *)RSSI {
    // ペリフェラルがMAGだった場合，接続を開始する
    if ([peripheral.name hasPrefix:PERIPHERAL_PREFIX_MAG]) {
        NSLog(@"MSG-0005-I Discovered peripheral(%@)：%@", PERIPHERAL_PREFIX_MAG, peripheral);
        [self connectPeripheral:peripheral];
    }
}

// ペリフェラルと接続すると呼ばれる
- (void)  centralManager:(CBCentralManager *)central
    didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"MSG-0007-I Success to connect to peripheral:%@", peripheral.identifier);
    
    // サービス探索結果を受け取るためにデリゲートをセット
    peripheral.delegate = self;
    
    // サービス探索開始
    [peripheral discoverServices:nil];
}

// ペリフェラルと接続失敗すると呼ばれる
- (void)        centralManager:(CBCentralManager *)central
    didFailToConnectPeripheral:(CBPeripheral *)peripheral
                         error:(NSError *)error
{
    NSLog(@"MSG-0008-E Failed to connect to peripheral:%@, error:%@", peripheral, error);
}

// =============================================================================
#pragma mark - CBPeripheralDelegate

// サービス発見時に呼ばれる
- (void)     peripheral:(CBPeripheral *)peripheral
    didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"MSG-0009-E Failed to discover services. peripheral:%@, error:%@", peripheral, error);
        return;
    }

    NSArray *services = peripheral.services;
    NSLog(@"MSG-0010-I Found services. count:%lu, peripheral:%@", (unsigned long)services.count, peripheral.identifier);
    [self discoverCharacteristics:peripheral services:services];
}

// キャラクタリスティック発見時に呼ばれる
- (void)                      peripheral:(CBPeripheral *)peripheral
    didDiscoverCharacteristicsForService:(CBService *)service
                                   error:(NSError *)error
{
    if (error) {
        NSLog(@"MSG-0012-E Failed to discover characteristics. peripheral:%@, service:%@, error:%@", peripheral.identifier, service.UUID, error);
        return;
    }

    NSArray *characteristics = service.characteristics;
    NSLog(@"MSG-0013-I Found characteristics. count:%lu, peripheral:%@, service:%@", (unsigned long)characteristics.count, peripheral.identifier, service.UUID);
    [self readValueForCharasteristic:peripheral characteristics:characteristics];
}


// データ読み出しが完了すると呼ばれる
- (void)                 peripheral:(CBPeripheral *)peripheral
    didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                              error:(NSError *)error
{
    if (error) {
        NSLog(@"MSG-0018-E Faild to read value from charasteristic. characteristic:%@, error:%@", characteristic.UUID, error);
        return;
    }
    
    NSLog(@"MSG-0019-I Success to read value. peripheral:%@, service:%@, characteristic:%@, value:%@",
          peripheral.identifier, characteristic.service.UUID, characteristic.UUID, characteristic.value);

    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString: CHARACTERISTICS_UUID_LEAFEE_MAG]]) {
        unsigned char byteValue;
        [characteristic.value getBytes:&byteValue length:1];
        NSLog(@"MSG-0020-I Leafee Mag Switch value:%d, peripheral id:%@", byteValue, peripheral.identifier);
        
        NSNumber *magSwitch = [NSNumber numberWithInt:0];
        if (byteValue != 0) {
            magSwitch = [NSNumber numberWithInt:1];
        }
        
        NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
        NSDate *dateNow = [NSDate date];
        [self.switchValues setValue:magSwitch forKey:peripheralUUIDString];
        [self.lastUpdatedTimes setValue:dateNow forKey:peripheralUUIDString];
        [self dumpCurrentStatus];
    }
}

// =============================================================================
#pragma end

@end
