# Quantifying the Impacts of Online Mental Health Therapists

## Objective
We seek to create a viable measure of therapist quality to be used by a major online mental health therapy platform. Such a measure may be useful to the company for several reasons:

* Helps the company in the evaluation and management of their therapeutic labor
* Helps the company and its therapists understand what contributes to high-quality therapy
* Provides evidence of the company's effects on clients' mental health

We utilize an econometric approach common to the world of education: value-added modeling. This approach is conventionally used to model teacher quality in terms of how much a given teacher increases their students' test scores over the course of a school year; we analogize to model therapist quality in terms of how much a given therapist increases their clients' scores on standardized mental health assessments. While this measure is obviously insufficient to capture every aspect of therapist quality (as this is a multi-dimensional, and often intangible, concept), it does offer one helpful and empirically rigorous dimension to any serious evaluation. 

## Data
We utilize proprietary data from a major online therapy platform. Our data are observed at the client level, and provide one observation for each time a client completed a mental health assessment with their therapist. We thus observe multiple rows per client, with each row containing which therapist they were paired with, the type of assessment they completed, and their score on that assessment. Each row also contains demographic information on the client, demographic information on the therapist, and information about the interaction between the client and their therapist, including dates of the interaction and counts of messages and video chats. 

We use the scores clients receive on mental health assessments to construct our measures of therapist value-added. These mental health assessments are standard assessments conventionally used by therapists throughout the world, and despite the inescapable subjectivity of assessing one’s own mental well-being, these assessments have been demonstrated to be reliable measures of mental health. One of the most common assessments used by therapists in our data is the GAD-7, which represents about 40% of the assessments administered to clients in our dataset. This is an assessment designed to measure key symptoms of anxiety and depression. Because of its abundance in our data, and because of its relevance to discussions of contemporary mental health, we restrict our estimation of therapist VA to this assessment type specifically, though note that it would be easy to replicate this process across a range of assessment types.

Of course, there are strengths and weaknesses to our value-added approach. Being necessarily tied to these specific symptom assessments means that our measures of therapist quality will be specific to the conditions being diagnosed with a given assessment, which may overlook ways in which therapists are contributing to their patients’ overall well-being. For example, symptom assessments may be quite poor at measuring productivity and interpersonal relationship health, coping strategies, or therapeutic alliance. These ancillary outcomes are important healthcare outcomes that some therapists might be quite skilled at generating, so a myopic focus on symptom assessment scores may miss these features of therapist quality. One consolation is that these assessments are fairly rich in the number of underlying factors that generate the scores. As an example, the Depression Anxiety Stress Scales (DASS-21) evaluates a patient’s levels of stress, self-confidence, and anxiety, as well as their abilities to cope, to focus, and to relax. As a result, these symptom assessment scores serve as a meaningful proxy for overall mental health and well-being. Additionally, and importantly, we create value-added estimates based on these assessment scores that are unbiased predictors of the actual gains to assessment scores that a client can expect upon being matched to a given therapist. Their usefulness notwithstanding, it should be noted that these assessment score-based measures of therapist value-added are not sufficient to capture every aspect of therapist quality, and are likely best used in concert with other methods of evaluation.

Our dataset, when restricted to GAD-7 outcomes, consists of 110,983 unique clients being served by 4,797 unique therapists. A histogram of standardized scores on the GAD-7 (our outcome variable) is displayed below. A higher score indicates greater levels of anxiety and thus poorer mental health.

![zscorehist](https://user-images.githubusercontent.com/58236773/214170324-c8be5f5c-5567-48ce-b427-40341c9c1dcb.jpg)

## Strategy

Our estimation strategy proceeds in 3 steps, closely analogizing from the approach in Chetty, Friedman, & Rockoff (2014).

We begin by regressing standardized assessment scores on a vector of client characteristics and therapist fixed effects, as in Equation 1:

$$Y_{it} = \beta X_{it}+\mu_{jt}+\epsilon_{it}$$

Where $Y_{it}$ is client $i$'s assessment score in $monthyear t$. $X_{it}$ includes controls for client demographic information and, importantly, their past assessment scores. $\mu_{jt}$ is a fixed effect for therapist $j$ in $monthyear t$.

We calculate the residuals from this model according to Equation 2:

$$R_{it}=Y_{it}-\beta X_{it} = \mu_{jt}+\epsilon_{it}$$

Where $R_{it}$ represents residual client assessment scores. Notably, $R_{it}$ is equivalent to therapist effect, $\mu_{jt}$, plus idiosyncratic error $\epsilon_{it}$. This idiosyncratic error is unobserved and assumed to be uncorrelated with either of $\beta X_{it}$ or $\mu_{jt}$.

Next, we calculate each therapist's average effect in each $monthyear$ period, $\bar{R}_{jt}$. This could be thought of as a naive estimate of therapist $j$'s VA in $monthyear t$, noting only that it does not account for drift in therapist quality over time.

In order to account for such drift over time, we finalize our estimate for therapist $j$'s VA in $monthyear t$:

$$ \hat{\mu}_{jt} = \sum_{s=1}^{t-1} \phi_{s} \bar{R}_{js}  $$

where the vector of coefficients $\phi_{s}$ are chosen to minimize the mean squared error of the forecasts from prior assessment scores; these are calculated via a regression of $\bar{R}_{jt}$ on $\sum_{s=1}^{t-1} \phi_{s} \bar{R}_{js}$. (Thus, $\hat{\mu}_{jt}$ are essentially the fitted values from this regression, minus the constant.) 

## Evaluation 

Having made these estimates, our second task was to evaluate them against our objective, which is to create predictively valid estimators of therapist quality. We utilize two main approaches to assess this validity.

First, we compare our estimates of a given therapist’s quality in a given period directly to their actual quality in that period. 

Actual quality in a given period can be measured as the actual improvement in a therapists’ clients’ mental health assessment scores during that period. It is easy to compare these directly. Utilizing months as our time period, we compute a client's actual gains in mental health as their assessment score in that month minus their assessment score in the previous month. Then, for each therapist in each month, we compute that therapist's actual quality as the average of their clients' actual gains during that month. We then compare these measures of actual therapist quality to the estimates produced by our VA method. If our method is useful, these estimates should not be far off. Results can be seen in the table below.

![table1](https://user-images.githubusercontent.com/58236773/214174318-7fabdc19-bcba-42e9-bc40-540a062371e4.png)

The first two columns represent the difference between estimated VA scores and actual quality. Specifically, the mean difference between these two numbers, and the SD of that mean, are shown. It can be seen that the mean difference between our estimates of VA and actual quality is about 0.101 SD of standardized assessment scores. We estimate several specifications of the VA model, using additional variables as well as polynomials. These can be seen in the rows of the table. Ultimately, our original specification is preferred; it produces estimates with the smallest mean difference between those estimates and the reality.

We also utilize our VA estimation method to predict assessment scores in future periods, using a leave-one-out method and accounting for drift in quality over time as in CFR. We find the difference between the results of this prediction and actual quality, as shown in the second two columns of the above table. While predicted scores are, on average, slightly further from actual scores than the direct estimates in column 1, they are still within 0.2 SD of actual assessment scores.

The second method we use to evaluate our estimation of VA is to simulate a real-world application of the VA strategy. Specifically, we predict the value added to client i’s mental health when they join the platform with therapist j in some period t. We then compare that prediction, once again, with client i’s actual improvement during period t. This simulates a real-world situation in which a client, upon joining the therapy platform, might be interested to know what they can reasonably expect in terms of mental health gains upon being assigned to a given therapist. 

The difference between our predictions of client improvement in period $t$ and their actual improvement during that period (again measured in standardized assessment scores) is presented in the table below.

![table2](https://user-images.githubusercontent.com/58236773/214174721-275343f1-05e5-4f8a-9414-9064ff70ba84.png)

We can see in column 1 that the predictions made by our original model were within 0.014 SD's, on average, of clients' actual improvement. A T-test between our predictions and actual improvement yields a p-value of 0.112, indicating no statistically significant difference between the two. Again, the remaining columns show the results from other specifications of the model, but the original performs the best.

## Conclusion

Are our estimates of therapist quality useful? 

They are consistently within 0.2 standard deviations of actual scores, on average. Our estimates, therefore, are useful predictors of a client's mental health score gains upon assignment to a new theraist. This implies that our estimates are very useful, insofar as standardized mental health scores produce a useful metric for assessing mental wellbeing.
