---
name: rails-on-lambda
description: This skill should be used when deploying, running, or debugging a Rails app on AWS Lambda, or when moving a Rails app from ECS, App Runner, Heroku or a VM onto Lambda. Use it when touching the Dockerfile, an entrypoint, a Lambda handler, ActiveJob on SQS, secrets loading, CloudFront in front of a function URL, one-off commands like `db:migrate` in production, or the deploy workflow of such an app, even if the user only says "add a job", "add a secret" or "why is the client IP wrong" in such an app. Signs include `apigatewayv2_rack`, `aws_lambda_ric`, `lambdakiq`, `Lambdakiq.cmd`, `LambdaRackApp`, `CommandRunner`, `lambrunner.rb`, `lambda_entrypoint.sh`, `SSM_SECRET__`, `APP_HANDLER`, `AWS_LAMBDA_FUNCTION_NAME`, `aws_lambda_function_url`, `x-origin-verify`, or the user mentioning "Rails on Lambda", "serverless Rails", "Lamby", or "function URL". Provides the container image, handlers for web, jobs and commands, secrets, CloudFront, deploy and migration flow, and the limits to design around. Project-specific conventions always take priority.
version: 0.1.0
---

# Rails on AWS Lambda

How to run a Rails app on Lambda from one container image, with three functions: `web` (HTTP through a function URL behind CloudFront), `lambdakiq` (ActiveJob over SQS) and `runner` (one-off commands such as `db:migrate`). Taken from a production app that runs this way. Project-specific conventions (CLAUDE.md, `docs/`) always take priority.

- Terraform follows /sorah-guides:terraform, the workflow /sorah-guides:github-ci.
- Aurora DSQL fits Lambda well (IAM auth, no connection limit to manage); see /sorah-guides:dsql-on-rails.
- Lambda Web Functions (HTTP servers on Lambda without an adapter) support Node.js only so far. Check `/aws` docs before choosing them for Ruby.

Lambda is not a server. Plan around these:

- One request per execution environment. Concurrency means more environments, each with its own boot and its own database connections.
- The environment is frozen as soon as the handler returns. Threads that work after the response (async reporters, buffered log shippers, `Thread.new`) stall until the next invocation, or never resume.
- The filesystem is read-only except `/tmp` (512 MB by default).
- A function URL buffers the request and response, each limited to 6 MB. No streaming, SSE, WebSocket or Action Cable through `apigatewayv2_rack`.
- An invocation lasts at most 15 minutes. The web function is further limited by CloudFront's origin read timeout (60 s unless raised).
- Cold starts boot Rails. Precompile bootsnap, eager load, and give the function enough memory, since CPU scales with it.
- No in-process scheduler. ActiveJob delays are limited to SQS's 15 minutes.

## Reference files

`references/` mirrors an app's tree. Copy the files, then replace `myapp`, `MyApp`, the account ID and the region.

| File | What it is |
|---|---|
| `Dockerfile` | One image for Lambda and Puma, with `aws_lambda_ric`, read-only bootsnap cache, `tmp/` on `/tmp` |
| `config/lambda_entrypoint.sh` | Lambda entrypoint: handler from `APP_HANDLER`, writable `HOME`, starts `aws_lambda_ric` |
| `config/docker_entrypoint.sh` | Entrypoint everywhere else |
| `config/boot.rb` | Loads `lambda_boot.rb` on Lambda only |
| `config/lambda_boot.rb` | Copies SSM parameters into `ENV` before Rails boots |
| `config/lambda_rack.rb` | Web handler, `config.ru` through `apigatewayv2_rack` |
| `config.ru` | CloudFront verification and client IP middlewares |
| `config/lambda_runner.rb` | Runner handler: runs a command, returns output and exit status |
| `config/initializers/active_job.rb`, `lambdakiq.rb` | Queue adapter by `JOB_ADAPTER`, Lambdakiq worker on every job and mailer |
| `config/initializers/sentry.rb` | Synchronous Sentry on Lambda |
| `deploy/lambrunner.rb`, `deploy/Gemfile` | CLI that invokes the runner and exits with the command's status |
| `tf/lambda.tf` | The three functions, function URL, SQS event source mapping |
| `tf/sqs.tf`, `tf/locals.tf`, `tf/variables.tf` | Job queue and DLQ, environment and `SSM_SECRET__` variables |
| `tf/cloudfront.tf` | Distribution in front of the function URL, origin verify secret |
| `tf/iam_MyApp.tf` | Execution role, and the deploy role's Lambda permissions |
| `.github/workflows/deploy.yml` | Build and deploy jobs: image push, migrate, update functions |

Gems: `apigatewayv2_rack`, `lambdakiq`, `aws_lambda_ric` (`require: false`), `aws-sdk-ssm`, `bootsnap` (`require: false`). The deploy Gemfile needs only `aws-sdk-lambda`.

## Image

Build one image and choose the function by handler. The same image still runs `puma` on ECS or locally, which keeps a way out if Lambda stops fitting.

- Any Ruby base image works with the `aws_lambda_ric` runtime interface client; install a binstub at `/usr/local/bin/aws_lambda_ric`. AWS's `public.ecr.aws/lambda/ruby` base image works too, but resolves handlers relative to `LAMBDA_TASK_ROOT` instead of the working directory.
- Each function overrides the image's entrypoint with `/lambda_entrypoint.sh` (`image_config.entry_point`), so the image's `ENTRYPOINT`/`CMD` stay Puma.
- `_HANDLER` is reserved on Lambda, so the function sets `APP_HANDLER` and the entrypoint exports it as `_HANDLER`. Handlers are `file.Constant.method`, with `file` relative to the working directory (`/app`).
- Point everything that writes at `/tmp`: link `/app/tmp` to `/tmp/apptmp` at build time and create the target at start; set `HOME=/tmp/home`.
- Precompile bootsnap into the image (`bootsnap precompile --gemfile app/ lib/ config/`) and run with `BOOTSNAP_READONLY=1`, since the cache directory is read-only at runtime.
- Build for the function's `architectures`. Push with `provenance: false` and `sbom: false`: attestations turn the tag into an image index, which Lambda rejects.
- Write `REVISION` (the commit SHA) into the image for release tracking.

## Handlers

| Function | Handler | Trigger |
|---|---|---|
| `web` | `config/lambda_rack.LambdaRackApp.handle` | function URL |
| `lambdakiq` | `config/environment.Lambdakiq.cmd` | SQS event source mapping |
| `runner` | `config/lambda_runner.CommandRunner.handle` | synchronous `Invoke` |

The handler file is loaded once per execution environment, so Rails boots during init and stays loaded across invocations. Guard every Lambda-only line with `ENV['AWS_LAMBDA_FUNCTION_NAME']` so development, tests and Puma are unaffected.

## Configuration and secrets

- Plain settings go in the function's environment variables, built in `tf/locals.tf` and shared by all three functions.
- Secrets live in SSM Parameter Store. For each one, set `SSM_SECRET__<NAME>=<parameter ARN>`; `lambda_boot.rb` fetches them with `GetParameters` (10 names per call) from `config/boot.rb`, before any initializer reads `ENV`. Lambda environment variables are visible to anyone who can read the function configuration, and limited to 4 KB in total.
- The execution role needs `ssm:GetParameters` on exactly those ARNs, and `kms:Decrypt` if the parameters use a customer managed key.
- `secret_key_base` and other credentials come in the same way; there is no `master.key` in the image.
- Set `WEB_CONCURRENCY=0` (no Puma cluster) and a small `RAILS_MAX_THREADS`, which sizes the Active Record pool. Total database connections are roughly concurrent environments × pool, across all functions. Cap them with reserved concurrency, or use RDS Proxy or DSQL.
- Log to stdout (`RAILS_LOG_TO_STDOUT=1`, `ActiveSupport::TaggedLogging.logger($stdout)`); Lambda sends it to `/aws/lambda/<function>`. Create that log group in Terraform to set a retention.
- Sentry: `config.background_worker_threads = 0` on Lambda, so events are sent before the handler returns. Apply the same to any library that reports from a background thread.

## Web: function URL behind CloudFront

- The function URL uses `authorization_type = "NONE"`. CloudFront adds a random `x-origin-verify` header, kept in SSM as `CLOUDFRONT_VERIFY`, and `Apigatewayv2Rack::Middlewares::CloudfrontVerify` answers 401 to requests without it. CloudFront OAC is not an option for a Rails app: with OAC, viewers must send `x-amz-content-sha256` for every request body, which browser forms do not.
- Do not forward the viewer's `Host`; the function URL answers only to its own. CloudFront sends `x-forwarded-host: <app domain>` as an origin custom header instead, and Rails builds URLs from it. The origin check is what makes trusting that header safe.
- `Apigatewayv2Rack::Middlewares::CloudfrontXff` rewrites `X-Forwarded-For` from `CloudFront-Viewer-Address` and sets `REMOTE_ADDR` to `127.0.0.1`, so `request.remote_ip` is the client's. `Managed-AllViewerExceptHostHeader` includes that header; a custom origin request policy or legacy `forwarded_values` must list it explicitly, or every client looks like CloudFront.
- Set `config.assume_ssl = true` and `config.force_ssl = true`.
- Serve fingerprinted assets from the app (`RAILS_SERVE_STATIC_FILES=1`) and cache their path in CloudFront with `Managed-CachingOptimized`; disable caching for everything else. With legacy `forwarded_values`, also allowlist the session and locale cookies and the headers the app reads (`X-CSRF-Token`, `Origin`), or they never reach Rails.
- Uploads go straight to S3 with presigned URLs, never through the function, because of the 6 MB payload limit.

## Jobs: Lambdakiq

[Lambdakiq](https://github.com/rails-lambda/lambdakiq) is an ActiveJob adapter that enqueues to SQS; an event source mapping delivers messages to the `lambdakiq` function, which performs them.

- Include `Lambdakiq::Worker` in `ActiveJob::Base` and `ActionMailer::MailDeliveryJob`, and `queue_as ENV['LAMBDAKIQ_QUEUE']`. Select the adapter by `JOB_ADAPTER`, defaulting to `:inline` for development.
- Event source mapping: `batch_size = 1` and `function_response_types = ["ReportBatchItemFailures"]` (required by Lambdakiq).
- Queue: `visibility_timeout_seconds` just above the function timeout (301 for 300), and `maxReceiveCount = 13` on the redrive policy, which is Lambdakiq's 12 retries plus the first attempt. Lambdakiq applies Sidekiq's backoff by changing message visibility; `lambdakiq_options retry: n` lowers it per job.
- `set(wait:)` beyond 15 minutes does not work. Store a due time and have a scheduled task pick it up.
- Scheduled work: an EventBridge Scheduler schedule that invokes the `runner` function with `{"run": ["bin/rails", "runner", "..."]}`, or a small dedicated handler. Lambdakiq has no cron.
- Lambdakiq writes CloudWatch embedded metrics (namespace `Lambdakiq`, dimensions `AppName`, `JobEvent`, `JobName`) to the log; alarm on those and on the DLQ depth.

## One-off commands: runner

The `runner` function runs any command in the app image and returns `{ok, status, output, duration}`. `deploy/lambrunner.rb <function> <command...>` invokes it synchronously, prints the output and exits with the command's status, so it drops into CI or a terminal:

```sh
BUNDLE_GEMFILE=deploy/Gemfile bundle exec deploy/lambrunner.rb myapp-runner-prd bundle exec rake db:migrate
```

- Give it more memory than `web` and the 900 s maximum timeout. Anything longer, or interactive (`rails console`), needs ECS (or ECS Exec) with the same image.
- `lambda:InvokeFunction` on the runner is arbitrary command execution as the app's role. Grant it only to the deploy role and operators.
- Output is cut at 5 MB to fit the 6 MB response limit. On a function error, the CLI prints the last 4 KB of the log; read the rest in CloudWatch by the `RUNCMD <request id>` line.

## Deploy

Terraform creates the functions and ignores `image_uri`. CI owns the code: build and push the image tagged with the commit SHA, then, in order:

1. `update-function-code` on `runner`, `aws lambda wait function-updated`.
2. `lambrunner.rb ... rake db:migrate` (or `db:prepare`, or the schema task the app uses).
3. `update-function-code` on `lambdakiq`, then `web`, each followed by `wait function-updated`.

Migrate first so neither jobs nor requests run new code against an old schema; keep each schema change compatible with the code still running. Jobs go before web so jobs enqueued by new code find new code. Run one deploy at a time (`concurrency: production`).

- The function URL points at `$LATEST`, so an update takes effect for new execution environments right away. Roll back by running the same `update-function-code` with the previous image tag.
- The deploy role needs `lambda:UpdateFunctionCode` and `lambda:GetFunctionConfiguration` on the three functions, `lambda:InvokeFunction` on the runner, and read access to the ECR repository.
- The first `terraform apply` needs an image that already exists in ECR; pass it as `initial_image_uri`.
