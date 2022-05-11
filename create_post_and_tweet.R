library(rvest)
library(xml2)
library(tidyverse)
library(rtweet)

cran_url <- "https://cran.r-project.org/web/packages/available_packages_by_name.html"

cran_pkg_by_name <- read_html(cran_url)

pkg_tbk <- cran_pkg_by_name %>%
  html_element("body") %>%
  html_element("table") %>%
  html_table() %>%
  rename("name" = X1, "description" = X2)


pkg_links <- cran_pkg_by_name %>%
  html_element("body") %>%
  html_element("table") %>%
  html_elements("a") %>%
  html_attr('href') %>%
  enframe %>%
  mutate(name = gsub("(^\\.\\./\\.\\./web/packages/)([A-z0-9.]+)(/index\\.html)", "\\2", value),
         value = gsub("^\\.\\./\\.\\./", "https://cran.r-project.org/", value)) %>%
  left_join(pkg_tbk, by = "name")

# anti_join with already tweeted packages

# draw one random package

# write name into vector with already tweeted packages

# create text

# post tweet

