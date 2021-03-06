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

# Reason for difficulty receiving needed dental care
  FYC <- FYC %>%
    mutate(delay_DN  = (DNUNAB42 == 1 | DNDLAY42 == 1)*1,
           afford_DN = (DNDLRS42 == 1 | DNUNRS42 == 1)*1,
           insure_DN = (DNDLRS42 %in% c(2,3) | DNUNRS42 %in% c(2,3))*1,
           other_DN  = (DNDLRS42 > 3 | DNUNRS42 > 3)*1)

# Sex
  FYC <- FYC %>%
    mutate(sex = recode_factor(SEX, .default = "Missing",
      "1" = "Male",
      "2" = "Female"))

FYCdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~PERWT02F,
  data = FYC,
  nest = TRUE)

svyby(~afford_DN + insure_DN + other_DN, FUN = svytotal, by = ~sex, design = subset(FYCdsgn, ACCELI42==1 & delay_DN==1))
