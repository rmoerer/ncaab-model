# function to initiate a new ema
new_ema <- function(
    init_ratings,
    inconf_k,
    outconf_k,
    hfa = 0,
    regress = 1,
    loss_function = \(mov, pred) (mov - pred)^2
  ) {
  object <- list(
    ratings = init_ratings,
    inconf_k = inconf_k,
    outconf_k = outconf_k,
    hfa = hfa,
    regress = regress,
    loss_function = loss_function,
    res = numeric(),
    preds = numeric(),
    loss = 0
  )
  class(object) <- "ema"
  return(object)
}

# ema predict method
predict.ema <- function(object, newdata) {
  home <- newdata$home
  away <- newdata$away
  location <- newdata$location
  return(predict_ema(object, home, away, location))
}

# helper function for predict.ema
predict_ema <- function(object, home, away, location) {
  object$ratings[home] - object$ratings[away] + object$hfa * location
}

# updates ema with new data
update_ema <- function(object, data) {
  res <- numeric(nrow(data))
  preds <- numeric(nrow(data))
  for (i in 1:nrow(data)) {
    home <- data$home[i]
    away <- data$away[i]
    location <- data$location[i]
    away_regress <- data$away_regress[i]
    home_regress <- data$home_regress[i]
    mov <- data$mov[i]
    conf <- data$conf[i]
    if (away_regress == 1L) {
      object$ratings[away] <- (object$ratings[away] ) * object$regress + 0
    }
    if (home_regress == 1L) {
      object$ratings[home] <- (object$ratings[home]) * object$regress + 0
    }
    pred <- object$ratings[home] - object$ratings[away] + object$hfa * location
    preds[i] <- pred
    res[i] <- mov - pred
    object$loss <- object$loss + object$loss_function(mov, pred)
    if (conf) {
      object$ratings[home] <- object$ratings[home] + object$inconf_k * (mov - pred)
      object$ratings[away] <- object$ratings[away] + object$inconf_k * (pred - mov)
    } else {
      object$ratings[home] <- object$ratings[home] + object$outconf_k * (mov - pred)
      object$ratings[away] <- object$ratings[away] + object$outconf_k * (pred - mov)
    }
  }
  object$res <- c(object$res, res)
  object$preds <- c(object$preds, preds)
  return(object)
}
