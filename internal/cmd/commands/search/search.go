// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package search

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"

	"github.com/hashicorp/boundary/internal/cmd/base"
	"github.com/mitchellh/cli"
	"github.com/posener/complete"
	"github.com/tmc/langchaingo/chains"
	"github.com/tmc/langchaingo/llms/openai"
	"github.com/tmc/langchaingo/tools/sqldatabase"
)

var (
	_ cli.Command             = (*SearchCommand)(nil)
	_ cli.CommandAutocomplete = (*SearchCommand)(nil)
)

type SearchCommand struct {
	*base.Command

	flagOpenAiToken string
	flagOpenAiModel string
	flagPsqlDsn     string
}

func (c *SearchCommand) Synopsis() string {
	return "Use natual language to search and understand data within Boundary"
}

func (c *SearchCommand) Help() string {
	var args []string
	args = append(args,
		"Usage: boundary search [options]",
		"",
		"  Start an interactive session with Boundary's natural language search capability using OpenAI's GPT4 LLM:",
		"",
		`    $ boundary search`,
		"",
	)

	return base.WrapForHelpText(args) + c.Flags().Help()
}

func (c *SearchCommand) Flags() *base.FlagSets {
	set := c.FlagSet(base.FlagSetNone)

	f := set.NewFlagSet("Command Options")

	f.StringVar(&base.StringVar{
		Name:   "openai-token",
		Target: &c.flagOpenAiToken,
		EnvVar: "OPENAI_TOKEN",
		Usage:  `Your OpenAI auth token`,
	})

	f.StringVar(&base.StringVar{
		Name:    "openai-model",
		Default: "GPT-4",
		Target:  &c.flagOpenAiToken,
		EnvVar:  "OPENAI_MODEL",
		Usage:   `Your OpenAI auth token`,
	})

	f.StringVar(&base.StringVar{
		Name:   "psql-dsn",
		Target: &c.flagPsqlDsn,
		EnvVar: "PSQL_DSN",
		Usage:  `Your postgres DSN`,
	})

	return set
}

func (c *SearchCommand) AutocompleteArgs() complete.Predictor {
	return complete.PredictAnything
}

func (c *SearchCommand) AutocompleteFlags() complete.Flags {
	return c.Flags().Completions()
}

func (c *SearchCommand) Run(args []string) (ret int) {
	f := c.Flags()
	if err := f.Parse(args); err != nil {
		c.PrintCliError(err)
		return base.CommandUserError
	}

	llm, err := openai.New(
		openai.WithToken(c.flagOpenAiToken),
		openai.WithModel(c.flagOpenAiModel),
	)
	if err != nil {
		log.Fatal(err)
	}

	dsn := os.Getenv(c.flagPsqlDsn)

	db, err := sqldatabase.NewSQLDatabaseWithDSN("pgx", dsn, nil)
	if err != nil {
		log.Printf("err getting sql db instance")
		log.Fatal(err)
	}
	defer db.Close()

	sqlDatabaseChain := chains.NewSQLDatabaseChain(llm, 10, db)
	ctx := context.Background()

	fmt.Println("Conversation")
	fmt.Println("---------------------")
	fmt.Print("> ")
	s := bufio.NewScanner(os.Stdin)
	for s.Scan() {
		input := map[string]any{
			"query": s.Text(),
			"table_names_to_use": []string{
				"auth_method",
				"auth_account",
				"auth_oidc_account",
				"auth_oidc_method",
				"auth_password_account",
				"auth_password_method",
				"auth_token",
				"host",
				"host_catalog",
				"host_dns_name",
				"host_ip_address",
				"host_set",
				"iam_group",
				"iam_group_member_user",
				"iam_group_role",
				"iam_role",
				"iam_role_grant",
				"iam_scope",
				"iam_scope_global",
				"iam_scope_org",
				"iam_scope_project",
				"iam_user",
				"iam_user_role",
			},
		}
		out, err := chains.Predict(ctx, sqlDatabaseChain, input)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(out)

		fmt.Print("> ")
	}
	return base.CommandSuccess
}
