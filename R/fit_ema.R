source("R/ema.R")
library(dplyr)

# create training and test data
games <- read_csv(here::here("data/completed_games.csv"))

# separate out teams that were in D1 in the first year I have available
# and those that came into D1 after the first year available
min_season <- min(games$season)
teams_first_season <- rbind(
  games |> select(team = away, season),
  games |> select(team = home, season)
) |> 
  group_by(team) |> 
  slice_min(order_by = season, with_ties = F)

# create distinction in initial ratings between original teams and 
# those that came in after first year
orig_team <- teams_first_season |> filter(season == min_season) |> pull(team)
new_team <- teams_first_season |> filter(season != min_season) |> pull(team)
orig_ratings <- numeric(length(orig_team))
names(orig_ratings) <- orig_team
new_ratings <- numeric(length(new_team))
names(new_ratings) <- new_team

# find optimal params on train
loss_function <- function(mov, pred) {
  (mov - pred)^2
}

# prediction values to ignore (want to give a couple years of burn in so I don't
# have to estimate initial ratings)
ignore_indices <- 1:(games |> filter(season < 2013) |> nrow())

# objective function
opt_loss_fn <- function(params) {
  inconf_k_param <- params[1]
  outconf_k_param <- params[2]
  hfa_param <- params[3]
  regress_param <- params[4]
  new_team_rating_param <- params[5]
  
  new_ratings[] <- new_team_rating_param
  
  ema <- new_ema(
    c(orig_ratings, new_ratings),
    inconf_k_param,
    outconf_k_param,
    hfa_param,
    regress = regress_param,
    loss_function = loss_function
  )
  ema <- update_ema(ema, games)
  return(sum(ema$res[-ignore_indices]^2))
}

# actual optimization
params <- c(0.10, 0.10, 3, 0.8, -1)
opt <- optim(
  params,
  opt_loss_fn,
  method = "L-BFGS-B",
  lower = c(0, 0, 0, 0, -Inf),
  upper = c(1, 1, Inf, 1, 0)
)


# save model parameters as list
saveRDS(
  list(
    inconf_k = opt$par[1],
    outconf_k = opt$par[2],
    hfa = opt$par[3],
    regress = opt$par[4],
    new_team_rating = opt$par[5]
  ),
  "model_files/model_params.rds"
)
