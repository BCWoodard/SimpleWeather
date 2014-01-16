//
//  WXClient.m
//  SimpleWeather
//
//  Created by Brad Woodard on 1/15/14.
//  Copyright (c) 2014 Spartz, Inc. All rights reserved.
//

#import "WXClient.h"
#import "WXCondition.h"
#import "WXDailyForecast.h"

@interface WXClient ()

@property (strong, nonatomic) NSURLSession  *mSession;

@end

@implementation WXClient

- (id)init
{
    if (self = [super init]) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _mSession = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (RACSignal *)fetchJSONFromURL:(NSURL *)url {
    NSLog(@"Fetching: %@",url.absoluteString);
    
    // 1 - Return the signal
    return [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        // 2 - Create a data task to fetch data from the URL (new in iOS 7)
        NSURLSessionDataTask *dataTask = [self.mSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (! error) {
                NSError *jsonError = nil;
                id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
                if (! jsonError) {
                    // a. When JSON data exists and there are no errors, send the data
                    //    to the subscriber as an array or dictionary
                    [subscriber sendNext:json];
                }
                else {
                    // b. If there is an error, notify the subscriber
                    [subscriber sendError:jsonError];
                }
            }
            else {
                // b. If there is an error, notify the subscriber
                [subscriber sendError:error];
            }
            
            // c. Notify the subscriber that the request is completed
            [subscriber sendCompleted];
        }];
        
        // 3 - Starts the network request
        [dataTask resume];
        
        // 4 - Create and return a RACDisposable object to handle any cleanup when the dataTask is destroyed
        return [RACDisposable disposableWithBlock:^{
            [dataTask cancel];
        }];
    }] doError:^(NSError *error) {
        // 5 - Log any errors
        NSLog(@"%@",error);
    }];
}

- (RACSignal *)fetchCurrentConditionsForLocation:(CLLocationCoordinate2D)coordinate
{
    // 6 - Create a url string with the lat and lon and an instance of NSURL
    NSString *urlString = [NSString stringWithFormat:@"http://api.openweathermap.org/data/2.5/weather?lat=%f&lon=%f&units=imperial", coordinate.latitude, coordinate.longitude];
    NSURL *url = [NSURL URLWithString:urlString];
    
    // 7 - Create the signal from the url we just built
    return [[self fetchJSONFromURL:url] map:^(NSDictionary *json) {
        // a. Use MTLJSONAdapter to convert the JSON into a WXCondition object
        return [MTLJSONAdapter modelOfClass:[WXCondition class] fromJSONDictionary:json error:nil];
    }];
}

- (RACSignal *)fetchHourlyForecastForLocation:(CLLocationCoordinate2D)coordinate
{
    NSString *urlString = [NSString stringWithFormat:@"http://api.openweathermap.org/data/2.5/forecast?lat=%f&lon=%f&units=imperial&count=12", coordinate.latitude, coordinate.latitude];
    NSURL *url = [NSURL URLWithString:urlString];
    
    // 8 - Reuse fetchJSONFromURL and map the result
    return [[self fetchJSONFromURL:url] map:^(NSDictionary *json) {
        // a. Build a RACSequence from the "list" key of the NSDictionary "json"
        //    RACSequence allows us to perform ReactiveCocoa on lists
        RACSequence *list = [json[@"list"] rac_sequence];
        
        // b. Map the new list of objects.
        //    NOTE: This calls map: on each object in the list returning a list of new objects
        return [[list map:^(NSDictionary *item) {
            // c. Use MTLJSONAdapter again to convert the objects in "item" to WXCondition objects
            //    and return the data as an array
            return [MTLJSONAdapter modelOfClass:[WXCondition class] fromJSONDictionary:item error:nil];
        }] array];
    }];
}

- (RACSignal *)fetchDailyForecastForLocation:(CLLocationCoordinate2D)coordinate
{
    NSString *urlString = [NSString stringWithFormat:@"http://api.openweathermap.org/data/2.5/forecast/daily?lat=%f&lon=%f&units=imperial&cnt=7", coordinate.latitude, coordinate.longitude];
    NSURL *url = [NSURL URLWithString:urlString];
    
    return [[self fetchJSONFromURL:url] map:^(NSDictionary *json) {
        RACSequence *list = [json[@"list"] rac_sequence];
        
        return [[list map:^(NSDictionary *item) {
            return [MTLJSONAdapter modelOfClass:[WXDailyForecast class] fromJSONDictionary:item error:nil];
        }] array];
    }];
}

@end
