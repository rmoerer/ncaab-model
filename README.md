## NCAAB modeling

A repo to house the code and results of my NCAAB power ratings model.

### Directory structure

-   `data/`
    -   `games_raw.csv`: the raw game data going back 2008 that is pulled from barttorvik.com
    -   `completed_games.csv`: processed and completed games going back to 2008. Predictions and prediction errors are included
    -   `current_ratings.csv`: the current power ratings
    -   `todays_predictions.csv`: predictions for the current day's game. Should have no rows if there are no games for that day
-   `model_files/`
    -   `model_params.rds`: the fitted model parameters
    -   `current_model.rds`: the current most up-to-date model
-   `R/`
    -   R code for processing data, fitting model, etc.
-   `main.R`: the R script for updating the data and model. Gets run every morning

### Current methodology

The outcome of interest is the differential in final score between the home team and the away team. Each team has a rating that can be thought of as the predicted score differential for that team against an average team. For a given game, the predicted home team score differential is calculated using the following formula

> Home team's predicted score differential = Home team's rating - Away team's rating + Home field advantage

Once a game occurs, the home team's and away team's ratings get updated based on how much the prediction was off by. For the home team the updated rating would be calculated like so

> Home team's new rating = K\*Error + Home team's old rating

where Error = Actual score differential - Predicted score differential and K is some value between 0 and 1 that determines how much to update the rating. For the away team the formula is exactly the same except the sign of the error is flipped.

There are some extra bells and whistles:

-   Any team that has been in D1 since 2008 (as far back as I have data) started with a rating equal to 0. However, for teams that came into D1 after 2008, they start with a rating around that of -8.
-   The K value depends on whether the game is an in conference game, an out of conference game, or a postseason game. For an out of conference game the K is around 0.08-0.09, for an in conference game the K is around 0.04-0.05, and for a postseason game the K is around 0.025-0.03.
    -   I initially thought that these large discrepancies in K's were the result of out of conference games telling us more about teams' strengths relative to out of conference teams that they don't play that much. In actuality I realize now it is likely primarily because of the time at which the games are played (first out of conference, then in conference, then postseason) and the fact that the strength of the updates should decrease over time as we've seen more games and thus are more confident in our estimates of team ratings. Going to at some point look into using a Kalman filter instead of an exponential smooth to better account for this change in update strength over time.
-   At the end of each season, the teams ratings get regressed a bit back to 0. For a new season, a team's rating is about 90% of the previous season's rating.
