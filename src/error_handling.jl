function register_error_handler(bot)
    register_error_handler!(bot) do client, message, ex, stack_frames, args...
        if ex isa IgUserError
            reply(client, message, ex.message)
        else
            @error "Non user exception" ex
            foreach(x -> println(x[1], ": ", x[2]), enumerate(stack_frames))
        end
    end
end
