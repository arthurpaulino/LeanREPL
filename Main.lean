/-
  Copyright (c) 2021 Microsoft Corporation. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.
  Authors: Alexander Bentkamp, Arthur Paulino, Daniel Selsam
-/

import Lean

open Lean Lean.Elab Lean.Elab.Command

def runCommandElabM (commandElabM : CommandElabM Unit) : IO Unit := do
  initSearchPath (← findSysroot?)
  
  let commandElabCtx : Command.Context := {
    fileName := "repl",
    fileMap := { source := "", positions := #[0], lines := #[1] }
  }
  
  let _ ← (commandElabM commandElabCtx).run
    {env := ← importModules [{ module := `Init }] {},
      maxRecDepth := defaultMaxRecDepth} |>.toIO'

def parseCommand (cmd : String) : CommandElabM Unit := do
  match Parser.runParserCategory (← getEnv) `command cmd "repl" with
  | Except.error err => throwError err
  | Except.ok stx    =>
    let _ ← modifyGet fun st => (st.messages, { st with messages := {} })
    Elab.Command.elabCommandTopLevel stx
    let s ← get
    for msg in s.messages.msgs do
      IO.print $ ← msg.toString
    printTraces

partial def loop : CommandElabM Unit := do
  IO.print "> "
  let cmd ← (← (← IO.getStdin).getLine)
  try parseCommand cmd
  catch | e => IO.println $ ← MessageData.toString e.toMessageData
  loop

def main : IO Unit := do
  let _ ← runCommandElabM loop
