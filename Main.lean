/-
  Copyright (c) 2021 Microsoft Corporation. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.
  Authors: Alexander Bentkamp, Arthur Paulino, Daniel Selsam

  A simple REPL environment for Lean 4 that also supports meta-commands
  (commands starting with '!').
-/

import Lean
import Std

open Lean Lean.Elab Lean.Elab.Command Std

def fileName : String := "repl"

def defaultModuleNames : List String := ["Init"]

def commandElabCtx : Context := {
  fileName := fileName,
  fileMap := { source := "", positions := #[0], lines := #[1] }
}

def runCommandElabM (commandElabM : CommandElabM Unit) :
    IO Unit := do
  let _ ← (commandElabM commandElabCtx).run
    { env := ← mkEmptyEnvironment, maxRecDepth := defaultMaxRecDepth } |>.toIO'

def runCommand (cmd : String) : CommandElabM Unit := do
  match Parser.runParserCategory (← getEnv) `command cmd fileName with
  | Except.error err => throwError err
  | Except.ok stx    =>
    let _ ← modifyGet fun st => (st.messages, { st with messages := {} })
    elabCommandTopLevel stx
    for msg in (← get).messages.msgs do
      IO.print $ ← msg.toString

def cleanStack (imports : List Import) : IO (Stack Environment) := do
  Stack.empty |>.push $ ← importModules imports {}

partial def loop (imports : List Import) (envs : Stack Environment) :
    CommandElabM Unit := do
  setEnv envs.peek!
  IO.print "> "
  let cmdIn ← (← (← IO.getStdin).getLine)
  let cmd ← if cmdIn.length = 0 then "\n" else cmdIn
  if cmd ≠ "\n" then
    if cmd.data.head! ≠ '!' then
      try runCommand cmd
      catch | e => IO.println $ ← e.toMessageData.toString
    else
      let metaCmd ← String.mk cmd.trim.data.tail!
      -- handling meta-commands without parameters
      if metaCmd = "quit" then return
      if metaCmd = "reset" then
        loop imports (← cleanStack imports)
        return
      let split ← metaCmd.splitOn " "
      let metaCmd ← split.head!
      -- handling meta-commands with parameters
      if metaCmd = "rb" then
        let metaPar ← split.getLast!.toNat!
        let mut envs' ← envs
        for _ in [0 : metaPar] do
          envs' ← envs'.pop
        loop imports envs'
        return
      -- handling invalid meta-commands
      IO.println $ s!"{fileName}:1:{fileName.length}: " ++
        "invalid meta-command '!{metaCmd}'"
      loop imports envs
      return
    loop imports $ envs.push (← getEnv)
  else loop imports envs

def buildImports (moduleNames : List String) : List Import :=
  defaultModuleNames ++ moduleNames
    |>.map fun s => { module := Name.mkSimple s }

def main (args : List String) : IO Unit := do
  initSearchPath (← findSysroot?)
  let imports ← buildImports args
  runCommandElabM $ loop imports (← cleanStack imports)
