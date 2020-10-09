package main

import "log"

const (
	trumpID int64 = 25073877
	preferredBitrate int = 832000
	expectedContentType string = "video/mp4"
	videoFilePath string = "video.mp4"
)

func main() {
	url, err := getVideoURL(trumpID)
	if err != nil {
		log.Fatal(err)
		panic(err)	
	}
	
	if url == "" {
		log.Println("No video found.")
		return
	} else {
		log.Println("Video found.")
	}

	err = fetchFile(videoFilePath, url)
	if err != nil {
		log.Fatal(err)
		panic(err)	
	}
}