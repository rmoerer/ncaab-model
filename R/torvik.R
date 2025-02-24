# taken from 
get_super_sked <- function(seasons, sleep = 5) {
  games_list <- list()
  names <- c('game_id', 'date','conf','type','location','team1','team1_pts','team2','team2_pts')
  for (i in seq_along(seasons)) {
    print(seasons[i])
    x <- readr::read_csv(
      paste0('https://barttorvik.com/', seasons[i], '_super_sked.csv'),
      col_names = FALSE,
      show_col_types = FALSE
    ) |>
      dplyr::select(1,2,3,7,8,9,28,15,29,1)
    colnames(x) <- names
    x <- x |> 
      dplyr::mutate(
        type = case_when(
          type==0~'nc',
          type==1~'conf',
          type==2~'conf_t',
          type==3~'post',
          type==99~'nond1'
        ),
        game_id = as.character(game_id),
        date = lubridate::mdy(date),
        season = seasons[i],
        location = 1 - location,
        conf = dplyr::case_when(
          type %in% c("conf", "conf_t") ~ TRUE,
          TRUE ~ FALSE
        )
    )
    games_list[[i]] <- x
    Sys.sleep(sleep)
  }
  
  games_raw <- dplyr::bind_rows(games_list) |> 
    dplyr::arrange(date)
  
}

prep_games <- function(games_raw) {
  games <- games_raw |> 
    dplyr::select(season, game_id, date, location, type, conf,
                  away = team1, home = team2, away_pts = team1_pts, home_pts = team2_pts) |> 
    dplyr::mutate(game_id = glue::glue("{season}_{game_id}")) |> 
    dplyr::arrange(date) |>
    tidyr::pivot_longer(cols = c(away, home), names_to = "team_column", values_to = "team") |>
    dplyr::arrange(date) |>
    dplyr::group_by(team, season) |>
    dplyr::mutate(
      regress = dplyr::case_when(
        season == 2008 ~ 0,
        TRUE ~ ifelse(dplyr::row_number() == 1, 1, 0)
      ),
      rest = as.integer(date - dplyr::lag(date))
    ) |>
    dplyr::group_by(team) |> 
    dplyr::mutate(
      regress = dplyr::case_when(
        # remove regression indicator for teams whose first season is not the first season
        # in the data
        season == min(season) & row_number() == 1 ~ 0,
        TRUE ~ regress
      )
    ) |> 
    tidyr::pivot_wider(names_from = team_column, values_from = c(team, regress, rest)) |>
    dplyr::rename(
      away = team_away,
      home = team_home,
      away_rest = rest_away,
      home_rest = rest_home,
      away_regress = regress_away,
      home_regress = regress_home
    ) |>
    dplyr::mutate(
      mov = home_pts - away_pts,
      location = ifelse(location, 1, 0),
      rest_adv = tidyr::replace_na(home_rest - away_rest, 0)
    )
  
  games
}



