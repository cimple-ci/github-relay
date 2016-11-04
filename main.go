package main

import (
	"fmt"
	cimpleApi "github.com/cimple-ci/cimple-go-api"
	"github.com/phayes/hookserve/hookserve"
	"github.com/urfave/cli"
	"os"
	"strconv"
)

func main() {
	var webhookPort string
	var webhookSecret string

	app := cli.NewApp()
	app.Name = "Cimple GitHub relay"
	app.Usage = "Relay webhook requests from GitHub to a Cimple server"
	app.Version = "0.0.1"
	app.Flags = []cli.Flag{
		cli.StringFlag{
			Name:        "port",
			Value:       "4567",
			Usage:       "Port to listen for webhooks",
			Destination: &webhookPort,
			EnvVar:      "GITHUB_HOOK_PORT",
		},
		cli.StringFlag{
			Name:        "secret",
			Value:       "",
			Usage:       "Secret token",
			Destination: &webhookSecret,
			EnvVar:      "GITHUB_HOOK_SECRET",
		},
	}
	app.Action = func(c *cli.Context) error {
		cimpleClient, err := cimpleApi.NewApiClient()
		if err != nil {
			fmt.Print(err)
			os.Exit(1)
		}
		cimpleClient.ServerUrl = os.Getenv("CIMPLE_SERVER_URL")

		if c.NArg() > 0 {
			cimpleClient.ServerUrl = c.Args()[0]
		}

		if len(cimpleClient.ServerUrl) == 0 {
			fmt.Print("Cimple server url not specified")
			os.Exit(1)
		}

		port, _ := strconv.Atoi(webhookPort)
		server := hookserve.NewServer()
		server.Port = port
		server.Secret = webhookSecret

		fmt.Printf("Listening on :%d", port)

		server.GoListenAndServe()

		for event := range server.Events {
			if event.Type == "push" {
				fmt.Println(event.Owner + " " + event.Repo + " " + event.Branch + " " + event.Commit)
				options := &cimpleApi.BuildSubmissionOptions{
					Url:    event.Repo,
					Commit: event.Commit,
				}

				err := cimpleClient.SubmitBuild(options)
				if err != nil {
					fmt.Println("Failed to submit build of %s:%s - %s", event.Repo, event.Commit, err)
				}
			}
		}

		return nil
	}

	app.Run(os.Args)
}
