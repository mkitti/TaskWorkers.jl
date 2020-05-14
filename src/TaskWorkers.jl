module TaskWorkers

import Base: put!, take!, run

export TaskWorker, start, stop, run

mutable struct TaskWorker
    running::Bool
    recv::Channel
    resp::Channel
    task::Task
    TaskWorker() = new(false,Channel(1),Channel(1))
end

put!(w::TaskWorker,t) = put!(w.recv,t)
take!(w::TaskWorker) = take!(w.resp)

function startworker()
    global worker = TaskWorker()
    start(worker)
end

function start(w::TaskWorker)
    w.running = true
    w.task = current_task()
    worker_loop(w)
end

function stop(w::TaskWorker)
    if w.running
        w.running = false
        run(w,()->nothing)
    end
end

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

run(w::TaskWorker, f::Function, args... ; kwargs...) =
    length(kwargs) > 0 ? run(w,((f,args...),kwargs)) : run(w,(f,args...))

function run(w::TaskWorker,t::Tuple)
    put!(w,t)
    out = take!(w)
    if isa(out,Exception)
        throw(out)
    else
        out[1]
    end
end

end # module
