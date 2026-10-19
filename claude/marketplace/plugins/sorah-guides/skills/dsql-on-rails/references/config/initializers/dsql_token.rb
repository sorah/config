# frozen_string_literal: true

# Mints DSQL IAM auth tokens for pg-aws_rds_iam (`aws_rds_iam_auth_token_generator: dsql` in database.yml).
class DsqlAuthTokenGenerator
  def call(host:, port:, user:)
    # A token signed at travelled time fails with "Signature not yet current"; TimeHelpers cannot be suspended, Timecop can.
    if defined?(Timecop)
      Timecop.return { generate_token(host: host, user: user) }
    else
      generate_token(host: host, user: user)
    end
  end

  private def generate_token(host:, user:)
    # e.g. host == "<clusterID>.dsql.us-east-1.on.aws"
    region = host.split(".")[2]
    raise "Unable to extract AWS region from host '#{host}'" unless region&.match?(/\A[a-z0-9-]+\z/)

    token_generator = Aws::DSQL::AuthTokenGenerator.new(
      credentials: Aws::CredentialProviderChain.new.resolve,
    )

    auth_token_params = {
      endpoint: host,
      region: region,
      expires_in: 15 * 60,
    }

    case user
    when "admin"
      token_generator.generate_db_connect_admin_auth_token(auth_token_params)
    else
      token_generator.generate_db_connect_auth_token(auth_token_params)
    end
  end
end

PG::AWS_RDS_IAM.auth_token_generators.add :dsql do
  DsqlAuthTokenGenerator.new
end
