library(rvest)
library(xml2)
library(dplyr)
library(tibble)
library(rtweet)

cran_url <- "https://cran.r-project.org/web/packages/available_packages_by_name.html"

cran_pkg_by_name <- read_html(cran_url)

pkg_tbl <- cran_pkg_by_name %>%
  html_element("body") %>%
  html_element("table") %>%
  html_table() %>%
  rename("name" = X1, "description" = X2)


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

# anti_join with already tweeted packages
# pkgs_already_tweeted <- data.frame(name = "ANonExistingPackage")
# saveRDS(pkgs_already_tweeted, "pkgs_already_tweeted.rds")
pkgs_already_tweeted <- readRDS("pkgs_already_tweeted.rds")

pkg_draw_from <- pkg_tbl_links %>%
  anti_join(pkgs_already_tweeted, by = "name")

# draw one random package
pkg_sample <- pkg_draw_from %>%
  slice_sample(n = 1)

# Adjust size of description so that Tweet fits 280 chars
adj_description <- if (pkg_sample$char_nr > 271) {
  delta <- pkg_sample$char_nr - 271
  toString(pkg_sample$description, width = pkg_sample$char_nr_desc - delta)
  } else  {
  pkg_sample$description
  }

# create text
tweet_text <- paste0("\U0001f4e6", " ", pkg_sample$name, "\n",
                     "\U0001f4dd", " ", adj_description, "\n\n",
                     "\U0001f517", " ", pkg_sample$link)



# Create a token containing your Twitter keys
bot_token <- rtweet::create_token(
  app = "rstatspkgbot",
  # the name of the Twitter app
  consumer_key = Sys.getenv("RBOT_TWITTER_CONSUMER_API_KEY"),
  consumer_secret = Sys.getenv("RBOT_TWITTER_CONSUMER_API_SECRET"),
  access_token = Sys.getenv("RBOT_TWITTER_ACCESS_TOKEN"),
  access_secret = Sys.getenv("RBOT_TWITTER_ACCESS_TOKEN_SECRET"),
  set_renv = FALSE
)

# post tweet
post_tweet(status = tweet_text,
           token = bot_token)

# write name into tibble with already tweeted packages
upd_pkg_already_tweeted <- bind_rows(pkgs_already_tweeted, pkg_sample[, "name"])
saveRDS(upd_pkg_already_tweeted, "pkgs_already_tweeted.rds")
