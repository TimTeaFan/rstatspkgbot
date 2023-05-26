library(rvest)
library(httr2)
library(xml2)
library(dplyr)
library(tibble)
library(rtweet)
library(rtoot)
library(jsonlite)

# read-in CRAN package list
cran_url <- "https://cran.r-project.org/web/packages/available_packages_by_name.html"

cran_pkg_by_name <- read_html(cran_url)

pkg_tbl <- cran_pkg_by_name %>%
  html_element("body") %>%
  html_element("table") %>%
  html_table() %>%
  rename("name" = X1, "description" = X2)

# get CRAN package links and join to tbl above
pkg_tbl_links <- cran_pkg_by_name %>%
  html_element("body") %>%
  html_element("table") %>%
  html_elements("a") %>%
  html_attr('href') %>%
  tibble(link = .) %>%
  mutate(name = gsub("(^\\.\\./\\.\\./web/packages/)([A-z0-9.]+)(/index\\.html)", "\\2", link),
         link = gsub("^\\.\\./\\.\\./", "https://cran.r-project.org/", link)) %>%
  left_join(pkg_tbl, by = "name") %>%
  mutate(char_nr = nchar(link) + nchar(name) + nchar(description),
         char_nr_descr = nchar(description))


# for manual use: create tbl of already tweeted packages
# pkgs_already_tweeted <- data.frame(name = c("argonDash", "radarBoxplot", "scoringUtils",
#                                             "correctedAUC", "evir", "WindCurves"))
# saveRDS(pkgs_already_tweeted, "data/pkgs_already_tweeted.rds")


# for manual use: create counts of tweets
# tweet_count <- 14
# saveRDS(tweet_count, "data/tweet_count.rds")

# get tbl of already tweeted pkgs
pkgs_already_tweeted <- readRDS("data/pkgs_already_tweeted.rds")

# anti_join with already tweeted packages
pkg_draw_from <- pkg_tbl_links %>%
  anti_join(pkgs_already_tweeted, by = "name")

# get count of tweets
tweet_count <- readRDS("data/tweet_count.rds")

# once every 4 tweets (= once every day)
every_forth_post <- !as.logical(tweet_count %% 4)

if (every_forth_post) {

  # get subset of shiny, ggplot, tidy packages
  pkg_sub_set <- pkg_draw_from %>%
    filter(grepl("shiny", name) | grepl("shiny", description) |
           grepl("tidy", name) | grepl("tidy", description) |
           grepl("^gg", name) | grepl("ggplot", description))

  # if subset is not empty: make it the tbl to draw from
  if (nrow(pkg_sub_set) != 0) {
    pkg_draw_from <- pkg_sub_set
  } else {
    # if no pkgs left ...
    # ... reset pkgs_already_tweeted including shiny/tidy/ggplot
    pkgs_already_tweeted <- pkg_tbl_links %>%
      semi_join(pkgs_already_tweeted, by = "name") %>%
      filter(!(grepl("shiny", name) | grepl("shiny", description) |
               grepl("tidy", name) | grepl("tidy", description) |
               grepl("^gg", name) | grepl("ggplot", description))) %>%
      select(name)

    # filter on shiny/tidy/ggplot
    pkg_draw_from <- pkg_tbl_links %>%
      anti_join(pkgs_already_tweeted, by = "name") %>%
      filter(grepl("shiny", name) | grepl("shiny", description) |
               grepl("tidy", name) | grepl("tidy", description) |
               grepl("^gg", name) | grepl("ggplot", description))
  }
}

# draw one random package
pkg_sample <- pkg_draw_from %>%
  slice_sample(n = 1)

# Adjust size of description so that Tweet fits 280 chars
adj_tweet_description <- if (pkg_sample$char_nr > 261) {
  delta <- pkg_sample$char_nr - 261
  toString(pkg_sample$description, width = pkg_sample$char_nr_desc - delta)
  } else  {
  pkg_sample$description
}

# create text using emojis
tweet_text <- paste0("\U0001f4e6", " ", pkg_sample$name, "\n",
                     "\U0001f4dd", " ", adj_tweet_description, "\n\n",
                     "\U0001f517", " ", pkg_sample$link, "\n\n",
                     "\U0001f916", "#RStats")

# Create a token containing Twitter keys
bot_token <- rtweet::rtweet_bot(
  api_key = Sys.getenv("TWITTER_CONSUMER_API_KEY"),
  api_secret = Sys.getenv("TWITTER_CONSUMER_API_SECRET"),
  access_token = Sys.getenv("TWITTER_ACCESS_TOKEN"),
  access_secret = Sys.getenv("TWITTER_ACCESS_TOKEN_SECRET")
)

possibly_post_tweet <- purrr::possibly(rtweet::post_tweet)

# post tweet
possibly_post_tweet(status = tweet_text,
                    token = bot_token)

if (every_forth_post) {
  # adapted from: https://www.rostrum.blog/2023/02/09/londonmapbotstodon/
  mastodon_token <- structure(
    list(
      bearer   = Sys.getenv("RTOOT_DEFAULT_TOKEN"),
      type     = "user",
      instance = "botsin.space"
    ),
    class = "rtoot_bearer"
  )

  adj_toot_description <- if (pkg_sample$char_nr > 481) {
    delta <- pkg_sample$char_nr - 481
    toString(pkg_sample$description, width = pkg_sample$char_nr_desc - delta)
  } else {
    pkg_sample$description
  }

  toot_text <- paste0("\U0001f4e6", " ", pkg_sample$name, "\n",
                       "\U0001f4dd", " ", adj_toot_description, "\n\n",
                       "\U0001f517", " ", pkg_sample$link, "\n\n",
                       "\U0001f916", "#RStats")

  rtoot::post_toot(
    status   = toot_text,
    token    = mastodon_token
  )
}


# write name into tibble with already tweeted packages
upd_pkg_already_tweeted <- bind_rows(pkgs_already_tweeted, pkg_sample[, "name"])
saveRDS(upd_pkg_already_tweeted, "data/pkgs_already_tweeted.rds")

# adjust tweet count
new_tweet_count <- tweet_count + 1
saveRDS(new_tweet_count, "data/tweet_count.rds")

# Finally: get number of Twitter followers
# rstatspkgbot_info <- lookup_users("rstatspkgbot", token = bot_token)
# no_of_followers <- rstatspkgbot_info[["followers_count"]]

# write latest follower data as json
# no_followers_ls <- list(data = list(followers = no_of_followers))
# jsonlite::write_json(no_followers_ls, "data/followers")
