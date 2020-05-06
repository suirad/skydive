import proxy
import utils


proc initProxy(port: Port): Proxy {.raises: [].} =
  try:
    let proxy = newProxy(port)
    result = proxy
  except:
    error "Failed to bind proxy port"
    quit(0)


proc main() =
  let port = Port(30111)
  var proxy = initProxy(port)
  info &"Proxy listening on {port}"

  proxy.loop()

main()
