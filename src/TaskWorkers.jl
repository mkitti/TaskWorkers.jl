"""
    TaskWorkers

    Creates worker loops that runs functions on a specific `Task`

    See TaskWorker, taskrun, TaskWorkers.startworker_and_repl
"""
module TaskWorkers

import Base: put!, take!

export TaskWorker, start, stop, taskrun


"""
    TaskWorker()

    Create a new TaskWorker

    # Usage

    worker = TaskWorker()
    @async(doSomethingOnAnotherTask()); start(worker)
"""
mutable struct TaskWorker
    running::Bool
    recv::Channel
    resp::Channel
    task::Task
    TaskWorker() = new(false,Channel(1),Channel(1))
end

# Private, do not use directly
put!(w::TaskWorker,t) = put!(w.recv,t)
take!(w::TaskWorker) = take!(w.resp)

"""
    worker::Ref{TaskWorker}

    Default `TaskWorker` reference when a `TaskWorker` is not specified.

    See also startworker, startworker_and_repl
"""
const worker = Ref{TaskWorker}()

"""
    startworker()

    Create a new TaskWorker (TaskWorkers.worker[]) and start it
"""
function startworker()
    sleep(1)
    worker[] = TaskWorker()
    start(worker[])
end

"""
    startworker_and_repl(interactive=true, quiet=true, banner=true, history_file=true, color_set=true, args...)

    Starts a new Julia REPL on a new `Task` via `@async` and runs a new `TaskWorker` on the current `Task`
    See Base.run_main_repl in client.jl for argument definitions
"""
function startworker_and_repl(interactive=true, quiet=true, banner=true, history_file=true, color_set=true, args...)
    @async Base.run_main_repl(interactive, quiet, banner, history_file, color_set, args...)
    startworker()
end

"""
    start(w::TaskWorker)

    Start the worker loop for a `TaskWorker`
"""
function start(w::TaskWorker)
    w.running = true
    w.task = current_task()
    worker_loop(w)
end

"""
    stop(w::TaskWorker)

    Stop the worker loop for a `TaskWorker`
"""
function stop(w::TaskWorker)
    if w.running
        w.running = false
        taskrun(w,()->nothing)
    end
end

# Private implementation
function worker_loop(w::TaskWorker)
    while(w.running)
        func_and_args = take!(w.recv)
        out = ()
        try
            @debug "Before invoke"
            if isa(func_and_args[1],Tuple)
                out = Base.invokelatest(func_and_args[1]... ;
                                        func_and_args[2]...)
            else
                out = Base.invokelatest(func_and_args...)
            end
            @debug "After invoke"
            out = (out,)
        catch err
            out = err
        end
        put!(w.resp,out)
    end
    nothing
end

"""
    taskrun(w::TaskWorker, f::Function, args...)
    taskrun(f::Function, w::TaskWorker, args...)
    taskrun(w::TaskWorker) do ... end
    taskrun(f::Function, args...)
    taskrun(args...) do ... end

    Run a function f on a worker w
    If a worker is not provided as in the last two forms,
    taskrun will use TaskWorkers.worker[]
"""
taskrun(w::TaskWorker, f::Function, args... ; kwargs...) =
    length(kwargs) > 0 ? taskrun(w,((f,args...),kwargs)) : taskrun(w,(f,args...))
taskrun(f::Function, w::TaskWorker, args... ; kwargs...) =
    length(kwargs) > 0 ? taskrun(w,((f,args...),kwargs)) : taskrun(w,(f,args...))
taskrun(f::Function, args...; kwargs...) =
    length(kwargs) > 0 ? taskrun(worker[],((f,args...),kwargs)) : taskrun(worker[],(f,args...))

# Private interface, could change
# t could be either (f,args...) or ((f,args...),kwargs)
function taskrun(w::TaskWorker,t::Tuple)
    put!(w,t)
    out = take!(w)
    if isa(out,Exception)
        throw(out)
    else
        out[1]
    end
end

end # module
