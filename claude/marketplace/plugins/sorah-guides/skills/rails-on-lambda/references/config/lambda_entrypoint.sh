#!/bin/bash
# _HANDLER is reserved on Lambda, so the function sets APP_HANDLER instead.
export _HANDLER="${APP_HANDLER}"
# Only /tmp is writable. The image links /app/tmp to /tmp/apptmp.
mkdir -p /tmp/home /tmp/apptmp
export HOME=/tmp/home
exec /usr/local/bin/aws_lambda_ric
