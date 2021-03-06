//
//  Pjsip.m
//  sip
//
//  Created by QF  on 15/4/13.
//  Copyright (c) 2015年 BZW. All rights reserved.
//

#import "Pjsip.h"
#include <pjsua-lib/pjsua.h>
#include <pjsua-lib/pjsua_internal.h>
#import <AudioToolbox/AudioToolbox.h>


@implementation Pjsip
{
    int statusInt;//监听登陆成功和失败的数
  
}



+ (Pjsip *)sharedXCPjsua
{
    static Pjsip *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Pjsip alloc] init];
        
    });
    return sharedInstance;
}
static void on_reg_state2(pjsua_acc_id acc_id, pjsua_reg_info *info);
/* Callback called by the library when registration state has changed */
static void on_reg_state2(pjsua_acc_id acc_id, pjsua_reg_info *info)
{
    [[Pjsip sharedXCPjsua]  handleRegistrationStateChangeWithRegInfo: info];
}
-(void)answer:(int)callId
{
    
    pjsua_call_answer(callId, 200, NULL, NULL); // 接来电

}

/* Callback called by the library upon receiving incoming call */
static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id,
                             pjsip_rx_data *rdata)
{
    /*** 来电的回调函数 */
    pjsua_call_info ci;
    
    PJ_UNUSED_ARG(acc_id);
    PJ_UNUSED_ARG(rdata);
    //获取呼叫信息
    pjsua_call_get_info(call_id, &ci);
    pjsua_call_get_info(call_id, &ci);
    
   
    PJ_LOG(3,(THIS_FILE, "Incoming call from %.*s!!",
              (int)ci.remote_info.slen,ci.remote_info.ptr));
   // NSLog(@"---------%ld,%s",ci.remote_info.slen,ci.remote_info.ptr);
   // NSLog(@"-----------%d,%d, %d",call_id,acc_id,ci.id);
    
    char *phoneId = ci.remote_info.ptr;
    NSArray *arr = @[@(call_id),[NSString stringWithFormat:@"%s",phoneId]];
    
    
   
    
    
 //   [Pjsip sharedXCPjsua].callid = arr;
    /***  发送通知给应用 有来电提示 */
    NSNotificationCenter *center =[NSNotificationCenter defaultCenter];
    NSNotification *notify =[NSNotification notificationWithName:@"reloadMessag" object:arr];
    [center postNotification:notify];
    
   
   
    
    
    
   // pjsua_call_answer(call_id, 200, NULL, NULL); // 接来电
}


/* Callback called by the library when call's state has changed */
static void on_call_state(pjsua_call_id call_id, pjsip_event *e)
{
    /***  呼叫状态改变的回调函数 */
    pjsua_call_info ci;
    
    PJ_UNUSED_ARG(e);
    
    pjsua_call_get_info(call_id, &ci);
    PJ_LOG(3,(THIS_FILE, "Call %d state=%.*s", call_id,
              (int)ci.state_text.slen,ci.state_text.ptr));
    
    
    if (!strcmp(ci.state_text.ptr, "DISCONNCTD"))
    {
        // 通话已经结束  无论是对方挂断还是我自己挂断都进入这个方法
        NSNotificationCenter *center =[NSNotificationCenter defaultCenter];
        NSNotification *notify =[NSNotification notificationWithName:@"whoHangUp" object:nil];
        [center postNotification:notify];
    }
}


/* Callback called by the library when call's media state has changed */
static void on_call_media_state(pjsua_call_id call_id)
{
    pjsua_call_info ci;
    
    pjsua_call_get_info(call_id, &ci);
    
    if (ci.media_status == PJSUA_CALL_MEDIA_ACTIVE)
    {
        // When media is active, connect call to sound device.
        pjsua_conf_connect(ci.conf_slot, 0);
        pjsua_conf_connect(0, ci.conf_slot);
    }
}


static void error_exit(const char *title, pj_status_t status)
{
    pjsua_perror(THIS_FILE, title, status);
    pjsua_destroy();
    
}

/***  注册pjsip */
- (int)registerToServer:(NSString *)domian username:(NSString *)username passwd:(NSString *)passwd
{
    
    pjsua_acc_id acc_id;
    pj_status_t status;
    
    /* Create pjsua first! */
    NSLog(@"--------创建pjsua first");
    status = pjsua_create();
    if (status != PJ_SUCCESS) {
        error_exit("Error in pjsua_create()", status);
        return -1;
    }

    NSLog(@"--------初始化 pjsua,设置回调函数");
    /* Init pjsua */
    {
        pjsua_config cfg;
        pjsua_logging_config log_cfg;
        
        pjsua_config_default(&cfg);
        cfg.cb.on_incoming_call = &on_incoming_call;
        cfg.cb.on_call_media_state = &on_call_media_state;
        cfg.cb.on_call_state = &on_call_state;
        
        
        cfg.cb.on_reg_state2 = &on_reg_state2;
        pjsua_logging_config_default(&log_cfg);
        log_cfg.console_level = 4;
        
        status = pjsua_init(&cfg, &log_cfg, NULL);
        if (status != PJ_SUCCESS)
        {
            error_exit("Error in pjsua_create()", status);
            return -1;
        }
    }
    NSLog(@"------------创建pjsip的传输端口");
    /* Add UDP transport. */
    {
        pjsua_transport_config cfg;
        
        pjsua_transport_config_default(&cfg);
        cfg.port = 0;
        status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &cfg, NULL);
        if (status != PJ_SUCCESS)
        {
            error_exit("Error in pjsua_init()", status);
            return -1;
        }
    }
    NSLog(@"----------------启动pjsua");
    /* Initialization is done, now start pjsua */
    status = pjsua_start();
    if (status != PJ_SUCCESS)
    {
        error_exit("Error starting pjsua", status);
        return -1;
    }
    NSLog(@"----------------创建sip账户");
    /* Register to SIP server by creating SIP account. */
    {
        NSString *ID = [NSString stringWithFormat:@"sip:%@@%@",username,domian];
        NSString *reg_uri = [NSString stringWithFormat:@"sip:%@",domian];
        
        pjsua_acc_config cfg;
        pjsua_acc_config_default(&cfg);
        //cfg.id = pj_str([ID UTF8String]);
        cfg.id = pj_str((char *)[ID UTF8String]);
        cfg.reg_uri = pj_str((char *)[reg_uri UTF8String]);
        cfg.cred_count = 1;
        cfg.cred_info[0].realm = pj_str("*");
        cfg.cred_info[0].scheme = pj_str("digest");
        cfg.cred_info[0].username = pj_str((char *)[username UTF8String]);
        cfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
        cfg.cred_info[0].data = pj_str((char *)[passwd UTF8String]);
        
        cfg.vid_in_auto_show = PJ_TRUE;
        cfg.vid_out_auto_transmit = PJ_TRUE;
        
        status = pjsua_acc_add(&cfg, PJ_TRUE, &acc_id);
        
        if (status != PJ_SUCCESS)
            
        {
            error_exit("Error adding account", status);
            return -1;
        }
    }
   // pjsip_status_code
    return 0;
}
- (void)handleRegistrationStateChangeWithRegInfo: (pjsua_reg_info *)info
{
    NSLog(@"cbparam->code:%d",info->cbparam->code);
    
    //发送通知来更改登陆与否状态
    if (info->cbparam->code == 200)
    {
        if (statusInt %2 == 0)
        {
            NSNotificationCenter *center =[NSNotificationCenter defaultCenter];
            NSNotification *notify =[NSNotification notificationWithName:@"loginOrNot" object:@(info->cbparam->code)];
            [center postNotification:notify];
            statusInt = statusInt + 1;
        }
        else
        {
            statusInt ++;
        }
    }
    
    //登陆失败必须发通知改变状态
    if (info->cbparam->code == 403)
    {
        NSNotificationCenter *center =[NSNotificationCenter defaultCenter];
        NSNotification *notify =[NSNotification notificationWithName:@"loginOrNot" object:@(info->cbparam->code)];
        [center postNotification:notify];
        
    }
}

/***  挂电话 */
- (void) callHangup
{
    pjsua_call_hangup_all();
}
/***  销毁  */
- (void) unregister
{
    pjsua_destroy();
}

/***  打电话 **/
- (void) makeCall:(NSString *)callname domain:(NSString *)domian
{
    NSString *ID = [NSString stringWithFormat:@"sip:%@@%@",callname,domian];
    pjsua_call_id current_call = PJSUA_INVALID_ID;
    pj_str_t tmp;
    tmp = pj_str((char *)[ID UTF8String]);
    pjsua_call_make_call(current_acc, &tmp, NULL, NULL,
                         NULL, &current_call);
    
}



@end


