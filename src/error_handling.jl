function register_error_handler(bot)
    register_error_handler!(bot) do client, message, ex, args...
        if ex isa IgUserError
            @info "Replying to message" message ex.message
            result = reply(client, message, ex.message)
        else
            @info "Other exceptions" ex
        end
    end
end
