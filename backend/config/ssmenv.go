package config

import (
	"context"
	"fmt"
	"os"
	"sort"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
)

const ssmEnvPrefix = "ssm://"

type ssmParameterGetter interface {
	GetParameters(context.Context, *ssm.GetParametersInput, ...func(*ssm.Options)) (*ssm.GetParametersOutput, error)
}

func ResolveSSMEnv(ctx context.Context) error {
	awsCfg, err := awsconfig.LoadDefaultConfig(ctx)
	if err != nil {
		return fmt.Errorf("load AWS config: %w", err)
	}

	return ResolveSSMEnvWithGetter(ctx, ssm.NewFromConfig(awsCfg))
}

func ResolveSSMEnvWithGetter(ctx context.Context, getter ssmParameterGetter) error {
	paramsByName := make(map[string][]string)
	for _, env := range os.Environ() {
		key, value, ok := strings.Cut(env, "=")
		if !ok || !strings.HasPrefix(value, ssmEnvPrefix) {
			continue
		}

		name := strings.TrimPrefix(value, ssmEnvPrefix)
		if name == "" {
			return fmt.Errorf("%s has empty SSM parameter name", key)
		}
		if !strings.HasPrefix(name, "/") {
			return fmt.Errorf("%s SSM parameter name must start with /: %s", key, name)
		}
		paramsByName[name] = append(paramsByName[name], key)
	}

	if len(paramsByName) == 0 {
		return nil
	}

	names := make([]string, 0, len(paramsByName))
	for name := range paramsByName {
		names = append(names, name)
	}
	sort.Strings(names)

	resolved := make(map[string]string, len(names))
	for i := 0; i < len(names); i += 10 {
		end := i + 10
		if end > len(names) {
			end = len(names)
		}

		out, err := getter.GetParameters(ctx, &ssm.GetParametersInput{
			Names:          names[i:end],
			WithDecryption: aws.Bool(true),
		})
		if err != nil {
			return fmt.Errorf("get SSM parameters: %w", err)
		}
		if len(out.InvalidParameters) > 0 {
			sort.Strings(out.InvalidParameters)
			return fmt.Errorf("invalid SSM parameters: %s", strings.Join(out.InvalidParameters, ", "))
		}
		for _, param := range out.Parameters {
			resolved[aws.ToString(param.Name)] = aws.ToString(param.Value)
		}
	}

	for _, name := range names {
		value, ok := resolved[name]
		if !ok {
			return fmt.Errorf("SSM parameter %s was not returned", name)
		}
		for _, key := range paramsByName[name] {
			if err := os.Setenv(key, value); err != nil {
				return fmt.Errorf("set %s from SSM: %w", key, err)
			}
		}
	}

	return nil
}
