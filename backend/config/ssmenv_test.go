package config

import (
	"context"
	"errors"
	"os"
	"reflect"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"github.com/aws/aws-sdk-go-v2/service/ssm/types"
)

type fakeSSMGetter struct {
	calls   [][]string
	values  map[string]string
	invalid []string
	err     error
}

func (f *fakeSSMGetter) GetParameters(_ context.Context, in *ssm.GetParametersInput, _ ...func(*ssm.Options)) (*ssm.GetParametersOutput, error) {
	f.calls = append(f.calls, append([]string(nil), in.Names...))
	if f.err != nil {
		return nil, f.err
	}

	out := &ssm.GetParametersOutput{
		InvalidParameters: append([]string(nil), f.invalid...),
	}
	for _, name := range in.Names {
		if value, ok := f.values[name]; ok {
			out.Parameters = append(out.Parameters, types.Parameter{
				Name:  aws.String(name),
				Value: aws.String(value),
			})
		}
	}
	return out, nil
}

func TestResolveSSMEnvWithGetterSkipsPlainValues(t *testing.T) {
	t.Setenv("PLAIN_VALUE", "plain")

	getter := &fakeSSMGetter{}
	if err := ResolveSSMEnvWithGetter(context.Background(), getter); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(getter.calls) != 0 {
		t.Fatalf("expected no SSM calls, got %d", len(getter.calls))
	}
	if got := getenv(t, "PLAIN_VALUE"); got != "plain" {
		t.Fatalf("expected plain value to remain, got %q", got)
	}
}

func TestResolveSSMEnvWithGetterResolvesSSMValues(t *testing.T) {
	t.Setenv("OPENAI_API_KEY", "ssm:///zuntalk/dev/openai-api-key")
	t.Setenv("DUPLICATE_KEY", "ssm:///zuntalk/dev/openai-api-key")

	getter := &fakeSSMGetter{
		values: map[string]string{
			"/zuntalk/dev/openai-api-key": "sk-test",
		},
	}

	if err := ResolveSSMEnvWithGetter(context.Background(), getter); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got := getenv(t, "OPENAI_API_KEY"); got != "sk-test" {
		t.Fatalf("expected resolved key, got %q", got)
	}
	if got := getenv(t, "DUPLICATE_KEY"); got != "sk-test" {
		t.Fatalf("expected duplicate key to resolve, got %q", got)
	}
	if !reflect.DeepEqual(getter.calls, [][]string{{"/zuntalk/dev/openai-api-key"}}) {
		t.Fatalf("unexpected calls: %#v", getter.calls)
	}
}

func TestResolveSSMEnvWithGetterBatchesByTen(t *testing.T) {
	values := make(map[string]string)
	for i := 0; i < 11; i++ {
		key := string(rune('A' + i))
		name := "/zuntalk/dev/" + key
		t.Setenv("KEY_"+key, "ssm://"+name)
		values[name] = key
	}

	getter := &fakeSSMGetter{values: values}
	if err := ResolveSSMEnvWithGetter(context.Background(), getter); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(getter.calls) != 2 {
		t.Fatalf("expected 2 SSM calls, got %d", len(getter.calls))
	}
	if len(getter.calls[0]) != 10 || len(getter.calls[1]) != 1 {
		t.Fatalf("expected batches of 10 and 1, got %#v", getter.calls)
	}
}

func TestResolveSSMEnvWithGetterFailsOnInvalidParameters(t *testing.T) {
	t.Setenv("OPENAI_API_KEY", "ssm:///zuntalk/dev/openai-api-key")
	getter := &fakeSSMGetter{invalid: []string{"/zuntalk/dev/openai-api-key"}}

	if err := ResolveSSMEnvWithGetter(context.Background(), getter); err == nil {
		t.Fatal("expected error")
	}
}

func TestResolveSSMEnvWithGetterFailsOnSSMError(t *testing.T) {
	t.Setenv("OPENAI_API_KEY", "ssm:///zuntalk/dev/openai-api-key")
	getter := &fakeSSMGetter{err: errors.New("boom")}

	if err := ResolveSSMEnvWithGetter(context.Background(), getter); err == nil {
		t.Fatal("expected error")
	}
}

func TestResolveSSMEnvWithGetterFailsOnRelativeParameterName(t *testing.T) {
	t.Setenv("OPENAI_API_KEY", "ssm://zuntalk/dev/openai-api-key")
	getter := &fakeSSMGetter{}

	if err := ResolveSSMEnvWithGetter(context.Background(), getter); err == nil {
		t.Fatal("expected error")
	}
	if len(getter.calls) != 0 {
		t.Fatalf("expected no SSM calls, got %d", len(getter.calls))
	}
}

func getenv(t *testing.T, key string) string {
	t.Helper()
	value, ok := os.LookupEnv(key)
	if !ok {
		t.Fatalf("%s is unset", key)
	}
	return value
}
