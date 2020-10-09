package main

import (
	"io"
	"log"
	"net/http"
	"os"
)

func downloadFile(filepath string, url string) error {
	// Get the data
	resp, err := http.Get(url)
	if err != nil {
		log.Fatal(err)
		return err
	}
	defer resp.Body.Close()

	// Create the file
	out, err := os.Create(filepath)
	if err != nil {
		log.Fatal(err)
		return err
	}
	defer out.Close()

	// Write the body to file
	_, err = io.Copy(out, resp.Body)
	return err
}

func cleanUpFile(filePath string) error {
	err := os.Remove("video.mp4")
	if e, ok := err.(*os.PathError); err != nil && !ok { 
		return e
	}
	return nil
}

func fetchFile(filePath string, url string) error {
	err := cleanUpFile(filePath)
	
	if err != nil {
		return err
	}

	return downloadFile(filePath, url)
}