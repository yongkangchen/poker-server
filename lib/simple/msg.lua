--[[
https://github.com/yongkangchen/poker-server

Copyright (C) 2016  Yongkang Chen lx1988cyk#gmail.com

GNU GENERAL PUBLIC LICENSE
   	Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.
--]]

return {
    DEBUG = 0x0001,
    TICK = 0x0002,
    NEWS = 0x0003,
    DISCONNECT = 0x0004,
    KICK = 0x0009,
    LOGIN = 0x0010,

    ------LOBBY---------
    COIN = 0x0023,
    CASH = 0x01010,
    REFRESH_PAY = 0x1013,

    INVITER = 0x0036,
    INVITER_REWARD = 0x0037,

    IDENTIFY = 0x1014,

    ACCREDIT_COUNT = 0x1015,
    BE_ACCREDIT = 0x1016,
    CANCEL_ACCREDIT = 0x1017,

    ------ROOM----------
    CREATE = 0x0011,
    ENTER = 0x0012,

    START_GAME = 0x001A,
    MID_ENTER = 0x001B,
    VISITOR = 0x001F,

    SIT_DOWN = 0x003E,
    VISITOR_LIST = 0x003F,

    ------------------
    RENTER = 0x0013,
    READY = 0x0014,
    GET_ROOM = 0x1018,
    INIT = 0x0024,
    RESULT = 0x0025,


    APPLY = 0x0027,
    AGREE = 0x0028,
    GPS = 0x0029,

    SMILE = 0x0031,
    DISMISS = 0x0032,
    ROOM_OUT = 0x0033,
    PAUSE = 0x0034,
    SEND_MSG = 0x0038,
    GET_MSG_LIST = 0x0039,

    OFFLINE = 0x1008,

    UPLOAD_VOICE = 0x1011,
    PLAY_VOICE = 0x1012,
}
