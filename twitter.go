package main

import (
	"flag"
	"log"
	"os"

	"github.com/coreos/pkg/flagutil"
	"github.com/dghubble/go-twitter/twitter"
	"github.com/dghubble/oauth1"
)

var client Client 

type Client struct {
	*twitter.Client
}

func init() {
	flags := flag.NewFlagSet("user-auth", flag.ExitOnError)
	consumerKey := flags.String("consumer-key", "", "Twitter Consumer Key")
	consumerSecret := flags.String("consumer-secret", "", "Twitter Consumer Secret")
	accessToken := flags.String("access-token", "", "Twitter Access Token")
	accessSecret := flags.String("access-secret", "", "Twitter Access Secret")
	flags.Parse(os.Args[1:])
	flagutil.SetFlagsFromEnv(flags, "TWITTER")

	if *consumerKey == "" || *consumerSecret == "" || *accessToken == "" || *accessSecret == "" {
		log.Fatal("Consumer key/secret and Access token/secret required")
	}

	config := oauth1.NewConfig(*consumerKey, *consumerSecret)
	token := oauth1.NewToken(*accessToken, *accessSecret)
	httpClient := config.Client(oauth1.NoContext, token)
	
	client = Client{twitter.NewClient(httpClient)}
}

func getTweetsByUserID(userID int64, count int) ([]twitter.Tweet, error) {
	userTimelineParams := &twitter.UserTimelineParams{
		Count:     count,
		TweetMode: "extended",
		ExcludeReplies: twitter.Bool(true),
		IncludeRetweets: twitter.Bool(false),
		UserID: userID,
	}
	tweets, _, err := client.Timelines.UserTimeline(userTimelineParams)
	if err != nil {
		return tweets, err
	}
	return tweets, nil
}

func getVideoFromTweets(tweets []twitter.Tweet) string {
	for _, tweet := range tweets {
		if tweet.ExtendedEntities != nil {
			for _, media := range tweet.ExtendedEntities.Media {
				if media.Type == "video" {
					for _, variant := range media.VideoInfo.Variants {
						if variant.Bitrate <= preferredBitrate && variant.ContentType == expectedContentType {
							return variant.URL
						} 
					}
				}
			}
		}
	}
	return ""
}

func getVideoURL(userID int64) (string, error) {
	tweets, err := getTweetsByUserID(userID, 20)
	if err != nil {
		return "", err
	}

	url := getVideoFromTweets(tweets)
	return url, nil
}