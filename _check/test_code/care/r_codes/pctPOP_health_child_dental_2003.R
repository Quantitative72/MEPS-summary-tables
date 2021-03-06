# Install and load packages
  package_names <- c("survey","dplyr","foreign","devtools")
  lapply(package_names, function(x) if(!x %in% installed.packages()) install.packages(x))
  lapply(package_names, require, character.only=T)

  install_github("e-mitchell/meps_r_pkg/MEPS")
  library(MEPS)

  options(survey.lonely.psu="adjust")

# Load FYC file
  FYC <- read.xport('C:/MEPS/h79.ssp');
  year <- 2003
  
  FYC <- FYC %>%
    mutate_at(vars(starts_with("AGE")),funs(replace(., .< 0, NA))) %>%
    mutate(AGELAST = coalesce(AGE03X, AGE42X, AGE31X))

  FYC$ind = 1

# Children receiving dental care
  FYC <- FYC %>%
    mutate(
      child_2to17 = (1 < AGELAST & AGELAST < 18),
      child_dental = ((DVTOT03 > 0) & (child_2to17==1))*1,
      child_dental = recode_factor(
        child_dental, .default = "Missing",
        "1" = "One or more dental visits",
        "0" = "No dental visits in past year"))

# Perceived health status
  if(year == 1996)
    FYC <- FYC %>% mutate(RTHLTH53 = RTEHLTH2, RTHLTH42 = RTEHLTH2, RTHLTH31 = RTEHLTH1)

  FYC <- FYC %>%
    mutate_at(vars(starts_with("RTHLTH")), funs(replace(., .< 0, NA))) %>%
    mutate(
      health = coalesce(RTHLTH53, RTHLTH42, RTHLTH31),
      health = recode_factor(health, .default = "Missing",
        "1" = "Excellent",
        "2" = "Very good",
        "3" = "Good",
        "4" = "Fair",
        "5" = "Poor"))

FYCdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~PERWT03F,
  data = FYC,
  nest = TRUE)

svyby(~child_dental, FUN = svymean, by = ~health, design = subset(FYCdsgn, child_2to17==1))
