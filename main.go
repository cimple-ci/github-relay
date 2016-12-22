package main

import (
	"fmt"
	cimpleApi "github.com/cimple-ci/cimple-go-api"
	"github.com/lukesmith/hookserve/hookserve"
	"github.com/urfave/cli"
	"os"
	"strconv"
)

var (
	Revision  string
	VERSION   string
	BuildDate string
)

func main() {
	var webhookPort string
	var webhookSecret string

	cli.VersionPrinter = func(c *cli.Context) {
		fmt.Fprintf(c.App.Writer, "version=%s\n\nrevision=%s\ndate=%s\n", c.App.Version, Revision, BuildDate)
	}

	app := cli.NewApp()
	app.Name = "Cimple GitHub relay"
	app.Usage = "Relay webhook requests from GitHub to a Cimple server"
	app.Version = VERSION
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
			return err
		}
		cimpleClient.ServerUrl = os.Getenv("CIMPLE_SERVER_URL")

		if c.NArg() > 0 {
			cimpleClient.ServerUrl = c.Args()[0]
		}

		if len(cimpleClient.ServerUrl) == 0 {
			return fmt.Errorf("Cimple server url not specified")
		}

		port, _ := strconv.Atoi(webhookPort)
		server := hookserve.NewServer()
		server.Port = port
		server.Secret = webhookSecret

		fmt.Printf("Listening on :%d", port)
		fmt.Println("")

		server.GoListenAndServe()

		for event := range server.Events {
			if event.Type == "push" {
				fmt.Printf("Recieved push to %s/%s %s", event.Owner, event.Repo, event.Commit)
				fmt.Println("")

				options := &cimpleApi.BuildSubmissionOptions{
					Url:    event.SSHUrl,
					Commit: event.Commit,
				}

				err := cimpleClient.SubmitBuild(options)
				if err != nil {
					fmt.Printf("Failed to submit build of %s:%s - %s", event.Repo, event.Commit, err)
					fmt.Println("")
				}
			}
		}

		return nil
	}

	app.Run(os.Args)
}
