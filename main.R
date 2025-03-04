library(dplyr)
library(readr)
source("R/torvik.R")
source("R/ema.R")

min_season <- 2008
curr_season <- 2025
todays_date <- Sys.Date()
games_raw_path <- "data/games_raw.csv"
completed_games_path <- "data/completed_games.csv"
todays_predictions_path <- "data/todays_predictions.csv"
current_ratings_path <- "data/current_ratings.csv"
model_params_path <- "model_files/model_params.rds"
current_model_path <- "model_files/current_model.rds"

# download games
if (!file.exists(games_raw_path)) {
  # fetch all games
  games_raw <- get_super_sked(min_season:curr_season)
} else {
  # read in games we already have and merge with current season games
  saved_games_raw <- read_csv(games_raw_path)
  curr_season_games_raw <- get_super_sked(curr_season, sleep = 0)
  games_raw <- bind_rows(
    saved_games_raw |> filter(season != curr_season),
    curr_season_games_raw
  ) |> 
    arrange(date)
}

# save out raw games data
write_csv(games_raw, games_raw_path)

games <- prep_games(games_raw)

# load fitted params
ema_params <- readRDS(model_params_path)

# create distinction in initial ratings between original teams and 
# those that came in after first year
teams_first_season <- rbind(
  games |> select(team = away, season),
  games |> select(team = home, season)
) |> 
  group_by(team) |> 
  slice_min(order_by = season, with_ties = F)

orig_team <- teams_first_season |> filter(season == min_season) |> pull(team)
new_team <- teams_first_season |> filter(season != min_season) |> pull(team)
orig_ratings <- numeric(length(orig_team))
names(orig_ratings) <- orig_team
new_ratings <- numeric(length(new_team))
names(new_ratings) <- new_team
new_ratings[] <- ema_params$new_team_rating

# initialize ema model
ema <- new_ema(
  init_ratings = c(orig_ratings, new_ratings),
  inconf_k = ema_params$inconf_k,
  outconf_k = ema_params$outconf_k,
  hfa = ema_params$hfa,
  regress = ema_params$regress
)

completed_games <- games |> filter(!is.na(mov))
todays_games <- games |> filter(date == todays_date)

# roll through all completed games
ema <- update_ema(ema, completed_games)

# add predictions and errors to completed games data
completed_games$pred <- ema$preds
completed_games$error <- ema$res
completed_games <- bind_cols(completed_games, ema$ratings_history)

# save completed_games
write_csv(completed_games, completed_games_path)

# make predictions for today's games
todays_games <- games |> 
  filter(date == todays_date)

if (nrow(todays_games) > 0) {
  todays_games$pred <- predict(ema, newdata = todays_games)
}

write_csv(
  todays_games |> select(any_of(c("date", "home", "away", "pred"))),
  todays_predictions_path
)

# save out current ratings
curr_season_teams <- unique(c(
  games_raw |> filter(season == curr_season) |> pull(team1),
  games_raw |> filter(season == curr_season) |> pull(team2)
))

ema$ratings |> 
  tibble::enframe(name = "team", value = "rating") |> 
  arrange(desc(rating)) |> 
  filter(team %in% curr_season_teams) |> 
  mutate(date = todays_date - 1) |> 
  relocate(date) |> 
  write_csv(current_ratings_path)

# save out current model
saveRDS(ema, current_model_path)
