# Install and load packages
  package_names <- c("survey","dplyr","foreign","devtools")
  lapply(package_names, function(x) if(!x %in% installed.packages()) install.packages(x))
  lapply(package_names, require, character.only=T)

  install_github("e-mitchell/meps_r_pkg/MEPS")
  library(MEPS)

  options(survey.lonely.psu="adjust")

# Load FYC file
  FYC <- read.xport('C:/MEPS/h121.ssp');
  year <- 2008

  if(year <= 2001) FYC <- FYC %>% mutate(VARPSU = VARPSU08, VARSTR=VARSTR08)
  if(year <= 1998) FYC <- FYC %>% rename(PERWT08F = WTDPER08)
  if(year == 1996) FYC <- FYC %>% mutate(AGE42X = AGE2X, AGE31X = AGE1X)

  FYC <- FYC %>%
    mutate_at(vars(starts_with("AGE")),funs(replace(., .< 0, NA))) %>%
    mutate(AGELAST = coalesce(AGE08X, AGE42X, AGE31X))

  FYC$ind = 1  

# Add aggregate sources of payment
  if(year <= 1999)
    FYC <- FYC %>% mutate(TOTTRI08 = TOTCHM08)

  FYC <- FYC %>% mutate(
    TOTOTH08 = TOTOFD08 + TOTSTL08 + TOTOPR08 + TOTOPU08 + TOTOSR08,
    TOTOTZ08 = TOTOTH08 + TOTWCP08 + TOTVA08,
    TOTPTR08 = TOTPRV08 + TOTTRI08)

# Keep only needed variables from FYC
  FYCsub <- FYC %>% select(ind, DUPERSID, PERWT08F, VARSTR, VARPSU)

# Load event files
  RX <- read.xport('C:/MEPS/h118a.ssp')
  DVT <- read.xport('C:/MEPS/h118b.ssp')
  IPT <- read.xport('C:/MEPS/h118d.ssp')
  ERT <- read.xport('C:/MEPS/h118e.ssp')
  OPT <- read.xport('C:/MEPS/h118f.ssp')
  OBV <- read.xport('C:/MEPS/h118g.ssp')
  HHT <- read.xport('C:/MEPS/h118h.ssp')

# Define sub-levels for office-based and outpatient
  OBV <- OBV %>%
    mutate(event_v2X = recode_factor(
      SEEDOC, .default = 'Missing', '1' = 'OBD', '2' = 'OBO'))

  OPT <- OPT %>%
    mutate(event_v2X = recode_factor(
      SEEDOC, .default = 'Missing', '1' = 'OPY', '2' = 'OPZ'))

# Sum RX purchases for each event
  RX <- RX %>%
    rename(EVNTIDX = LINKIDX) %>%
    group_by(DUPERSID,EVNTIDX) %>%
    summarise_at(vars(RXSF08X:RXXP08X),sum) %>%
    ungroup

# Stack events (dental visits and other medical not collected for events)
  stacked_events <- stack_events(RX, IPT, ERT, OPT, OBV, HHT, keep.vars = c('SEEDOC','event_v2X'))

  stacked_events <- stacked_events %>%
    mutate(event = data,
           PR08X = PV08X + TR08X,
           OZ08X = OF08X + SL08X + OT08X + OR08X + OU08X + WC08X + VA08X)

# Read in event-condition linking file
  clink1 = read.xport('C:/MEPS/h118if1.ssp') %>%
    select(DUPERSID,CONDIDX,EVNTIDX)

# Read in conditions file and merge with condition_codes, link file
  cond <- read.xport('C:/MEPS/h120.ssp') %>%
    select(DUPERSID, CONDIDX, CCCODEX) %>%
    mutate(CCS_Codes = as.numeric(as.character(CCCODEX))) %>%
    left_join(condition_codes, by = "CCS_Codes") %>%
    full_join(clink1, by = c("DUPERSID", "CONDIDX")) %>%
    distinct(DUPERSID, EVNTIDX, Condition, .keep_all=T)

# Merge events with conditions-link file and FYCsub
  all_events <- full_join(stacked_events, cond, by=c("DUPERSID","EVNTIDX")) %>%
    filter(!is.na(Condition),XP08X >= 0) %>%
    mutate(count = 1) %>%
    full_join(FYCsub, by = "DUPERSID")

# Sum by person, condition, across event
all_pers <- all_events %>%
  group_by(ind, DUPERSID, VARSTR, VARPSU, PERWT08F, Condition, count) %>%
  summarize_at(vars(SF08X, PR08X, MR08X, MD08X, OZ08X, XP08X),sum) %>% ungroup

PERSdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~PERWT08F,
  data = all_pers,
  nest = TRUE)

svyby(~XP08X + SF08X + MR08X + MD08X + PR08X + OZ08X, by = ~Condition, FUN = svymean, design = PERSdsgn)
