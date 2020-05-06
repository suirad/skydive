import minetest
import net
import nativesockets
import os
import packet
import utils

export net

type
  State = enum
    PreAuth = 0'u8, LoggedIn, Ingame, Dead

  AddressPair = ref object
    host: string
    port: Port
    socket: Socket
    seq_offset: uint16
    last_seq: uint16
    eat_acks: uint32

  Connection = ref object
    state: State
    server: AddressPair
    client: AddressPair
    pings: int16
    peer: uint16
    name: string

  MetaPacket = object
    packet: Packet
    host: string
    port: Port
    
  Proxy* = ref object
    name*: string
    port*: Port
    socket*: Socket
    cons*: seq[Connection]

proc sendTo*(pair: var AddressPair, packet: sink Packet) {.raises: [].} =
  try:
    pair.socket.sendTo(pair.host, pair.port, packet.pack(pair.seq_offset))
  except:
    discard

proc `$`*(proxy: Proxy): string =
  result = "Proxy("
  result &= &"name = {proxy.name}, "
  result &= &"port = {proxy.port})"

proc newProxy*(port: Port, name: string = "Skydive Server"): Proxy =
  result.new
  result.name = name
  result.port = port
  result.cons = @[]

  let sock = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP, buffered=false)
  sock.setSockOpt(OptReusePort, true)
  sock.getFd.setBlocking(false)
  sock.bindAddr(port)
  result.socket = sock

proc getPacket(sock: var Socket, dir: PacketDirection): Option[MetaPacket] =
    var data = ""
    var address = ""
    var port = 0.Port

    try:
      discard sock.recvFrom(data, 1000, address, port)
    except:
      return MetaPacket.none

    if data.len > 600 or data.len < PROTOCOL_ID.sizeof:
      error "Invalid Len"
      return MetaPacket.none

    var packet = data.parse(dir)

    if packet.isNone:
      return MetaPacket.none

    return MetaPacket(packet: packet.get, host: address, port: port).some

proc inject*(dst: var AddressPair, src: AddressPair, p: sink Packet) =
  if p.type == Reliable:
    dst.seq_offset += 1
    dst.eat_acks += 1
    p.seq = src.last_seq

  dst.sendTo(p)


proc loop*(proxy: var Proxy) = #{.raises: [].} =
  #TODO: Use a Selector for socket handling

  while true:
    var gotdata = false
    var maybe_packet = proxy.socket.getPacket(toServer)

    if maybe_packet.isSome:
      gotdata = true
      let meta = maybe_packet.get
      var packet = meta.packet
      var found = false

      # find client pair
      for con in proxy.cons:
        # if found, send to server
        if con.client.host == meta.host and con.client.port == meta.port:
          var skip = false

          if packet.type == Control and packet.control_type == ControlType.Ack and packet.channel == 0:
            if con.client.eat_acks > 0:
              info "Skipped Client ack"
              con.client.eat_acks -= 1
              skip = true
            else:
              packet.control_ack -= con.client.seq_offset

          elif packet.type == Reliable and packet.channel == 0:
            con.client.last_seq = packet.seq

          if not skip:
            con.server.sendTo(packet.copy)

          if packet.type == Control and packet.control_type == ControlType.Disco:
            con.state = Dead

          elif packet.type == Reliable and packet.subtype == Control and packet.control_type == ControlType.Ping:
            con.pings -= 1
            if con.pings < -100:
              info &"Server timed out - {con.server.host}:{con.server.port}"
              con.state = Dead
              var disc = Packet(dir: toClient)
              disc.peer = 1
              disc.type = Control
              disc.control_type = ControlType.Disco
              con.client.sendTo(disc)

          found = true
          break

      # Setup new connection
      if not found and packet.type == Original and packet.server_packet.cmd == INIT:
        # if not, create pair
        info &"New connection - {meta.host}:{meta.port}"
        var con = Connection.new
        con.client = AddressPair.new
        con.client.host = meta.host
        con.client.port = meta.port
        con.client.socket = proxy.socket

        con.server = AddressPair.new
        #con.server.host = "127.0.0.1"
        con.server.host = "civtest.org"
        con.server.port = 30000.Port
        con.server.socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP, buffered=false)
        con.server.socket.getFd.setBlocking(false)
        con.server.sendTo(packet)
        proxy.cons.add(con)

        con.name = packet.server_packet.name
        info &"Attempted login for '{con.name}' by {con.client.host}:{con.client.port}"

    # loop server pairs 
    for con in proxy.cons:
      maybe_packet = con.server.socket.getPacket(toClient)
      if maybe_packet.isSome:
        gotdata = true
        var packet = maybe_packet.get.packet
        var skip = false

        if packet.channel == 0 and packet.type == Control and packet.control_type == ControlType.Ack:
          if con.server.eat_acks > 0:
            con.server.eat_acks -= 1
            skip = true
          else:
            packet.control_ack -= con.server.seq_offset

        elif packet.type == Reliable and packet.channel == 0:
          con.server.last_seq = packet.seq

        if not skip:
          con.client.sendTo(packet.copy)

        if packet.type == Control and packet.control_type == ControlType.Disco:
          con.state = Dead

        elif packet.type == Reliable and packet.subtype == Original and packet.client_packet.cmd == AUTH_ACCEPT:
          con.state = LoggedIn
          info &"Successful Login by - '{con.name}'"

        elif packet.type == Reliable and packet.subtype == Original and packet.client_packet.cmd == PRIVILEGES and con.state == LoggedIn:
          con.state = Ingame
          info &"Player is In Game - '{con.name}'"
          #[
          var hi = Packet(dir: toServer)
          hi.peer = con.peer
          hi.type = Reliable
          hi.subtype = Original
          hi.server_packet = ServerPacket(cmd: ToServer.CHAT_MESSAGE)
          hi.server_packet.msg = "howdy"
          hi.server_packet.msg_len = hi.server_packet.msg.len.uint16
          con.server.inject(con.client, hi)
          ]#

        elif packet.type == Reliable and packet.subtype == Control and packet.control_type == ControlType.Peer:
          con.peer = packet.control_peer

        elif packet.type == Reliable and packet.subtype == Control and packet.control_type == ControlType.Ping:
          con.pings += 1
          if con.pings > 100:
            info &"Client timed out - {con.client.host}:{con.client.port}"
            con.state = Dead
            
            # Only send disconnection packet for valid peers
            if con.peer > 0:
              var disc = Packet(dir: toServer)
              disc.peer = con.peer
              disc.type = Control
              disc.control_type = ControlType.Disco
              con.server.sendTo(disc)

    
    # cleanup dead connections
    var rmindex = -1
    for i, con in proxy.cons:
      if con.state == Dead:
        info &"Disconnected Client '{con.name}' - {con.client.host}:{con.client.port}"
        con.server.socket.close()
        rmindex = i
        break

    if rmindex != -1:
      proxy.cons.del(rmindex)

    if not gotdata:
      sleep(25)



