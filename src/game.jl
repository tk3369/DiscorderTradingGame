"File location of the game file for a user"
user_game_file_path(user_id::Snowflake) = joinpath(game_data_directory(), "$user_id.json")

"Directory of the investment game data files"
game_data_directory() = joinpath("data", "ig")

"Returns true if user already has a game in progress."
is_player(user_id::Snowflake) = isfile(user_game_file_path(user_id))

"Start a new game file"
function start_new_game(user_id::Snowflake)
    pf = IgPortfolio(1_000_000.00, IgHolding[])
    save_portfolio(user_id, pf)
    return pf
end

"Destroy the existing game file for a user."
remove_game(user_id::Snowflake) = rm(user_game_file_path(user_id))

"Affirms the user has a game or throw an exception."
function affirm_player(user_id::Snowflake)
    is_player(user_id) || throw(
        IgUserError("you don't have a game yet. Type `ig start-game` to start a new game."),
    )
    return nothing
end

"Affirms the user does not have game or throw an exception."
function affirm_non_player(user_id::Snowflake)
    !is_player(user_id) || throw(
        IgUserError(
            "You already have a game running. Type `ig view` to see your current portfolio.",
        ),
    )
    return nothing
end

"Save a user portfolio in the data directory."
function save_portfolio(user_id::Snowflake, pf::IgPortfolio)
    @debug "Saving portfolio" user_id
    path = user_game_file_path(user_id)
    write(ensurepath!(path), JSON3.write(pf))
    return nothing
end

"Load the portfolio for a single user"
function load_portfolio(user_id::Snowflake)
    @debug "Loading portfolio" user_id
    path = user_game_file_path(user_id)
    return load_portfolio(path)
end

"Load a single portfolio from game file"
function load_portfolio(path::AbstractString)
    bytes = read(path)
    return JSON3.read(bytes, IgPortfolio)
end

"Extract user id from the portfolio data file"
function user_id_from_path(path::AbstractString)
    filename = basename(path)
    filename_without_extension = replace(filename, r"\.json$" => "")
    return parse(Snowflake, filename_without_extension)
end

"Load all game files"
function load_all_portfolios()
    dir = game_data_directory()
    files = readdir(dir)
    user_ids = user_id_from_path.(files)
    return Dict(
        user_id => load_portfolio(joinpath(dir, file)) for
        (user_id, file) in zip(user_ids, files)
    )
end
