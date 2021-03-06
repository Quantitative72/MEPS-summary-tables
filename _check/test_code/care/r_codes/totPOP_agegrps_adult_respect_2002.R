# Install and load packages
  package_names <- c("survey","dplyr","foreign","devtools")
  lapply(package_names, function(x) if(!x %in% installed.packages()) install.packages(x))
  lapply(package_names, require, character.only=T)

  install_github("e-mitchell/meps_r_pkg/MEPS")
  library(MEPS)

  options(survey.lonely.psu="adjust")

# Load FYC file
  FYC <- read.xport('C:/MEPS/h70.ssp');
  year <- 2002
  
  FYC <- FYC %>%
    mutate_at(vars(starts_with("AGE")),funs(replace(., .< 0, NA))) %>%
    mutate(AGELAST = coalesce(AGE02X, AGE42X, AGE31X))

  FYC$ind = 1

# How often doctor showed respect (adults)
  FYC <- FYC %>%
    mutate(adult_respect = recode_factor(
      ADRESP42, .default = "Missing",
      "4" = "Always",
      "3" = "Usually",
      "2" = "Sometimes/Never",
      "1" = "Sometimes/Never",
      "-7" = "Don't know/Non-response",
      "-8" = "Don't know/Non-response",
      "-9" = "Don't know/Non-response",
      "-1" = "Inapplicable"))

# Age groups
# To compute for all age groups, replace 'agegrps' in the 'svyby' function with 'agegrps_v2X' or 'agegrps_v3X'
  FYC <- FYC %>%
    mutate(agegrps = cut(AGELAST,
      breaks = c(-1, 4.5, 17.5, 44.5, 64.5, Inf),
      labels = c("Under 5","5-17","18-44","45-64","65+"))) %>%
    mutate(agegrps_v2X = cut(AGELAST,
      breaks = c(-1, 17.5 ,64.5, Inf),
      labels = c("Under 18","18-64","65+"))) %>%
    mutate(agegrps_v3X = cut(AGELAST,
      breaks = c(-1, 4.5, 6.5, 12.5, 17.5, 18.5, 24.5, 29.5, 34.5, 44.5, 54.5, 64.5, Inf),
      labels = c("Under 5", "5-6", "7-12", "13-17", "18", "19-24", "25-29",
                 "30-34", "35-44", "45-54", "55-64", "65+")))

SAQdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~SAQWT02F,
  data = FYC,
  nest = TRUE)

svyby(~adult_respect, FUN=svytotal, by = ~agegrps, design = subset(SAQdsgn, ADAPPT42 >= 1 & AGELAST >= 18))
