# Install and load packages
  package_names <- c("survey","dplyr","foreign","devtools")
  lapply(package_names, function(x) if(!x %in% installed.packages()) install.packages(x))
  lapply(package_names, require, character.only=T)

  install_github("e-mitchell/meps_r_pkg/MEPS")
  library(MEPS)

  options(survey.lonely.psu="adjust")

# Load FYC file
  FYC <- read.xport('C:/MEPS/h113.ssp');
  year <- 2007
  
  FYC <- FYC %>%
    mutate_at(vars(starts_with("AGE")),funs(replace(., .< 0, NA))) %>%
    mutate(AGELAST = coalesce(AGE07X, AGE42X, AGE31X))

  FYC$ind = 1

# Diabetes care: Flu shot
  if(year > 2007){
    FYC <- FYC %>%
      mutate(
        past_year = (DSFL0753==1 | DSFL0853==1),
        more_year = (DSFL0653==1 | DSVB0653==1),
        never_chk = (DSFLNV53 == 1),
        non_resp  = (DSFL0753 %in% c(-7,-8,-9))
      )
  }else{
    FYC <- FYC %>%
      mutate(
        past_year = (FLUSHT53 == 1),
        more_year = (1 < FLUSHT53 & FLUSHT53 < 6),
        never_chk = (FLUSHT53 == 6),
        non_resp  = (FLUSHT53 %in% c(-7,-8,-9))
      )
  }

  FYC <- FYC %>%
    mutate(
      diab_flu = as.factor(case_when(
        .$past_year ~ "In the past year",
        .$more_year ~ "More than 1 year ago",
        .$never_chk ~ "Never had flu shot",
        .$non_resp ~ "Don\'t know/Non-response",
        TRUE ~ "Missing")))

# Perceived mental health
  if(year == 1996)
    FYC <- FYC %>% mutate(MNHLTH53 = MNTHLTH2, MNHLTH42 = MNTHLTH2, MNHLTH31 = MNTHLTH1)

  FYC <- FYC %>%
    mutate_at(vars(starts_with("MNHLTH")), funs(replace(., .< 0, NA))) %>%
    mutate(mnhlth = coalesce(MNHLTH53, MNHLTH42, MNHLTH31)) %>%
    mutate(mnhlth = recode_factor(mnhlth, .default = "Missing",
      "1" = "Excellent",
      "2" = "Very good",
      "3" = "Good",
      "4" = "Fair",
      "5" = "Poor"))

DIABdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~DIABW07F,
  data = FYC,
  nest = TRUE)

svyby(~diab_flu, FUN = svymean, by = ~mnhlth, design = DIABdsgn)
