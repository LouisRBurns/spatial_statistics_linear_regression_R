rm(list = ls())
setwd(choose.dir())
library(spdep)
library(RColorBrewer)
library(classInt)
library(car)
library(maptools)
library(effects)

# Task 1 Regressor selection
# Follow this template for shape files to include projections
df <- readShapePoly(choose.files(), IDvar="ID",
                          proj4string=CRS("+proj=longlat"))
# Create any calculated values
# df$DENSITY <- df$POP2001/df$AREA
summary(df)
str(df)
# Formulate hypothesis and intuition

## Task 2 Variable exploration
# Check for any needed transformations
scatterplotMatrix(df) # to check all variables
scatterplotMatrix(~ Y + X1 + X2 + X3, df) # to check specific
# Examine log transformation
scatterplotMatrix(~ log(Y) + X1 + log(X3), df)

# Check for structural zeros, NaNs, etc.
hist(df)

## Task 3 Spatial variable exploration
# Bounding box
dfbox <- bbox(df)
# Background
plot(df, axes=T, col=grey(0.9), border="black", 
     xlim = dfbox[1,], ylim = dfbox[2,])

# Initialize chloropleth functions from SpatialAItaly.R now HelperFunctions.R
# Choropleth Dependent Variable (Y)
plotColorRamp(df$Y, df, my.title="Prices",
              my.legend="Median Price") 

# Choropleth Independent Variable (MEDROOM) using as.factor() where needed
plotColorQual(as.factor(glas$Y), glas, my.title="Rooms",
              my.legend="Median Rooms") 
# Note patterns, clusters, outliers, relations with other maps, etc.


## Task 4 Tentative Regression Model
# Consider what type of regression to do (based on dependent variable values):
# lm - linear model for continuous (gaussian) data
# glm, binomial - for binary data (aka logit regression)
# glm, poisson - for count data
# glm, quasipoisson, quasibinomial - for unaccounted hetero or SAC
# Keep this section concise - just show the reduced model
mod0 <- lm(log(Y) ~ X1 + X2 + log(X3), df)
summary(mod0)
# Comment on signs, magnitude, significance, R-squared, prior hypothesis

# Check for multicollinearity
vif(mod0)

# Refine the model based on significance (e.g. drop X2)
mod1 <- update(mod0, . ~ . -X2)

# Check residuals for heteroscedasticity (residuals vs fitted)
par(mfrow=c(2,2))
plot(mod1)
# Get exact test of hetero
ncvTest(mod1)
# Check for outliers
influenceIndexPlot(mod1, id.n = 5)
influencePlot(mod1, id.n = 5)

# Check outliers (+1 for zero index)
df@data[c(x1, x2, x3), ]

# Examine the outliers
detached <- subset(df, TYPE=="detached")
plot(detached$MEDROOM)
hist(detached$MEDROOM)
boxplot(detached$MEDROOM)

# Adjust an outlier
which.max(df$MEDROOM) # Index x1
df$MEDROOM[x1] <- newvalue

# Drop an outlier
df2 <- df[-x2, ]

## Task 5 Further Revise Regression Model
# Examine additional outliers
mod2 <- lm(Y ~ X1 + X3, df)
influencePlot(mod2, id.n = 3)

# Transform adjusted dataset and check
mod3 <- lm(log(Y) ~ X1 + log(X3), df)
summary(mod3)
anova(mod3, mod1)
influenceIndexPlot(mod3, id.n = 3)
par(mfrow=c(2,2))
plot(mod3)

# Check for collinerarity
vif(mod3)

# Plot locations of outliers on map
par(mfrow=c(1,1))
outliers <- df2
outliers$outlier <- FALSE
outliers$outlier[df.out.index] <- TRUE
plotColorQual(as.factor(outliers$outlier), outliers, my.title="Outliers",
              my.legend="Outliers") 

## Task 6 Address heteroscedasticity
# 6 Perform Breusch-Pagan tests to select appropriate weight
ncvTest(mod3)
ncvTest(mod3, var.formula = ~ log(WEIGHT))
ncvTest(mod3, var.formula = ~ log(WEIGHT2)) # insignificant
ncvTest(mod3, var.formula = ~ log(WEIGHT3)) # insignificant

# Create heteroscedastic plot (selected a weight variable)
auxreg1 <- lm(log(residuals(mod3)^2) ~ log(WEIGHT), df2) 
summary(auxreg1)
plot(log(residuals(mod3)^2) ~ log(WEIGHT))
abline(auxreg1)
title("Heteroscedastic lm-Residuals")

## Task 7 Weighted model estimation
# Using lmHetero from MultiWeightedMaxLike.r (now in HelperFunctions.R)
lmHO <- lmHetero(mod3, df)
summary(lmH0)

## Simple weighted model with keyword syntax
lmH1 <- lmHetero(mod3, hetero= ~log(WEIGHT), data = df2)
summary(lmH1)
wlm1 <- lm(mod3, data = df2, weights = lmH1$weights)
summary(wlm1)

# Log-Likeliness Ratio Test
(likeH0 <- logLik(lmH0))
(likeH1 <- logLik(lmH1))

cat("chi-square value:  ", chi <- -2*(likeH0[1]-likeH1[1]))
cat("error-probability: ", pchisq(chi, df=2, lower.tail=F))
# Compare with anova LR test (reduced model then full model)
anova(lmH1, lmH0, test = "LRT")

## Task 8 Residual Mapping
#plot(glas5, axes=T, col=grey(0.9), border="black",
#     xlim = glasbox[1,], ylim = glasbox[2,]) 
plotBiPolar(mod6$residuals, glas5, my.title = "Residuals", 
            my.legend = "Residual Values")
# Plot positive residuals (if helpful)
pos.res <- mod3$residuals[mod3$residuals >= 0]
plotBiPolar(pos.res, df2, my.title = "Positive Residuals", 
            my.legend = "Positive Residual Values")
hist(mod3$residuals)

## Task 9 Spatial Link Matrix
# Get province centroids and links
centroids <- coordinates(df)
links <- poly2nb(df, queen=F)
# Make plots
plot(df, col="grey", border=grey(0.9), axes=T)
plot(links, coords=centroids, pch=19, cex=0.1,
     col="blue", add=T)
title("Links Between Units") 

## Task 10 Spatial Autocorrelation
# Generated row-sum standardized neighbors list
linkW <- nb2listw(links, style="W")    
# 10[a] Moran plot with outlier diagnositics
moran.plot(residuals(mod3), linkW)
# 10[b] Generate Moran's I statistic
lm.morantest(mod3, linkW)

## Task 11 Estimated Spatial Autoregressive Model
mod4 <- spautolm(mod3, data=df2, listw=linkW, family="SAR")
summary(mod4)
# Note the chi-squared result
lm.morantest(mod4, linkW)
moran.mc(residuals(mod4), linkW, nsim=10000) 
anova(mod4, mod3, test = 'LRT')
# Discuss the differences in the models (esp. variance and significance)