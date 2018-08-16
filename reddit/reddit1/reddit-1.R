library(slam)
library(tm)
library(RTextTools)
library(topicmodels)
library(reshape2)
library(ggplot2)
library(scales)
library(wordcloud)


#On BigQuery the data is stored in seperate tables for each month. 
#While putting it together I used the quantile() function to set top1 and top10 variables for the top 1 and 10 score percentiles each month
#this is an easy way to isolate the top-scoring posts for all months, using score directly results in over-representation of the boom months

#read in post data for /r/cryptocurrency posts August 2017-May 2018
cc1 = read.csv("cc-export1.csv", stringsAsFactors = FALSE)
cc2 = read.csv("cc-export2.csv", stringsAsFactors = FALSE)
cc = rbind(cc1, cc2)

#this is a dummy variable that gets counted later on for aggregations
cc$post = 1

#fig0a-score-distribution
p.score.density = ggplot(cc, aes(x=score)) +
  stat_density(aes(y=..count..), color="black", fill="blue", alpha=0.3) +
  scale_x_continuous(breaks = c(1, 10, 100, 1000, 10000, 100000 ), trans="log1p")+
  scale_y_continuous(breaks = c( 10, 100, 1000, 10000, 100000, 1000000 ),labels =  c( "10", "100", "1,000", "10,000", "100,000", "1,000,000"), trans="log1p")+
  labs(y = "posts", x = "score")+
  theme_bw()

ggsave(file = "fig0a-score-distribution.png", width = 10)

#fig0b-comments-density
p.comments.density = ggplot(cc, aes(x=num_comments)) +
  stat_density(aes(y=..count..), color="black", fill="blue", alpha=0.3) +
  scale_x_continuous(breaks = c(1, 10, 100, 1000, 10000, 100000 ), trans="log1p")+
  scale_y_log10(breaks = c( 10, 100, 1000, 10000, 100000, 1000000), labels =  c( "10", "100", "1,000", "10,000", "100,000", "1,000,000")) +
  labs(y = "posts", x = "comments")+
  theme_bw()

ggsave(file = "fig0b-comments-distribution.png", width = 10)


#calculating acitvity proportions for posts scoring >= 100
sum(cc$score[cc$score >= 100])/sum(cc$score)
length(cc$score[cc$score >= 100])/length(cc$score)
sum(cc$num_comments[cc$score >= 100])/sum(cc$num_comments)


#activity through time
cc$time = as.POSIXct(as.numeric(cc$created_utc), origin = '1970-01-01', tz = 'UTC')
cc$day = as.Date(cc$time)

#create the days data-frame
day = unique(cc$day)
posts = seq(1:length(unique(cc$day)))
score = seq(1:length(unique(cc$day)))
comments = seq(1:length(unique(cc$day)))

days = data.frame(day, posts, score, comments)

for(d in days$day)
{
  p = cc[cc$day == d,]
  days$posts[days$day == d] = nrow(p)
  days$score[days$day == d] = sum(p$score)
  days$comments[days$day == d] = sum(p$num_comments)
  
}

#ggplot prefers long form tables
daymelt = melt(days, id.vars = "day", measure.vars = c( "comments", "score", "posts"))

#fig1-activity-by-day.png
p.activity.grid = ggplot(daymelt) +
  aes(day, value)+
  geom_line()+
  facet_grid(variable ~ ., scales = "free_y")

ggsave("fig1-activity-by-day.png", width = 10)

#day of week
cc$weekday = weekdays(as.Date(cc$time))

weekmelt = melt(cc, id.vars = c("weekday"), measure.vars = c("post", "num_comments", "score"))
weekcast = dcast(weekmelt,  weekday ~ variable, sum)

#fig2-dayofweek.png
p.dayofweek = ggplot(weekcast) +
  aes(x = factor(weekday, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")), y = post)+
  geom_bar(stat = "identity")+
  labs(x = "Day of week", y = "posts")

ggsave(file = "fig2-dayofweek.png", width = 12, height = 4)


#automoderator daily discussion post
sum(cc$num_comments[cc$author == "AutoModerator"])


#hours
cc$hour = format(cc$time, "%H")

#initialize hours data frame
hour = unique(cc$hour)
posts = seq(1:length(unique(cc$hour)))
score = seq(1:length(unique(cc$hour)))
comments = seq(1:length(unique(cc$hour)))

hours = data.frame(hour, posts, score, comments)

for(d in hours$hour)
{
  p = cc[cc$hour == d,]
  hours$posts[hours$hour == d] = nrow(p)
  hours$topposts[hours$hour == d] = nrow(p[p$top1 == 1,])
  hours$score[hours$hour == d] = sum(p$score)
  hours$comments[hours$hour == d] = sum(p$num_comments)
  
}

#express aspects of post performance as percentages
hours$Score = (hours$score/sum(hours$score))*100
hours$Posts = (hours$posts/sum(hours$posts))*100
hours$TopPosts = (hours$topposts/sum(hours$topposts))*100
hours$scoreperpost = hours$score/hours$posts
hours$ScorePerPost = (hours$scoreperpost/sum(hours$scoreperpost))*100


hours.m = melt(hours, id.vars = c("hour"), measure.vars = c("Posts", "TopPosts", "Score", "ScorePerPost"), variable.name = "Activity")

#fig3-hourly-activity.png
p.hours = ggplot(hours.m)+
  aes(x = hour, y = value, fill= Activity)+
geom_bar(stat = "identity", position=position_dodge())+
  labs(x = "Hour (UTC)", y = "Percent")
ggsave(file = "fig3-hourly-activity.png", width = 12)


#month

cc$month = substr(cc$day, 0, 7)

cc$amonth = paste(cc$month, "-01", sep="")  
cc$pmonth = as.POSIXct(cc$amonth, format="%Y-%m-%d", tz="GMT")

month = unique(cc$month)
posts = seq(1:length(unique(cc$month)))
score = seq(1:length(unique(cc$month)))
comments = seq(1:length(unique(cc$month)))

months = data.frame(month, posts, score, comments)


for(d in months$month)
{
  p = cc[cc$month == d,]
  months$posts[months$month == d] = nrow(p)
  months$score[months$month == d] = sum(p$score)
  months$comments[months$month == d] = sum(p$num_comments)
    
}


#domains
#merge some domains
cc$domain[cc$domain == "mobile.twitter.com"] = "twitter.com"
cc$domain[cc$domain == "m.youtube.com"] = "youtube.com"
cc$domain[cc$domain == "youtu.be"] = "youtube.com"
cc$domain[cc$domain == "m.imgur.com"] = "imgur.com"
cc$domain[cc$domain == "i.imgur.com"] = "imgur.com"

#build the domains data frame        
domainmelt = melt(cc, id.vars = c("domain"), measure.vars = c( "num_comments", "score", "post"))  
domaincast = dcast(domainmelt, domain ~ variable, sum)
domains = domaincast[order(-domaincast$score ),]


#classify type of post based on domain
cc$type = ""
cc$type[cc$domain == "self.CryptoCurrency"] = "self.cc"
cc$type[cc$domain == "i.redd.it" | cc$domain == "imgur.com" | cc$domain == "media.giphy.com" | cc$domain == "i.gyazo.com" | cc$domain == "gfycat.com" | cc$domain == "pbs.twimg.com" ] = "image"
cc$type[cc$domain == "youtube.com" | cc$domain == "v.redd.it" | cc$domain == "streamable.com"  ] = "video"
cc$type[cc$domain == "twitter.com"] = "twitter"
cc$type[substr(cc$domain, 0, 5) == "self."] = "self.other"
cc$type[cc$domain == "reddit.com" | cc$domain == "np.reddit.com"] = "reddit other"
cc$type[cc$type == "self.other" | cc$type == "reddit other"] = "other reddit"
cc$type[cc$domain == "medium.com" | cc$domain == "news.bitcoin.com" | cc$domain == "steemit.com" | cc$domain == "cointelegraph.com" | cc$domain == "ccn.com" | cc$domain == "cryptobible.io" | cc$domain == "coindesk.com" | cc$domain == "cnbc.com" | cc$domain == "themerkle.com" | cc$domain == "m.news.naver.com" | cc$domain == "bbc.com" ] = "Articles"
cc$type[cc$domain == "forbes.com" | cc$domain == "trustnodes.com" | cc$domain == "usethebitcoin.com" | cc$domain == "techcrunch.com" | cc$domain == "bloomberg.com" | cc$domain == "bitcoinist.com" | cc$domain == "astralcrypto.com" | cc$domain == "investinblockchain.com" | cc$domain == "thenextweb.com" | cc$domain == "captainaltcoin.com" | cc$domain == "independent.co.uk" ] = "Articles"


typemelt = melt(cc, id.vars = c("type"), measure.vars = c( "num_comments", "score", "post"))  

typecast = dcast(typemelt, type ~ variable, sum)
types = typecast[order(-typecast$score ),]


#this was my elegant solution to getting the numbers for post activity proportions by type
sum(types$post[types$type == "self.cc"])/sum(types$post)
sum(types$num_comments[types$type == "self.cc"])/sum(types$num_comments)
sum(types$score[types$type == "self.cc"])/sum(types$score)

sum(types$post[types$type == "image"])/sum(types$post)
sum(types$num_comments[types$type == "image"])/sum(types$num_comments)
sum(types$score[types$type == "image"])/sum(types$score)

sum(types$post[types$type == "video"])/sum(types$post)
sum(types$num_comments[types$type == "video"])/sum(types$num_comments)
sum(types$score[types$type == "video"])/sum(types$score)

sum(types$post[types$type == "twitter"])/sum(types$post)
sum(types$num_comments[types$type == "twitter"])/sum(types$num_comments)
sum(types$score[types$type == "twitter"])/sum(types$score)

sum(types$post[types$type == "self.other"])/sum(types$post)
sum(types$num_comments[types$type == "self.other"])/sum(types$num_comments)
sum(types$score[types$type == "self.other"])/sum(types$score)

sum(types$post[types$type == "reddit other"])/sum(types$post)
sum(types$num_comments[types$type == "reddit other"])/sum(types$num_comments)
sum(types$score[types$type == "reddit other"])/sum(types$score)

sum(types$post[types$type == "self.other" | types$type == "reddit other"])/sum(types$post)
sum(types$num_comments[types$type == "self.other" | types$type == "reddit other"])/sum(types$num_comments)
sum(types$score[types$type == "self.other" | types$type == "reddit other"])/sum(types$score)

sum(types$post[types$type != ""])/sum(types$post)
sum(types$num_comments[types$type != ""])/sum(types$num_comments)
sum(types$score[types$type != ""])/sum(types$score)

sum(types$post[types$type == "Articles"])/sum(types$post)
sum(types$num_comments[types$type == "Articles"])/sum(types$num_comments)
sum(types$score[types$type == "Articles"])/sum(types$score)

cc$type[cc$type == ""] = "Misc"


#look at post type prevalence by month
monthmelt = melt(cc, id.vars = c("month", "type"), measure.vars = c( "num_comments", "score", "post"))  
monthcast = dcast(monthmelt, month + type ~ variable, sum)

p.score.month = ggplot(monthcast)+
  aes(month, score, fill = type)+
  geom_bar(stat = "identity")

p.comments.month = ggplot(monthcast)+
  aes(month, num_comments, fill = type)+
  geom_bar(stat = "identity")

#express scores as a percentage of the total for the month, so all bars sum to 100
for(m in monthcast$month)
{
  monthcast$monthscore[monthcast$month == m] = months$score[months$month == m]
}
monthcast$score.p = (as.numeric(monthcast$score)/as.numeric(monthcast$monthscore))*100
monthcast$type = factor(monthcast$type, levels = c("Misc", "other reddit", "twitter", "Articles", "video", "image", "self.cc"))


#fig4-type-month.png
p.month.type = ggplot(monthcast)+
  aes(x = month, y = score.p, fill = type)+
  geom_bar(stat = "identity")+
  labs(y = "Percentage of Score")+
  scale_fill_brewer(palette = "Set3")
  
ggsave(file = "fig4-type-month.png", width = 12)  
 

#articles table
articles = cc[cc$type == "Articles",]

articles.m = melt(articles, id.vars = "domain", measure.vars = c( "num_comments", "score", "post"))
articles.c = dcast(articles.m, domain ~ variable, sum)
articles.c = articles.c[order(articles.c$score, decreasing = TRUE),]
articles.c$score.posts = articles.c$score/articles.c$post
articles.c$comments.posts = articles.c$num_comments/articles.c$post

write.csv(articles.c, file = "article domains.csv", row.names = FALSE)

#wordclouds

#wordcloud per month, only top 10% of posts by score in the month
for(m in months$month)
{
  titlestext = as.character(cc$title[cc$top10 == 1 & cc$month == m])
  
  #cleaning up text and removing common terms like "crypto"
  titles = Corpus(VectorSource(as.character(titlestext)))
  titles = tm_map(titles, removeWords, c("amp", "www", "https", "com", "nbsp", "http", stopwords("english"), "the", "will", "crypto"))
  titles <- tm_map(titles, removeNumbers)
  titles <- tm_map(titles, removePunctuation)
  titles <- tm_map(titles, stripWhitespace)
  titles <- tm_map(titles, tolower)
  titles <- tm_map(titles, stemDocument)
  titles = tm_map(titles, removeWords, c("amp", "www", "https", "com", "nbsp", "http", stopwords("english"), "the", "will", "crypto", "cryptocurr"))
  
  #make a simple word count dataframe for the word clouds 
  tdm <- TermDocumentMatrix(titles)
  tdm2 = removeSparseTerms(tdm, sparse = 0.999)
  mat <- as.matrix(tdm2)
  v <- sort(rowSums(mat),decreasing=TRUE)
  d <- data.frame(word = names(v),freq=v)
  
  
  #word cloud
  set.seed(1234)
  
  png(paste("wordcloud-title-", m, ".png", sep=""))
  layout(matrix(c(1, 2), nrow=2), heights=c(0.2, 4))
  par(mar=rep(0, 4))
  plot.new()
  text(x=0.5, y=0.5, m)
  wordcloud(words = d$word, freq = d$freq, min.freq = 1, max.words = 200, 
            random.order=FALSE, rot.per=0.30, scale=c(4,.4), 
            colors=brewer.pal(8, "Dark2"), main = m)
  
  dev.off()  
  
}



