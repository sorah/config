# Lambda-relevant parts only. The same image runs Puma on ECS or locally through docker_entrypoint.sh,
# and the Lambda functions override the entrypoint with lambda_entrypoint.sh.

FROM public.ecr.aws/docker/library/node:24-trixie-slim AS assets
WORKDIR /app
RUN corepack enable
COPY package.json pnpm-lock.yaml /app/
RUN pnpm install --frozen-lockfile
COPY . /app/
RUN NODE_ENV=production pnpm run build

###

FROM ghcr.io/sorah-rbpkg/ruby:4.0-dev AS builder

RUN apt-get update \
 && apt-get install --no-install-recommends -y libpq-dev libyaml-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock /app/
RUN bundle config set deployment true \
 && bundle config set without development:test \
 && bundle config set path /gems
RUN bundle install
RUN BUNDLE_BIN=/usr/local/bin bundle binstubs bundler aws_lambda_ric --force

###

FROM ghcr.io/sorah-rbpkg/ruby:4.0

RUN apt-get update \
 && apt-get install --no-install-recommends -y libpq5 libyaml-0-2 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# Lambda mounts the image read-only except /tmp.
RUN ln -s /tmp/apptmp /app/tmp
COPY --from=builder /gems /gems
COPY --from=builder /app/.bundle /app/.bundle
COPY --from=builder /usr/local/bin/bundle /usr/local/bin/aws_lambda_ric /usr/local/bin/
COPY --from=assets /app/public/vite /app/public/vite
COPY . /app/

ENV BOOTSNAP_CACHE_DIR=/bootsnap
RUN mkdir -p /bootsnap && bundle exec bootsnap precompile --gemfile app/ lib/ config/
ENV BOOTSNAP_READONLY=1

COPY config/lambda_entrypoint.sh /lambda_entrypoint.sh
COPY config/docker_entrypoint.sh /docker_entrypoint.sh

ENV PORT=3000
ENV LANG=C.UTF-8
ENTRYPOINT ["/docker_entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
