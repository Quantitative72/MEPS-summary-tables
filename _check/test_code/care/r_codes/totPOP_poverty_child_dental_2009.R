# Install and load packages
  package_names <- c("survey","dplyr","foreign","devtools")
  lapply(package_names, function(x) if(!x %in% installed.packages()) install.packages(x))
  lapply(package_names, require, character.only=T)

  install_github("e-mitchell/meps_r_pkg/MEPS")
  library(MEPS)

  options(survey.lonely.psu="adjust")

# Load FYC file
  FYC <- read.xport('C:/MEPS/h129.ssp');
  year <- 2009
  
  FYC <- FYC %>%
    mutate_at(vars(starts_with("AGE")),funs(replace(., .< 0, NA))) %>%
    mutate(AGELAST = coalesce(AGE09X, AGE42X, AGE31X))

  FYC$ind = 1

# Children receiving dental care
  FYC <- FYC %>%
    mutate(
      child_2to17 = (1 < AGELAST & AGELAST < 18),
      child_dental = ((DVTOT09 > 0) & (child_2to17==1))*1,
      child_dental = recode_factor(
        child_dental, .default = "Missing",
        "1" = "One or more dental visits",
        "0" = "No dental visits in past year"))

# Poverty status
  if(year == 1996)
    FYC <- FYC %>% rename(POVCAT96 = POVCAT)

  FYC <- FYC %>%
    mutate(poverty = recode_factor(POVCAT09, .default = "Missing",
      "1" = "Negative or poor",
      "2" = "Near-poor",
      "3" = "Low income",
      "4" = "Middle income",
      "5" = "High income"))

FYCdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~PERWT09F,
  data = FYC,
  nest = TRUE)

svyby(~child_dental, FUN = svytotal, by = ~poverty, design = subset(FYCdsgn, child_2to17==1))
