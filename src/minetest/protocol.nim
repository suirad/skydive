const
  LATEST_PROTOCOL_VERSION* = 39
  SERVER_PROTOCOL_VERSION_MIN* = 37
  SERVER_PROTOCOL_VERSION_MAX* = LATEST_PROTOCOL_VERSION
  CLIENT_PROTOCOL_VERSION_MIN* = 37
  CLIENT_PROTOCOL_VERSION_MAX* = LATEST_PROTOCOL_VERSION
  PROTOCOL_ID* = 0x4f457403
  PASSWORD_SIZE* = 28
  FORMSPEC_API_VERSION* = 3

type
  Auth* {.pure.} = enum
    NONE = 0,
    LEGACY_PASSWORD = 1 shl 0,
    SRP = 1 shl 1,
    FIRST_SRP = 1 shl 2

  AccessDenied* {.pure.} = enum
    WRONG_PASSWORD = 0, UNEXPECTED_DATA, SINGLEPLAYER, WRONG_VERSION, WRONG_CHARS_IN_NAME, WRONG_NAME, TOO_MANY_USERS, EMPTY_PASSWORD, ALREADY_CONNECTED, SERVER_FAIL, CUSTOM_STRING, SHUTDOWN, CRASH, MAX

  ToServer* {.pure.} = enum
    NIL = 0x0'u16
    INIT = 0x02,
    INIT_LEGACY = 0x10,
    INIT2,
    MODCHANNEL_JOIN = 0x17,
    MODCHANNEL_LEAVE,
    MODCHANNEL_MSG,
    GETBLOCK = 0x20,
    ADDNODE,
    REMOVENODE,
    PLAYERPOS,
    GOTBLOCKS,
    DELETEDBLOCKS,
    ADDNODE_FROM_INVENTORY,
    CLICK_OBJECT,
    GROUND_ACTION,
    RELEASE,
    SIGNTEXT = 0x30,
    INVENTORY_ACTION,
    CHAT_MESSAGE,
    SIGNNODETEXT,
    CLICK_ACTIVEOBJECT,
    DAMAGE,
    PASSWORD_LEGACY,
    PLAYERITEM,
    RESPAWN,
    INTERACT,
    REMOVED_SOUNDS,
    NODEMETA_FIELDS,
    INVENTORY_FIELDS,
    REQUEST_MEDIA = 0x40,
    RECEIVED_MEDIA,
    BREATH,
    CLIENT_READY,
    FIRST_SRP = 0x50,
    SRP_BYTES_A,
    SRP_BYTES_M,
    NUM_MSG_TYPES

  ToClient* {.pure.} = enum
    NIL = 0x0'u16
    HELLO = 0x02,
    AUTH_ACCEPT,
    ACCEPT_SUDO_MODE,
    DENY_SUDO_MODE,
    ACCESS_DENIED = 0x0a,
    INIT_LEGACY = 0x10,
    BLOCKDATA = 0x20,
    ADDNODE,
    REMOVENODE,
    PLAYERPOS,
    PLAYERINFO,
    OPT_BLOCK_NOT_FOUND,
    SECTORMETA,
    INVENTORY,
    OBJECTDATA,
    TIME_OF_DAY,
    CSM_RESTRICTION_FLAGS,
    PLAYER_SPEED,
    CHAT_MESSAGE = 0x2f,
    CHAT_MESSAGE_OLD,
    ACTIVE_OBJECT_REMOVE_ADD,
    ACTIVE_OBJECT_MESSAGES,
    HP,
    MOVE_PLAYER,
    ACCESS_DENIED_LEGACY,
    FOV,
    DEATHSCREEN,
    MEDIA,
    TOOLDEF,
    NODEDEF,
    CRAFTITEMDEF,
    ANNOUNCE_MEDIA,
    ITEMDEF,
    PLAY_SOUND = 0x3f,
    STOP_SOUND,
    PRIVILEGES,
    INVENTORY_FORMSPEC,
    DETACHED_INVENTORY,
    SHOW_FORMSPEC,
    MOVEMENT,
    SPAWN_PARTICLE,
    ADD_PARTICLESPAWNER,
    DELETE_PARTICLESPAWNER_LEGACY,
    HUDADD,
    HUDRM,
    HUDCHANGE,
    HUD_SET_FLAGS,
    HUD_SET_PARAM,
    BREATH,
    SET_SKY,
    OVERRIDE_DAY_NIGHT_RATIO,
    LOCAL_PLAYER_ANIMATIONS,
    EYE_OFFSET,
    DELETE_PARTICLESPAWNER,
    CLOUD_PARAMS,
    FADE_SOUND,
    UPDATE_PLAYER_LIST,
    MODCHANNEL_MSG,
    MODCHANNEL_SIGNAL,
    NODEMETA_CHANGED,
    SET_SUN,
    SET_MOON,
    SET_STARS,
    SRP_BYTES_S_B = 0x60,
    FORMSPEC_PREPEND,
    NUM_MSG_TYPES

  ControlType* {.pure.} = enum
    Ack, Peer, Ping, Disco

