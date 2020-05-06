import endians
import minetest
import options
import streams

export options, streams

type
  PacketType* = enum
    Control = 0'u8, Original, Split, Reliable

  PacketDirection* = enum
    toServer = 0'u8, toClient

  Packet* = ref object
    peer*: uint16
    channel*: uint8
    `type`*: PacketType
    control_type*: ControlType
    control_ack*: uint16
    control_peer*: uint16
    `seq`*: uint16
    subtype*: PacketType
    split_seq*: uint16
    split_chunk_count*: uint16
    split_chunk_num*: uint16
    split_data*: string
    case dir*: PacketDirection
      of toServer:
        server_packet*: ServerPacket
      of toClient:
        client_packet*: ClientPacket
  
  ServerPacket* = ref object
    case cmd*: ToServer
      of INIT:
        serialization*: uint8
        compression*: uint16
        proto_min*: uint16
        proto_max*: uint16
        name_len*: uint16
        name*: string

      of ToServer.CHAT_MESSAGE:
        msg_len*: uint16
        msg*: string
      else: discard
    rest*: string

  ClientPacket* = ref object
    case cmd*: ToClient
      of HELLO:
        format_version*: uint8
        compression*: uint16
        protocol_version*: uint16
        auth_modes*: uint32
        name_len*: uint16
        name*: string

      of ToClient.CHAT_MESSAGE:
        msg_version*: uint8
        msg_type*: uint8
        msg_sender_len*: uint16
        msg_sender*: string
        msg_len*: uint16
        msg*: string
      else: discard
    rest*: string
  

# helpers
proc clone*(p: Packet): Packet = p.deepCopy()
proc copy*(p: Packet): Packet = p.deepCopy()
proc swape*(np: var uint16) = swapEndian16(np.addr, np.addr)
proc swape*(np: var uint32) = swapEndian32(np.addr, np.addr)


proc parseServerPacket(s: StringStream): ServerPacket =
  var cmd = s.readUint16
  cmd.swape

  var sp = ServerPacket(cmd: cmd.ToServer)
  case sp.cmd:
    of INIT:
      s.read(sp.serialization)
      s.read(sp.compression)
      sp.compression.swape
      s.read(sp.proto_min)
      sp.proto_min.swape
      s.read(sp.proto_max)
      sp.proto_max.swape
      s.read(sp.name_len)
      sp.name_len.swape
      sp.name = s.readStr(sp.name_len.int)

    of ToServer.CHAT_MESSAGE:
      s.read(sp.msg_len)
      sp.msg_len.swape
      sp.msg = ""
      if sp.msg_len > 0:
        for _ in 0 .. sp.msg_len.int - 1:
          discard s.readUint8
          sp.msg.add(s.readChar)

    else:
      sp.rest = s.readAll()

  return sp

proc parseClientPacket(s: StringStream): ClientPacket =
  var cmd = s.readUint16
  cmd.swape

  var cp = ClientPacket(cmd: cmd.ToClient)
  # switch on cmd
  case cp.cmd:
    of ToClient.CHAT_MESSAGE:
      s.read(cp.msg_version)
      s.read(cp.msg_type)
      s.read(cp.msg_sender_len)
      cp.msg_sender_len.swape
      cp.msg_sender = ""
      if cp.msg_sender_len > 0:
        for _ in 0 .. cp.msg_sender_len.int - 1:
          discard s.readUint8
          cp.msg_sender.add(s.readChar)
      s.read(cp.msg_len)
      cp.msg_len.swape
      cp.msg = ""
      if cp.msg_len > 0:
        for _ in 0 .. cp.msg_len.int - 1:
          discard s.readUint8
          cp.msg.add(s.readChar)

    else:
      cp.rest = s.readAll()

  return cp

proc parse*(data: string, dir: PacketDirection): Option[Packet] =

  var s = newStringStream(data)
  var magic = s.readUint32
  magic.swape
  if magic != PROTOCOL_ID:
    return Packet.none

  var p = Packet(dir: dir)
  p.peer = s.readUint16
  p.peer.swape
  p.channel = s.readUint8
  p.type = s.readUint8.PacketType

  case p.type:
    of Split, Original: discard
    of Control:
      p.control_type = s.readUint8.ControlType
      case p.control_type:
        of Ack:
          s.read(p.control_ack)
          p.control_ack.swape
        of Peer:
          s.read(p.control_peer)
          p.control_peer.swape
        else: discard

    of Reliable:
      p.seq = s.readUint16
      p.seq.swape
      p.subtype = s.readUint8.PacketType
      case p.subtype:
        of Reliable, Original: discard

        of Control:
          p.control_type = s.readUint8.ControlType
          case p.control_type:
            of Ack:
              s.read(p.control_ack)
              p.control_ack.swape
            of Peer:
              s.read(p.control_peer)
              p.control_peer.swape
            else: discard

        of Split:
          s.read(p.split_seq)
          p.split_seq.swape
          s.read(p.split_chunk_count)
          p.split_chunk_count.swape
          s.read(p.split_chunk_num)
          p.split_chunk_num.swape
          p.split_data = s.readAll()

  if p.type != Original and p.type != Reliable or p.type == Reliable and p.subtype != Original:
    # return early if no further processing is needed
    return p.some

  # Read MT data if needed
  if dir == toServer:
    var sp = s.parseServerPacket()
    p.server_packet = sp
  elif dir == toClient:
    var cp = s.parseClientPacket()
    p.client_packet = cp

  return p.some

proc pack(res: StringStream, sp: ServerPacket) =
  var cmd = sp.cmd.uint16
  cmd.swape
  res.write(cmd)

  case sp.cmd:
    of ToServer.INIT:
      res.write(sp.serialization)
      sp.compression.swape
      res.write(sp.compression)
      sp.proto_min.swape
      res.write(sp.proto_min)
      sp.proto_max.swape
      res.write(sp.proto_max)
      sp.name_len.swape
      res.write(sp.name_len)
      res.write(sp.name)

    of ToServer.CHAT_MESSAGE:
      sp.msg_len.swape
      res.write(sp.msg_len)
      if sp.msg.len > 0:
        for c in sp.msg:
          res.write(0'u8)
          res.write(c)

      
    else:
      res.write(sp.rest)

proc pack(res: StringStream, cp: ClientPacket) =
  var cmd = cp.cmd.uint16
  cmd.swape
  res.write(cmd)

  case cp.cmd:
    of ToClient.CHAT_MESSAGE:
      res.write(cp.msg_version)
      res.write(cp.msg_type)
      cp.msg_sender_len.swape
      res.write(cp.msg_sender_len)
      if cp.msg_sender.len > 0:
        for c in cp.msg_sender:
          res.write(0'u8)
          res.write(c)
      cp.msg_len.swape
      res.write(cp.msg_len)
      if cp.msg.len > 0:
        for c in cp.msg:
          res.write(0'u8)
          res.write(c)
        res.write(0'u64) # what is this value? Timestamp?

    else:
      res.write(cp.rest)

# Destructive, fixes up endian-ness for network byte order
proc pack*(p: var Packet, seq_offset: uint16 = 0): string =
  var res = newStringStream()
  
  var magic: uint32 = PROTOCOL_ID
  magic.swape
  res.write(magic)
  p.peer.swape
  res.write(p.peer)
  res.write(p.channel)
  res.write(p.type)

  case p.type:
    of Split, Original: discard

    of Control:
      res.write(p.control_type)
      case p.control_type:
        of Ack:
          p.control_ack.swape
          res.write(p.control_ack)
        of Peer:
          p.control_peer.swape
          res.write(p.control_peer)
        else: discard

    of Reliable:
      p.seq += seq_offset
      p.seq.swape
      res.write(p.seq)
      res.write(p.subtype)
      case p.subtype:
        of Reliable, Original: discard

        of Control:
          res.write(p.control_type)
          case p.control_type:
            of Ack:
              p.control_ack.swape
              res.write(p.control_ack)
            of Peer:
              p.control_peer.swape
              res.write(p.control_peer)
            else: discard

        of Split:
          p.split_seq.swape
          res.write(p.split_seq)
          p.split_chunk_count.swape
          res.write(p.split_chunk_count)
          p.split_chunk_num.swape
          res.write(p.split_chunk_num)
          res.write(p.split_data)

  if p.type == Original or p.type == Reliable and p.subtype == Original:
    if p.dir == toServer:
      res.pack(p.server_packet)
    elif p.dir == toClient:
      res.pack(p.client_packet)

  res.setPosition(0)
  return res.readAll()

