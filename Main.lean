/-
  Copyright (c) 2021 Microsoft Corporation. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.
  Authors: Alexander Bentkamp, Arthur Paulino, Daniel Selsam
-/

import Lean

open Lean Lean.Elab Lean.Elab.Command

def fileName : String := "repl"

def commandElabCtx : Context := {
  fileName := fileName,
  fileMap := { source := "", positions := #[0], lines := #[1] }
}

def runCommandElabM (commandElabM : CommandElabM Unit) (env : Environment) :
    IO Unit := do
  let _ ← (commandElabM commandElabCtx).run
    { env := env, maxRecDepth := defaultMaxRecDepth } |>.toIO'

def parseCommand (cmd : String) : CommandElabM Unit := do
  match Parser.runParserCategory (← getEnv) `command cmd fileName with
  | Except.error err => throwError err
  | Except.ok stx    =>
    let _ ← modifyGet fun st => (st.messages, { st with messages := {} })
    elabCommandTopLevel stx
    for msg in (← get).messages.msgs do
      IO.print $ ← msg.toString

partial def loop : CommandElabM Unit := do
  IO.print "> "
  let cmdIn ← (← (← IO.getStdin).getLine)
  let cmd ← if cmdIn.length = 0 then "\n" else cmdIn
  let mut mustLoop : Bool ← true
  if cmd.data ≠ ['\n'] then
    if cmd.data.head! ≠ '!' then
      try parseCommand cmd
      catch | e => IO.println $ ← e.toMessageData.toString
    else
      -- how to quit the monad and signal a message?
      mustLoop ← false
  if mustLoop then loop

def main : IO Unit := do
  initSearchPath (← findSysroot?)
  let env ← importModules [{ module := `Init }] {}
  let _ ← runCommandElabM loop env
