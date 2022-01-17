# LeanREPL

A simple REPL environment for Lean 4 that also supports meta-commands
(commands starting with '!').

The code in this repository was adapted from:

* [`dselsam/lean-gym`](https://github.com/dselsam/lean-gym)
* [`abentkamp/hoare-logic`](https://github.com/abentkamp/hoare-logic)

## Usage

Run `.../LeanREPL$ lake build` and an executable file will be created under
`build/bin`.

Then you can run it and pass the initial imported modules. `Init` is already
added by default. Example:

```bash
.../LeanREPL$ ./build/bin/LeanREPL Std
```

## Meta-commands

Meta-commands are just commands that start with "!" and allow extra control
of the REPL. The ones available are:

* `!quit` exits the REPL
* `!reset` resets the REPL to the initial state
* `!rb <n>` resets the REPL to the state it was `n` commands ago

Example:

```lean
> def a := 1
> def a := 2 -- causes an error and doesn't stack a new state
repl:1:4: error: 'a' has already been declared
> def b := 2
> def c := 3
> !rb 2      -- undoes the definitions of `b` and `c`
> #check a
a : Nat
> #check b
repl:1:7: error: unknown identifier 'b'
> #check c
repl:1:7: error: unknown identifier 'c'
> !reset     -- undoes all definitions
> #check a
repl:1:7: error: unknown identifier 'a'
> !quit
```
