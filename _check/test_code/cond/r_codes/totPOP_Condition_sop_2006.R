# Install and load packages
  package_names <- c("survey","dplyr","foreign","devtools")
  lapply(package_names, function(x) if(!x %in% installed.packages()) install.packages(x))
  lapply(package_names, require, character.only=T)

  install_github("e-mitchell/meps_r_pkg/MEPS")
  library(MEPS)

  options(survey.lonely.psu="adjust")

# Load FYC file
  FYC <- read.xport('C:/MEPS/h105.ssp');
  year <- 2006

  if(year <= 2001) FYC <- FYC %>% mutate(VARPSU = VARPSU06, VARSTR=VARSTR06)
  if(year <= 1998) FYC <- FYC %>% rename(PERWT06F = WTDPER06)
  if(year == 1996) FYC <- FYC %>% mutate(AGE42X = AGE2X, AGE31X = AGE1X)

  FYC <- FYC %>%
    mutate_at(vars(starts_with("AGE")),funs(replace(., .< 0, NA))) %>%
    mutate(AGELAST = coalesce(AGE06X, AGE42X, AGE31X))

  FYC$ind = 1  

# Add aggregate sources of payment
  if(year <= 1999)
    FYC <- FYC %>% mutate(TOTTRI06 = TOTCHM06)

  FYC <- FYC %>% mutate(
    TOTOTH06 = TOTOFD06 + TOTSTL06 + TOTOPR06 + TOTOPU06 + TOTOSR06,
    TOTOTZ06 = TOTOTH06 + TOTWCP06 + TOTVA06,
    TOTPTR06 = TOTPRV06 + TOTTRI06)

# Keep only needed variables from FYC
  FYCsub <- FYC %>% select(ind, DUPERSID, PERWT06F, VARSTR, VARPSU)

# Load event files
  RX <- read.xport('C:/MEPS/h102a.ssp')
  DVT <- read.xport('C:/MEPS/h102b.ssp')
  IPT <- read.xport('C:/MEPS/h102d.ssp')
  ERT <- read.xport('C:/MEPS/h102e.ssp')
  OPT <- read.xport('C:/MEPS/h102f.ssp')
  OBV <- read.xport('C:/MEPS/h102g.ssp')
  HHT <- read.xport('C:/MEPS/h102h.ssp')

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
    summarise_at(vars(RXSF06X:RXXP06X),sum) %>%
    ungroup

# Stack events (dental visits and other medical not collected for events)
  stacked_events <- stack_events(RX, IPT, ERT, OPT, OBV, HHT, keep.vars = c('SEEDOC','event_v2X'))

  stacked_events <- stacked_events %>%
    mutate(event = data,
           PR06X = PV06X + TR06X,
           OZ06X = OF06X + SL06X + OT06X + OR06X + OU06X + WC06X + VA06X)

# Read in event-condition linking file
  clink1 = read.xport('C:/MEPS/h102if1.ssp') %>%
    select(DUPERSID,CONDIDX,EVNTIDX)

# Read in conditions file and merge with condition_codes, link file
  cond <- read.xport('C:/MEPS/h104.ssp') %>%
    select(DUPERSID, CONDIDX, CCCODEX) %>%
    mutate(CCS_Codes = as.numeric(as.character(CCCODEX))) %>%
    left_join(condition_codes, by = "CCS_Codes") %>%
    full_join(clink1, by = c("DUPERSID", "CONDIDX")) %>%
    distinct(DUPERSID, EVNTIDX, Condition, .keep_all=T)

# Merge events with conditions-link file and FYCsub
  all_events <- full_join(stacked_events, cond, by=c("DUPERSID","EVNTIDX")) %>%
    filter(!is.na(Condition),XP06X >= 0) %>%
    mutate(count = 1) %>%
    full_join(FYCsub, by = "DUPERSID")

# Sum by person, condition, across event
all_pers <- all_events %>%
  group_by(ind, DUPERSID, VARSTR, VARPSU, PERWT06F, Condition, count) %>%
  summarize_at(vars(SF06X, PR06X, MR06X, MD06X, OZ06X, XP06X),sum) %>% ungroup

PERSdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~PERWT06F,
  data = all_pers,
  nest = TRUE)

svyby(~(XP06X > 0) + (SF06X > 0) + (MR06X > 0) + (MD06X > 0) + (PR06X > 0) + (OZ06X > 0),
 by = ~Condition, FUN = svytotal, design = PERSdsgn)
