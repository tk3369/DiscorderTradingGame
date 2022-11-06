function register_error_handler(bot)
    register_error_handler!(bot) do client, message, ex, args...
        if ex isa IgUserError
            reply(client, message, ex.message)
        else
            @error "Non user exception" ex
        end
    end
end
