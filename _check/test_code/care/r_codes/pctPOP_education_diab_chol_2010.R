# Install and load packages
  package_names <- c("survey","dplyr","foreign","devtools")
  lapply(package_names, function(x) if(!x %in% installed.packages()) install.packages(x))
  lapply(package_names, require, character.only=T)

  install_github("e-mitchell/meps_r_pkg/MEPS")
  library(MEPS)

  options(survey.lonely.psu="adjust")

# Load FYC file
  FYC <- read.xport('C:/MEPS/h138.ssp');
  year <- 2010
  
  FYC <- FYC %>%
    mutate_at(vars(starts_with("AGE")),funs(replace(., .< 0, NA))) %>%
    mutate(AGELAST = coalesce(AGE10X, AGE42X, AGE31X))

  FYC$ind = 1

# Diabetes care: Lipid profile
  if(year > 2007){
    FYC <- FYC %>%
      mutate(
        past_year = (DSCH1053==1 | DSCH1153==1),
        more_year = (DSCH0953==1 | DSCB0953==1),
        never_chk = (DSCHNV53 == 1),
        non_resp  = (DSCH1053 %in% c(-7,-8,-9))
      )
  }else{
    FYC <- FYC %>%
      mutate(
        past_year = (CHOLCK53 == 1),
        more_year = (1 < CHOLCK53 & CHOLCK53 < 6),
        never_chk = (CHOLCK53 == 6),
        non_resp  = (CHOLCK53 %in% c(-7,-8,-9))
      )
  }

  FYC <- FYC %>%
    mutate(
      diab_chol = as.factor(case_when(
        .$past_year ~ "In the past year",
        .$more_year ~ "More than 1 year ago",
        .$never_chk ~ "Never had cholesterol checked",
        .$non_resp ~ "Don\'t know/Non-response",
        TRUE ~ "Missing")))

# Education
  if(year <= 1998){
    FYC <- FYC %>% mutate(EDUCYR = EDUCYR10)
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

DIABdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~DIABW10F,
  data = FYC,
  nest = TRUE)

svyby(~diab_chol, FUN = svymean, by = ~education, design = DIABdsgn)
