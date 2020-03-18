rm(list = ls())
setwd(choose.dir())
library(spdep)
library(RColorBrewer)
library(classInt)
library(car)
library(maptools)
library(effects)

# Task 1 Regressor selection
# Read in TXCnty.shp
Texas.shp <- readShapePoly(choose.files(), IDvar="ID",
                          proj4string=CRS("+proj=longlat"))

# Examine Trump/Clinton variables
hist(log(Texas.shp$TRUMPVOT16))
hist(log(Texas.shp$CLINTONVOT))

hist(Texas.shp$TRUMPVOT16/Texas.shp$TOTALVOT16)
hist(Texas.shp$CLINTONVOT/Texas.shp$TOTALVOT16)

hist(log(Texas.shp$TRUMPVOT16/Texas.shp$TOTALVOT16))
hist(log(Texas.shp$CLINTONVOT/Texas.shp$TOTALVOT16))

summary(Texas.shp$TRUMPVOT16/Texas.shp$TOTALVOT16)
summary(Texas.shp$CLINTONVOT/Texas.shp$TOTALVOT16)

summary(log(Texas.shp$CLINTONVOT/Texas.shp$TOTALVOT16)) # Negative and needs a 3.5 offset
hist(log(Texas.shp$CLINTONVOT/Texas.shp$TOTALVOT16) + 3.5)

# Create any calculated values
# Transformed Rate of Clinton Voters
Texas.shp$CLINTONRATE <- log(Texas.shp$CLINTONVOT/Texas.shp$TOTALVOT16) + 3.5
hist(Texas.shp$CLINTONRATE)
plotColorRamp(Texas.shp$CLINTONRATE, Texas.shp, my.title="Texas 2016 Clinton Voting",
              my.legend="Log Voting Rate")

## Task 2 Formulate hypothesis and intuition

## Task 3 Variable exploration
# Check for any needed transformations
scatterplotMatrix(~ CLINTONRATE + CRIMERATE + OBAVOT12 + HISPORG + COLLEGEDEG +
                    POVERTY, Texas.shp)
# Examine log transformation
scatterplotMatrix(~ CLINTONRATE + CRIMERATE + log(OBAVOT12) + log(HISPORG) + 
                    log(COLLEGEDEG) + POVERTY, Texas.shp)
boxplot(CLINTONRATE ~ URBRURAL, data = Texas.shp)


## Task 4 initial model (including transformations)
mod1 <- lm(CLINTONRATE ~ CRIMERATE + log(OBAVOT12) + log(HISPORG) + 
             log(COLLEGEDEG) + POVERTY + URBRURAL, Texas.shp)
summary(mod1)
vif(mod1)

# Check residuals for heteroscedasticity (residuals vs fitted)
par(mfrow=c(2,2))
plot(mod1)
# Get exact test of hetero
ncvTest(mod1)
# Check for outliers
influenceIndexPlot(mod1, id.n = 5)
par(mfrow=c(1,1))
influencePlot(mod1, id.n = 5)
hist(mod1$residuals)

# Check outliers 35 & 251
Texas.shp@data[c(35, 251), ]

## Task 5 revised model
mod2 <- lm(CLINTONRATE ~ CRIMERATE + log(OBAVOT12) + log(HISPORG) + POVERTY, Texas.shp)
summary(mod2)
hist(mod2$residuals)
par(mfrow=c(2,2))
plot(mod2)

## Task 6 Address heteroscedasticity
# Create heteroscedastic plot (selected a weight variable)
par(mfrow=c(1,1))
auxreg1 <- lm(log(residuals(mod2)^2) ~ log(Texas.shp$POP2010), Texas.shp) 
summary(auxreg1)
plot(log(residuals(mod2)^2) ~ log(Texas.shp$POP2010))
abline(auxreg1)
title("Heteroscedastic lm-Residuals")

# Weighted model estimation
# Using lmHetero from MultiWeightedMaxLike.r (now in HelperFunctions.R)
lmH0 <- lmHetero(mod2, data=Texas.shp)
summary(lmH0)

## Simple weighted model with keyword syntax
lmH1 <- lmHetero(mod2, hetero= ~log(Texas.shp$POP2010), data = Texas.shp)
summary(lmH1)
wlm1 <- lm(mod2, data = Texas.shp, weights = lmH1$weights)
summary(wlm1)

# Log-Likeliness Ratio Test - This didn't work for some reason
(likeH0 <- logLik(lmH0))
(likeH1 <- logLik(lmH1))

cat("chi-square value:  ", chi <- -2*(likeH0[1]-likeH1[1]))
cat("error-probability: ", pchisq(chi, df=2, lower.tail=F))
# Compare with anova LR test (reduced model then full model)
anova(lmH1, lmH0, test = "LRT")

## Task 7 Residual Mapping
plotBiPolar(mod2$residuals, Texas.shp, my.title = "Residuals Model 2", 
            my.legend = "Residual Values")

## Spatial Link Matrix
# Get province centroids and links
centroids <- coordinates(Texas.shp)
links <- poly2nb(Texas.shp, queen=F)
# Make plots
plot(Texas.shp, col="grey", border=grey(0.9), axes=T)
plot(links, coords=centroids, pch=19, cex=0.1,
     col="blue", add=T)
title("Links Between Counties") 

## Spatial Autocorrelation
# Generated row-sum standardized neighbors list
linkW <- nb2listw(links, style="W")    
# 10[a] Moran plot with outlier diagnositics
moran.plot(residuals(mod2), linkW)
title("Moran Scatterplot")
# 10[b] Generate Moran's I statistic
lm.morantest(mod2, linkW)

## Task 8 Estimated Spatial Autoregressive Model
mod3 <- spautolm(mod2, data = Texas.shp, listw=linkW, family="SAR")
summary(mod3)
# Note the chi-squared result
lm.morantest(mod3, linkW)
anova(mod3, mod2, test = 'LRT')
# Discuss the differences in the models (esp. variance and significance)
moran.plot(residuals(mod3), linkW)
title("Adjusted Moran Scatterplot")
