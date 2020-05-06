import strformat
import strutils

export strformat
export strutils

template msg(pre: untyped, args: untyped) =
  echo pre, args

template info*(args: untyped) =
  msg "[INFO] ", args

template error*(args: untyped) =
  msg "[ERROR] ", args
