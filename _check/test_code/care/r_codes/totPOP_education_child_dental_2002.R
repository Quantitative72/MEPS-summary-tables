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

# Children receiving dental care
  FYC <- FYC %>%
    mutate(
      child_2to17 = (1 < AGELAST & AGELAST < 18),
      child_dental = ((DVTOT02 > 0) & (child_2to17==1))*1,
      child_dental = recode_factor(
        child_dental, .default = "Missing",
        "1" = "One or more dental visits",
        "0" = "No dental visits in past year"))

# Education
  if(year <= 1998){
    FYC <- FYC %>% mutate(EDUCYR = EDUCYR02)
  }else if(year <= 2004){
    FYC <- FYC %>% mutate(EDUCYR = EDUCYEAR)
  }

  if(year >= 2012){
    FYC <- FYC %>%
      mutate(
        less_than_hs = (0 <= EDRECODE & EDRECODE < 13),
        high_school  = (EDRECODE == 13),
        some_college = (EDRECODE > 13))

  }else{
    FYC <- FYC %>%
      mutate(
        less_than_hs = (0 <= EDUCYR & EDUCYR < 12),
        high_school  = (EDUCYR == 12),
        some_college = (EDUCYR > 12))
  }

  FYC <- FYC %>% mutate(
    education = 1*less_than_hs + 2*high_school + 3*some_college,
    education = replace(education, AGELAST < 18, 9),
    education = recode_factor(education, .default = "Missing",
      "1" = "Less than high school",
      "2" = "High school",
      "3" = "Some college",
      "9" = "Inapplicable (age < 18)",
      "0" = "Missing"))

FYCdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~PERWT02F,
  data = FYC,
  nest = TRUE)

svyby(~child_dental, FUN = svytotal, by = ~education, design = subset(FYCdsgn, child_2to17==1))
