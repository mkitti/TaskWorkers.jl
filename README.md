# TaskWorkers.jl

TaskWorkers.jl creates a loop that executes functions or closures sent to it.
The main use is ensuring those functions will execute on the `Task` that
the `TaskWorker` was started on. For example, this could be used to
ensure that functions are executed on Julia's root `Task`.

The main purpose of this package is to facilitate interoperation of
Julia with other software that may be confused with Julia's
`Tasks` which do not copy the stack by default.

## Installation

This package is currently not registered in the general Julia registry
as significant prototyping is underway. To add from the Julia REPL:

```
]add https://github.com/mkitti/TaskWorkers.jl#master
```

## Quick Usage and Demo

```julia
julia> Base.current_task() == Base.roottask
true

julia> using TaskWorkers

julia> TaskWorkers.startworker_and_repl()
               _
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.5.0 (2020-08-01)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
|__/                   |

julia> Base.current_task() == Base.roottask
false

julia> taskrun() do
           Base.current_task() == Base.roottask
       end
true

julia>
```

## Extended Usage

Because of Julia's stack conventions for `Task`s it may be necessary to ensure certain commands run on a certain `Task`, in particular the root `Task` (`Base.roottask`).

The following will start a new REPL on a new `Task` and start running a `TaskWorker` on the root `Task`:

```julia
using TaskWorkers
worker = TaskWorker()
@async(Base.run_main_repl(true,true,true,true,true)); sleep(1); start(worker)
```

A shortcut for the above is available as `TaskWorkers.startworker_and_repl()`.
Replace `Base.run_main_repl` with any function which will continue on a new `Task`.
The `TaskWorker` will take over the current `Task` with its execution loop.

From the newly created REPL you can then check to see which commands are running on the root `Task`

```julia
julia> Base.current_task() == Base.roottask
false

julia> taskrun(worker) do
           Base.current_task() == Base.roottask
       end
true
```

If worker is not specified (e.g. `taskrun() do ... end`), `TaskWorkers.worker[]` will be used.
`TaskWorkers.worker` is a `Ref{TaskWorker}` can be populated manually or with these convenience functions:

* `TaskWorkers.startworker()`
* `TaskWorkers.startworker_and_repl()`

This is only meant as a convenience. Otherwise, it is recommended that you track your own global references
to `TaskWorker`s.

## Applications

This package was developed to help Julia interoperate with other software that depend 
In particular, this could be useful for use with [JavaCall.jl](https://github.com/JuliaInterop/JavaCall.jl).

## Related Julia issues, pull requests, and packages

* https://github.com/JuliaLang/julia/pull/31983 (https://github.com/JuliaLang/julia/pull/31983)
* https://github.com/JuliaLang/julia/pull/35726 (Create a Base.root_task method and document it)
* https://github.com/JuliaLang/julia/pull/35048 (Allow the the REPL backend to run on the root Task; Merged as of Julia 1.5)
** Julia pre-1.5, consider https://github.com/mkitti/RootTaskREPL.jl
