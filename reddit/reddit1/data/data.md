I have used the data in this comprehensive looking [bigquery table](https://bigquery.cloud.google.com/dataset/fh-bigquery:reddit_posts) as a starting point for analysis. It appears to be a comprehensive set of reddit posts, but I'm not sure yet whether it includes deleted/censored posts, my guess is not. 

On BigQuery the data is stored in seperate tables for each month. 
While putting it together I used the quantile() function to set top1 and top10 variables for the top 1 and 10 score percentiles each month
This is an easy way to isolate the top-scoring posts for all months, using score directly results in over-representation of the boom months
